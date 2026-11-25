import 'dart:io';

import 'package:filip_mcp/obsidian_note.dart';
import 'package:filip_mcp/vector_search.dart';
import 'package:test/test.dart';

void main() {
  group('VectorSearchEngine integration with local Ollama', () {
    late Directory tempDir;
    late String cachePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vector_search_test_');
      cachePath = '${tempDir.path}/cache.bin';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('indexes notes via Ollama and finds semantic match', () async {
      final engine = await VectorSearchEngine.initialize(
        model: 'embeddinggemma-2',
        dimensions: 768,
        windowSize: 300,
        windowOverlap: 100,
        cachePath: cachePath,
      );

      final noteFile1 = File('${tempDir.path}/prague.md');
      await noteFile1.writeAsString(
        'Prague is the capital city of the Czech Republic. '
        'It is known for the Old Town Square, Charles Bridge, and Prague Castle.',
      );

      final noteFile2 = File('${tempDir.path}/baking.md');
      await noteFile2.writeAsString(
        'Baking sourdough bread requires flour, water, salt, and active starter. '
        'Fermentation produces carbon dioxide gas which rises the dough.',
      );

      final notes = [
        ObsidianNote(noteFile1.path, await noteFile1.readAsString()),
        ObsidianNote(noteFile2.path, await noteFile2.readAsString()),
      ];

      await engine.indexNotes(notes);

      expect(File(cachePath).existsSync(), isTrue);

      final (results, total) = await engine.search(
        'Czech capital landmarks',
        topK: 2,
      );

      expect(total, greaterThanOrEqualTo(1));
      expect(results.first.path, equals(noteFile1.path));
      expect(results.first.score, greaterThan(0.3));

      // Test second engine run loading from cache
      final cachedEngine = await VectorSearchEngine.initialize(
        model: 'embeddinggemma-2',
        dimensions: 768,
        cachePath: cachePath,
      );

      await cachedEngine.indexNotes(notes);

      final (cachedResults, _) = await cachedEngine.search(
        'sourdough starter fermentation',
        topK: 2,
      );
      expect(cachedResults.first.path, equals(noteFile2.path));
    });

    test(
      'handles empty notes, whitespace notes, and empty queries without error',
      () async {
        final engine = await VectorSearchEngine.initialize(
          model: 'embeddinggemma-2',
          dimensions: 768,
          cachePath: cachePath,
        );

        final emptyNote = File('${tempDir.path}/empty.md');
        await emptyNote.writeAsString('');

        final whitespaceNote = File('${tempDir.path}/whitespace.md');
        await whitespaceNote.writeAsString('   \n\t  \n  ');

        final validNote = File('${tempDir.path}/valid.md');
        await validNote.writeAsString(
          'Machine learning models process vector representations.',
        );

        final notes = [
          ObsidianNote(emptyNote.path, await emptyNote.readAsString()),
          ObsidianNote(
            whitespaceNote.path,
            await whitespaceNote.readAsString(),
          ),
          ObsidianNote(validNote.path, await validNote.readAsString()),
        ];

        // Should not throw ApiException(400): empty content
        await engine.indexNotes(notes);

        // Search with empty query should return empty without throwing
        final (emptyResults, emptyTotal) = await engine.search('');
        expect(emptyResults, isEmpty);
        expect(emptyTotal, equals(0));

        // Search with valid query should find the valid note
        final (results, _) = await engine.search('vectors and embeddings');
        expect(results, isNotEmpty);
        expect(results.first.path, equals(validNote.path));
      },
    );
  });
}
