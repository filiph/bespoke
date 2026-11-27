import 'package:filip_mcp/obsidian_note.dart';
import 'package:filip_mcp/obsidian_query.dart';
import 'package:filip_mcp/obsidian_vault.dart';
import 'package:filip_mcp/scored_result.dart';
import 'package:filip_mcp/vector_search.dart';
import 'package:test/test.dart';

class _FakeVectorSearchEngine implements VectorSearchEngine {
  @override
  void clear() {}

  @override
  Future<void> indexNote(ObsidianNote note) async {}

  @override
  Future<void> indexNotes(
    List<ObsidianNote> notes, {
    void Function(int processed, int total, String status)? onProgress,
  }) async {}

  @override
  Future<(List<ScoredResult>, int)> search(
    String query, {
    int? topK = 5,
    DateTime? createdBefore,
    DateTime? createdAfter,
    double similarityThreshold = 0.2,
  }) async {
    return (<ScoredResult>[], 0);
  }
}

void main() {
  group('ObsidianNote metadata extraction', () {
    test('extracts date and tags from YAML front matter', () {
      const content = '''---
date: 2022-05-09
tags:
  - thought
  - Game-Design
---
# My Title
This is a note body.
''';
      final note = ObsidianNote('/vault/notes/my_note.md', content);

      expect(note.createdAt, equals(DateTime(2022, 5, 9)));
      expect(note.tags, containsAll(['thought', 'game-design']));
      expect(note.title, equals('my_note'));
    });

    test('extracts comma-separated tags from front matter and inline #tags', () {
      const content = '''---
created: 2021-11-20T10:00:00Z
tags: personal, flutter
---
# Main Heading

Here is an inline #Thought and another #game/idea.
Punctuation check: #dev! And in parentheses (#architecture).
Do not match markdown # Heading.
''';
      final note = ObsidianNote('/vault/2021-11-20 note.md', content);

      expect(note.createdAt, equals(DateTime.utc(2021, 11, 20, 10, 0, 0)));
      expect(
        note.tags,
        containsAll([
          'personal',
          'flutter',
          'thought',
          'game/idea',
          'dev',
          'architecture',
        ]),
      );
      expect(note.tags, isNot(contains('heading')));
      expect(note.tags, isNot(contains('main')));
    });

    test('falls back to filename date prefix then file modification time', () {
      final modifiedTime = DateTime(2020, 1, 1, 12, 0);

      // Has filename date
      final noteWithFilenameDate = ObsidianNote(
        '/vault/2022-05-09 my thought.md',
        'No frontmatter',
        fileModifiedAt: modifiedTime,
      );
      expect(noteWithFilenameDate.createdAt, equals(DateTime(2022, 5, 9)));

      // No frontmatter, no filename date -> uses fileModifiedAt
      final noteWithModTime = ObsidianNote(
        '/vault/undated.md',
        'No frontmatter',
        fileModifiedAt: modifiedTime,
      );
      expect(noteWithModTime.createdAt, equals(modifiedTime));
    });
  });

  group('ObsidianVault.listNotes', () {
    late ObsidianVault vault;

    setUp(() {
      vault = ObsidianVault('/vault', _FakeVectorSearchEngine());
    });

    test('filters by from and to timestamps inclusively', () async {
      final notes = [
        ObsidianNote('/vault/2022-05-07 early.md', 'Early note'),
        ObsidianNote('/vault/2022-05-08 boundary_start.md', 'May 8 note'),
        ObsidianNote('/vault/2022-05-09 middle.md', 'May 9 note'),
        ObsidianNote('/vault/2022-05-10 boundary_end.md', 'May 10 note'),
        ObsidianNote('/vault/2022-05-11 late.md', 'Late note'),
        ObsidianNote('/vault/no_date.md', 'No date note'),
      ];
      vault.addNotes(notes);

      final response = await vault.listNotes(
        ObsidianListQuery(
          from: DateTime(2022, 5, 8),
          to: DateTime(2022, 5, 10),
        ),
      );

      expect(response.totalResults, equals(3));
      expect(
        response.results.map((r) => r.path).toList(),
        equals([
          '/vault/2022-05-08 boundary_start.md',
          '/vault/2022-05-09 middle.md',
          '/vault/2022-05-10 boundary_end.md',
        ]),
      );
    });

    test('includes notes without a date when no from/to is set', () async {
      final notes = [
        ObsidianNote('/vault/2022-05-09 dated.md', 'Dated note'),
        ObsidianNote('/vault/no_date.md', 'No date note'),
      ];
      vault.addNotes(notes);

      final response = await vault.listNotes(const ObsidianListQuery());

      expect(response.totalResults, equals(2));
      expect(
        response.results.map((r) => r.path).toList(),
        equals(['/vault/2022-05-09 dated.md', '/vault/no_date.md']),
      );
    });

    test('filters by tags with case-insensitive AND logic', () async {
      final notes = [
        ObsidianNote(
          '/vault/note1.md',
          '---\ntags: [thought, flutter]\n---\nNote 1',
        ),
        ObsidianNote(
          '/vault/note2.md',
          '---\ntags: [thought]\n---\nNote 2 with #Dart',
        ),
        ObsidianNote(
          '/vault/note3.md',
          '---\ntags: [dart, flutter]\n---\nNote 3',
        ),
      ];
      vault.addNotes(notes);

      // Filtering for #THOUGHT and #flutter
      final response = await vault.listNotes(
        const ObsidianListQuery(tags: ['#THOUGHT', 'flutter']),
      );

      expect(response.totalResults, equals(1));
      expect(response.results.single.path, equals('/vault/note1.md'));
    });

    test('filters by simple substring pattern in title or body', () async {
      final notes = [
        ObsidianNote('/vault/alpha.md', 'Discussing game mechanics'),
        ObsidianNote('/vault/Game Design.md', 'Level design details'),
        ObsidianNote('/vault/charlie.md', 'Unrelated content'),
      ];
      vault.addNotes(notes);

      final response = await vault.listNotes(
        const ObsidianListQuery(pattern: 'game'),
      );

      expect(response.totalResults, equals(2));
      expect(
        response.results.map((r) => r.path).toList(),
        equals(['/vault/alpha.md', '/vault/Game Design.md']),
      );
    });

    test('filters by regular expression pattern', () async {
      final notes = [
        ObsidianNote('/vault/note1.md', 'Issue #123 has been fixed'),
        ObsidianNote('/vault/note2.md', 'Issue #456 is in progress'),
        ObsidianNote('/vault/note3.md', 'No numbers here'),
      ];
      vault.addNotes(notes);

      final response = await vault.listNotes(
        const ObsidianListQuery(pattern: r'issue #\d{3}', isRegExp: true),
      );

      expect(response.totalResults, equals(2));
      expect(
        response.results.map((r) => r.path).toList(),
        equals(['/vault/note1.md', '/vault/note2.md']),
      );
    });

    test('sorts alphabetically by relative path and paginates with limit/offset', () async {
      final notes = [
        ObsidianNote('/vault/c_folder/note1.md', 'Content'),
        ObsidianNote('/vault/a_folder/note2.md', 'Content'),
        ObsidianNote('/vault/b_folder/note3.md', 'Content'),
        ObsidianNote('/vault/b_folder/note1.md', 'Content'),
      ];
      vault.addNotes(notes);

      // Page 1: limit 2, offset 0
      final page1 = await vault.listNotes(
        const ObsidianListQuery(limit: 2, offset: 0),
      );

      expect(page1.totalResults, equals(4));
      expect(page1.returnedResults, equals(2));
      expect(page1.offset, equals(0));
      expect(page1.hasMore, isTrue);
      expect(
        page1.results.map((r) => r.path).toList(),
        equals(['/vault/a_folder/note2.md', '/vault/b_folder/note1.md']),
      );

      // Page 2: limit 2, offset 2
      final page2 = await vault.listNotes(
        const ObsidianListQuery(limit: 2, offset: 2),
      );

      expect(page2.totalResults, equals(4));
      expect(page2.returnedResults, equals(2));
      expect(page2.offset, equals(2));
      expect(page2.hasMore, isFalse);
      expect(
        page2.results.map((r) => r.path).toList(),
        equals(['/vault/b_folder/note3.md', '/vault/c_folder/note1.md']),
      );
    });

    test('supports user scenario: "list my thought from around May 9, 2022"', () async {
      final notes = [
        ObsidianNote(
          '/vault/2022-05-08 thoughts on travel.md',
          'Reflecting on Prague.',
        ),
        ObsidianNote(
          '/vault/2022-05-09 thought on ai tools.md',
          'LLMs are evolving quickly.',
        ),
        ObsidianNote(
          '/vault/2022-05-10 meeting notes.md',
          'Discussed architecture with the team.',
        ),
        ObsidianNote(
          '/vault/2022-05-10 thought on rust.md',
          'Memory safety is fascinating.',
        ),
        ObsidianNote(
          '/vault/2022-05-12 thought on work.md',
          'Outside the range.',
        ),
      ];
      vault.addNotes(notes);

      // LLM translates "thoughts from around May 9, 2022" to from=2022-05-08, to=2022-05-10, pattern="thought"
      final response = await vault.listNotes(
        ObsidianListQuery(
          from: DateTime(2022, 5, 8),
          to: DateTime(2022, 5, 10),
          pattern: 'thought',
        ),
      );

      expect(response.totalResults, equals(3));
      expect(
        response.results.map((r) => r.path).toList(),
        equals([
          '/vault/2022-05-08 thoughts on travel.md',
          '/vault/2022-05-09 thought on ai tools.md',
          '/vault/2022-05-10 thought on rust.md',
        ]),
      );
      for (final item in response.results) {
        expect(item.snippet, isNotEmpty);
      }
    });
  });
}
