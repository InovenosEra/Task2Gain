import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/models/city.dart';

void main() {
  test('fromDoc handles missing data', () {
    final c = City.fromDoc('u1', null);
    expect(c.buildings, isEmpty);
    expect(c.cityValue, 0);
    expect(c.cityLevel, 1);
  });

  test('round-trips buildings and derives value + level', () {
    final c = City.fromDoc('u1', {
      'buildings': [
        {'type': 'house', 'gridX': 0, 'gridY': 0, 'level': 1}, // value 10
        {'type': 'shop', 'gridX': 1, 'gridY': 0, 'level': 2},  // value 40
      ],
    });
    expect(c.buildings.length, 2);
    expect(c.cityValue, 50);
    expect(c.cityLevel, 1); // 50 < 100
    expect(c.isOccupied(0, 0), isTrue);
    expect(c.isOccupied(5, 5), isFalse);
  });

  test('displayName falls back to a stable default when unnamed', () {
    final a = City.fromDoc('u1', null);
    final b = City.fromDoc('u1', {'buildings': []});
    expect(a.name, isEmpty);
    expect(a.displayName, isNotEmpty);
    // Deterministic: same uid => same default name.
    expect(a.displayName, b.displayName);
  });

  test('displayName prefers the chosen name (trimmed)', () {
    final c = City.fromDoc('u1', {'name': '  סאניוויל  ', 'buildings': []});
    expect(c.name, '  סאניוויל  ');
    expect(c.displayName, 'סאניוויל');
  });

  test('PlacedBuilding toMap matches schema', () {
    const b = PlacedBuilding(typeId: 'park', gridX: 3, gridY: 4, level: 1);
    expect(b.toMap(), {'type': 'park', 'gridX': 3, 'gridY': 4, 'level': 1});
  });
}
