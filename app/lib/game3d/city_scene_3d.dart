import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../models/city.dart';
import 'city3d_config.dart';
import 'city3d_layout.dart';
import 'model_cache.dart';

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
  Object? _texGrass, _texSoil, _texStone;
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

    // Load the ground + cloud textures, then build the plot.
    _texGrass = await _models.texture(kCity3DTexGrass);
    _texSoil = await _models.texture(kCity3DTexSoil);
    _texStone = await _models.texture(kCity3DTexStone);

    // The revealed plot (grass + wall), the cloud frontier, trees, buildings.
    _buildPlot();

    await _models.warmUp();
  }

  void _cloud(Node n) {
    scene.add(n);
    _cloudNodes.add(n);
  }

  /// Lit material (PlaneGeometry/SphereGeometry only — they have normals)
  /// carrying a texture. [doubleSided] for thin wall faces seen from both sides.
  PhysicallyBasedMaterial _mat(Object? tex,
      {double rough = 0.95, bool doubleSided = false}) {
    final m = PhysicallyBasedMaterial()
      ..metallicFactor = 0.0
      ..roughnessFactor = rough
      ..doubleSided = doubleSided;
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

  /// (Re)builds the plot as ONE natural, cohesive grass surface (no per-cell
  /// lots / sidewalks / street grid — nothing that reads as a board). The grid
  /// stays in logic only; buildings still snap to invisible cells. A soil apron
  /// frames the plot. Sized to [_plotSize], centered on the grid origin. Trees
  /// scatter after for life.
  void _buildPlot() {
    for (final n in _plotNodes) {
      scene.remove(n);
    }
    _plotNodes.clear();

    final half = plotHalfExtentWorld(_plotSize);
    final span = half * 2;

    // Soil apron framing the plot (lit PlaneGeometry, has normals).
    _addPlot(Node(
      mesh: Mesh(PlaneGeometry(width: span + 1.4, depth: span + 1.4),
          _mat(_texSoil, rough: 0.95)),
    )..localTransform = vm.Matrix4.translation(vm.Vector3(0, -0.12, 0)));

    // One continuous grass surface — cohesive, no visible grid. Buildings sit
    // on it at y=0, snapping to the (invisible) logical cells.
    _addPlot(Node(
      mesh: Mesh(PlaneGeometry(width: span, depth: span),
          _mat(_texGrass, rough: 0.95)),
    )..localTransform = vm.Matrix4.translation(vm.Vector3(0, 0.0, 0)));

    _buildWall(half, span);
    _buildCloudFrontier(half, span);
    _scatterTrees();
    _updateBuildHighlights();
  }

  /// A low-poly stone wall ringing the plot, built from LIT PlaneGeometry faces
  /// (no CuboidGeometry → no prismatic-edge fringe). Each side is a thin
  /// double-sided vertical face + a horizontal top cap; lighting makes the cap
  /// read brighter than the face. The grass (y=0) sits a wall-height below the
  /// cap, so the developed area reads as sunken inside a retaining wall.
  void _buildWall(double half, double span) {
    const h = kCity3DWallHeight;
    const cy = h / 2 - 0.1; // face center (dips slightly under the grass)
    const top = h - 0.1; // wall top
    final len = span + 0.6; // overlap the corners
    Node face(PlaneGeometry g) =>
        Node(mesh: Mesh(g, _mat(_texStone, rough: 0.9, doubleSided: true)));
    Node cap(PlaneGeometry g) =>
        Node(mesh: Mesh(g, _mat(_texStone, rough: 0.9)));

    for (final z in [half, -half]) {
      _addPlot(face(PlaneGeometry(width: len, depth: h))
        ..localTransform =
            (vm.Matrix4.translation(vm.Vector3(0, cy, z))..rotateX(pi / 2)));
      _addPlot(cap(PlaneGeometry(width: len, depth: 0.7))
        ..localTransform = vm.Matrix4.translation(vm.Vector3(0, top, z)));
    }
    for (final x in [half, -half]) {
      _addPlot(face(PlaneGeometry(width: h, depth: len))
        ..localTransform =
            (vm.Matrix4.translation(vm.Vector3(x, cy, 0))..rotateZ(pi / 2)));
      _addPlot(cap(PlaneGeometry(width: 0.7, depth: len))
        ..localTransform = vm.Matrix4.translation(vm.Vector3(x, top, 0)));
    }
  }

  /// The cloud frontier: instead of cloud blobs on the ground, a ring of soft
  /// fluffy WHITE clouds just outside the wall that RISE well above it, hiding
  /// everything beyond. Lit puffs (volume + soft shadow); stacked vertically
  /// into a billowing bank. (The logical chunk world model is untouched — this
  /// is visual-only.)
  void _buildCloudFrontier(double half, double span) {
    for (final n in _cloudNodes) {
      scene.remove(n);
    }
    _cloudNodes.clear();
    // Ring sits just OUTSIDE the wall so the wall stays visible in front and
    // the clouds rise beyond it (inner edge ≈ wall outer face, no cream gap).
    final outer = half + 5.5;
    final n = (span / 8).ceil() + 1;
    const layers = [(1.2, 5.0), (5.6, 4.5)];
    void column(double x, double z) {
      for (final (y, r) in layers) {
        _cloud(Node(
          mesh: Mesh(SphereGeometry(radius: r, segments: 12, rings: 7),
              _unlit(kCity3DCloudColor)),
        )..localTransform = (vm.Matrix4.translation(vm.Vector3(x, y, z))
          ..scaleByDouble(1.0, 0.85, 1.0, 1)));
      }
    }

    for (var i = 0; i <= n; i++) {
      final t = -outer + (2 * outer) * (i / n); // -outer..+outer along a side
      column(t, outer); // north edge
      column(t, -outer); // south edge
      column(outer, t); // east edge
      column(-outer, t); // west edge
    }
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

  /// In build/move mode, tints OCCUPIED (blocked) plot cells RED so the player
  /// sees where they can't place. Valid cells get no marking. Cleared when not
  /// in build/move mode, so the grid is invisible normally.
  void _updateBuildHighlights() {
    for (final n in _highlights.values) {
      scene.remove(n);
    }
    _highlights.clear();
    if (!widget.buildMode) return;
    final (lo, hi) = plotRange(_plotSize);
    const t = kCell3DSpacing * 0.92;
    for (var gx = lo; gx <= hi; gx++) {
      for (var gy = lo; gy <= hi; gy++) {
        if (!_spec.containsKey(cellKey(gx, gy))) continue; // only occupied
        final w = cellToWorld(gx, gy, gridSize: widget.gridSize);
        final n = Node(
          mesh: Mesh(PlaneGeometry(width: t, depth: t),
              _unlit(kCity3DBlockedColor)),
        )..localTransform = vm.Matrix4.translation(vm.Vector3(w.x, 0.04, w.z));
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
