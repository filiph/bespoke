import 'package:filip_mcp/obsidian_note.dart';
import 'package:filip_mcp/obsidian_query.dart';
import 'package:filip_mcp/obsidian_vault.dart';
import 'package:filip_mcp/scored_result.dart';
import 'package:filip_mcp/vector_search.dart';
import 'package:test/test.dart';

void main() {
  group('ObsidianVault', () {
    late _FakeVectorSearchEngine fakeVectorSearchEngine;
    late ObsidianVault vault;

    setUp(() {
      fakeVectorSearchEngine = _FakeVectorSearchEngine();
      vault = ObsidianVault('/fake/path', fakeVectorSearchEngine);
    });

    test('fetch returns null for non-existent note', () {
      expect(vault.fetch('/non/existent/path.md'), isNull);
    });

    test('fetch returns the correct note', () {
      final note = ObsidianNote('/fake/path/note.md', 'Test content');
      vault.addNotes([note]);
      expect(vault.fetch('/fake/path/note.md'), equals(note));
    });

    group('query', () {
      test('query with searchPhrase calls vectorSearchEngine.search', () async {
        final testNotes = [
          ObsidianNote('/fake/path/2023-01-15 note1.md', 'Test content 1'),
          ObsidianNote('/fake/path/2023-02-20 note2.md', 'Test content 2'),
          ObsidianNote('/fake/path/2023-03-25 note3.md', 'Test content 3'),
        ];
        vault.addNotes(testNotes);

        final query = ObsidianQuery(
          searchPhrase: 'test query',
          createdAfter: null,
          createdBefore: null,
          limit: 10,
        );

        final mockResults = [
          ScoredResult(testNotes[0], 0.9, 'Test content 1'),
          ScoredResult(testNotes[1], 0.8, 'Test content 2'),
        ];

        fakeVectorSearchEngine.setSearchResults(mockResults);

        final orderedResults = await vault.query(query);

        expect(orderedResults.results, equals(mockResults));
        expect(orderedResults.totalResults, equals(mockResults.length));
        expect(orderedResults.returnedResults, equals(mockResults.length));
      });

      test('query without searchPhrase returns all notes', () async {
        final testNotes = [
          ObsidianNote('/fake/path/2023-01-15 note1.md', 'Test content 1'),
          ObsidianNote('/fake/path/2023-02-20 note2.md', 'Test content 2'),
          ObsidianNote('/fake/path/2023-03-25 note3.md', 'Test content 3'),
        ];
        vault.addNotes(testNotes);

        final query = ObsidianQuery(
          searchPhrase: null,
          createdAfter: null,
          createdBefore: null,
          limit: null,
        );

        final orderedResults = await vault.query(query);

        expect(orderedResults.results.length, equals(3));
        expect(
          orderedResults.results.map((r) => r.path).toList()..sort(),
          equals(testNotes.map((n) => n.path).toList()..sort()),
        );
      });

      test('query with createdAfter filters notes correctly', () async {
        final testNotes = [
          ObsidianNote('/fake/path/2023-01-15 note1.md', 'Test content 1'),
          ObsidianNote('/fake/path/2023-02-20 note2.md', 'Test content 2'),
          ObsidianNote('/fake/path/2023-03-25 note3.md', 'Test content 3'),
        ];
        vault.addNotes(testNotes);

        final query = ObsidianQuery(
          searchPhrase: null,
          createdAfter: DateTime(2023, 2, 1),
          createdBefore: null,
          limit: null,
        );

        final orderedResults = await vault.query(query);

        expect(orderedResults.results.length, equals(2));
        expect(
          orderedResults.results.map((r) => r.path).toList()..sort(),
          equals([testNotes[1].path, testNotes[2].path]..sort()),
        );
      });

      test('query with createdBefore filters notes correctly', () async {
        final testNotes = [
          ObsidianNote('/fake/path/2023-01-15 note1.md', 'Test content 1'),
          ObsidianNote('/fake/path/2023-02-20 note2.md', 'Test content 2'),
          ObsidianNote('/fake/path/2023-03-25 note3.md', 'Test content 3'),
        ];
        vault.addNotes(testNotes);

        final query = ObsidianQuery(
          searchPhrase: null,
          createdAfter: null,
          createdBefore: DateTime(2023, 3, 1),
          limit: null,
        );

        final orderedResults = await vault.query(query);

        expect(orderedResults.results.length, equals(2));
        expect(
          orderedResults.results.map((r) => r.path).toList()..sort(),
          equals([testNotes[0].path, testNotes[1].path]..sort()),
        );
      });

      test(
        'query with createdAt fence does not return outside it',
        () async {
          final testNotes = [
            ObsidianNote('/fake/path/2018-02-14 note1.md', 'Test content 1'),
            ObsidianNote('/fake/path/2016-02-14 KoSF.md', 'Test content 2'),
            ObsidianNote('/fake/path/2023-03-25 note3.md', 'Test content 3'),
          ];
          vault.addNotes(testNotes);

          final query = ObsidianQuery(
            searchPhrase: 'content',
            createdAfter: DateTime(2016, 1, 1),
            createdBefore: DateTime(2016, 12, 31),
            limit: null,
          );

          final mockResults = [
            ScoredResult(testNotes[0], 0.9, 'Test content 1'),
            ScoredResult(testNotes[1], 0.8, 'Test content 2'),
            ScoredResult(testNotes[2], 0.8, 'Test content 3'),
          ];

          fakeVectorSearchEngine.setSearchResults(mockResults);

          final orderedResults = await vault.query(query);

          expect(orderedResults.results.length, equals(1));
          expect(
            orderedResults.results.map((r) => r.path),
            isNot(contains(testNotes[0].path)),
          );
          expect(
            orderedResults.results.map((r) => r.path),
            isNot(contains(testNotes[2].path)),
          );
        },
        skip: "we're actually limiting in the search engine now",
      );

      test(
        'query with createdAt fence does not return notes with no date',
        () async {
          final testNotes = [
            ObsidianNote('/fake/path/no-date.md', 'Test content 1'),
            ObsidianNote('/fake/path/2016-02-14 date.md', 'Test content 2'),
          ];
          vault.addNotes(testNotes);

          final query = ObsidianQuery(
            searchPhrase: 'content',
            createdAfter: DateTime(2016, 1, 1),
            createdBefore: DateTime(2016, 12, 31),
            limit: null,
          );

          final mockResults = [
            ScoredResult(testNotes[0], 0.9, 'Test content 1'),
            ScoredResult(testNotes[1], 0.8, 'Test content 2'),
          ];

          fakeVectorSearchEngine.setSearchResults(mockResults);

          final orderedResults = await vault.query(query);

          expect(orderedResults.results.length, equals(1));
          expect(
            orderedResults.results.map((r) => r.path),
            isNot(contains(testNotes[0].path)),
          );
          expect(
            orderedResults.results.map((r) => r.path),
            contains(testNotes[1].path),
          );
        },
        skip: "we're actually limiting in the search engine now",
      );

      test('query with limit restricts number of results', () async {
        final testNotes = [
          ObsidianNote('/fake/path/2023-01-15 note1.md', 'Test content 1'),
          ObsidianNote('/fake/path/2023-02-20 note2.md', 'Test content 2'),
          ObsidianNote('/fake/path/2023-03-25 note3.md', 'Test content 3'),
        ];
        vault.addNotes(testNotes);

        final query = ObsidianQuery(
          searchPhrase: null,
          createdAfter: null,
          createdBefore: null,
          limit: 2,
        );

        final orderedResults = await vault.query(query);

        expect(orderedResults.results.length, equals(2));
        expect(orderedResults.totalResults, equals(3));
        expect(orderedResults.returnedResults, equals(2));
      });

      test('query with all filters combined works correctly', () async {
        final testNotes = [
          ObsidianNote('/fake/path/2023-01-15 note1.md', 'Test content 1'),
          ObsidianNote('/fake/path/2023-02-20 note2.md', 'Test content 2'),
          ObsidianNote('/fake/path/2023-03-25 note3.md', 'Test content 3'),
        ];
        vault.addNotes(testNotes);

        final mockResults = [
          ScoredResult(testNotes[1], 0.9, 'Test content 2'),
          ScoredResult(testNotes[2], 0.8, 'Test content 3'),
        ];

        fakeVectorSearchEngine.setSearchResults(mockResults);

        final query = ObsidianQuery(
          searchPhrase: 'test query',
          createdAfter: DateTime(2023, 2, 1),
          createdBefore: DateTime(2023, 3, 1),
          limit: 1,
        );

        final orderedResults = await vault.query(query);

        expect(orderedResults.results.length, equals(1));
        expect(orderedResults.results[0].path, equals(testNotes[1].path));
        expect(orderedResults.totalResults, equals(2));
        expect(orderedResults.returnedResults, equals(1));
      });
    });
  });
}

/// A fake implementation of VectorSearchEngine for testing.
class _FakeVectorSearchEngine implements VectorSearchEngine {
  List<ScoredResult> _searchResults = [];
  bool clearCalled = false;
  List<ObsidianNote> indexedNotes = [];

  @override
  void clear() {
    clearCalled = true;
  }

  @override
  Future<void> indexNote(ObsidianNote note) async {
    indexedNotes.add(note);
  }

  @override
  Future<void> indexNotes(List<ObsidianNote> notes) async {
    for (final note in notes) {
      await indexNote(note);
    }
  }

  @override
  (List<ScoredResult>, int) search(
    String query, {
    int? topK = 5,
    DateTime? createdBefore,
    DateTime? createdAfter,
  }) {
    return (_searchResults, _searchResults.length);
  }

  /// Test helper to set up search results
  void setSearchResults(List<ScoredResult> results) {
    _searchResults = results;
  }
}
