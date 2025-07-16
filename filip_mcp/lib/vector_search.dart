import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:filip_mcp/scored_result.dart';
import 'package:logging/logging.dart';

import 'obsidian_note.dart';
import 'word_embedding_serde.dart';

// /// Example usage
// Future<void> main() async {
//   // Initialize the search engine with custom window settings
//   final searchEngine = await VectorSearchEngine.initialize(
//     glovePath: 'path/to/glove.6B.100d.txt',
//     dimensions: 100,
//     windowSize: 50,
//     windowOverlap: 25,
//   );
//
//   // Load sample notes
//   final notes = [
//     ObsidianNote.create(
//       '2023-01-15 Machine Learning.md',
//       'Machine learning is a field of study that gives computers the ability to learn '
//           'without being explicitly programmed. The process involves algorithms that '
//           'can analyze and draw inferences from patterns in data.',
//     ),
//     ObsidianNote.create(
//       '2023-02-20 Natural Language Processing.md',
//       'Natural language processing (NLP) is a subfield of linguistics, computer science, '
//           'and artificial intelligence concerned with the interactions between computers and '
//           'human language. It involves programming computers to process large amounts of '
//           'natural language data.',
//     ),
//   ];
//
//   // Index the notes
//   await searchEngine.indexNotes(notes);
//
//   // Search for relevant notes
//   final results = searchEngine.search(
//     'AI and computers understanding language',
//     topK: 2,
//   );
//
//   // Display results
//   for (final result in results) {
//     print(result);
//   }
// }

/// Main vector search engine for notes
class VectorSearchEngine {
  static final Logger _logger = Logger('VectorSearchEngine');

  final _WordEmbeddingManager _embeddingManager;

  final List<_TextEmbedding> _noteEmbeddings = [];

  // Sliding window configuration
  final int _windowSize; // words per window
  final int _windowOverlap; // overlapping words between windows

  VectorSearchEngine._(
    this._embeddingManager, {
    int windowSize = 100,
    int windowOverlap = 50,
  }) : _windowSize = windowSize,
       _windowOverlap = windowOverlap {
    // Validate window parameters
    if (_windowSize <= 0) {
      throw ArgumentError('Window size must be positive');
    }
    if (_windowOverlap < 0 || _windowOverlap >= _windowSize) {
      throw ArgumentError(
        'Overlap must be non-negative and less than window size',
      );
    }
  }

  /// Indexes a single note using the configured sliding window approach.
  ///
  /// The note is split into overlapping text segments according to the
  /// window size and overlap settings. Each segment is then converted to
  /// a vector embedding for semantic search.
  ///
  /// [note] is the [ObsidianNote] to index.
  Future<void> indexNote(ObsidianNote note) async {
    final words = _tokenize(note.contents);

    if (words.length < _windowSize / 2) {
      // For very small notes, just index the entire content
      _addEmbedding(note, note.contents);
    } else {
      // Use sliding window approach
      for (int i = 0; i < words.length; i += _windowSize - _windowOverlap) {
        final end = min(i + _windowSize, words.length);
        final windowText = words.sublist(i, end).join(' ');

        // Add window as a separate embedding
        _addEmbedding(note, windowText);

        if (end >= words.length) break;
      }
    }
  }

  /// Indexes a list of notes using the configured sliding window approach.
  ///
  /// Each note is split into overlapping text segments according to the
  /// window size and overlap settings. Each segment is then converted to
  /// a vector embedding for semantic search.
  ///
  /// [notes] is the list of [ObsidianNote] objects to index.
  Future<void> indexNotes(List<ObsidianNote> notes) async {
    _logger.info('Indexing ${notes.length} notes...');
    _noteEmbeddings.clear();

    for (final note in notes) {
      await indexNote(note);
    }

    _logger.info(
      'Indexed ${_noteEmbeddings.length} text segments from ${notes.length} notes',
    );
  }

  /// Searches for notes that semantically match the query.
  ///
  /// [query] is the search phrase to find in the indexed notes.
  /// [topK] is the maximum number of results to return (default: 5).
  ///
  /// Returns a growable list of [ScoredResult] objects.
  /// Each result contains the note, the similarity score,
  /// and the specific text segment that best matched the query.
  (List<ScoredResult>, int) search(
    String query, {
    int topK = 5,
    DateTime? createdAfter,
    DateTime? createdBefore,
  }) {
    final queryEmbedding = _embeddingManager.computeEmbedding(query);
    if (queryEmbedding == null) {
      _logger.warning('Query contains no recognizable words');
      return ([], 0);
    }

    final results = <ScoredResult>[];
    final seenNotes = <String>{};

    // Calculate similarity for each text segment
    for (final textEmbedding in _noteEmbeddings) {
      if (createdAfter != null &&
          (textEmbedding.note.createdAt?.isBefore(createdAfter) ?? true)) {
        continue;
      }

      if (createdBefore != null &&
          (textEmbedding.note.createdAt?.isAfter(createdBefore) ?? true)) {
        continue;
      }

      final similarity = _embeddingManager.cosineSimilarity(
        queryEmbedding,
        textEmbedding.embedding,
      );

      // Only add unique notes to results
      if (!seenNotes.contains(textEmbedding.note.path)) {
        results.add(
          ScoredResult(textEmbedding.note, similarity, textEmbedding.text),
        );
        seenNotes.add(textEmbedding.note.path);
      } else {
        // If we've seen this note before, update score if this segment is more relevant
        final existingResult = results.firstWhere(
          (result) => result.path == textEmbedding.note.path,
        );

        if (similarity > existingResult.score) {
          results.remove(existingResult);
          results.add(
            ScoredResult(textEmbedding.note, similarity, textEmbedding.text),
          );
        }
      }
    }

    // Sort by score (highest first).
    results.sort((a, b) => b.score.compareTo(a.score));

    // Return top K results
    return (results.take(topK).toList(), results.length);
  }

  void _addEmbedding(ObsidianNote note, String text) {
    final embedding = _embeddingManager.computeEmbedding(text);
    if (embedding != null) {
      _noteEmbeddings.add(_TextEmbedding(text, embedding, note));
    }
  }

  /// Tokenizes text into words for processing.
  ///
  /// This is exposed for testing purposes.
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  /// Initializes the search engine with GloVe embeddings.
  ///
  /// [glovePath] is the file path to the GloVe embeddings file.
  /// [dimensions] specifies the vector dimensions in the GloVe file (default: 100).
  /// [windowSize] is the number of words in each window segment (default: 100).
  /// [windowOverlap] is the number of words that overlap between consecutive windows (default: 50).
  ///
  /// Returns a [VectorSearchEngine] instance that's ready to index notes.
  static Future<VectorSearchEngine> initialize({
    required String glovePath,
    int dimensions = 100,
    int windowSize = 100,
    int windowOverlap = 50,
  }) async {
    final manager = _WordEmbeddingManager(dimensions: dimensions);
    await manager.loadFromFile(glovePath);
    return VectorSearchEngine._(
      manager,
      windowSize: windowSize,
      windowOverlap: windowOverlap,
    );
  }

  void clear() {
    _noteEmbeddings.clear();
  }
}

/// Vector representation of a text segment
class _TextEmbedding {
  final String text;
  final List<double> embedding;
  final ObsidianNote note;

  _TextEmbedding(this.text, this.embedding, this.note);
}

/// Handles word embeddings loading and vector operations
class _WordEmbeddingManager {
  final Map<int, List<double>> _wordVectors = {};
  final int dimensions;
  final Logger _logger = Logger('WordEmbeddingManager');

  _WordEmbeddingManager({required this.dimensions});

  /// Compute embedding for a text by averaging its word vectors
  List<double>? computeEmbedding(String text) {
    final words = _tokenize(text);
    final validWords = words
        .where((word) => _wordVectors.containsKey(word.hashCode))
        .toList();

    if (validWords.isEmpty) return null;

    final result = List<double>.filled(dimensions, 0);

    for (final word in validWords) {
      final vector = _wordVectors[word.hashCode]!;
      for (int i = 0; i < dimensions; i++) {
        result[i] += vector[i];
      }
    }

    // Normalize by dividing by the number of words
    for (int i = 0; i < dimensions; i++) {
      result[i] /= validWords.length;
    }

    return result;
  }

  /// Compute cosine similarity between two vectors
  double cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Load GloVe embeddings from file
  ///
  /// If a binary version of the file exists at '$path.bin' and is newer than
  /// the text file, it will load from the binary file for better performance.
  /// Otherwise, it will load from the text file and save a binary version.
  Future<void> loadFromFile(String path) async {
    final textFile = File(path);
    if (!await textFile.exists()) {
      throw FileSystemException('Embeddings file not found', path);
    }

    final binaryPath = '$path.bin';
    final binaryFile = File(binaryPath);
    final binaryExists = await binaryFile.exists();

    // Check if binary file exists and is newer than text file
    if (binaryExists) {
      final textStat = await textFile.stat();
      final binaryStat = await binaryFile.stat();

      if (binaryStat.modified.isAfter(textStat.modified)) {
        _logger.info('Loading word embeddings from binary file $binaryPath...');
        try {
          final wordVectors = await WordEmbeddingSerde.loadFromBinaryFile(
            binaryPath,
            dimensions,
          );

          _wordVectors.clear();
          _wordVectors.addEntries(wordVectors.entries);

          _logger.info(
            'Loaded ${_wordVectors.length} word vectors with $dimensions dimensions from binary file',
          );

          return;
        } catch (e) {
          _logger.warning(
            'Failed to load binary file: $e. Falling back to text file.',
          );
        }
      }
    }

    // Load from text file
    _logger.info('Loading word embeddings from text file $path...');
    final lines = textFile
        .openRead()
        .transform(utf8.decoder)
        .transform(LineSplitter());

    _wordVectors.clear();
    int count = 0;

    final Map<int, String> wordHashes = {};
    await for (final line in lines) {
      final parts = line.split(' ');
      if (parts.length != dimensions + 1) continue;

      final word = parts[0].toLowerCase();
      final vector = parts.sublist(1).map((s) => double.parse(s)).toList();

      final int wordHash = word.hashCode;
      if (wordHashes.containsKey(wordHash)) {
        throw Exception(
          'Hash collision detected: "$word" and "${wordHashes[wordHash]}" '
          'have the same hash ($wordHash)',
        );
      }
      _wordVectors[wordHash] = vector;
      count++;

      if (count % 10000 == 0) {
        _logger.info('Loaded $count words...');
      }
    }

    _logger.info(
      'Loaded ${_wordVectors.length} word vectors with $dimensions dimensions from text file',
    );

    // Save to binary file for future use
    try {
      await WordEmbeddingSerde.saveToBinaryFile(
        binaryPath,
        _wordVectors,
        dimensions,
      );
      _logger.info('Saved binary version to $binaryPath');
    } catch (e) {
      _logger.warning('Failed to save binary file: $e');
    }
  }

  /// Simple tokenization - split text into lowercase words
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }
}
