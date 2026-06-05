import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game3d/glb_bounds.dart';
import 'package:task2play/game3d/model_cache.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  group('AssetByteCache', () {
    test('reads each asset from the bundle at most once', () async {
      final calls = <String>[];
      final cache = AssetByteCache(loader: (key) async {
        calls.add(key);
        return Uint8List.fromList([key.length]);
      });

      final a = await cache.load('a.glb');
      final b = await cache.load('a.glb');

      expect(calls, ['a.glb'], reason: 'second load must hit the cache');
      expect(identical(a, b), isTrue, reason: 'same bytes instance reused');
    });

    test('concurrent loads of the same key share one fetch', () async {
      var count = 0;
      final cache = AssetByteCache(loader: (key) async {
        count++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return Uint8List.fromList([1, 2, 3]);
      });

      final results = await Future.wait([
        cache.load('x.glb'),
        cache.load('x.glb'),
        cache.load('x.glb'),
      ]);

      expect(count, 1, reason: 'in-flight future is shared, not re-fetched');
      expect(results[0], results[1]);
    });

    test('different keys are fetched independently', () async {
      final calls = <String>[];
      final cache = AssetByteCache(loader: (key) async {
        calls.add(key);
        return Uint8List(0);
      });

      await cache.load('a.glb');
      await cache.load('b.glb');

      expect(calls, ['a.glb', 'b.glb']);
      expect(cache.isCached('a.glb'), isTrue);
      expect(cache.isCached('c.glb'), isFalse);
    });

    test('clear() drops cached entries so they refetch', () async {
      var count = 0;
      final cache = AssetByteCache(loader: (key) async {
        count++;
        return Uint8List(0);
      });

      await cache.load('a.glb');
      cache.clear();
      await cache.load('a.glb');

      expect(count, 2);
    });
  });

  group('ModelNormalization', () {
    GlbInfo info(double sx, double sy, double sz, {bool embedded = true}) =>
        GlbInfo(
          bounds: vm.Aabb3.minMax(
              vm.Vector3(0, 0, 0), vm.Vector3(sx, sy, sz)),
          hasEmbeddedTextures: embedded,
        );

    test('normalizes footprint uniformly for a short building', () {
      // 12 wide, 10 tall (<= height ref) -> uniform scale, no vertical emphasis.
      final n = ModelNormalization.from(info(12, 10, 12));
      expect(n.horizontalScale, closeTo(n.verticalScale, 1e-9));
    });

    test('emphasizes height for a tall building (hybrid)', () {
      // 60 wide, 75 tall -> footprint dominated, but vertical gets stretched.
      final n = ModelNormalization.from(info(60, 75, 28));
      expect(n.verticalScale, greaterThan(n.horizontalScale),
          reason: 'tall model should stretch vertically');
    });

    test('vertical stretch is capped (mild distortion)', () {
      final n = ModelNormalization.from(info(60, 500, 28));
      expect(n.verticalScale / n.horizontalScale, lessThanOrEqualTo(2.4001));
    });

    test('recenter offset puts base at y=0 and footprint center at origin', () {
      final n = ModelNormalization.from(info(12, 20, 12)); // min at origin
      // base (minY=0) -> offset.y = 0; center (6,*,6) -> offset.x/z negative.
      expect(n.offset.y, closeTo(0, 1e-9));
      expect(n.offset.x, closeTo(-n.horizontalScale * 6, 1e-6));
    });

    test('embedded-texture models do not need the colormap fallback', () {
      expect(ModelNormalization.from(info(10, 10, 10)).needsColormap, isFalse);
      expect(
          ModelNormalization.from(info(10, 10, 10, embedded: false))
              .needsColormap,
          isTrue);
    });
  });
}
