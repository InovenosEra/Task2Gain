import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'city3d_config.dart';
import 'glb_bounds.dart';

/// Loads raw asset bytes, caching each asset key so the bundle is read at most
/// once per key. The actual loader is injectable for tests; in the app it
/// falls back to [rootBundle].
///
/// Caching the *future* (not just the result) means concurrent callers for the
/// same key share a single in-flight fetch instead of racing.
class AssetByteCache {
  AssetByteCache({Future<Uint8List> Function(String key)? loader})
      : _loader = loader ?? _loadFromBundle;

  final Future<Uint8List> Function(String key) _loader;
  final Map<String, Future<Uint8List>> _inFlight = {};

  /// Returns the bytes for [key], fetching (and caching) on first request.
  Future<Uint8List> load(String key) =>
      _inFlight.putIfAbsent(key, () => _loader(key));

  /// Whether [key] has been requested (and is cached or in flight).
  bool isCached(String key) => _inFlight.containsKey(key);

  /// Drops all cached entries; subsequent [load] calls refetch.
  void clear() => _inFlight.clear();

  static Future<Uint8List> _loadFromBundle(String key) async =>
      (await rootBundle.load(key)).buffer.asUint8List();
}

/// Per-model normalization: how to scale a source model to the target
/// footprint and recenter it so its base sits at y=0, centered on the origin
/// in X/Z. Computed once per model from its bounding box. [needsColormap] is
/// true for models without embedded textures (the Kenney placeholder), which
/// fall back to the shared colormap.
@immutable
class ModelNormalization {
  const ModelNormalization({
    required this.scale,
    required this.offset,
    required this.needsColormap,
  });

  final double scale;
  final vm.Vector3 offset;
  final bool needsColormap;

  /// Local transform that scales the source model and shifts its base-center
  /// to the origin. Applied to the model node; the placement transform (tile
  /// position + level scale) is applied to the wrapper above it.
  vm.Matrix4 get transform =>
      vm.Matrix4.translation(offset)..scaleByDouble(scale, scale, scale, 1);

  /// Derives a normalization from a model's [info]. Scales the larger of the
  /// X/Z extents to [kCity3DTargetFootprint]; offset places the footprint
  /// center + base at the origin. Falls back to identity for boundless models.
  factory ModelNormalization.from(GlbInfo info) {
    final b = info.bounds;
    final needsColormap = !info.hasEmbeddedTextures;
    if (b == null) {
      return ModelNormalization(
          scale: 1, offset: vm.Vector3.zero(), needsColormap: needsColormap);
    }
    final footprint = math.max(b.max.x - b.min.x, b.max.z - b.min.z);
    final scale =
        footprint > 1e-6 ? kCity3DTargetFootprint / footprint : 1.0;
    // After scaling vertex v -> scale*v, we want the footprint center + base
    // (cx, minY, cz) to land at the origin, so offset = -scale * that point.
    final cx = (b.min.x + b.max.x) / 2;
    final cz = (b.min.z + b.max.z) / 2;
    final offset = vm.Vector3(-scale * cx, -scale * b.min.y, -scale * cz);
    return ModelNormalization(
        scale: scale, offset: offset, needsColormap: needsColormap);
  }
}

/// Load-once provider of 3D building models for the city scene.
///
/// Each placed building is a *fresh* [Node] (flutter_scene mutates a node's
/// transform in place, so instances can't be shared), but the expensive
/// inputs — the GLB bytes, its computed normalization, and the shared colormap
/// texture — are loaded a single time and reused across every placement.
/// Building type ids resolve to GLB files through [modelAssetPathFor], so
/// swapping in nicer per-type models later is just an edit to [kBuildingModels].
///
/// Every model is auto-scaled to a consistent footprint and recentered on its
/// tile (see [ModelNormalization]), so models from any pack — whatever their
/// native size or origin — drop in cleanly.
class City3DModels {
  City3DModels({AssetByteCache? byteCache})
      : _bytes = byteCache ?? AssetByteCache();

  final AssetByteCache _bytes;
  final Map<String, ModelNormalization> _norms = {};

  /// The shared palette texture, loaded once. Kept as [Object] so callers/
  /// tests don't need to import the flutter_gpu types directly. `null` until
  /// [warmUp] (or the first [newBuilding]) succeeds, or if it fails to load.
  Object? _colormap;
  Future<void>? _colormapLoad;

  /// Pre-loads the shared colormap so the first building placement is instant.
  /// Safe to call repeatedly; the work happens once.
  Future<void> warmUp() => _colormapLoad ??= _loadColormap();

  Future<void> _loadColormap() async {
    try {
      _colormap = await gpuTextureFromAsset(kCity3DColormap);
    } catch (e) {
      debugPrint('city3d: colormap not applied: $e');
    }
  }

  /// Instantiates a fresh building [Node] for [typeId], auto-scaled to the
  /// target footprint and recentered so its base sits on its tile. Returns a
  /// wrapper node (identity transform) whose single child is the normalized
  /// model — callers position the wrapper; the model keeps its normalization.
  ///
  /// The GLB bytes and the model's normalization are cached, so repeated calls
  /// for the same model only pay GLB parsing, not asset I/O or bbox analysis.
  /// Texture-less models (the Kenney placeholder) get the colormap fallback;
  /// models with embedded textures keep their own.
  Future<Node> newBuilding(String typeId) async {
    await warmUp();
    final path = modelAssetPathFor(typeId);
    final bytes = await _bytes.load(path);
    final norm = _norms.putIfAbsent(
        path, () => ModelNormalization.from(gltfInfo(parseGlbJson(bytes))));

    final model = await Node.fromGlbBytes(bytes);
    model.localTransform = norm.transform;
    if (norm.needsColormap) _applyColormap(model);

    return Node()..add(model);
  }

  void _applyColormap(Node root) {
    final tex = _colormap;
    if (tex == null) return;
    void walk(Node n) {
      final mesh = n.mesh;
      if (mesh != null) {
        for (final primitive in mesh.primitives) {
          final material = primitive.material;
          if (material is PhysicallyBasedMaterial) {
            material.baseColorTexture = tex as dynamic;
          }
        }
      }
      for (final child in n.children) {
        walk(child);
      }
    }

    walk(root);
  }
}
