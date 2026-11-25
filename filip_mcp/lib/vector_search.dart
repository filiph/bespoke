import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:ollama_dart/ollama_dart.dart';

import 'embedding_cache.dart';
import 'obsidian_note.dart';
import 'scored_result.dart';

extension Float32VectorOps on Float32List {
  /// Computes dot product between two float32 vectors.
  /// For L2-normalized vectors (as returned by Ollama), dot product equals cosine similarity.
  double dotProduct(Float32List other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector dimensions must match ($length != ${other.length})',
      );
    }
    var sum = 0.0;
    for (var i = 0; i < length; i++) {
      sum += this[i] * other[i];
    }
    return sum;
  }
}

/// Main vector search engine for notes using local Ollama embeddings.
class VectorSearchEngine {
  static final Logger _log = Logger('VectorSearchEngine');

  final OllamaClient _client;
  final String _model;
  final int _dimensions;
  final int _windowSize; // words per window
  final int _windowOverlap; // overlapping words between windows
  final String? _cachePath;
  final EmbeddingCache? _cache;

  final List<_TextEmbedding> _noteEmbeddings = [];

  VectorSearchEngine._({
    required OllamaClient client,
    required String model,
    required int dimensions,
    required int windowSize,
    required int windowOverlap,
    String? cachePath,
    EmbeddingCache? cache,
  }) : _client = client,
       _model = model,
       _dimensions = dimensions,
       _windowSize = windowSize,
       _windowOverlap = windowOverlap,
       _cachePath = cachePath,
       _cache = cache {
    if (_windowSize <= 0) {
      throw ArgumentError('Window size must be positive');
    }
    if (_windowOverlap < 0 || _windowOverlap >= _windowSize) {
      throw ArgumentError(
        'Overlap must be non-negative and less than window size',
      );
    }
  }

  /// Initializes the search engine with an Ollama client and optional cache.
  static Future<VectorSearchEngine> initialize({
    String baseUrl = 'http://localhost:11434',
    String model = 'embeddinggemma-2',
    int dimensions = 768,
    int windowSize = 300,
    int windowOverlap = 100,
    String? cachePath,
    OllamaClient? client,
  }) async {
    final ollamaClient =
        client ?? OllamaClient(config: OllamaConfig(baseUrl: baseUrl));
    EmbeddingCache? cache;
    if (cachePath != null) {
      cache = await EmbeddingCache.load(cachePath, dimensions: dimensions);
    }

    return VectorSearchEngine._(
      client: ollamaClient,
      model: model,
      dimensions: dimensions,
      windowSize: windowSize,
      windowOverlap: windowOverlap,
      cachePath: cachePath,
      cache: cache,
    );
  }

  /// Tokenizes text into word tokens preserving punctuation and case.
  static List<String> _tokenize(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  /// Splits a note into sliding window segments of words.
  List<String> _extractSegments(String text) {
    final words = _tokenize(text);
    if (words.isEmpty) {
      return const [];
    }
    if (words.length <= _windowSize) {
      final trimmed = text.trim();
      return trimmed.isNotEmpty ? [trimmed] : const [];
    }

    final segments = <String>[];
    for (int i = 0; i < words.length; i += _windowSize - _windowOverlap) {
      final end = min(i + _windowSize, words.length);
      final segmentText = words.sublist(i, end).join(' ').trim();
      if (segmentText.isNotEmpty) {
        segments.add(segmentText);
      }
      if (end >= words.length) break;
    }
    return segments;
  }

  /// Embeds a batch of texts using Ollama.
  Future<List<Float32List>> _embedBatch(List<String> texts) async {
    if (texts.isEmpty) return [];

    final response = await _client.embeddings.create(
      request: EmbedRequest(model: _model, input: EmbedInput.list(texts)),
    );

    final embeddings = response.embeddings;
    if (embeddings == null) {
      throw StateError('Ollama returned no embeddings in response.');
    }

    return embeddings.map((vec) => Float32List.fromList(vec)).toList();
  }

  /// Indexes a single note.
  Future<void> indexNote(ObsidianNote note) async {
    await indexNotes([note]);
  }

  /// Indexes a list of notes using cached embeddings where possible and
  /// batching embedding generation for new or modified notes.
  Future<void> indexNotes(
    List<ObsidianNote> notes, {
    void Function(int processed, int total, String status)? onProgress,
  }) async {
    _log.info('Indexing ${notes.length} notes...');
    _noteEmbeddings.clear();

    final toEmbed = <(ObsidianNote, int, List<String>)>[];
    final validPaths = <String>{};
    var cachedNotesCount = 0;

    for (final note in notes) {
      validPaths.add(note.path);
      final file = File(note.path);
      int mtime = 0;
      if (file.existsSync()) {
        mtime = file.statSync().modified.millisecondsSinceEpoch;
      }

      final cached = _cache?.getNote(note.path);
      if (cached != null && cached.lastModifiedMs >= mtime && mtime > 0) {
        cachedNotesCount++;
        for (final seg in cached.segments) {
          _noteEmbeddings.add(_TextEmbedding(seg.text, seg.embedding, note));
        }
      } else {
        final segments = _extractSegments(note.contents);
        toEmbed.add((note, mtime, segments));
      }
    }

    if (toEmbed.isNotEmpty) {
      _log.info(
        'Found ${toEmbed.length} notes requiring embedding computation.',
      );

      // Collect all segments with note association and prep per-note cache
      final noteSegmentsMap = <String, List<CachedSegment>>{};
      final allSegments = <(ObsidianNote, int, String)>[];
      for (final (note, mtime, segments) in toEmbed) {
        noteSegmentsMap[note.path] = <CachedSegment>[];
        for (final seg in segments) {
          final trimmed = seg.trim();
          if (trimmed.isNotEmpty) {
            allSegments.add((note, mtime, trimmed));
          }
        }
      }

      const batchSize = 64;
      var lastSave = DateTime.now();

      for (int i = 0; i < allSegments.length; i += batchSize) {
        final end = min(i + batchSize, allSegments.length);
        final batch = allSegments.sublist(i, end);
        final texts = batch.map((item) => item.$3).toList();

        final vectors = await _embedBatch(texts);

        for (int j = 0; j < batch.length; j++) {
          final (note, _, text) = batch[j];
          final vec = vectors[j];
          _noteEmbeddings.add(_TextEmbedding(text, vec, note));
          noteSegmentsMap[note.path]?.add(CachedSegment(text, vec));
        }

        onProgress?.call(
          end,
          allSegments.length,
          'Embedding text segments ($end / ${allSegments.length})',
        );

        // Periodically save intermediate cache every 30 seconds
        if (_cache != null &&
            _cachePath != null &&
            DateTime.now().difference(lastSave).inSeconds >= 30) {
          for (final (note, mtime, _) in toEmbed) {
            final segs = noteSegmentsMap[note.path];
            if (segs != null && segs.isNotEmpty) {
              _cache.putNote(
                CachedNote(
                  path: note.path,
                  lastModifiedMs: mtime,
                  segments: segs,
                ),
              );
            }
          }
          await _cache.save(_cachePath, dimensions: _dimensions);
          lastSave = DateTime.now();
        }
      }

      // Update cache for all notes in toEmbed (including empty notes)
      if (_cache != null) {
        for (final (note, mtime, _) in toEmbed) {
          final noteSegments = noteSegmentsMap[note.path] ?? const [];
          _cache.putNote(
            CachedNote(
              path: note.path,
              lastModifiedMs: mtime,
              segments: noteSegments,
            ),
          );
        }
      }
    }

    if (_cache != null) {
      _cache.removeNotesNotIn(validPaths);
      if (_cachePath != null && toEmbed.isNotEmpty) {
        await _cache.save(_cachePath, dimensions: _dimensions);
      }
    }

    _log.info(
      'Indexed ${_noteEmbeddings.length} text segments from ${notes.length} notes '
      '($cachedNotesCount reused from cache, ${toEmbed.length} newly embedded).',
    );
  }

  /// Searches for notes that semantically match the query.
  Future<(List<ScoredResult>, int)> search(
    String query, {
    int topK = 5,
    DateTime? createdAfter,
    DateTime? createdBefore,
    double similarityThreshold = 0.2,
  }) async {
    _log.fine('Searching for: "$query"');

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return (<ScoredResult>[], 0);
    }

    final queryResponse = await _client.embeddings.create(
      request: EmbedRequest(
        model: _model,
        input: EmbedInput.string(trimmedQuery),
      ),
    );

    final queryVectorList = queryResponse.embedding;
    if (queryVectorList == null || queryVectorList.isEmpty) {
      return (<ScoredResult>[], 0);
    }
    final queryVector = Float32List.fromList(queryVectorList);

    final results = <ScoredResult>[];
    final seenNotes = <String>{};
    final lowerQuery = query.toLowerCase();

    for (final textEmbedding in _noteEmbeddings) {
      if (createdAfter != null &&
          (textEmbedding.note.createdAt?.isBefore(createdAfter) ?? true)) {
        continue;
      }

      if (createdBefore != null &&
          (textEmbedding.note.createdAt?.isAfter(createdBefore) ?? true)) {
        continue;
      }

      var similarity = queryVector.dotProduct(textEmbedding.embedding);

      if (textEmbedding.text.toLowerCase().contains(lowerQuery)) {
        const exactMatchBonus = 0.5;
        similarity += exactMatchBonus;
      }

      if (similarity < similarityThreshold) continue;

      if (!seenNotes.contains(textEmbedding.note.path)) {
        results.add(
          ScoredResult(textEmbedding.note, similarity, textEmbedding.text),
        );
        seenNotes.add(textEmbedding.note.path);
      } else {
        final existingIndex = results.indexWhere(
          (r) => r.path == textEmbedding.note.path,
        );
        if (existingIndex != -1 && similarity > results[existingIndex].score) {
          results[existingIndex] = ScoredResult(
            textEmbedding.note,
            similarity,
            textEmbedding.text,
          );
        }
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return (results.take(topK).toList(), results.length);
  }

  void clear() {
    _noteEmbeddings.clear();
  }
}

class _TextEmbedding {
  final String text;
  final Float32List embedding;
  final ObsidianNote note;

  _TextEmbedding(this.text, this.embedding, this.note);
}
