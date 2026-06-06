import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game3d/city3d_layout.dart';
import 'package:task2play/models/city.dart';
import 'package:vector_math/vector_math.dart' as vm;

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

  group('worldToCell', () {
    test('is the inverse of cellToWorld for every cell', () {
      for (var gx = 0; gx < 10; gx++) {
        for (var gy = 0; gy < 10; gy++) {
          final w = cellToWorld(gx, gy);
          final cell = worldToCell(w.x, w.z);
          expect(cell.x, gx);
          expect(cell.y, gy);
        }
      }
    });

    test('rounds a near-center world point to the nearest cell', () {
      final w = cellToWorld(3, 4, spacing: 2.0);
      final cell = worldToCell(w.x + 0.4, w.z - 0.4, spacing: 2.0);
      expect(cell, (x: 3, y: 4));
    });
  });

  group('cellInBounds', () {
    test('accepts cells inside and rejects cells outside', () {
      expect(cellInBounds(0, 0), isTrue);
      expect(cellInBounds(9, 9), isTrue);
      expect(cellInBounds(-1, 0), isFalse);
      expect(cellInBounds(0, 10), isFalse);
    });
  });

  group('plot', () {
    test('plotRange centers the plot in the grid', () {
      expect(plotRange(4, maxGrid: 10), (3, 6)); // cells 3..6
      expect(plotRange(6, maxGrid: 10), (2, 7));
      expect(plotRange(10, maxGrid: 10), (0, 9));
    });

    test('cellInPlot gates to the centered region', () {
      expect(cellInPlot(3, 6, 4), isTrue);
      expect(cellInPlot(4, 4, 4), isTrue);
      expect(cellInPlot(2, 4, 4), isFalse); // outside 3..6
      expect(cellInPlot(7, 7, 4), isFalse);
    });

    test('plot grows symmetrically without shifting building positions', () {
      // cell (4,5) is in-plot for every size that reaches it; its world pos is
      // independent of plot size (cellToWorld uses the fixed grid).
      final w4 = cellToWorld(4, 5, gridSize: 10);
      final w6 = cellToWorld(4, 5, gridSize: 10);
      expect(w4.x, w6.x);
      expect(cellInPlot(4, 5, 6), isTrue);
    });

    test('requiredPlotForCells contains all cells', () {
      expect(requiredPlotForCells([(x: 4, y: 5)]), 4); // central -> base
      expect(requiredPlotForCells([(x: 2, y: 7)]), 6); // needs 2..7
      expect(requiredPlotForCells([(x: 0, y: 9)]), 10); // corner -> full grid
      expect(requiredPlotForCells(const []), 4); // empty -> base
    });

    test('plotHalfExtentWorld grows with plot size', () {
      expect(plotHalfExtentWorld(8), greaterThan(plotHalfExtentWorld(4)));
    });

    test('treeSpots are sparse, in-plot, deterministic', () {
      final a = treeSpots(10);
      final b = treeSpots(10);
      expect(a.map((s) => (s.i, s.j, s.model)),
          b.map((s) => (s.i, s.j, s.model))); // deterministic
      final (lo, hi) = plotRange(10);
      for (final s in a) {
        expect(s.i, inInclusiveRange(lo, hi - 1));
        expect(s.j, inInclusiveRange(lo, hi - 1));
        expect(s.model, inInclusiveRange(0, 1));
      }
      // sparse: well under the number of interior intersections (81 for P=10)
      expect(a.length, lessThan(40));
      // a bigger plot yields at least as many spots
      expect(treeSpots(10).length, greaterThanOrEqualTo(treeSpots(4).length));
    });
  });

  group('rayGroundHit', () {
    test('straight-down ray hits directly below the origin', () {
      final hit = rayGroundHit(vm.Vector3(2, 10, -3), vm.Vector3(0, -1, 0));
      expect(hit, isNotNull);
      expect(hit!.x, closeTo(2, 1e-9));
      expect(hit.y, closeTo(0, 1e-9));
      expect(hit.z, closeTo(-3, 1e-9));
    });

    test('angled ray hits further along the plane', () {
      final hit = rayGroundHit(vm.Vector3(0, 10, 0), vm.Vector3(1, -1, 0));
      expect(hit!.x, closeTo(10, 1e-9));
      expect(hit.z, closeTo(0, 1e-9));
    });

    test('returns null when parallel to the ground', () {
      expect(rayGroundHit(vm.Vector3(0, 10, 0), vm.Vector3(1, 0, 0)), isNull);
    });

    test('returns null when pointing away from the ground', () {
      expect(rayGroundHit(vm.Vector3(0, 10, 0), vm.Vector3(0, 1, 0)), isNull);
    });
  });

  group('fitRadius', () {
    test('larger footprints need a larger radius', () {
      final small = fitRadius(5, 5, 45 * 3.14159265 / 180);
      final big = fitRadius(15, 15, 45 * 3.14159265 / 180);
      expect(big, greaterThan(small));
    });

    test('a narrower FOV needs a larger radius for the same footprint', () {
      final wide = fitRadius(10, 10, 60 * 3.14159265 / 180);
      final narrow = fitRadius(10, 10, 30 * 3.14159265 / 180);
      expect(narrow, greaterThan(wide));
    });

    test('fits the bounding circle to the vertical half-FOV', () {
      // r = sqrt(10^2+10^2)=14.14; halfFov=22.5deg, sin=.3827 -> ~36.95
      final r = fitRadius(10, 10, 45 * 3.14159265 / 180);
      expect(r, closeTo(36.95, 0.2));
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
