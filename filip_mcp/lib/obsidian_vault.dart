import 'dart:io';
import 'dart:math';

import 'package:filip_mcp/vector_search.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'obsidian_note.dart';
import 'obsidian_query.dart';
import 'ordered_results_list.dart';
import 'scored_result.dart';

class ObsidianVault {
  static final Logger _log = Logger('ObsidianVault');

  final String vaultPath;

  final List<ObsidianNote> _notes = [];

  final VectorSearchEngine vectorSearchEngine;

  ObsidianVault(this.vaultPath, this.vectorSearchEngine);

  /// Used in tests to avoid having to actually index the file system.
  @visibleForTesting
  void addNotes(Iterable<ObsidianNote> notes) {
    _notes.addAll(notes);
  }

  ObsidianNote? fetch(String path) {
    _log.fine('Fetching note with path = $path');
    return _notes.where((n) => n.path == path).singleOrNull;
  }

  Future<void> initialize({
    void Function(int processed, int total, String status)? onProgress,
  }) async {
    await _reindex(onProgress: onProgress);
    _log.info('Vault initialized');
  }

  Future<OrderedResultsList> query(ObsidianQuery query) async {
    _log.info('Performing query: $query');

    final List<ScoredResult> results;
    final limit = query.limit;

    // Store the total number of results before applying filters
    final int totalResults;

    final searchPhrase = query.searchPhrase;
    if (searchPhrase != null) {
      (results, totalResults) = await vectorSearchEngine.search(
        searchPhrase,
        topK: query.limit ?? 100,
        createdAfter: query.createdAfter,
        createdBefore: query.createdBefore,
      );
    } else {
      results = _notes
          .map(
            (n) => ScoredResult(
              n,
              1.0,
              n.contents.substring(0, min(100, n.contents.length)),
            ),
          )
          .toList();

      final createdAfter = query.createdAfter;
      if (createdAfter != null) {
        results.removeWhere((r) => r.createdAt?.isBefore(createdAfter) ?? true);
        _log.fine('After applying createdAfter: ${results.length}');
      }

      final createdBefore = query.createdBefore;
      if (createdBefore != null) {
        results.removeWhere((r) => r.createdAt?.isAfter(createdBefore) ?? true);
        _log.fine('After applying createdBefore: ${results.length}');
      }

      totalResults = results.length;
    }

    _log.fine('Found ${results.length} raw results.');

    if (limit != null && results.length > limit) {
      results.removeRange(limit, results.length);
      _log.fine('After applying limit: ${results.length}');
    }

    return OrderedResultsList(
      results: results,
      totalResults: totalResults,
      returnedResults: results.length,
    );
  }

  /// Lists and filters notes according to [query], sorted alphabetically by
  /// path relative to the vault and paginated with limit/offset.
  ///
  /// When [ObsidianListQuery.from] or [ObsidianListQuery.to] is set, notes
  /// without a parseable creation date are excluded.
  Future<NoteListResponse> listNotes(ObsidianListQuery query) async {
    _log.info('Listing notes with query: $query');

    final fromDate = query.from;
    final fromStartOfDay = fromDate != null
        ? DateTime(fromDate.year, fromDate.month, fromDate.day, 0, 0, 0, 0)
        : null;

    final toDate = query.to;
    final toEndOfDay = toDate != null
        ? DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999)
        : null;

    final queryTags = query.tags
        ?.map((t) => ObsidianNote.normalizeTag(t))
        .whereType<String>()
        .toList();

    RegExp? patternRegex;
    String? lowerPattern;
    if (query.pattern != null && query.pattern!.isNotEmpty) {
      if (query.isRegExp) {
        patternRegex = RegExp(query.pattern!, caseSensitive: false);
      } else {
        lowerPattern = query.pattern!.toLowerCase();
      }
    }

    final filtered = <ObsidianNote>[];
    for (final note in _notes) {
      // Date filter
      if (fromStartOfDay != null) {
        if (note.createdAt == null || note.createdAt!.isBefore(fromStartOfDay)) {
          continue;
        }
      }
      if (toEndOfDay != null) {
        if (note.createdAt == null || note.createdAt!.isAfter(toEndOfDay)) {
          continue;
        }
      }

      // Tags filter (case-insensitive AND)
      if (queryTags != null && queryTags.isNotEmpty) {
        var hasAllTags = true;
        for (final tag in queryTags) {
          if (!note.tags.contains(tag)) {
            hasAllTags = false;
            break;
          }
        }
        if (!hasAllTags) continue;
      }

      // Pattern filter (title or contents)
      if (patternRegex != null) {
        if (!patternRegex.hasMatch(note.title) &&
            !patternRegex.hasMatch(note.contents)) {
          continue;
        }
      } else if (lowerPattern != null) {
        if (!note.title.toLowerCase().contains(lowerPattern) &&
            !note.contents.toLowerCase().contains(lowerPattern)) {
          continue;
        }
      }

      filtered.add(note);
    }

    // Sort alphabetically by relative file path
    filtered.sort((a, b) {
      final relA = p.relative(a.path, from: vaultPath).toLowerCase();
      final relB = p.relative(b.path, from: vaultPath).toLowerCase();
      return relA.compareTo(relB);
    });

    final totalResults = filtered.length;
    final offset = query.offset.clamp(0, totalResults);
    final limit = query.limit.clamp(1, 1000);
    final paged = filtered.skip(offset).take(limit).toList();
    final hasMore = offset + paged.length < totalResults;

    final results = <NoteListResult>[];
    for (final note in paged) {
      final snippet = _generateSnippet(note, patternRegex, lowerPattern);
      results.add(
        NoteListResult(
          title: note.title,
          path: note.path,
          createdAt: note.createdAt,
          tags: note.tags.toList()..sort(),
          snippet: snippet,
        ),
      );
    }

    return NoteListResponse(
      results: results,
      totalResults: totalResults,
      returnedResults: results.length,
      offset: offset,
      hasMore: hasMore,
    );
  }

  static String _generateSnippet(
    ObsidianNote note,
    RegExp? patternRegex,
    String? lowerPattern,
  ) {
    final contents = note.contents;
    if (contents.isEmpty) return '';

    int matchIndex = -1;
    int matchLength = 0;

    if (patternRegex != null) {
      final match = patternRegex.firstMatch(contents);
      if (match != null) {
        matchIndex = match.start;
        matchLength = match.end - match.start;
      }
    } else if (lowerPattern != null) {
      final idx = contents.toLowerCase().indexOf(lowerPattern);
      if (idx != -1) {
        matchIndex = idx;
        matchLength = lowerPattern.length;
      }
    }

    const snippetRadius = 75;
    if (matchIndex != -1) {
      final start = max(0, matchIndex - snippetRadius);
      final end = min(contents.length, matchIndex + matchLength + snippetRadius);
      var snippet = contents
          .substring(start, end)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (start > 0) snippet = '... $snippet';
      if (end < contents.length) snippet = '$snippet ...';
      return snippet;
    }

    // Default: beginning of note (skipping front matter if present)
    var text = contents;
    final fmMatch = ObsidianNote.frontMatterRegex.firstMatch(text);
    if (fmMatch != null) {
      text = text.substring(fmMatch.end).trim();
    }
    if (text.isEmpty) text = contents;

    const maxLen = 150;
    if (text.length <= maxLen) {
      return text.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return '${text.substring(0, maxLen).replaceAll(RegExp(r'\s+'), ' ').trim()} ...';
  }

  Future<void> _reindex({
    void Function(int processed, int total, String status)? onProgress,
  }) async {
    final directory = Directory(vaultPath);

    final files = directory
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.md'))
        .cast<File>();

    final notes = await files.asyncMap(_noteFromFile).toList();
    _notes.clear();
    _notes.addAll(notes);

    vectorSearchEngine.clear();
    await vectorSearchEngine.indexNotes(notes, onProgress: onProgress);
  }

  static Future<ObsidianNote> _noteFromFile(File file) async {
    final path = file.path;
    final contents = await file.readAsString();
    final modified = await file.lastModified();
    return ObsidianNote(path, contents, fileModifiedAt: modified);
  }
}
