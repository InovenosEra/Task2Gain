import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game3d/model_cache.dart';

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
}
