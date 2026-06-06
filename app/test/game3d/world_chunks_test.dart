import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game3d/world_chunks.dart';

void main() {
  group('defaultWorld', () {
    test('is a 3x3 grid with only the center revealed', () {
      final world = defaultWorld();
      expect(world.length, 9);
      expect(world.where((c) => c.revealed).length, 1);
      final center = world.singleWhere((c) => c.revealed);
      expect((center.col, center.row), (0, 0));
      // the other 8 form the hidden ring
      expect(world.where((c) => !c.revealed).length, 8);
    });
  });

  group('chunkWorldOffset', () {
    test('center chunk is at the origin', () {
      final o = chunkWorldOffset(0, 0);
      expect(o.x, 0);
      expect(o.z, 0);
    });

    test('neighbours are one chunk span away', () {
      expect(chunkWorldOffset(1, 0).x, closeTo(kChunkSpan, 1e-9));
      expect(chunkWorldOffset(0, -1).z, closeTo(-kChunkSpan, 1e-9));
      expect(chunkWorldOffset(1, 1).x, closeTo(kChunkSpan, 1e-9));
    });
  });
}
