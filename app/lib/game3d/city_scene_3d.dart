import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../models/city.dart';
import 'city3d_config.dart';
import 'city3d_layout.dart';
import 'model_cache.dart';
import 'world_chunks.dart';

/// 3D city view bound to the real city data (Stage 3): a warm, lit diorama
/// with soft shadows and a ground plane, rendering the player's actual
/// [buildings] — type → model, (gridX, gridY) → world position, level → scale.
///
/// The same `watchCity` stream that feeds the Flame board feeds this widget;
/// only the renderer differs. It's shown only when `kUse3DCity` is true.
/// Interaction (tap/place/upgrade) is unchanged for now — that's Stage 4.
class CityScene3D extends StatefulWidget {
  const CityScene3D({
    super.key,
    required this.buildings,
    this.cityLevel = 1,
    this.gridSize = kCity3DMaxGrid,
    this.onCellTapped,
    this.selectedCell,
    this.buildMode = false,
    this.anchorSink,
  });

  /// The player's placed buildings, straight from the city model. A new list
  /// instance on each stream update triggers reconciliation.
  final List<PlacedBuilding> buildings;

  /// The player's current city level — the buildable plot grows with it.
  final int cityLevel;

  /// Grid dimension the coordinates are anchored to (matches the Flame board);
  /// the plot is a centered sub-region that grows with [cityLevel].
  final int gridSize;

  /// True while arming a placement / relocating, so empty plot cells highlight.
  final bool buildMode;

  /// Called when the player taps an in-bounds grid cell. Routes to the same
  /// select / place / move logic the Flame board uses (`_onCellTapped`).
  final void Function(int gx, int gy)? onCellTapped;

  /// The currently selected cell, lifted + highlighted in the scene.
  final ({int x, int y})? selectedCell;

  /// Receives the screen-space anchor (a point just above the selected
  /// building) each frame, so the parent can float the upgrade popup over it.
  /// Set to null when nothing is selected or it's off-screen.
  final ValueNotifier<Offset?>? anchorSink;

  @override
  State<CityScene3D> createState() => _CityScene3DState();
}

class _CityScene3DState extends State<CityScene3D> {
  final Scene scene = Scene();
  final City3DModels _models = City3DModels();
  late final Ticker _ticker;
  late final Future<void> _ready;

  // --- Orbit camera state -----------------------------------------------
  double _yaw = pi / 4; // 45° — classic iso feel
  double _pitch = 0.62; // ~35° above the ground
  double _radius = 17;
  final vm.Vector3 _target = vm.Vector3(0, 0.6, 0);

  static const double _minRadius = 5; // zoom-in limit (get close)
  static const double _minPitch = 0.12;
  static const double _maxPitch = 1.45;
  static const double _fovRadiansY = 45 * pi / 180; // matches PerspectiveCamera
  static const double _cityMargin = 3.0; // world units around the city

  // Zoom-out limit, derived from the city's extent so the whole city fits at
  // max zoom-out (and adapts as the city grows). Recomputed when buildings
  // change; floored so a tiny/empty city still pulls back sensibly.
  double _maxRadius = 40;

  double _gestureStartRadius = 17;
  Size _viewSize = Size.zero;

  // --- Plot state (the buildable island) --------------------------------
  int _plotSize = kCity3DBasePlot;
  final List<Node> _plotNodes = []; // base + asphalt + lots + sidewalks
  final List<Node> _treeNodes = []; // scattered street trees
  final Map<String, Node> _highlights = {}; // build-mode empty-cell markers
  int _treeGen = 0; // guards async tree scatter against stale rebuilds
  // Street-top textures (colour baked in). Loaded once in _init.
  Object? _texGrass, _texAsphalt, _texSidewalk, _texSoil, _texCloud;
  final List<Node> _cloudNodes = []; // static hidden-chunk cloud cover

  // --- City reconciliation state ----------------------------------------
  // cellKey → the node currently rendering that cell, and the spec it renders.
  final Map<String, Node> _placed = {};
  final Map<String, PlacedBuilding> _spec = {};
  List<PlacedBuilding> _desired = const [];
  int _targetGen = 0; // bumped whenever a new buildings list arrives
  int _appliedGen = -1; // last generation fully reflected in the scene
  bool _busy = false; // a reconcile pass is running

  @override
  void initState() {
    super.initState();
    _plotSize = _computePlotSize();
    _ready = _init();
    _desired = widget.buildings;
    _targetGen = 1;
    _recomputeMaxRadius();
    _pump();
    // Continuous repaint keeps the 3D view live and smooth. Updating the popup
    // anchor here (between frames) — not during build — avoids notifying the
    // parent's ValueListenableBuilder mid-build.
    _ticker = Ticker((_) {
      if (!mounted) return;
      _updateAnchor();
      setState(() {});
    })..start();
  }

  @override
  void didUpdateWidget(CityScene3D old) {
    super.didUpdateWidget(old);
    // The city model hands us a fresh list on every real update, so an identity
    // check is enough to skip unrelated rebuilds (tray toggles, etc.).
    if (!identical(old.buildings, widget.buildings)) {
      _desired = widget.buildings;
      _targetGen++;
      _pump();
    }
    // Grow the plot if the level (or building spread) changed.
    final newPlot = _computePlotSize();
    final plotChanged = newPlot != _plotSize;
    if (plotChanged) {
      _plotSize = newPlot;
      _recomputeMaxRadius(); // framing tracks the plot
      _ready.then((_) {
        if (mounted) _buildPlot(); // also refreshes highlights
      });
    }
    // Re-apply the transform of the de-selected and newly-selected cells so the
    // highlight lift follows the selection.
    if (old.selectedCell != widget.selectedCell) {
      for (final cell in [old.selectedCell, widget.selectedCell]) {
        if (cell == null) continue;
        final key = cellKey(cell.x, cell.y);
        final node = _placed[key];
        final spec = _spec[key];
        if (node != null && spec != null) _transformFor(node, spec);
      }
    }
    // Refresh build-mode highlights when build mode toggles or buildings
    // change (plot growth already refreshes them via _buildPlot).
    if (!plotChanged &&
        (old.buildMode != widget.buildMode ||
            !identical(old.buildings, widget.buildings))) {
      _ready.then((_) {
        if (mounted) _updateBuildHighlights();
      });
    }
  }

  int _computePlotSize() {
    final cells = widget.buildings.map((b) => (x: b.gridX, y: b.gridY));
    return max(
      plotSizeForLevel(widget.cityLevel),
      requiredPlotForCells(cells),
    );
  }

  Future<void> _init() async {
    await Scene.initializeStaticResources();

    // --- Warm, cozy diorama lighting (proven in the prototype) ------------
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(0.5, -0.82, 0.42),
      color: vm.Vector3(1.0, 0.89, 0.70), // golden key
      intensity: 4.8,
      castsShadow: true,
      shadowSoftness: 0.25,
      shadowMapResolution: 2048,
      shadowNormalBias: 0.04,
    );
    scene.environmentIntensity = 0.5;

    // Warm color grade + gentle bloom + vignette. colorGrading defaults OFF;
    // post-process changes only apply on a COLD restart, not hot reload.
    scene.postProcess.colorGrading
      ..enabled = true
      ..temperature = 0.55
      ..saturation = 1.14
      ..brightness = 1.02
      ..gain = vm.Vector3(1.06, 1.0, 0.9);
    scene.postProcess.bloom
      ..enabled = true
      ..threshold = 1.1
      ..intensity = 0.25
      ..scatter = 0.7;
    scene.postProcess.vignette
      ..enabled = true
      ..intensity = 0.32
      ..radius = 0.85
      ..smoothness = 0.6;

    // Load the street-top textures, then build the plot.
    _texGrass = await _models.texture(kCity3DTexGrass);
    _texAsphalt = await _models.texture(kCity3DTexAsphalt);
    _texSidewalk = await _models.texture(kCity3DTexSidewalk);
    _texSoil = await _models.texture(kCity3DTexSoil);
    _texCloud = await _models.texture(kCity3DTexCloud);

    // The revealed (current) city plot — streets, lots, trees, buildings.
    _buildPlot();
    // The surrounding hidden chunks, covered in cloud (fog of war).
    _buildHiddenChunks();

    await _models.warmUp();
  }

  /// Deterministic cloud-puff layout within a chunk (dx, dz from chunk center,
  /// radius). Covers the 24-unit chunk with a few overlapping low-poly puffs.
  /// Renders the hidden world chunks as a fluffy WHITE cloud bank — LIT puffs
  /// (volume + soft self-shadowing) over a solid soft floor that hides what's
  /// beneath. A grid of overlapping puffs reaches in to hug the revealed plot's
  /// edge (no beige gap), and is culled to a band near the city. Static.
  void _buildHiddenChunks() {
    final half = plotHalfExtentWorld(_plotSize);
    final cull = half + 16; // how far the cloud band extends from origin
    for (final ch in defaultWorld()) {
      if (ch.revealed) continue;
      final o = chunkWorldOffset(ch.col, ch.row);
      // Solid soft floor over the chunk (lit white) — hides what's beneath and
      // hugs the plot edge at the shared boundary.
      _cloud(Node(
        mesh: Mesh(PlaneGeometry(width: kChunkSpan, depth: kChunkSpan),
            _mat(_texCloud, rough: 1.0)),
      )..localTransform = vm.Matrix4.translation(vm.Vector3(o.x, 0.35, o.z)));
      // Overlapping fluffy puffs (grid), culled to the band near the city.
      var i = 0;
      for (final dx in const [-10.0, 0.0, 10.0]) {
        for (final dz in const [-10.0, 0.0, 10.0]) {
          final wx = o.x + dx, wz = o.z + dz;
          i++;
          if (max(wx.abs(), wz.abs()) > cull) continue;
          final r = 4.4 + ((i % 3) - 1) * 0.7; // 3.7..5.1 size variation
          final y = 1.1 + (i % 2) * 0.5;
          _cloud(Node(
            mesh: Mesh(SphereGeometry(radius: r, segments: 12, rings: 7),
                _mat(_texCloud, rough: 1.0)),
          )..localTransform =
              (vm.Matrix4.translation(vm.Vector3(wx, y, wz))
                ..scaleByDouble(1.0, 0.65, 1.0, 1)));
        }
      }
    }
  }

  void _cloud(Node n) {
    scene.add(n);
    _cloudNodes.add(n);
  }

  /// Lit material (PlaneGeometry only — it has normals) carrying a grass tex.
  PhysicallyBasedMaterial _mat(Object? tex, {double rough = 0.95}) {
    final m = PhysicallyBasedMaterial()
      ..metallicFactor = 0.0
      ..roughnessFactor = rough;
    if (tex != null) m.baseColorTexture = tex as dynamic;
    return m;
  }

  /// Unlit material whose [c] colour renders directly (works on any geometry,
  /// no normals/lighting needed) — used for the island base + highlights.
  UnlitMaterial _unlit(List<double> c) => UnlitMaterial()
    ..baseColorFactor = vm.Vector4(c[0], c[1], c[2], c.length > 3 ? c[3] : 1.0);

  void _addPlot(Node n) {
    scene.add(n);
    _plotNodes.add(n);
  }

  /// (Re)builds the plot as a street-organized city block: a layered island
  /// base, one asphalt street layer, and a sidewalk + grass lot per cell (the
  /// gaps between lots form the streets). Sized to [_plotSize], centered on the
  /// grid origin. Buildings sit on the grass lots at y=0. Trees scatter after.
  void _buildPlot() {
    for (final n in _plotNodes) {
      scene.remove(n);
    }
    _plotNodes.clear();

    final half = plotHalfExtentWorld(_plotSize);
    final span = half * 2;

    // Flat lit soil ground (PlaneGeometry → has normals; replaces the
    // no-normals cuboid whose hard silhouette fringed at grazing angles). A
    // soil apron around the streets reads as the plot without raised sides.
    _addPlot(Node(
      mesh: Mesh(PlaneGeometry(width: span + 1.4, depth: span + 1.4),
          _mat(_texSoil, rough: 0.95)),
    )..localTransform = vm.Matrix4.translation(vm.Vector3(0, -0.12, 0)));

    // Three stacked surfaces — street < sidewalk < grass — spaced into real
    // curb heights so they never z-fight at grazing angles. Asphalt is inset so
    // a soil rim shows around the plot.
    _addPlot(Node(
      mesh: Mesh(PlaneGeometry(width: span - 0.4, depth: span - 0.4),
          _mat(_texAsphalt, rough: 0.85)),
    )..localTransform = vm.Matrix4.translation(vm.Vector3(0, -0.10, 0)));

    final (lo, hi) = plotRange(_plotSize);
    for (var gx = lo; gx <= hi; gx++) {
      for (var gy = lo; gy <= hi; gy++) {
        final w = cellToWorld(gx, gy, gridSize: widget.gridSize);
        _addPlot(Node(
          mesh: Mesh(
              PlaneGeometry(
                  width: kCity3DSidewalkSize, depth: kCity3DSidewalkSize),
              _mat(_texSidewalk, rough: 0.9)),
        )..localTransform =
            vm.Matrix4.translation(vm.Vector3(w.x, -0.045, w.z)));
        _addPlot(Node(
          mesh: Mesh(
              PlaneGeometry(width: kCity3DLotSize, depth: kCity3DLotSize),
              _mat(_texGrass, rough: 0.9)),
        )..localTransform = vm.Matrix4.translation(vm.Vector3(w.x, 0.0, w.z)));
      }
    }

    _scatterTrees();
    _updateBuildHighlights();
  }

  /// Scatters sparse low-poly trees at street intersections (boundary corners,
  /// so they never sit on a buildable lot). Async (GLB load); a generation
  /// token ensures a newer plot rebuild wins over an in-flight scatter.
  Future<void> _scatterTrees() async {
    for (final n in _treeNodes) {
      scene.remove(n);
    }
    _treeNodes.clear();
    final gen = ++_treeGen;
    final models = kCity3DTreeModels;
    if (models.isEmpty) return;
    for (final s in treeSpots(_plotSize, models: models.length)) {
      final node =
          await _models.prop(models[s.model], footprint: kCity3DTreeFootprint);
      if (!mounted || gen != _treeGen) return; // superseded
      final a = cellToWorld(s.i, s.j, gridSize: widget.gridSize);
      final b = cellToWorld(s.i + 1, s.j + 1, gridSize: widget.gridSize);
      node.localTransform = vm.Matrix4.translation(
          vm.Vector3((a.x + b.x) / 2, 0, (a.z + b.z) / 2));
      scene.add(node);
      _treeNodes.add(node);
    }
  }

  /// In build mode, marks every empty plot cell with a bright tile so the
  /// player sees where they can drop. Cleared otherwise.
  void _updateBuildHighlights() {
    for (final n in _highlights.values) {
      scene.remove(n);
    }
    _highlights.clear();
    if (!widget.buildMode) return;
    final (lo, hi) = plotRange(_plotSize);
    const t = kCell3DSpacing * 0.9;
    for (var gx = lo; gx <= hi; gx++) {
      for (var gy = lo; gy <= hi; gy++) {
        if (_spec.containsKey(cellKey(gx, gy))) continue; // occupied
        final w = cellToWorld(gx, gy, gridSize: widget.gridSize);
        final n = Node(
          mesh: Mesh(PlaneGeometry(width: t, depth: t),
              _unlit(kCity3DHighlightColor)),
        )..localTransform = vm.Matrix4.translation(vm.Vector3(w.x, 0.02, w.z));
        scene.add(n);
        _highlights[cellKey(gx, gy)] = n;
      }
    }
  }

  /// Serialized reconcile loop. Always drives the scene toward the latest
  /// [_desired]; if a new list arrives while a pass is mid-flight (across an
  /// await), the while-loop picks it up before exiting. Single-threaded Dart
  /// guarantees no interleaving outside await points, so this can't drop an
  /// update or run two passes at once.
  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      await _ready;
      while (_appliedGen != _targetGen) {
        final gen = _targetGen;
        await _applyTarget(_desired);
        _appliedGen = gen;
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _applyTarget(List<PlacedBuilding> target) async {
    final diff = diffCity(_spec, target);

    for (final key in diff.toRemove) {
      final node = _placed.remove(key);
      if (node != null) scene.remove(node);
      _spec.remove(key);
    }

    for (final b in diff.toAdd) {
      final node = await _models.newBuilding(b.typeId);
      _transformFor(node, b);
      if (!mounted) return; // widget went away mid-load
      scene.add(node);
      _placed[cellKey(b.gridX, b.gridY)] = node;
      _spec[cellKey(b.gridX, b.gridY)] = b;
    }

    for (final b in diff.toUpdate) {
      final node = _placed[cellKey(b.gridX, b.gridY)];
      if (node != null) _transformFor(node, b);
      _spec[cellKey(b.gridX, b.gridY)] = b;
    }

    // Keep build-mode highlights in sync with occupancy after a reconcile.
    if (widget.buildMode && (diff.toAdd.isNotEmpty || diff.toRemove.isNotEmpty)) {
      _updateBuildHighlights();
    }
  }

  void _transformFor(Node node, PlacedBuilding b) {
    final pos = cellToWorld(b.gridX, b.gridY, gridSize: widget.gridSize);
    final sel = widget.selectedCell;
    if (sel != null && sel.x == b.gridX && sel.y == b.gridY) {
      pos.y += _selectionLift; // hop the selected building up a touch
    }
    final s = scaleForLevel(b.level);
    node.localTransform = vm.Matrix4.translation(pos)..scaleByDouble(s, s, s, 1);
  }

  static const double _selectionLift = 0.5;

  /// Anchor height (world units) above a cell where the popup should point.
  static const double _anchorHeight = 2.4;

  // --- Tap → grid cell --------------------------------------------------
  void _onTapUp(TapUpDetails d) {
    final cb = widget.onCellTapped;
    if (cb == null || _viewSize == Size.zero) return;
    final ray = _screenRay(d.localPosition);
    if (ray == null) return;
    final hit = rayGroundHit(ray.origin, ray.dir);
    if (hit == null) return;
    final cell = worldToCell(hit.x, hit.z, gridSize: widget.gridSize);
    // Only cells within the unlocked plot are interactive.
    if (!cellInPlot(cell.x, cell.y, _plotSize)) return;
    cb(cell.x, cell.y);
  }

  /// Builds a world-space ray from a screen point through the camera.
  ({vm.Vector3 origin, vm.Vector3 dir})? _screenRay(Offset local) {
    final cam = _camera();
    final worldFromClip = vm.Matrix4.inverted(cam.getViewTransform(_viewSize));
    final ndcX = (local.dx / _viewSize.width) * 2 - 1;
    final ndcY = 1 - (local.dy / _viewSize.height) * 2;
    final v = vm.Vector4(ndcX, ndcY, 1, 1)..applyMatrix4(worldFromClip);
    if (v.w == 0) return null;
    final far = vm.Vector3(v.x / v.w, v.y / v.w, v.z / v.w);
    final origin = cam.position;
    return (origin: origin, dir: (far - origin)..normalize());
  }

  /// Projects the selected cell's anchor to a screen point (null if behind the
  /// camera or nothing selected), and pushes it to [widget.anchorSink].
  void _updateAnchor() {
    final sink = widget.anchorSink;
    if (sink == null) return;
    final sel = widget.selectedCell;
    if (sel == null || _viewSize == Size.zero) {
      sink.value = null;
      return;
    }
    final w = cellToWorld(sel.x, sel.y, gridSize: widget.gridSize);
    final clip = _camera().getViewTransform(_viewSize);
    final v = vm.Vector4(w.x, _anchorHeight, w.z, 1)..applyMatrix4(clip);
    if (v.w <= 0) {
      sink.value = null;
      return;
    }
    sink.value = Offset(
      (v.x / v.w * 0.5 + 0.5) * _viewSize.width,
      (1 - (v.y / v.w * 0.5 + 0.5)) * _viewSize.height,
    );
  }

  /// Recomputes the zoom-out limit so the whole PLOT fits at max zoom-out
  /// (tracks plot size, not just the buildings, so the framing grows with the
  /// island). Floored for tiny plots, capped so it never goes absurd.
  void _recomputeMaxRadius() {
    final half = plotHalfExtentWorld(_plotSize) + _cityMargin;
    final fit = fitRadius(half, half, _fovRadiansY);
    _maxRadius = fit.clamp(18.0, 110.0);
    // Never let the current radius exceed the new cap.
    if (_radius > _maxRadius) _radius = _maxRadius;
  }

  PerspectiveCamera _camera() {
    final cp = cos(_pitch);
    final eye = _target +
        vm.Vector3(
          _radius * cp * sin(_yaw),
          _radius * sin(_pitch),
          _radius * cp * cos(_yaw),
        );
    // Tight near/far for the small diorama → far better depth precision, which
    // kills z-fighting (rainbow shimmer) between the close ground layers. The
    // default far is 1000, which wrecks precision at this scale.
    return PerspectiveCamera(
      position: eye,
      target: _target.clone(),
      fovNear: 0.5,
      fovFar: 160,
    );
  }

  // --- Gesture handling -------------------------------------------------
  // One unified scale recognizer drives all three controls:
  //   • 1 finger  → orbit (yaw/pitch)
  //   • 2 fingers → pinch-zoom (radius) + two-finger pan (move target)
  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartRadius = _radius;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount >= 2) {
        _radius =
            (_gestureStartRadius / d.scale).clamp(_minRadius, _maxRadius);
        _panTarget(d.focalPointDelta);
      } else {
        _yaw -= d.focalPointDelta.dx * 0.01;
        _pitch =
            (_pitch + d.focalPointDelta.dy * 0.01).clamp(_minPitch, _maxPitch);
      }
    });
  }

  /// Slides [_target] along the ground by a screen-space [delta], mapped to
  /// world right/forward via the current yaw, scaled by radius so the world
  /// keeps pace with the fingers at any zoom level.
  void _panTarget(Offset delta) {
    final perPixel = _radius * 0.0016;
    final right = vm.Vector3(cos(_yaw), 0, -sin(_yaw));
    final forward = vm.Vector3(sin(_yaw), 0, cos(_yaw));
    _target
      ..add(right * (-delta.dx * perPixel))
      ..add(forward * (delta.dy * perPixel));
  }

  @override
  void dispose() {
    widget.anchorSink?.value = null;
    _ticker.dispose();
    scene.removeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.hasError) {
          return ColoredBox(
            color: const Color(0xFF12131C),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '3D scene failed:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            _viewSize = constraints.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Warm gradient sky behind the scene (the renderer leaves
                  // non-geometry areas transparent, so this shows through).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFE9C9), Color(0xFFF3C39A)],
                      ),
                    ),
                  ),
                  if (snap.connectionState != ConnectionState.done)
                    const Center(child: CircularProgressIndicator())
                  else
                    CustomPaint(
                      painter: _ScenePainter(scene, _camera()),
                      size: _viewSize,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.camera);
  final Scene scene;
  final PerspectiveCamera camera;

  @override
  void paint(Canvas canvas, Size size) {
    scene.render(camera, canvas, viewport: Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => true;
}
