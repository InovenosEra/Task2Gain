import 'dart:math';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import 'building_catalog.dart';
import '../models/city.dart';

/// Flame game that renders the isometric Little City with placeholder
/// (canvas-drawn) art and reports tapped grid cells back to the screen.
///
/// This is the prototype renderer: simple shaded iso tiles + extruded
/// building blocks. Real sprite art (AI-generated) replaces the drawing
/// helpers later without changing the screen wiring.
class CityGame extends FlameGame with TapCallbacks {
  CityGame({required this.onCellTapped, this.gridSize = 10});

  /// Called with the grid coordinates of a tapped, in-bounds cell.
  final void Function(int gx, int gy) onCellTapped;
  final int gridSize;

  List<PlacedBuilding> _buildings = const [];

  /// When true (placement armed), empty tiles get a pulsing highlight.
  bool _buildMode = false;
  double _pulse = 0;

  void setBuildMode(bool v) => _buildMode = v;

  /// The currently selected building cell (shows a ring + drives the upgrade
  /// popup in the screen layer). Null when nothing is selected.
  int? _selX;
  int? _selY;

  void setSelected(int? gx, int? gy) {
    _selX = gx;
    _selY = gy;
  }

  // --- drag-to-move (driven from the screen's gesture layer) ---
  int? _dragFromX;
  int? _dragFromY;
  Offset? _dragPos;

  bool get isDragging => _dragFromX != null;

  /// Begin dragging the currently selected building.
  void beginDrag() {
    _dragFromX = _selX;
    _dragFromY = _selY;
  }

  void updateDrag(double px, double py) => _dragPos = Offset(px, py);

  /// Finish the drag; returns the target cell under the pointer (or null).
  ({int x, int y})? endDrag() {
    final pos = _dragPos;
    final ok = _dragFromX != null;
    _dragFromX = null;
    _dragFromY = null;
    _dragPos = null;
    if (!ok || pos == null) return null;
    return tileAt(pos.dx, pos.dy);
  }

  /// Screen-space point above the building at ([gx],[gy]) — where the screen
  /// layer anchors the upgrade popup. The GameWidget is full-screen and the
  /// canvas is untransformed, so these are screen pixels.
  Offset anchorAbove(int gx, int gy) {
    PlacedBuilding? b;
    for (final x in _buildings) {
      if (x.gridX == gx && x.gridY == gy) {
        b = x;
        break;
      }
    }
    var lift = 34.0;
    if (b != null) {
      final style = _styles[b.typeId];
      if (style != null && style.kind == _Kind.building) {
        final h = style.baseH + (b.level - 1) * style.perLevel;
        lift = h + (style.roof == _Roof.pyramid ? h * 0.5 + 22 : 16);
      }
    }
    return _iso(gx + 0.5, gy + 0.5, lift);
  }

  /// Sprites keyed by building type id, loaded from `assets/city/<id>.png`.
  /// Any type without a sprite falls back to the canvas-drawn art below, so
  /// a partial art set still runs.
  final Map<String, Sprite> _sprites = {};

  static const double tileW = 60;
  static const double tileH = 30;

  Vector2 _origin = Vector2.zero();

  // --- juice / effects ---
  final List<_FloatText> _floats = [];
  final List<_Confetti> _confetti = [];
  final List<_Cloud> _clouds = [];
  final List<_Bird> _birds = [];
  final Map<String, double> _pop = {}; // 'gx_gy' -> elapsed seconds
  final Random _rand = Random();
  static const double _popDur = 0.45;
  static const List<Color> _confettiColors = [
    Color(0xFFFFD24A),
    Color(0xFFFF6F9C),
    Color(0xFF57C9A0),
    Color(0xFF7C83FF),
    Color(0xFFFF8B6B),
  ];

  /// Cozy mobile-game palette (Township / Clash vibe): cream walls + one
  /// roof accent per building, sky-blue glass windows.
  static const Color _wall = Color(0xFFF6F1E7);
  static const Color _glass = Color(0xFFBFE3FF);

  /// Per-type render style. Roof accent colours follow the art spec.
  static const Map<String, _Style> _styles = {
    'house': _Style(
        roof: _Roof.pyramid, roofColor: Color(0xFFFF8B6B), baseH: 26, perLevel: 14),
    'shop': _Style(
        roof: _Roof.flat, roofColor: Color(0xFF2BB7A3), baseH: 22, perLevel: 10),
    'school': _Style(
        roof: _Roof.pyramid, roofColor: Color(0xFF7C83FF), baseH: 30, perLevel: 16),
    'factory': _Style(
        roof: _Roof.flat, roofColor: Color(0xFFF4B942), baseH: 26, perLevel: 12),
    'apartment': _Style(
        roof: _Roof.flat, roofColor: Color(0xFF57C9A0), baseH: 38, perLevel: 18),
    'tower': _Style(
        roof: _Roof.flat,
        roofColor: Color(0xFF6E9BE8),
        baseH: 64,
        perLevel: 28,
        glass: true),
    'cityhall': _Style(
        roof: _Roof.dome, roofColor: Color(0xFFF4D06A), baseH: 30, perLevel: 14),
    'hospital': _Style(
        roof: _Roof.flat, roofColor: Color(0xFF4CC9F0), baseH: 30, perLevel: 14),
    'cafe': _Style(
        roof: _Roof.flat, roofColor: Color(0xFFE08D5A), baseH: 22, perLevel: 10),
    'bank': _Style(
        roof: _Roof.flat, roofColor: Color(0xFFB7AE97), baseH: 32, perLevel: 14),
    'park': _Style(roof: _Roof.none, roofColor: Color(0xFF57C9A0), kind: _Kind.park),
    'decor': _Style(roof: _Roof.none, roofColor: Color(0xFFF4B942), kind: _Kind.decor),
    'fountain': _Style(roof: _Roof.none, roofColor: Color(0xFF8FD3F2), kind: _Kind.decor),
    'road': _Style(roof: _Roof.none, roofColor: Color(0xFFAEB4C0), kind: _Kind.road),
  };

  static const _Style _fallback =
      _Style(roof: _Roof.flat, roofColor: Color(0xFFBBBBBB));

  Set<String> _roadCells = {};
  Set<String> _occupied = {};

  void setBuildings(List<PlacedBuilding> buildings) {
    _buildings = buildings;
    _roadCells = {
      for (final b in buildings)
        if (b.typeId == 'road') '${b.gridX}_${b.gridY}'
    };
    _occupied = {for (final b in buildings) '${b.gridX}_${b.gridY}'};
  }

  @override
  Future<void> onLoad() async {
    // Preload building sprites that ACTUALLY ship in assets/city/. We consult
    // the asset manifest first and only load files that exist, so missing
    // sprites (the common case — canvas art covers them) never trigger a
    // failed-asset exception.
    final cityImages = Images(prefix: 'assets/city/');
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final available = manifest.listAssets().toSet();
      for (final type in kBuildingCatalog) {
        if (!available.contains('assets/city/${type.id}.png')) continue;
        try {
          _sprites[type.id] = Sprite(await cityImages.load('${type.id}.png'));
        } catch (_) {
          // Corrupt/unreadable sprite — fall back to canvas art.
        }
      }
    } catch (_) {
      // No manifest available — canvas art covers every building.
    }
  }

  /// Plays the build/upgrade feedback at a cell: a pop-in, a rising "+XP",
  /// and (on a surprise) a confetti burst.
  void celebrate(int gx, int gy, {required int xpGained, int bonusTokens = 0}) {
    _pop['${gx}_$gy'] = 0;
    final top = _iso(gx + 0.5, gy + 0.5, 42);
    if (xpGained > 0) {
      _floats.add(_FloatText(
          Offset(top.dx, top.dy), '+$xpGained', const Color(0xFFFF6F9C)));
    }
    if (bonusTokens > 0) {
      _floats.add(_FloatText(Offset(top.dx, top.dy - 22), '🎁 +$bonusTokens',
          const Color(0xFFFFD24A)));
      for (var i = 0; i < 22; i++) {
        final ang = _rand.nextDouble() * pi * 2;
        final spd = 80 + _rand.nextDouble() * 170;
        _confetti.add(_Confetti(
          Offset(top.dx, top.dy),
          vx: cos(ang) * spd,
          vy: sin(ang) * spd - 130,
          color: _confettiColors[i % _confettiColors.length],
          spin: (_rand.nextDouble() - 0.5) * 12,
        ));
      }
    }
  }

  /// A big celebratory confetti burst from the top-centre (e.g. on level-up).
  void burstConfetti() {
    final cx = size.x / 2;
    for (var i = 0; i < 48; i++) {
      final ang = _rand.nextDouble() * pi * 2;
      final spd = 90 + _rand.nextDouble() * 220;
      _confetti.add(_Confetti(
        Offset(cx + (_rand.nextDouble() - 0.5) * 120, size.y * 0.28),
        vx: cos(ang) * spd,
        vy: sin(ang) * spd - 120,
        color: _confettiColors[i % _confettiColors.length],
        spin: (_rand.nextDouble() - 0.5) * 12,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pop.updateAll((k, v) => v + dt);
    _pop.removeWhere((k, v) => v > _popDur);
    for (final f in _floats) {
      f.pos = Offset(f.pos.dx, f.pos.dy - 34 * dt);
      f.age += dt;
    }
    _floats.removeWhere((f) => f.age > f.life);
    for (final c in _confetti) {
      c.vy += 430 * dt;
      c.pos = Offset(c.pos.dx + c.vx * dt, c.pos.dy + c.vy * dt);
      c.rot += c.spin * dt;
      c.age += dt;
    }
    _confetti.removeWhere((c) => c.age > c.life);
    for (final cl in _clouds) {
      cl.x += cl.speed * dt;
      if (cl.x - 70 * cl.scale > size.x) cl.x = -70 * cl.scale;
    }
    for (final bd in _birds) {
      bd.x += bd.speed * dt;
      bd.phase += dt * 6;
      if (bd.x - 14 * bd.scale > size.x) bd.x = -14 * bd.scale;
    }
    _pulse += dt;
  }

  @override
  Color backgroundColor() => const Color(0xFFBDE7FF);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Centre the diamond; scale the vertical anchor to the grid so a larger
    // city still fits between the HUD and the bottom edge.
    final topFactor = gridSize >= 10 ? 0.16 : 0.22;
    _origin = Vector2(size.x / 2, size.y * topFactor);
    if (_clouds.isEmpty) {
      for (var i = 0; i < 5; i++) {
        _clouds.add(_Cloud(
          x: _rand.nextDouble() * size.x,
          y: 20 + _rand.nextDouble() * size.y * 0.32,
          scale: 0.7 + _rand.nextDouble() * 0.8,
          speed: 6 + _rand.nextDouble() * 10,
        ));
      }
      for (var i = 0; i < 4; i++) {
        _birds.add(_Bird(
          x: _rand.nextDouble() * size.x,
          y: 40 + _rand.nextDouble() * size.y * 0.28,
          scale: 0.8 + _rand.nextDouble() * 0.6,
          speed: 22 + _rand.nextDouble() * 16,
          phase: _rand.nextDouble() * pi * 2,
        ));
      }
    }
  }

  Offset _iso(num gx, num gy, [double lift = 0]) => Offset(
        _origin.x + (gx - gy) * tileW / 2,
        _origin.y + (gx + gy) * tileH / 2 - lift,
      );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawSky(canvas);
    for (final cl in _clouds) {
      _drawCloud(canvas, cl);
    }
    for (final bd in _birds) {
      _drawBird(canvas, bd);
    }
    _drawIsland(canvas);
    _drawGround(canvas);

    final occupied = _occupied; // cached on setBuildings

    // Build mode: pulse-highlight the empty, buildable tiles.
    if (_buildMode) {
      final a = (0.12 + 0.06 * sin(_pulse * 3.2)).clamp(0.0, 1.0);
      final fill = Paint()..color = const Color(0xFFFFD166).withValues(alpha: a);
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFA94D).withValues(alpha: a + 0.2);
      for (var x = 0; x < gridSize; x++) {
        for (var y = 0; y < gridSize; y++) {
          if (occupied.contains('${x}_$y')) continue;
          final path = _tilePath(x.toDouble(), y.toDouble(), x + 1.0, y + 1.0);
          canvas.drawPath(path, fill);
          canvas.drawPath(path, border);
        }
      }
    }

    final dragKey =
        isDragging ? '${_dragFromX}_$_dragFromY' : null;

    // Selected building: a pulsing ring on its tile (hidden while dragging).
    if (_selX != null && _selY != null && dragKey == null) {
      final ring = _tilePath(
          _selX!.toDouble(), _selY!.toDouble(), _selX! + 1.0, _selY! + 1.0);
      final a = (0.6 + 0.4 * sin(_pulse * 4)).clamp(0.0, 1.0);
      canvas.drawPath(
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFFD166).withValues(alpha: a),
      );
    }

    // Painter's algorithm: buildings + ambient scenery, far tiles first.
    // The dragged building is drawn last (on top), following the pointer.
    final items = <_Drawable>[
      for (final b in _buildings)
        if ('${b.gridX}_${b.gridY}' != dragKey)
          _Drawable(b.gridX, b.gridY, () => _drawBuilding(canvas, b)),
    ];
    for (var x = 0; x < gridSize; x++) {
      for (var y = 0; y < gridSize; y++) {
        if (occupied.contains('${x}_$y')) continue;
        final kind = _sceneryAt(x, y);
        if (kind != null) {
          items.add(_Drawable(x, y, () => _drawSceneryItem(canvas, x, y, kind)));
        }
      }
    }
    items.sort((a, b) => (a.gx + a.gy).compareTo(b.gx + b.gy));
    for (final it in items) {
      it.draw();
    }

    // Drag preview: a target highlight + the lifted building on top.
    if (dragKey != null && _dragPos != null) {
      final t = tileAt(_dragPos!.dx, _dragPos!.dy);
      if (t != null && !occupied.contains('${t.x}_${t.y}')) {
        final path =
            _tilePath(t.x.toDouble(), t.y.toDouble(), t.x + 1.0, t.y + 1.0);
        canvas.drawPath(path, Paint()..color = const Color(0x66FFD166));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF06D6A0),
        );
      }
      for (final b in _buildings) {
        if ('${b.gridX}_${b.gridY}' == dragKey) {
          _drawBuilding(canvas, b);
          break;
        }
      }
    }

    for (final c in _confetti) {
      _drawConfetti(canvas, c);
    }
    for (final f in _floats) {
      _drawFloat(canvas, f);
    }
  }

  void _drawBird(Canvas canvas, _Bird bd) {
    final s = bd.scale;
    final flap = (sin(bd.phase) * 0.5 + 0.5) * 5 * s; // wing rise
    final paint = Paint()
      ..color = const Color(0xFF566173)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    final cx = bd.x, cy = bd.y;
    canvas.drawLine(
        Offset(cx - 9 * s, cy), Offset(cx, cy - flap), paint);
    canvas.drawLine(
        Offset(cx, cy - flap), Offset(cx + 9 * s, cy), paint);
  }

  void _drawCloud(Canvas canvas, _Cloud cl) {
    final s = cl.scale;
    final paint = Paint()..color = const Color(0xCCFFFFFF);
    void puff(double dx, double dy, double r) =>
        canvas.drawCircle(Offset(cl.x + dx * s, cl.y + dy * s), r * s, paint);
    puff(0, 0, 16);
    puff(18, 4, 13);
    puff(-18, 5, 12);
    puff(8, -8, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cl.x - 26 * s, cl.y + 4 * s, 54 * s, 12 * s),
        Radius.circular(8 * s),
      ),
      paint,
    );
  }

  void _drawSky(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final paint = Paint()
      ..shader = Gradient.linear(
        Offset(0, 0),
        Offset(0, size.y),
        const [Color(0xFFFFE6BF), Color(0xFFBDE7FF), Color(0xFFDFF7EE)],
        const [0.0, 0.45, 0.75],
      );
    canvas.drawRect(rect, paint);

    // Warm sun glow in the upper-left (matches the buildings' light source).
    final sun = Offset(size.x * 0.16, size.y * 0.1);
    canvas.drawCircle(
      sun,
      size.y * 0.5,
      Paint()
        ..shader = Gradient.radial(sun, size.y * 0.5, const [
          Color(0x66FFF4D6),
          Color(0x00FFF4D6),
        ]),
    );
  }

  /// Extrudes the grass diamond into a floating island: a soil edge under the
  /// two front faces, with a thin grass overhang lip, plus a soft drop shadow.
  void _drawIsland(Canvas canvas) {
    final n = gridSize.toDouble();
    final right = _iso(n, 0), bottom = _iso(n, n), left = _iso(0, n);
    const d = 18.0;
    Offset down(Offset o, [double e = d]) => Offset(o.dx, o.dy + e);

    // Soft shadow on the ground below the island.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bottom.dx, bottom.dy + d + 10),
          width: (right.dx - left.dx) * 0.92,
          height: 46),
      Paint()
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    Path face(Offset a, Offset b) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(down(b).dx, down(b).dy)
      ..lineTo(down(a).dx, down(a).dy)
      ..close();

    // Right-front face (darker), left-front face (mid).
    canvas.drawPath(face(right, bottom), Paint()..color = const Color(0xFF6B4A2E));
    canvas.drawPath(face(bottom, left), Paint()..color = const Color(0xFF7C5838));
    // Grass overhang lip along the top of each side.
    canvas.drawPath(
        face(right, bottom)
          ..reset()
          ..moveTo(right.dx, right.dy)
          ..lineTo(bottom.dx, bottom.dy)
          ..lineTo(down(bottom, 5).dx, down(bottom, 5).dy)
          ..lineTo(down(right, 5).dx, down(right, 5).dy)
          ..close(),
        Paint()..color = const Color(0xFF5FA63E));
    canvas.drawPath(
        Path()
          ..moveTo(bottom.dx, bottom.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(down(left, 5).dx, down(left, 5).dy)
          ..lineTo(down(bottom, 5).dx, down(bottom, 5).dy)
          ..close(),
        Paint()..color = const Color(0xFF6FB94A));
  }

  void _drawGround(Canvas canvas) {
    for (var x = 0; x < gridSize; x++) {
      for (var y = 0; y < gridSize; y++) {
        final path = Path()
          ..moveTo(_iso(x, y).dx, _iso(x, y).dy)
          ..lineTo(_iso(x + 1, y).dx, _iso(x + 1, y).dy)
          ..lineTo(_iso(x + 1, y + 1).dx, _iso(x + 1, y + 1).dy)
          ..lineTo(_iso(x, y + 1).dx, _iso(x, y + 1).dy)
          ..close();
        final base = (x + y).isEven
            ? const Color(0xFF8FD06A)
            : const Color(0xFF82C75E);
        canvas.drawPath(path, Paint()..color = base);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x2233691E),
        );
      }
    }
  }

  void _drawBuilding(Canvas canvas, PlacedBuilding b) {
    final pop = _pop['${b.gridX}_${b.gridY}'];
    final scale =
        pop == null ? 1.0 : _easeOutBack((pop / _popDur).clamp(0.0, 1.0));
    final anchor = _iso(b.gridX + 0.5, b.gridY + 1.0);
    final scaled = scale != 1.0;

    // If this is the building being dragged, lift it to follow the pointer.
    final dragging = _dragPos != null &&
        b.gridX == _dragFromX &&
        b.gridY == _dragFromY;
    if (dragging) {
      final center = _iso(b.gridX + 0.5, b.gridY + 0.5);
      canvas.save();
      canvas.translate(
          _dragPos!.dx - center.dx, _dragPos!.dy - center.dy - 14);
    }

    if (scaled) {
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.scale(scale);
      canvas.translate(-anchor.dx, -anchor.dy);
    }

    final sprite = _sprites[b.typeId];
    if (sprite != null) {
      _drawSprite(canvas, b, sprite);
    } else {
      final style = _styles[b.typeId] ?? _fallback;
      switch (style.kind) {
        case _Kind.road:
          _drawRoad(canvas, b);
        case _Kind.park:
          _drawPark(canvas, b);
        case _Kind.decor:
          if (b.typeId == 'fountain') {
            _drawFountain(canvas, b);
          } else {
            _drawDecor(canvas, b);
          }
        case _Kind.building:
          _drawTower(canvas, b, style);
      }
    }

    if (scaled) canvas.restore();
    if (dragging) canvas.restore();
  }

  /// Renders an AI-art sprite seated on its tile. The sprite is assumed to be
  /// a square asset with the building centered and its base around the middle
  /// (per the art spec); we anchor its bottom-centre to the tile centre and
  /// scale to the tile so 1×1 buildings line up on the grid. Tunable once the
  /// real assets land.
  void _drawSprite(Canvas canvas, PlacedBuilding b, Sprite sprite) {
    final contact = _iso(b.gridX + 0.5, b.gridY + 0.5);
    final levelScale = 1 + (b.level - 1) * 0.12;
    final w = tileW * 1.9 * levelScale;
    final size = Vector2(w, w); // square assets
    // Soft contact shadow under the sprite.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(contact.dx, contact.dy + 2),
          width: tileW * 0.7,
          height: tileH * 0.6),
      Paint()..color = const Color(0x33000000),
    );
    // Seat the base slightly below the tile centre so it sits on the ground.
    sprite.render(
      canvas,
      position: Vector2(contact.dx, contact.dy + tileH * 0.5),
      size: size,
      anchor: Anchor.bottomCenter,
    );
  }

  /// A walled building with windows and a pyramid or flat roof.
  void _drawTower(Canvas canvas, PlacedBuilding b, _Style style) {
    final h = style.baseH + (b.level - 1) * style.perLevel;
    const inset = 0.14;
    final x0 = b.gridX + inset, x1 = b.gridX + 1 - inset;
    final y0 = b.gridY + inset, y1 = b.gridY + 1 - inset;

    _contactShadow(canvas, x0, y0, x1, y1);

    Offset c(num gx, num gy) => _iso(gx, gy); // base
    Offset t(num gx, num gy) => _iso(gx, gy, h); // wall top

    // Subtle per-building roof shade so a row of same-type buildings varies.
    final roofC = _shade(style.roofColor, _jitter(b.gridX, b.gridY));

    final floors = (h / 14).round().clamp(2, 12);
    if (style.glass) {
      // Glass curtain-wall skyscraper: tinted gradient + mullion grid + sheen.
      _glassFace(canvas, c(x1, y0), c(x1, y1), t(x1, y0), t(x1, y1),
          style.roofColor, 0.82, 3, floors, sheen: false);
      _glassFace(canvas, c(x1, y1), c(x0, y1), t(x1, y1), t(x0, y1),
          style.roofColor, 1.0, 3, floors, sheen: true);
      // Glass lobby entrance.
      _facePanel(canvas, c(x1, y1), c(x0, y1), t(x1, y1), t(x0, y1), 0.38, 0.62,
          0.0, 0.12, _shade(style.roofColor, 0.5));
    } else {
      // Right wall (in shadow) + front-right wall (mid).
      _face(canvas, [c(x1, y0), c(x1, y1), t(x1, y1), t(x1, y0)],
          _shade(_wall, 0.74));
      _face(canvas, [c(x1, y1), c(x0, y1), t(x0, y1), t(x1, y1)],
          _shade(_wall, 0.88));

      // Windows: more rows the taller it is.
      final rows = (h / 16).round().clamp(1, 5);
      _windows(canvas, c(x1, y0), c(x1, y1), t(x1, y0), t(x1, y1), 2, rows,
          _shade(_glass, 0.82));
      _windows(canvas, c(x1, y1), c(x0, y1), t(x1, y1), t(x0, y1), 2, rows,
          _glass);

      // Door on the front-right face, ground-level centre.
      _facePanel(canvas, c(x1, y1), c(x0, y1), t(x1, y1), t(x0, y1), 0.40, 0.60,
          0.0, 0.30 * (16 / h).clamp(0.4, 1.0), const Color(0xFF8A5A3B));

      // Shop & café: a striped awning over the storefront.
      if (b.typeId == 'shop' || b.typeId == 'cafe') {
        final vTop = (0.46 * (16 / h)).clamp(0.18, 0.46);
        final stripe = b.typeId == 'cafe'
            ? const Color(0xFF2BB7A3)
            : const Color(0xFFEF476F);
        for (var k = 0; k < 6; k++) {
          _facePanel(canvas, c(x1, y1), c(x0, y1), t(x1, y1), t(x0, y1), k / 6,
              (k + 1) / 6, vTop * 0.62, vTop,
              k.isEven ? stripe : const Color(0xFFFFF3EC));
        }
        // Café: a parasol out front.
        if (b.typeId == 'cafe') {
          _parasol(canvas, _iso(b.gridX + 0.5, b.gridY + 0.92));
        }
      }

      // Hospital: a red cross on the front wall.
      if (b.typeId == 'hospital') {
        const red = Color(0xFFEF476F);
        _facePanel(canvas, c(x1, y1), c(x0, y1), t(x1, y1), t(x0, y1), 0.44,
            0.56, 0.45, 0.72, red);
        _facePanel(canvas, c(x1, y1), c(x0, y1), t(x1, y1), t(x0, y1), 0.38,
            0.62, 0.53, 0.64, red);
      }

      // Bank: a colonnade of light pilasters across the front.
      if (b.typeId == 'bank') {
        for (var k = 0; k < 4; k++) {
          final u = 0.16 + k * 0.22;
          _facePanel(canvas, c(x1, y1), c(x0, y1), t(x1, y1), t(x0, y1), u,
              u + 0.07, 0.0, 0.82, _shade(_wall, 1.15));
        }
      }
    }

    // Roof.
    final rim = [t(x0, y0), t(x1, y0), t(x1, y1), t(x0, y1)];
    if (style.roof == _Roof.pyramid) {
      final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
      final roofH = h * 0.5 + 18;
      final apex = _iso(cx, cy, h + roofH);
      // back/left (bright), right (dark), front (mid), left (mid-bright)
      _face(canvas, [rim[0], rim[1], apex], _shade(roofC, 1.12));
      _face(canvas, [rim[1], rim[2], apex], _shade(roofC, 0.74));
      _face(canvas, [rim[2], rim[3], apex], _shade(roofC, 0.94));
      _face(canvas, [rim[3], rim[0], apex], _shade(roofC, 1.04));
      // House gets a chimney; school gets a rooftop flag.
      if (b.typeId == 'house') {
        _chimney(canvas, x1 - 0.30, y0 + 0.16, h);
      } else if (b.typeId == 'school') {
        _flag(canvas, apex);
      }
    } else if (style.roof == _Roof.dome) {
      // Civic landmark: flat cream roof with a golden dome + finial.
      _face(canvas, rim, _shade(_wall, 1.05));
      _dome(canvas, (x0 + x1) / 2, (y0 + y1) / 2, h, roofC);
    } else {
      _face(canvas, rim, _shade(roofC, 1.06));
      // a slim parapet lip for depth
      final lip = 6.0;
      Offset l(int i) =>
          Offset(rim[i].dx, rim[i].dy - lip);
      _face(canvas, [rim[1], rim[2], l(2), l(1)], _shade(roofC, 0.7));
      _face(canvas, [rim[2], rim[3], l(3), l(2)], _shade(roofC, 0.85));
      _face(canvas, [l(0), l(1), l(2), l(3)], _shade(roofC, 1.12));
      // Factory: two short smokestacks puffing smoke.
      if (b.typeId == 'factory') {
        final s1 = _iso(x0 + 0.30, y0 + 0.30, h);
        final s2 = _iso(x0 + 0.52, y0 + 0.26, h);
        _smokestack(canvas, s1);
        _smokestack(canvas, s2);
        _smoke(canvas, Offset(s1.dx, s1.dy - 18), 0);
        _smoke(canvas, Offset(s2.dx, s2.dy - 18), 1.5);
      }
      // Hospital: a small red cross on the roof.
      if (b.typeId == 'hospital') {
        final r = _iso((x0 + x1) / 2, (y0 + y1) / 2, h);
        const red = Color(0xFFEF476F);
        canvas.drawRect(
            Rect.fromCenter(center: r, width: 14, height: 5), Paint()..color = red);
        canvas.drawRect(
            Rect.fromCenter(center: r, width: 5, height: 14), Paint()..color = red);
      }
      // Bank: a triangular pediment over the front colonnade.
      if (b.typeId == 'bank') {
        final apex = _iso((x0 + x1) / 2, y1, h + 12);
        final ped = Path()
          ..moveTo(t(x1, y1).dx, t(x1, y1).dy)
          ..lineTo(t(x0, y1).dx, t(x0, y1).dy)
          ..lineTo(apex.dx, apex.dy)
          ..close();
        canvas.drawPath(ped, Paint()..color = _shade(_wall, 1.18));
      }
      // Skyscraper: a thin rooftop antenna.
      if (style.glass) {
        final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
        final base = _iso(cx, cy, h);
        canvas.drawLine(
          Offset(base.dx, base.dy - 6),
          Offset(base.dx, base.dy - 26),
          Paint()
            ..color = const Color(0xFFCBD5E1)
            ..strokeWidth = 2,
        );
        canvas.drawCircle(Offset(base.dx, base.dy - 26), 2.5,
            Paint()..color = const Color(0xFFEF476F));
      }
    }

  }

  /// Fills a sub-rectangle of a wall face (params in face-local u/v, where
  /// base A→B is u and base→top is v). Used for doors.
  void _facePanel(Canvas canvas, Offset baseA, Offset baseB, Offset topA,
      Offset topB, double u0, double u1, double v0, double v1, Color color) {
    Offset at(double u, double v) => Offset.lerp(
        Offset.lerp(baseA, baseB, u)!, Offset.lerp(topA, topB, u)!, v)!;
    final path = Path()
      ..moveTo(at(u0, v0).dx, at(u0, v0).dy)
      ..lineTo(at(u1, v0).dx, at(u1, v0).dy)
      ..lineTo(at(u1, v1).dx, at(u1, v1).dy)
      ..lineTo(at(u0, v1).dx, at(u0, v1).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// A glass curtain-wall face: a vertical blue-glass gradient with a mullion
  /// grid, and (optionally) a bright sheen streak. [shadeF] dims the whole
  /// face for the shadowed side.
  void _glassFace(Canvas canvas, Offset baseA, Offset baseB, Offset topA,
      Offset topB, Color tint, double shadeF, int cols, int rows,
      {bool sheen = false}) {
    Offset at(double u, double v) => Offset.lerp(
        Offset.lerp(baseA, baseB, u)!, Offset.lerp(topA, topB, u)!, v)!;
    final ring = Path()
      ..moveTo(baseA.dx, baseA.dy)
      ..lineTo(baseB.dx, baseB.dy)
      ..lineTo(topB.dx, topB.dy)
      ..lineTo(topA.dx, topA.dy)
      ..close();
    // Darker at the base, brighter toward the top (sky reflection).
    final shader = Gradient.linear(
      Offset.lerp(baseA, baseB, 0.5)!,
      Offset.lerp(topA, topB, 0.5)!,
      [_shade(tint, 0.72 * shadeF), _shade(tint, 1.16 * shadeF)],
    );
    canvas.drawPath(ring, Paint()..shader = shader);

    // Mullion grid (thin darker lines between glass panels).
    final mull = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _shade(tint, 0.6 * shadeF);
    for (var i = 1; i < cols; i++) {
      final u = i / cols;
      canvas.drawLine(at(u, 0), at(u, 1), mull);
    }
    for (var j = 1; j < rows; j++) {
      final v = j / rows;
      canvas.drawLine(at(0, v), at(1, v), mull);
    }

    // Sheen: a bright vertical reflection streak on the lit face.
    if (sheen) {
      final streak = Path()
        ..moveTo(at(0.16, 0).dx, at(0.16, 0).dy)
        ..lineTo(at(0.26, 0).dx, at(0.26, 0).dy)
        ..lineTo(at(0.26, 1).dx, at(0.26, 1).dy)
        ..lineTo(at(0.16, 1).dx, at(0.16, 1).dy)
        ..close();
      canvas.drawPath(
          streak, Paint()..color = _shade(tint, 1.45 * shadeF).withValues(alpha: 0.55));
    }
  }

  /// A small brick chimney sitting on the roof at grid ([gx],[gy]), rising
  /// from wall-top height [baseH].
  void _chimney(Canvas canvas, double gx, double gy, double baseH) {
    const w = 0.14, hgt = 14.0;
    final x0 = gx, x1 = gx + w, y0 = gy, y1 = gy + w;
    Offset b(num px, num py) => _iso(px, py, baseH);
    Offset t(num px, num py) => _iso(px, py, baseH + hgt);
    const brick = Color(0xFFB1674A);
    _face(canvas, [b(x1, y0), b(x1, y1), t(x1, y1), t(x1, y0)],
        _shade(brick, 0.7));
    _face(canvas, [b(x1, y1), b(x0, y1), t(x0, y1), t(x1, y1)],
        _shade(brick, 0.85));
    _face(canvas, [t(x0, y0), t(x1, y0), t(x1, y1), t(x0, y1)],
        _shade(brick, 1.1));
  }

  /// A small, stable per-tile shade multiplier (~0.93–1.07) so identical
  /// building types don't look cloned.
  double _jitter(int gx, int gy) {
    final h = ((gx * 49297) ^ (gy * 233280)) & 0x7fffffff;
    return 0.93 + (h % 15) / 100.0;
  }

  /// A short factory smokestack rising from a roof point.
  void _smokestack(Canvas canvas, Offset base) {
    const w = 5.0, hgt = 18.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(base.dx - w / 2, base.dy - hgt, w, hgt + 2),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFFB6BCC6));
    // red band near the top
    canvas.drawRect(
      Rect.fromLTWH(base.dx - w / 2, base.dy - hgt + 3, w, 3),
      Paint()..color = const Color(0xFFEF476F),
    );
  }

  /// Rising, fading smoke puffs from a smokestack top at [top].
  void _smoke(Canvas canvas, Offset top, double seed) {
    for (var i = 0; i < 3; i++) {
      final t = ((_pulse * 0.4 + seed + i / 3) % 1.0);
      final y = top.dy - t * 24;
      final x = top.dx + sin(t * pi * 2 + seed) * 4;
      final op = (1 - t) * 0.4;
      canvas.drawCircle(Offset(x, y), 3 + t * 5,
          Paint()..color = const Color(0xFFE4E7EC).withValues(alpha: op));
    }
  }

  /// A pair of bright streaks bobbing on a water surface centred at [c].
  void _shimmer(Canvas canvas, Offset c) {
    final p = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final dx = sin(_pulse * 1.6) * 4;
    canvas.drawLine(
        Offset(c.dx - 6 + dx, c.dy - 1), Offset(c.dx + 1 + dx, c.dy - 1), p);
    canvas.drawLine(Offset(c.dx - 2 + dx * 0.6, c.dy + 3),
        Offset(c.dx + 4 + dx * 0.6, c.dy + 3), p);
  }

  /// A café parasol (table umbrella) standing on the ground at [base].
  void _parasol(Canvas canvas, Offset base) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(base.dx, base.dy + 1), width: 14, height: 5),
      Paint()..color = const Color(0x22000000),
    );
    // pole
    canvas.drawLine(base, Offset(base.dx, base.dy - 20),
        Paint()..color = const Color(0xFF8A8F9C)..strokeWidth = 2);
    // canopy (scalloped — two arcs)
    final canopy = Rect.fromCenter(
        center: Offset(base.dx, base.dy - 20), width: 26, height: 14);
    canvas.drawArc(canopy, pi, pi, true, Paint()..color = const Color(0xFFEF476F));
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(base.dx - 6, base.dy - 20), width: 14, height: 12),
        pi,
        pi,
        true,
        Paint()..color = const Color(0xFFFF6F9C));
  }

  /// A golden dome (with highlight + finial) centred on a building roof.
  void _dome(Canvas canvas, double cx, double cy, double h, Color color) {
    final center = _iso(cx, cy, h);
    final dw = tileW * 0.62, dh = tileW * 0.5;
    final rect = Rect.fromCenter(center: center, width: dw, height: dh);
    // top half-ellipse (chord closes the flat bottom)
    canvas.drawArc(rect, 0, -pi, false, Paint()..color = color);
    final hl = Rect.fromCenter(
        center: Offset(center.dx - 3, center.dy - 2),
        width: dw * 0.5,
        height: dh * 0.5);
    canvas.drawArc(hl, 0, -pi, false, Paint()..color = _shade(color, 1.18));
    final top = Offset(center.dx, center.dy - dh / 2);
    canvas.drawLine(top, Offset(top.dx, top.dy - 8),
        Paint()..color = _shade(color, 0.7)..strokeWidth = 2);
    canvas.drawCircle(
        Offset(top.dx, top.dy - 9), 3, Paint()..color = _shade(color, 1.1));
  }

  /// A little pennant flag at a roof apex, rippling in the wind.
  void _flag(Canvas canvas, Offset apex) {
    final poleTop = Offset(apex.dx, apex.dy - 20);
    canvas.drawLine(apex, poleTop,
        Paint()..color = const Color(0xFF6B7280)..strokeWidth = 2);
    final w = sin(_pulse * 5) * 2.5; // wind ripple
    final flag = Path()
      ..moveTo(poleTop.dx, poleTop.dy)
      ..quadraticBezierTo(
          poleTop.dx + 8, poleTop.dy + 2 + w, poleTop.dx + 16, poleTop.dy + 5)
      ..quadraticBezierTo(
          poleTop.dx + 8, poleTop.dy + 8 - w, poleTop.dx, poleTop.dy + 10)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFEF476F));
  }

  /// A flat asphalt tile that auto-connects to neighbouring road tiles:
  /// dashed lane markings run from the centre toward each adjacent road.
  void _drawRoad(Canvas canvas, PlacedBuilding b) {
    final x = b.gridX, y = b.gridY;
    final path = _tilePath(x.toDouble(), y.toDouble(), x + 1.0, y + 1.0);
    canvas.drawPath(path, Paint()..color = const Color(0xFF9BA1AD));
    final inner = _tilePath(x + 0.1, y + 0.1, x + 0.9, y + 0.9);
    canvas.drawPath(inner, Paint()..color = const Color(0xFFB7BCC7));

    final center = _iso(x + 0.5, y + 0.5);
    final dash = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    // Edge midpoints toward each of the 4 grid neighbours.
    final dirs = <List<int>, Offset>{
      [1, 0]: _iso(x + 1, y + 0.5),
      [-1, 0]: _iso(x.toDouble(), y + 0.5),
      [0, 1]: _iso(x + 0.5, y + 1),
      [0, -1]: _iso(x + 0.5, y.toDouble()),
    };
    var connected = 0;
    dirs.forEach((d, edge) {
      if (_roadCells.contains('${x + d[0]}_${y + d[1]}')) {
        connected++;
        // dashed line from centre to the shared edge
        for (var s = 0.1; s < 1.0; s += 0.34) {
          final p1 = Offset.lerp(center, edge, s)!;
          final p2 = Offset.lerp(center, edge, (s + 0.17).clamp(0.0, 1.0))!;
          canvas.drawLine(p1, p2, dash);
        }
      }
    });
    // Lone road tile: a single centred dash so it still reads as a road.
    if (connected == 0) {
      canvas.drawCircle(center, 2.2, Paint()..color = const Color(0xFFFFFFFF));
    }
  }

  /// A grassy park tile: two trees and a little pond.
  void _drawPark(Canvas canvas, PlacedBuilding b) {
    final x = b.gridX, y = b.gridY;
    _contactShadow(canvas, x + 0.1, y + 0.1, x + 0.9, y + 0.9, alpha: 0x18);
    // pond
    final pondC = _iso(x + 0.66, y + 0.66);
    canvas.drawOval(
      Rect.fromCenter(center: pondC, width: tileW * 0.42, height: tileH * 0.5),
      Paint()..color = const Color(0xFF8FD3F2),
    );
    _shimmer(canvas, pondC);
    _tree(canvas, _iso(x + 0.34, y + 0.36), 1.0);
    _tree(canvas, _iso(x + 0.62, y + 0.3), 0.78);
    // a little bench near the front
    final bench = _iso(x + 0.4, y + 0.72);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: bench, width: 16, height: 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF9B6B43),
    );
    canvas.drawRect(Rect.fromLTWH(bench.dx - 7, bench.dy - 5, 2, 5),
        Paint()..color = const Color(0xFF7E5836));
    canvas.drawRect(Rect.fromLTWH(bench.dx + 5, bench.dy - 5, 2, 5),
        Paint()..color = const Color(0xFF7E5836));
  }

  void _tree(Canvas canvas, Offset baseTop, double s) {
    // trunk
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(baseTop.dx, baseTop.dy - 6 * s),
          width: 5 * s,
          height: 14 * s),
      Paint()..color = const Color(0xFF9B6B43),
    );
    // foliage (two stacked blobs, lit from upper-left)
    canvas.drawCircle(Offset(baseTop.dx, baseTop.dy - 18 * s), 12 * s,
        Paint()..color = const Color(0xFF4FB477));
    canvas.drawCircle(Offset(baseTop.dx - 4 * s, baseTop.dy - 24 * s), 8 * s,
        Paint()..color = const Color(0xFF6FCB90));
  }

  /// A small plaza statue: cream pedestal + accent sphere.
  void _drawDecor(Canvas canvas, PlacedBuilding b) {
    final x = b.gridX, y = b.gridY;
    _contactShadow(canvas, x + 0.3, y + 0.3, x + 0.7, y + 0.7, alpha: 0x22);
    const inset = 0.34;
    final x0 = x + inset, x1 = x + 1 - inset;
    final y0 = y + inset, y1 = y + 1 - inset;
    const h = 16.0;
    Offset c(num gx, num gy) => _iso(gx, gy);
    Offset t(num gx, num gy) => _iso(gx, gy, h);
    _face(canvas, [c(x1, y0), c(x1, y1), t(x1, y1), t(x1, y0)],
        _shade(_wall, 0.74));
    _face(canvas, [c(x1, y1), c(x0, y1), t(x0, y1), t(x1, y1)],
        _shade(_wall, 0.88));
    _face(canvas, [t(x0, y0), t(x1, y0), t(x1, y1), t(x0, y1)],
        _shade(_wall, 1.1));
    final top = _iso((x0 + x1) / 2, (y0 + y1) / 2, h);
    canvas.drawCircle(Offset(top.dx, top.dy - 10), 9,
        Paint()..color = const Color(0xFFF4B942));
    canvas.drawCircle(Offset(top.dx - 3, top.dy - 13), 4,
        Paint()..color = const Color(0xFFFFD98A));
  }

  /// Deterministic ambient scenery for an empty tile (so the green isn't bare
  /// and the layout is stable across frames). Returns null for most tiles.
  _SceneryKind? _sceneryAt(int gx, int gy) {
    final h = ((gx * 73856093) ^ (gy * 19349663)) & 0x7fffffff;
    if (h % 100 >= 26) return null; // ~26% of empty tiles get something
    switch ((h ~/ 100) % 4) {
      case 0:
        return _SceneryKind.bush;
      case 1:
        return _SceneryKind.flowers;
      case 2:
        return _SceneryKind.rock;
      default:
        return _SceneryKind.person;
    }
  }

  void _drawSceneryItem(Canvas canvas, int gx, int gy, _SceneryKind kind) {
    final c = _iso(gx + 0.5, gy + 0.5);
    switch (kind) {
      case _SceneryKind.bush:
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx, c.dy + 2),
              width: tileW * 0.3,
              height: tileH * 0.35),
          Paint()..color = const Color(0x22000000),
        );
        canvas.drawCircle(Offset(c.dx - 4, c.dy - 4), 7,
            Paint()..color = const Color(0xFF4FB477));
        canvas.drawCircle(Offset(c.dx + 5, c.dy - 2), 6,
            Paint()..color = const Color(0xFF57C079));
        canvas.drawCircle(Offset(c.dx, c.dy - 8), 6,
            Paint()..color = const Color(0xFF6FCB90));
      case _SceneryKind.flowers:
        const petals = [
          Color(0xFFEF476F),
          Color(0xFFFFD166),
          Color(0xFF7C83FF),
          Color(0xFFFFFFFF),
        ];
        for (var i = 0; i < 4; i++) {
          final dx = (i.isEven ? -1 : 1) * (4 + (i ~/ 2) * 7).toDouble();
          final dy = (i < 2 ? -3 : 4).toDouble();
          canvas.drawCircle(
              Offset(c.dx + dx, c.dy + dy), 3, Paint()..color = petals[i]);
        }
      case _SceneryKind.rock:
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx, c.dy), width: 16, height: 11),
          Paint()..color = const Color(0xFF9AA1AC),
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx - 2, c.dy - 2), width: 10, height: 7),
          Paint()..color = const Color(0xFFB6BCC6),
        );
      case _SceneryKind.person:
        const shirts = [
          Color(0xFFEF476F),
          Color(0xFF4CC9F0),
          Color(0xFFFFD166),
          Color(0xFF06D6A0),
          Color(0xFF7C83FF),
        ];
        final h = ((gx * 12345) ^ (gy * 6789)) & 0x7fffffff;
        final shirt = shirts[h % shirts.length];
        // shadow
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(c.dx, c.dy + 2), width: 10, height: 4),
          Paint()..color = const Color(0x22000000),
        );
        // body (rounded) + head
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(c.dx, c.dy - 5), width: 7, height: 11),
            const Radius.circular(3),
          ),
          Paint()..color = shirt,
        );
        canvas.drawCircle(
            Offset(c.dx, c.dy - 12), 3.2, Paint()..color = const Color(0xFFF1C9A5));
    }
  }

  /// A plaza fountain: stone basin, blue water, a central tier, and a jet.
  void _drawFountain(Canvas canvas, PlacedBuilding b) {
    final x = b.gridX, y = b.gridY;
    final c = _iso(x + 0.5, y + 0.5);
    _contactShadow(canvas, x + 0.2, y + 0.2, x + 0.8, y + 0.8, alpha: 0x22);
    // basin rim (stone) + water
    canvas.drawOval(
      Rect.fromCenter(center: c, width: tileW * 0.6, height: tileH * 0.7),
      Paint()..color = const Color(0xFFCBD2DC),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: tileW * 0.46, height: tileH * 0.52),
      Paint()..color = const Color(0xFF8FD3F2),
    );
    _shimmer(canvas, c);
    // central pedestal + upper bowl
    canvas.drawRect(
      Rect.fromCenter(center: Offset(c.dx, c.dy - 6), width: 5, height: 12),
      Paint()..color = const Color(0xFFCBD2DC),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(c.dx, c.dy - 11), width: 16, height: 6),
      Paint()..color = const Color(0xFFD7DDE6),
    );
    // water jet
    canvas.drawLine(Offset(c.dx, c.dy - 12), Offset(c.dx, c.dy - 22),
        Paint()..color = const Color(0xFFBFE3FF)..strokeWidth = 2);
    canvas.drawCircle(Offset(c.dx, c.dy - 23), 2.5,
        Paint()..color = const Color(0xFFEAF6FF));
  }

  void _contactShadow(Canvas canvas, num x0, num y0, num x1, num y1,
      {int alpha = 0x33}) {
    canvas.drawPath(_tilePath(x0.toDouble(), y0.toDouble(), x1.toDouble(),
        y1.toDouble()), Paint()..color = Color(alpha << 24));
  }

  Path _tilePath(double x0, double y0, double x1, double y1) => Path()
    ..moveTo(_iso(x0, y0).dx, _iso(x0, y0).dy)
    ..lineTo(_iso(x1, y0).dx, _iso(x1, y0).dy)
    ..lineTo(_iso(x1, y1).dx, _iso(x1, y1).dy)
    ..lineTo(_iso(x0, y1).dx, _iso(x0, y1).dy)
    ..close();

  /// Draws a grid of glass windows on a wall face, defined by its four
  /// corners (base A→B along the bottom, top A→B along the top). Uses
  /// bilinear interpolation so windows sit correctly on the skewed iso face.
  void _windows(Canvas canvas, Offset baseA, Offset baseB, Offset topA,
      Offset topB, int cols, int rows, Color color) {
    Offset at(double u, double v) =>
        Offset.lerp(Offset.lerp(baseA, baseB, u)!,
            Offset.lerp(topA, topB, u)!, v)!;
    const padU = 0.12, padV = 0.12; // margins inside the face
    final spanU = (1 - 2 * padU) / cols;
    final spanV = (1 - 2 * padV) / rows;
    const gapU = 0.22, gapV = 0.26; // fraction of cell that is gap
    final paint = Paint()..color = color;
    for (var i = 0; i < cols; i++) {
      for (var j = 0; j < rows; j++) {
        final u0 = padU + i * spanU + spanU * gapU / 2;
        final u1 = padU + (i + 1) * spanU - spanU * gapU / 2;
        final v0 = padV + j * spanV + spanV * gapV / 2;
        final v1 = padV + (j + 1) * spanV - spanV * gapV / 2;
        final path = Path()
          ..moveTo(at(u0, v0).dx, at(u0, v0).dy)
          ..lineTo(at(u1, v0).dx, at(u1, v0).dy)
          ..lineTo(at(u1, v1).dx, at(u1, v1).dy)
          ..lineTo(at(u0, v1).dx, at(u0, v1).dy)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  double _easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    final x = t - 1;
    return 1 + c3 * x * x * x + c1 * x * x;
  }

  Color _fade(Color c, double op) => Color.fromARGB(
        (op.clamp(0.0, 1.0) * 255).round(),
        (c.r * 255).round(),
        (c.g * 255).round(),
        (c.b * 255).round(),
      );

  void _drawConfetti(Canvas canvas, _Confetti c) {
    final op = (1 - c.age / c.life).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(c.pos.dx, c.pos.dy);
    canvas.rotate(c.rot);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 6, height: 9),
      Paint()..color = _fade(c.color, op),
    );
    canvas.restore();
  }

  void _drawFloat(Canvas canvas, _FloatText f) {
    final op = (1 - f.age / f.life).clamp(0.0, 1.0);
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 21,
      fontWeight: FontWeight.w900,
    ))
      ..pushStyle(TextStyle(
        color: _fade(f.color, op),
        shadows: [
          Shadow(color: _fade(const Color(0xFF000000), op * 0.6), blurRadius: 4),
        ],
      ))
      ..addText(f.text);
    final p = builder.build()..layout(const ParagraphConstraints(width: 140));
    canvas.drawParagraph(p, Offset(f.pos.dx - 70, f.pos.dy));
  }

  void _face(Canvas canvas, List<Offset> pts, Color color) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22000000),
    );
  }

  Color _shade(Color c, double factor) {
    int ch(double v) => (v * 255.0 * factor).clamp(0, 255).round();
    return Color.fromARGB(255, ch(c.r), ch(c.g), ch(c.b));
  }

  /// Inverse iso projection: which grid cell a screen point falls on (null if
  /// outside the board). Shared by taps and drag-to-move.
  ({int x, int y})? tileAt(double px, double py) {
    final dx = px - _origin.x;
    final dy = py - _origin.y;
    final u = dx / (tileW / 2); // gx - gy
    final v = dy / (tileH / 2); // gx + gy
    final gx = ((u + v) / 2).floor();
    final gy = ((v - u) / 2).floor();
    if (gx < 0 || gy < 0 || gx >= gridSize || gy >= gridSize) return null;
    return (x: gx, y: gy);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final t = tileAt(event.localPosition.x, event.localPosition.y);
    if (t != null) onCellTapped(t.x, t.y);
  }
}

enum _Roof { pyramid, flat, dome, none }

enum _Kind { building, road, park, decor }

enum _SceneryKind { bush, flowers, rock, person }

/// A slow background cloud puff that drifts across the sky and wraps around.
class _Cloud {
  _Cloud({required this.x, required this.y, required this.scale, required this.speed});
  double x;
  final double y;
  final double scale;
  final double speed;
}

/// A little bird that flaps across the sky and wraps around.
class _Bird {
  _Bird(
      {required this.x,
      required this.y,
      required this.scale,
      required this.speed,
      required this.phase});
  double x;
  final double y;
  final double scale;
  final double speed;
  double phase;
}

/// A depth-sortable draw call (buildings + ambient scenery share one pass).
class _Drawable {
  _Drawable(this.gx, this.gy, this.draw);
  final int gx;
  final int gy;
  final void Function() draw;
}

/// Render recipe for a building type: roof shape + accent colour, base height
/// and per-level growth. [kind] selects a special ground feature (road/park/
/// decor) over the default walled [building].
class _Style {
  const _Style({
    required this.roof,
    required this.roofColor,
    this.baseH = 26,
    this.perLevel = 14,
    this.kind = _Kind.building,
    this.glass = false,
  });

  final _Roof roof;
  final Color roofColor;
  final double baseH;
  final double perLevel;
  final _Kind kind;

  /// When true the walls render as a blue glass curtain wall (mullion grid +
  /// sheen) instead of cream walls with sparse windows — i.e. a skyscraper.
  final bool glass;
}

class _FloatText {
  _FloatText(this.pos, this.text, this.color);
  Offset pos;
  final String text;
  final Color color;
  final double life = 1.1;
  double age = 0;
}

class _Confetti {
  _Confetti(
    this.pos, {
    required this.vx,
    required this.vy,
    required this.color,
    required this.spin,
  });
  Offset pos;
  double vx;
  double vy;
  final Color color;
  double spin;
  double rot = 0;
  final double life = 1.3;
  double age = 0;
}
