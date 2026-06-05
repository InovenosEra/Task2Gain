import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../models/city.dart';
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
    this.gridSize = 10,
  });

  /// The player's placed buildings, straight from the city model. A new list
  /// instance on each stream update triggers reconciliation.
  final List<PlacedBuilding> buildings;

  /// Grid dimension, used to center the city on the origin.
  final int gridSize;

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

  static const double _minRadius = 5;
  static const double _maxRadius = 30;
  static const double _minPitch = 0.12;
  static const double _maxPitch = 1.45;

  double _gestureStartRadius = 17;
  Size _viewSize = Size.zero;

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
    _ready = _init();
    _desired = widget.buildings;
    _targetGen = 1;
    _pump();
    // Continuous repaint keeps the 3D view live and smooth.
    _ticker = Ticker((_) {
      if (mounted) setState(() {});
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
    scene.environmentIntensity = 0.8;

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

    // Warm ground plane (top surface at y = 0) — receives the shadows.
    final ground = Node(
      mesh: Mesh(
        CuboidGeometry(vm.Vector3(40, 0.2, 40)),
        PhysicallyBasedMaterial()
          ..baseColorFactor = vm.Vector4(0.46, 0.38, 0.26, 1.0)
          ..metallicFactor = 0.0
          ..roughnessFactor = 0.95,
      ),
    )..localTransform = vm.Matrix4.translation(vm.Vector3(0, -0.1, 0));
    scene.add(ground);

    await _models.warmUp();
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
  }

  void _transformFor(Node node, PlacedBuilding b) {
    final pos = cellToWorld(b.gridX, b.gridY, gridSize: widget.gridSize);
    final s = scaleForLevel(b.level);
    node.localTransform = vm.Matrix4.translation(pos)..scaleByDouble(s, s, s, 1);
  }

  PerspectiveCamera _camera() {
    final cp = cos(_pitch);
    final eye = _target +
        vm.Vector3(
          _radius * cp * sin(_yaw),
          _radius * sin(_pitch),
          _radius * cp * cos(_yaw),
        );
    return PerspectiveCamera(position: eye, target: _target.clone());
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
