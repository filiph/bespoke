import 'dart:io';
import 'dart:typed_data';

import 'package:filip_mcp/embedding_cache.dart';
import 'package:test/test.dart';

void main() {
  group('EmbeddingCache', () {
    late Directory tempDir;
    late String cachePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('embedding_cache_test_');
      cachePath = '${tempDir.path}/test_cache.bin';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves and loads notes and segments correctly', () async {
      final cache = EmbeddingCache();

      final v1 = Float32List(4)
        ..[0] = 0.1
        ..[1] = 0.2
        ..[2] = 0.3
        ..[3] = 0.4;
      final v2 = Float32List(4)
        ..[0] = 0.5
        ..[1] = 0.6
        ..[2] = 0.7
        ..[3] = 0.8;

      final note = CachedNote(
        path: '/path/to/note1.md',
        lastModifiedMs: 123456789,
        segments: [
          CachedSegment('Segment 1 text', v1),
          CachedSegment('Segment 2 text with special chars: ěščřž', v2),
        ],
      );

      cache.putNote(note);

      await cache.save(cachePath, dimensions: 4);

      final loaded = await EmbeddingCache.load(cachePath, dimensions: 4);
      expect(loaded.noteCount, equals(1));

      final loadedNote = loaded.getNote('/path/to/note1.md');
      expect(loadedNote, isNotNull);
      expect(loadedNote!.path, equals('/path/to/note1.md'));
      expect(loadedNote.lastModifiedMs, equals(123456789));
      expect(loadedNote.segments.length, equals(2));
      expect(loadedNote.segments[0].text, equals('Segment 1 text'));
      expect(loadedNote.segments[0].embedding[0], closeTo(0.1, 1e-6));
      expect(
        loadedNote.segments[1].text,
        equals('Segment 2 text with special chars: ěščřž'),
      );
      expect(loadedNote.segments[1].embedding[3], closeTo(0.8, 1e-6));
    });

    test('returns empty cache if file does not exist', () async {
      final loaded = await EmbeddingCache.load(
        '${tempDir.path}/non_existent.bin',
      );
      expect(loaded.noteCount, equals(0));
    });

    test('returns empty cache on dimension mismatch', () async {
      final cache = EmbeddingCache();
      cache.putNote(
        CachedNote(
          path: '/path/a.md',
          lastModifiedMs: 100,
          segments: [CachedSegment('A', Float32List(4))],
        ),
      );
      await cache.save(cachePath, dimensions: 4);

      final loaded = await EmbeddingCache.load(cachePath, dimensions: 8);
      expect(loaded.noteCount, equals(0));
    });
  });
}
