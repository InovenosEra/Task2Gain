import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'model_cache.dart';

/// Standalone 3D city view (Stage 2): a warm, lit diorama with soft shadows,
/// a ground plane and a few hardcoded buildings, driven by a fixed iso-style
/// [PerspectiveCamera] the user can orbit, pinch-zoom and two-finger pan.
///
/// This is NOT wired to city data yet — it renders a fixed layout so the
/// renderer and camera feel can be validated on real hardware. It's shown only
/// when `kUse3DCity` is true; otherwise the Flame board renders.
class CityScene3D extends StatefulWidget {
  const CityScene3D({super.key});

  @override
  State<CityScene3D> createState() => _CityScene3DState();
}

/// A hardcoded building placement for Stage 2 (grid cell + type id).
class _Placement {
  const _Placement(this.x, this.z, this.typeId);
  final double x;
  final double z;
  final String typeId;
}

class _CityScene3DState extends State<CityScene3D> {
  final Scene scene = Scene();
  final City3DModels _models = City3DModels();
  late final Ticker _ticker;
  late final Future<void> _ready;

  // --- Orbit camera state -----------------------------------------------
  // Yaw spins around the target, pitch raises/lowers the eye, radius is the
  // distance. Defaults frame the little city at a cozy iso-ish angle.
  double _yaw = pi / 4; // 45° — classic iso feel
  double _pitch = 0.62; // ~35° above the ground
  double _radius = 15;
  final vm.Vector3 _target = vm.Vector3(0, 0.6, 0);

  static const double _minRadius = 5;
  static const double _maxRadius = 28;
  static const double _minPitch = 0.12;
  static const double _maxPitch = 1.45;

  // Captured at gesture start so pinch-zoom is relative to where it began.
  double _gestureStartRadius = 15;

  Size _viewSize = Size.zero;

  // A handful of hardcoded buildings laid out on a small grid. Type ids all
  // map to the placeholder model today (see city3d_config), but keeping
  // distinct ids means swapping in per-type models later "just works".
  static const List<_Placement> _layout = [
    _Placement(-3, -3, 'house'),
    _Placement(0, -3, 'shop'),
    _Placement(3, -3, 'cafe'),
    _Placement(-3, 0, 'tower'),
    _Placement(3, 0, 'apartment'),
    _Placement(-3, 3, 'school'),
    _Placement(0, 3, 'bank'),
    _Placement(3, 3, 'park'),
  ];

  @override
  void initState() {
    super.initState();
    _ready = _init();
    // Continuous repaint keeps the 3D view live and smooth.
    _ticker = Ticker((_) {
      if (mounted) setState(() {});
    })..start();
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

    // Warm up the shared colormap once, then place the hardcoded buildings.
    await _models.warmUp();
    for (final p in _layout) {
      final node = await _models.newBuilding(p.typeId);
      node.localTransform = vm.Matrix4.translation(vm.Vector3(p.x, 0, p.z));
      scene.add(node);
    }
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
        // Pinch-zoom: radius relative to the gesture's starting radius.
        _radius =
            (_gestureStartRadius / d.scale).clamp(_minRadius, _maxRadius);
        // Two-finger pan: slide the target across the ground. Scale by radius
        // so the world keeps pace with the fingers at any zoom level.
        _panTarget(d.focalPointDelta);
      } else {
        // Orbit. Invert so the world follows the finger naturally.
        _yaw -= d.focalPointDelta.dx * 0.01;
        _pitch =
            (_pitch + d.focalPointDelta.dy * 0.01).clamp(_minPitch, _maxPitch);
      }
    });
  }

  /// Moves [_target] along the ground plane by a screen-space [delta], using
  /// the camera's yaw to map screen X/Y to world right/forward.
  void _panTarget(Offset delta) {
    final perPixel = _radius * 0.0016; // world units per screen pixel
    // Horizontal basis vectors on the ground for the current yaw.
    final right = vm.Vector3(cos(_yaw), 0, -sin(_yaw));
    final forward = vm.Vector3(sin(_yaw), 0, cos(_yaw));
    // Drag right → world slides right (move target left); drag down → world
    // slides toward viewer (move target away).
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
