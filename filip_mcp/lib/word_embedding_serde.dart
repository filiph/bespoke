import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _logger = Logger('WordEmbeddingSerde');

/// Handles serialization and deserialization of word embeddings
class WordEmbeddingSerde {
  /// Save word embeddings to a binary file
  ///
  /// Serializes the word vectors to a binary format.
  /// For each word, stores an int64 hash of the word and a Float64List of the embedding.
  /// Throws an exception if any words have the same hash.
  static Future<void> saveToBinaryFile(
    String path,
    Map<String, List<double>> wordVectors,
    int dimensions,
  ) async {
    _logger.info('Saving word embeddings to binary file $path...');

    // Check for hash collisions
    final Map<int, String> wordHashes = {};
    for (final word in wordVectors.keys) {
      final int wordHash = word.hashCode;
      if (wordHashes.containsKey(wordHash)) {
        throw Exception(
          'Hash collision detected: "$word" and "${wordHashes[wordHash]}" '
          'have the same hash ($wordHash)',
        );
      }
      wordHashes[wordHash] = word;
    }

    // Calculate buffer size
    final int headerSize = 8; // 2 int32 values (word count and dimensions)
    final int wordSize = 8; // int64 hash
    final int vectorSize = dimensions * 8; // float64 values
    final int totalSize =
        headerSize + wordVectors.length * (wordSize + vectorSize);

    // Create a byte buffer
    final buffer = ByteData(totalSize);
    int offset = 0;

    // Write header: number of words and dimensions
    buffer.setInt32(offset, wordVectors.length, Endian.little);
    offset += 4;
    buffer.setInt32(offset, dimensions, Endian.little);
    offset += 4;

    // Write each word's hash and vector
    for (final entry in wordVectors.entries) {
      final word = entry.key;
      final vector = entry.value;

      // Write the word's hash
      buffer.setInt64(offset, word.hashCode, Endian.little);
      offset += 8;

      // Write the vector
      for (final value in vector) {
        buffer.setFloat64(offset, value, Endian.little);
        offset += 8;
      }
    }

    // Write to file
    final file = File(path);
    await file.writeAsBytes(buffer.buffer.asUint8List());

    _logger.info(
      'Saved ${wordVectors.length} word vectors with $dimensions dimensions to binary file',
    );
  }

  /// Load word embeddings from a binary file
  ///
  /// Deserializes the word vectors from a binary format.
  /// Each word is represented by an int64 hash and a list of float64 values for the embedding.
  static Future<Map<String, List<double>>> loadFromBinaryFile(
    String path,
    int dimensions,
  ) async {
    _logger.info('Loading word embeddings from binary file $path...');
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Binary embeddings file not found', path);
    }

    // Read the file
    final bytes = await file.readAsBytes();
    final buffer = ByteData.view(Uint8List.fromList(bytes).buffer);
    int offset = 0;

    // Clear existing vectors
    final Map<String, List<double>> wordVectors = {};

    // Read header: number of words and dimensions
    final int wordCount = buffer.getInt32(offset, Endian.little);
    offset += 4;
    final int embeddingDimensions = buffer.getInt32(offset, Endian.little);
    offset += 4;

    if (embeddingDimensions != dimensions) {
      throw Exception(
        'Dimension mismatch: File has $embeddingDimensions dimensions, '
        'but manager is configured for $dimensions dimensions',
      );
    }

    // Read each word's hash and vector
    for (int i = 0; i < wordCount; i++) {
      final int wordHash = buffer.getInt64(offset, Endian.little);
      offset += 8;

      // Read the vector
      final List<double> vector = [];
      for (int j = 0; j < dimensions; j++) {
        final double value = buffer.getFloat64(offset, Endian.little);
        offset += 8;
        vector.add(value);
      }

      // Store with the hash as a key
      final String hashKey = '#$wordHash';
      wordVectors[hashKey] = vector;

      if (i % 10000 == 0 && i > 0) {
        _logger.info('Loaded $i words...');
      }
    }

    _logger.info(
      'Loaded $wordCount word vectors with $dimensions dimensions from binary file',
    );

    return wordVectors;
  }
}
