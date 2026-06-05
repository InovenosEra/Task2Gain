import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/game3d/glb_bounds.dart';

/// Builds a minimal valid GLB byte buffer wrapping [jsonStr] in a JSON chunk.
Uint8List buildGlb(String jsonStr) {
  final jsonBytes = <int>[...utf8.encode(jsonStr)];
  while (jsonBytes.length % 4 != 0) {
    jsonBytes.add(0x20); // pad with spaces
  }
  final total = 12 + 8 + jsonBytes.length;
  final out = ByteData(total);
  out.setUint32(0, 0x46546C67, Endian.little); // 'glTF'
  out.setUint32(4, 2, Endian.little); // version
  out.setUint32(8, total, Endian.little);
  out.setUint32(12, jsonBytes.length, Endian.little);
  out.setUint32(16, 0x4E4F534A, Endian.little); // 'JSON'
  final bytes = out.buffer.asUint8List();
  bytes.setRange(20, 20 + jsonBytes.length, jsonBytes);
  return bytes;
}

void main() {
  group('parseGlbJson', () {
    test('extracts the JSON chunk', () {
      final glb = buildGlb('{"asset":{"version":"2.0"},"meshes":[]}');
      final doc = parseGlbJson(glb);
      expect(doc['asset'], {'version': '2.0'});
      expect(doc['meshes'], isEmpty);
    });

    test('rejects non-GLB bytes', () {
      expect(() => parseGlbJson(Uint8List.fromList([1, 2, 3, 4, 5, 6])),
          throwsFormatException);
    });
  });

  group('gltfInfo bounds', () {
    Map<String, dynamic> docWith({
      List<double> min = const [-1, 0, -1],
      List<double> max = const [1, 2, 1],
      Map<String, dynamic>? nodeExtra,
      List<dynamic>? images,
    }) =>
        {
          'scene': 0,
          'scenes': [
            {
              'nodes': [0]
            }
          ],
          'nodes': [
            {'mesh': 0, ...?nodeExtra}
          ],
          'meshes': [
            {
              'primitives': [
                {
                  'attributes': {'POSITION': 0}
                }
              ]
            }
          ],
          'accessors': [
            {'type': 'VEC3', 'min': min, 'max': max}
          ],
          'images': images ?? const [],
        };

    test('unions a single mesh POSITION accessor min/max', () {
      final info = gltfInfo(docWith());
      expect(info.bounds, isNotNull);
      expect(info.bounds!.min.x, closeTo(-1, 1e-9));
      expect(info.bounds!.min.y, closeTo(0, 1e-9));
      expect(info.bounds!.max.x, closeTo(1, 1e-9));
      expect(info.bounds!.max.y, closeTo(2, 1e-9));
    });

    test('applies a node translation to the bounds', () {
      final info = gltfInfo(docWith(nodeExtra: {
        'translation': [10.0, 0.0, -5.0]
      }));
      expect(info.bounds!.min.x, closeTo(9, 1e-9));
      expect(info.bounds!.max.x, closeTo(11, 1e-9));
      expect(info.bounds!.min.z, closeTo(-6, 1e-9));
      expect(info.bounds!.max.z, closeTo(-4, 1e-9));
    });

    test('returns null bounds when there is no geometry', () {
      final info = gltfInfo({'nodes': [], 'scenes': [], 'meshes': []});
      expect(info.bounds, isNull);
    });
  });

  group('gltfInfo embedded textures', () {
    test('true when an image has a bufferView (embedded)', () {
      final info = gltfInfo({
        'nodes': [],
        'images': [
          {'bufferView': 4, 'mimeType': 'image/png'}
        ]
      });
      expect(info.hasEmbeddedTextures, isTrue);
    });

    test('false when images only reference external URIs', () {
      final info = gltfInfo({
        'nodes': [],
        'images': [
          {'uri': 'Textures/colormap.png'}
        ]
      });
      expect(info.hasEmbeddedTextures, isFalse);
    });

    test('false when there are no images at all', () {
      final info = gltfInfo({'nodes': []});
      expect(info.hasEmbeddedTextures, isFalse);
    });
  });
}
