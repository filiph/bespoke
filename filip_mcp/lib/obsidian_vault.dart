import 'dart:io';
import 'dart:math';

import 'package:filip_mcp/vector_search.dart';

import 'obsidian_note.dart';
import 'obsidian_query.dart';
import 'scored_result.dart';

class ObsidianVault {
  final String path;

  final List<ObsidianNote> _notes = [];

  final VectorSearchEngine vectorSearchEngine;

  ObsidianVault(this.path, this.vectorSearchEngine);

  ObsidianNote? fetch(String path) {
    return _notes.where((n) => n.path == path).singleOrNull;
  }

  Future<void> initialize() async {
    await _reindex();
  }

  Future<List<ScoredResult>> query(ObsidianQuery query) async {
    final List<ScoredResult> results;
    final limit = query.limit;

    final searchPhrase = query.searchPhrase;
    if (searchPhrase != null) {
      results = vectorSearchEngine.search(
        searchPhrase,
        topK: query.limit ?? 100,
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
    }

    final createdAfter = query.createdAfter;
    if (createdAfter != null) {
      results.removeWhere((r) => r.createdAt?.isBefore(createdAfter) ?? true);
    }

    final createdBefore = query.createdBefore;
    if (createdBefore != null) {
      results.removeWhere((r) => r.createdAt?.isAfter(createdBefore) ?? true);
    }

    if (limit != null && results.length > limit) {
      results.removeRange(limit, results.length);
    }

    return results;
  }

  Future<void> _reindex() async {
    final directory = Directory(path);

    final files = directory
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.md'))
        .cast<File>();

    final notes = await files.asyncMap(_noteFromFile).toList();
    _notes.clear();
    _notes.addAll(notes);

    vectorSearchEngine.clear();
    await notes.map((note) => vectorSearchEngine.indexNote(note)).wait;
  }

  static Future<ObsidianNote> _noteFromFile(File file) async {
    final path = file.path;
    final contents = await file.readAsString();
    return ObsidianNote(path, contents);
  }
}
