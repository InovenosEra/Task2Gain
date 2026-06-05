import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

/// What we learn by inspecting a GLB up front: its world-space bounding box
/// (for auto-scale + recenter) and whether it carries embedded textures (so we
/// know whether to fall back to the Kenney colormap for texture-less models).
class GlbInfo {
  GlbInfo({required this.bounds, required this.hasEmbeddedTextures});

  /// World-space AABB of the default scene's geometry, or null if none.
  final vm.Aabb3? bounds;

  /// True if any image is stored in the binary buffer (vs an external `uri`
  /// we can't resolve at runtime).
  final bool hasEmbeddedTextures;
}

/// Extracts the glTF JSON document from GLB [bytes].
Map<String, dynamic> parseGlbJson(Uint8List bytes) {
  if (bytes.length < 20) {
    throw const FormatException('Too short to be a GLB');
  }
  final bd = ByteData.sublistView(bytes);
  if (bd.getUint32(0, Endian.little) != 0x46546C67) {
    throw const FormatException('Not a GLB file (bad magic)');
  }
  final length = bd.getUint32(8, Endian.little);
  var off = 12;
  while (off + 8 <= length && off + 8 <= bytes.length) {
    final chunkLen = bd.getUint32(off, Endian.little);
    final chunkType = bd.getUint32(off + 4, Endian.little);
    final start = off + 8;
    if (chunkType == 0x4E4F534A) {
      // 'JSON'
      final jsonBytes = bytes.sublist(start, start + chunkLen);
      return json.decode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
    }
    off = start + chunkLen;
  }
  throw const FormatException('No JSON chunk in GLB');
}

/// Computes the world-space AABB and embedded-texture flag for a parsed glTF
/// [doc]. Walks the default scene's node hierarchy applying each node's
/// transform, and unions the transformed corners of every primitive's
/// POSITION accessor min/max. Pure (no GPU / asset I/O) so it is unit-testable.
GlbInfo gltfInfo(Map<String, dynamic> doc) {
  final accessors = (doc['accessors'] as List?) ?? const [];
  final meshes = (doc['meshes'] as List?) ?? const [];
  final nodes = (doc['nodes'] as List?) ?? const [];
  final scenes = (doc['scenes'] as List?) ?? const [];
  final defaultScene = (doc['scene'] as num?)?.toInt() ?? 0;

  final List<int> roots;
  if (scenes.isNotEmpty && defaultScene >= 0 && defaultScene < scenes.length) {
    roots = (((scenes[defaultScene] as Map)['nodes'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList();
  } else {
    roots = List<int>.generate(nodes.length, (i) => i);
  }

  vm.Aabb3? acc;
  void expand(vm.Vector3 p) {
    if (acc == null) {
      acc = vm.Aabb3.minMax(p.clone(), p.clone());
    } else {
      acc!.hullPoint(p);
    }
  }

  void walk(int nodeIdx, vm.Matrix4 parent) {
    if (nodeIdx < 0 || nodeIdx >= nodes.length) return;
    final n = nodes[nodeIdx] as Map;
    final world = parent.multiplied(_nodeMatrix(n));
    final meshIdx = (n['mesh'] as num?)?.toInt();
    if (meshIdx != null && meshIdx >= 0 && meshIdx < meshes.length) {
      final prims = ((meshes[meshIdx] as Map)['primitives'] as List?) ?? const [];
      for (final prim in prims) {
        final posIdx = ((prim as Map)['attributes'] as Map?)?['POSITION'];
        if (posIdx is! num) continue;
        final a = accessors[posIdx.toInt()] as Map;
        final mn = (a['min'] as List?)?.cast<num>();
        final mx = (a['max'] as List?)?.cast<num>();
        if (mn == null || mx == null || mn.length < 3 || mx.length < 3) continue;
        for (var i = 0; i < 8; i++) {
          final corner = vm.Vector3(
            (i & 1) == 0 ? mn[0].toDouble() : mx[0].toDouble(),
            (i & 2) == 0 ? mn[1].toDouble() : mx[1].toDouble(),
            (i & 4) == 0 ? mn[2].toDouble() : mx[2].toDouble(),
          );
          expand(world.transformed3(corner));
        }
      }
    }
    for (final ch in (n['children'] as List?) ?? const []) {
      walk((ch as num).toInt(), world);
    }
  }

  for (final r in roots) {
    walk(r, vm.Matrix4.identity());
  }

  final images = (doc['images'] as List?) ?? const [];
  final hasEmbedded = images.any((im) => (im as Map)['bufferView'] != null);

  return GlbInfo(bounds: acc, hasEmbeddedTextures: hasEmbedded);
}

/// Builds a node's local transform from its glTF `matrix` or `translation`/
/// `rotation`/`scale` (TRS). Defaults to identity.
vm.Matrix4 _nodeMatrix(Map n) {
  final m = n['matrix'];
  if (m is List && m.length == 16) {
    return vm.Matrix4.fromList(m.map((e) => (e as num).toDouble()).toList());
  }
  final t = _vec3(n['translation'], 0);
  final s = _vec3(n['scale'], 1);
  final r = n['rotation'];
  final q = (r is List && r.length == 4)
      ? vm.Quaternion(r[0].toDouble(), r[1].toDouble(), r[2].toDouble(),
          r[3].toDouble())
      : vm.Quaternion.identity();
  return vm.Matrix4.compose(t, q, s);
}

vm.Vector3 _vec3(dynamic v, double fallback) {
  if (v is List && v.length >= 3) {
    return vm.Vector3(v[0].toDouble(), v[1].toDouble(), v[2].toDouble());
  }
  return vm.Vector3(fallback, fallback, fallback);
}
