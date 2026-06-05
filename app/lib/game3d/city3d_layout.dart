import 'package:vector_math/vector_math.dart' as vm;

import '../models/city.dart';

/// World units between adjacent grid cells in the 3D city.
const double kCell3DSpacing = 2.4;

/// Maps a grid cell `(gridX, gridY)` to a world position on the ground plane
/// (y = 0), centered so the whole grid straddles the origin.
vm.Vector3 cellToWorld(
  int gridX,
  int gridY, {
  int gridSize = 10,
  double spacing = kCell3DSpacing,
}) {
  final c = (gridSize - 1) / 2.0;
  return vm.Vector3((gridX - c) * spacing, 0, (gridY - c) * spacing);
}

/// Uniform footprint/height scale for a building [level]. Level 1 is unit
/// scale; higher levels grow gently. Clamped so bad data never shrinks a
/// building below its base size. (Stage 3 uses scale for level; swapping in
/// per-level model variants later only changes the renderer, not this math.)
double scaleForLevel(int level) => 1.0 + (level - 1).clamp(0, 100) * 0.14;

/// Inverse of [cellToWorld]: maps a world XZ position back to the nearest grid
/// cell. Used for tap-to-place / tap-to-select hit testing.
({int x, int y}) worldToCell(
  double worldX,
  double worldZ, {
  int gridSize = 10,
  double spacing = kCell3DSpacing,
}) {
  final c = (gridSize - 1) / 2.0;
  return (
    x: (worldX / spacing + c).round(),
    y: (worldZ / spacing + c).round(),
  );
}

/// Whether a cell is inside a [gridSize] x [gridSize] board.
bool cellInBounds(int x, int y, {int gridSize = 10}) =>
    x >= 0 && y >= 0 && x < gridSize && y < gridSize;

/// Intersects a ray (from [origin] along [dir]) with the ground plane y = 0.
/// Returns the hit point, or null if the ray is parallel to or points away
/// from the plane. Pure — the camera-dependent screen→ray unprojection lives
/// in the widget; this is the testable geometry.
vm.Vector3? rayGroundHit(vm.Vector3 origin, vm.Vector3 dir) {
  if (dir.y.abs() < 1e-6) return null;
  final t = -origin.y / dir.y;
  if (t <= 0) return null;
  return origin + dir * t;
}

/// Stable key for a grid cell, used to track which node renders which cell.
String cellKey(int gridX, int gridY) => '$gridX,$gridY';

/// The work needed to reconcile the currently-rendered building set toward a
/// new desired set. Computed purely (no scene/GPU) so it can be unit-tested.
class CityDiff {
  CityDiff({
    required this.toAdd,
    required this.toRemove,
    required this.toUpdate,
  });

  /// Cells with no node yet, or whose type changed (paired with a [toRemove]).
  final List<PlacedBuilding> toAdd;

  /// Cell keys whose node should be removed (gone, or type changed).
  final List<String> toRemove;

  /// Cells whose node stays but needs a new transform (level changed).
  final List<PlacedBuilding> toUpdate;
}

/// Diffs the rendered set [current] (cellKey → rendered spec) against the
/// desired [next] list. A cell that changed type is both removed and re-added;
/// a cell that only changed level is updated in place; unchanged cells produce
/// no work. If [next] has duplicate cells, the last one wins.
CityDiff diffCity(
  Map<String, PlacedBuilding> current,
  List<PlacedBuilding> next,
) {
  final desired = <String, PlacedBuilding>{};
  for (final b in next) {
    desired[cellKey(b.gridX, b.gridY)] = b;
  }

  final toRemove = <String>[];
  final toAdd = <PlacedBuilding>[];
  final toUpdate = <PlacedBuilding>[];

  current.forEach((key, have) {
    final want = desired[key];
    if (want == null || want.typeId != have.typeId) {
      toRemove.add(key);
    }
  });

  desired.forEach((key, want) {
    final have = current[key];
    if (have == null || have.typeId != want.typeId) {
      toAdd.add(want);
    } else if (have.level != want.level) {
      toUpdate.add(want);
    }
  });

  return CityDiff(toAdd: toAdd, toRemove: toRemove, toUpdate: toUpdate);
}
