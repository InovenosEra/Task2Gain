import 'package:vector_math/vector_math.dart' as vm;

import 'city3d_config.dart';
import 'city3d_layout.dart';

/// World-expansion foundation (Stage A, visual only): the world is a grid of
/// 10×10-cell CHUNKS. The current city is the one revealed chunk; the chunks
/// around it exist but are hidden under cloud cover. No reveal logic yet.

/// World-space size of one chunk (the full grid area).
const double kChunkSpan = kCity3DMaxGrid * kCell3DSpacing; // 10 * 2.4 = 24

class WorldChunk {
  const WorldChunk(this.col, this.row, {required this.revealed});
  final int col;
  final int row;
  final bool revealed;
}

/// The default static world: a 3×3 grid with the center revealed (the current
/// city) and the surrounding ring hidden. Foundation for later reveal mechanics.
List<WorldChunk> defaultWorld() => [
      for (var row = -1; row <= 1; row++)
        for (var col = -1; col <= 1; col++)
          WorldChunk(col, row, revealed: col == 0 && row == 0),
    ];

/// World offset of a chunk's center (the revealed chunk is centered on origin).
vm.Vector3 chunkWorldOffset(int col, int row) =>
    vm.Vector3(col * kChunkSpan, 0, row * kChunkSpan);
