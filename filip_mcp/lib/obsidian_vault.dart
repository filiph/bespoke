import 'dart:io';
import 'dart:math';

import 'package:filip_mcp/vector_search.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

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
    return ObsidianNote(path, contents);
  }
}
