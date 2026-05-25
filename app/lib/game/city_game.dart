import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../models/city.dart';

/// Flame game that renders the isometric Little City with placeholder
/// (canvas-drawn) art and reports tapped grid cells back to the screen.
///
/// This is the prototype renderer: simple shaded iso tiles + extruded
/// building blocks. Real sprite art (AI-generated) replaces the drawing
/// helpers later without changing the screen wiring.
class CityGame extends FlameGame with TapCallbacks {
  CityGame({required this.onCellTapped, this.gridSize = 8});

  /// Called with the grid coordinates of a tapped, in-bounds cell.
  final void Function(int gx, int gy) onCellTapped;
  final int gridSize;

  List<PlacedBuilding> _buildings = const [];

  static const double tileW = 60;
  static const double tileH = 30;

  Vector2 _origin = Vector2.zero();

  /// Placeholder colours per building type id (roof / left / right faces
  /// are derived from this base).
  static const Map<String, int> _typeColor = {
    'house': 0xFFFF8B6B,
    'shop': 0xFF2BB7A3,
    'park': 0xFF57C9A0,
    'school': 0xFF7C83FF,
    'factory': 0xFF9AA3B2,
    'apartment': 0xFFB06BFF,
    'decor': 0xFFF4B942,
    'road': 0xFFAEB4C0,
  };

  void setBuildings(List<PlacedBuilding> buildings) {
    _buildings = buildings;
  }

  @override
  Color backgroundColor() => const Color(0xFFBDE7FF);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Centre the diamond horizontally; leave headroom up top for tall builds.
    _origin = Vector2(size.x / 2, size.y * 0.22);
  }

  Offset _iso(num gx, num gy, [double lift = 0]) => Offset(
        _origin.x + (gx - gy) * tileW / 2,
        _origin.y + (gx + gy) * tileH / 2 - lift,
      );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawSky(canvas);
    _drawGround(canvas);

    // Painter's algorithm: far tiles (small gx+gy) first.
    final sorted = [..._buildings]
      ..sort((a, b) => (a.gridX + a.gridY).compareTo(b.gridX + b.gridY));
    for (final b in sorted) {
      _drawBuilding(canvas, b);
    }
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
    final baseColor = Color(_typeColor[b.typeId] ?? 0xFFBBBBBB);
    final h = 22.0 + (b.level - 1) * 16.0;
    const inset = 0.12;
    final x0 = b.gridX + inset, x1 = b.gridX + 1 - inset;
    final y0 = b.gridY + inset, y1 = b.gridY + 1 - inset;

    // Contact shadow.
    final shadow = Path()
      ..moveTo(_iso(x0, y0).dx, _iso(x0, y0).dy)
      ..lineTo(_iso(x1, y0).dx, _iso(x1, y0).dy)
      ..lineTo(_iso(x1, y1).dx, _iso(x1, y1).dy)
      ..lineTo(_iso(x0, y1).dx, _iso(x0, y1).dy)
      ..close();
    canvas.drawPath(shadow, Paint()..color = const Color(0x33000000));

    Offset c(num gx, num gy) => _iso(gx, gy); // base
    Offset t(num gx, num gy) => _iso(gx, gy, h); // top

    // Right wall (darker).
    _face(canvas, [c(x1, y0), c(x1, y1), t(x1, y1), t(x1, y0)],
        _shade(baseColor, 0.62));
    // Front-right wall.
    _face(canvas, [c(x1, y1), c(x0, y1), t(x0, y1), t(x1, y1)],
        _shade(baseColor, 0.78));
    // Roof (lightest).
    _face(canvas, [t(x0, y0), t(x1, y0), t(x1, y1), t(x0, y1)],
        _shade(baseColor, 1.12));

    // Level badge for upgraded buildings.
    if (b.level > 1) {
      final top = _iso(b.gridX + 0.5, b.gridY + 0.5, h);
      _drawLevelBadge(canvas, Offset(top.dx, top.dy - 6), b.level);
    }
  }

  void _drawLevelBadge(Canvas canvas, Offset center, int level) {
    canvas.drawCircle(center, 11, Paint()..color = const Color(0xFF1E2233));
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFD24A),
    );
    final builder = ParagraphBuilder(ParagraphStyle(
      textAlign: TextAlign.center,
      fontSize: 12,
      fontWeight: FontWeight.w900,
    ))
      ..pushStyle(TextStyle(color: const Color(0xFFFFFFFF)))
      ..addText('$level');
    final paragraph = builder.build()
      ..layout(const ParagraphConstraints(width: 22));
    canvas.drawParagraph(
        paragraph, Offset(center.dx - 11, center.dy - paragraph.height / 2));
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

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition;
    final dx = p.x - _origin.x;
    final dy = p.y - _origin.y;
    final u = dx / (tileW / 2); // gx - gy
    final v = dy / (tileH / 2); // gx + gy
    final gx = ((u + v) / 2).floor();
    final gy = ((v - u) / 2).floor();
    if (gx < 0 || gy < 0 || gx >= gridSize || gy >= gridSize) return;
    onCellTapped(gx, gy);
  }
}
