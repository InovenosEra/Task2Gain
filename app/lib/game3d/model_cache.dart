import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart';

import 'city3d_config.dart';

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

/// Load-once provider of 3D building models for the city scene.
///
/// Each placed building is a *fresh* [Node] (flutter_scene mutates a node's
/// transform in place, so instances can't be shared), but the expensive
/// inputs — the GLB bytes and the shared colormap texture — are loaded a
/// single time and reused across every placement. Building type ids resolve
/// to GLB files through [modelAssetPathFor], so swapping in nicer per-type
/// models later is just an edit to [kBuildingModels].
class City3DModels {
  City3DModels({AssetByteCache? byteCache})
      : _bytes = byteCache ?? AssetByteCache();

  final AssetByteCache _bytes;

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

  /// Instantiates a fresh, colormapped building [Node] for [typeId]. The GLB
  /// bytes for the resolved model are cached, so repeated calls for the same
  /// model only pay GLB parsing, not asset I/O.
  Future<Node> newBuilding(String typeId) async {
    await warmUp();
    final bytes = await _bytes.load(modelAssetPathFor(typeId));
    final node = await Node.fromGlbBytes(bytes);
    _applyColormap(node);
    return node;
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
