import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game3d/city3d_layout.dart';
import 'package:task2play/models/city.dart';

PlacedBuilding b(String type, int x, int y, {int level = 1}) =>
    PlacedBuilding(typeId: type, gridX: x, gridY: y, level: level);

void main() {
  group('cellToWorld', () {
    test('centers the grid on the origin', () {
      // 10x10 grid → center index 4.5; cell (0,0) sits at the far corner.
      final corner = cellToWorld(0, 0, gridSize: 10, spacing: 2.0);
      expect(corner.x, closeTo(-9.0, 1e-9));
      expect(corner.z, closeTo(-9.0, 1e-9));
      expect(corner.y, 0);

      final opposite = cellToWorld(9, 9, gridSize: 10, spacing: 2.0);
      expect(opposite.x, closeTo(9.0, 1e-9));
      expect(opposite.z, closeTo(9.0, 1e-9));
    });

    test('spacing scales distance between cells', () {
      final a = cellToWorld(0, 0, gridSize: 4, spacing: 3.0);
      final c = cellToWorld(1, 0, gridSize: 4, spacing: 3.0);
      expect(c.x - a.x, closeTo(3.0, 1e-9));
    });
  });

  group('scaleForLevel', () {
    test('level 1 is unit scale and higher levels grow', () {
      expect(scaleForLevel(1), 1.0);
      expect(scaleForLevel(3), greaterThan(scaleForLevel(1)));
      expect(scaleForLevel(3), greaterThan(scaleForLevel(2)));
    });

    test('never shrinks below unit for odd/low levels', () {
      expect(scaleForLevel(0), greaterThanOrEqualTo(1.0));
    });
  });

  group('diffCity', () {
    test('adds buildings that are not yet rendered', () {
      final d = diffCity({}, [b('house', 1, 1)]);
      expect(d.toAdd.map((e) => e.typeId), ['house']);
      expect(d.toRemove, isEmpty);
      expect(d.toUpdate, isEmpty);
    });

    test('removes buildings no longer present', () {
      final current = {cellKey(1, 1): b('house', 1, 1)};
      final d = diffCity(current, const []);
      expect(d.toRemove, [cellKey(1, 1)]);
      expect(d.toAdd, isEmpty);
    });

    test('a level change updates in place (no remove/add)', () {
      final current = {cellKey(2, 3): b('shop', 2, 3, level: 1)};
      final d = diffCity(current, [b('shop', 2, 3, level: 2)]);
      expect(d.toUpdate.single.level, 2);
      expect(d.toAdd, isEmpty);
      expect(d.toRemove, isEmpty);
    });

    test('a type change at a cell removes the old and adds the new', () {
      final current = {cellKey(0, 0): b('house', 0, 0)};
      final d = diffCity(current, [b('tower', 0, 0)]);
      expect(d.toRemove, [cellKey(0, 0)]);
      expect(d.toAdd.single.typeId, 'tower');
      expect(d.toUpdate, isEmpty);
    });

    test('unchanged buildings produce no work', () {
      final current = {cellKey(5, 5): b('park', 5, 5, level: 2)};
      final d = diffCity(current, [b('park', 5, 5, level: 2)]);
      expect(d.toAdd, isEmpty);
      expect(d.toRemove, isEmpty);
      expect(d.toUpdate, isEmpty);
    });

    test('mixed batch: add, remove, update together', () {
      final current = {
        cellKey(0, 0): b('house', 0, 0, level: 1), // → level up
        cellKey(1, 0): b('shop', 1, 0), // → removed
      };
      final next = [
        b('house', 0, 0, level: 2), // update
        b('cafe', 2, 2), // add
      ];
      final d = diffCity(current, next);
      expect(d.toUpdate.single.level, 2);
      expect(d.toRemove, [cellKey(1, 0)]);
      expect(d.toAdd.single.typeId, 'cafe');
    });
  });
}
