import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _logger = Logger('EmbeddingCache');

/// A single cached text segment and its dense vector representation.
class CachedSegment {
  final String text;
  final Float32List embedding;

  CachedSegment(this.text, this.embedding);
}

/// A cached note representation containing its modification timestamp
/// and all precomputed text segments.
class CachedNote {
  final String path;
  final int lastModifiedMs;
  final List<CachedSegment> segments;

  CachedNote({
    required this.path,
    required this.lastModifiedMs,
    required this.segments,
  });
}

/// Binary serialization and in-memory cache for note embeddings.
class EmbeddingCache {
  static const int magicNumber = 0x464D4350; // "FMCP"
  static const int formatVersion = 1;

  final Map<String, CachedNote> _notes = {};

  EmbeddingCache();

  int get noteCount => _notes.length;

  CachedNote? getNote(String path) => _notes[path];

  void putNote(CachedNote note) {
    _notes[note.path] = note;
  }

  void removeNotesNotIn(Set<String> validPaths) {
    _notes.removeWhere((path, _) => !validPaths.contains(path));
  }

  /// Loads the cache from a binary file. If the file is missing or invalid,
  /// returns an empty cache without throwing.
  static Future<EmbeddingCache> load(
    String cacheFilePath, {
    int dimensions = 768,
  }) async {
    final cache = EmbeddingCache();
    final file = File(cacheFilePath);
    if (!await file.exists()) {
      _logger.info('Cache file not found at $cacheFilePath. Starting fresh.');
      return cache;
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < 16) {
        _logger.warning('Cache file $cacheFilePath is too small. Ignoring.');
        return cache;
      }

      final buffer = ByteData.sublistView(bytes);
      int offset = 0;

      final magic = buffer.getUint32(offset, Endian.little);
      offset += 4;
      if (magic != magicNumber) {
        _logger.warning(
          'Cache file magic mismatch: expected $magicNumber, got $magic. Ignoring.',
        );
        return cache;
      }

      final version = buffer.getInt32(offset, Endian.little);
      offset += 4;
      if (version != formatVersion) {
        _logger.warning(
          'Cache format version mismatch: expected $formatVersion, got $version. Ignoring.',
        );
        return cache;
      }

      final fileDims = buffer.getInt32(offset, Endian.little);
      offset += 4;
      if (fileDims != dimensions) {
        _logger.warning(
          'Cache dimensions mismatch: expected $dimensions, got $fileDims. Ignoring.',
        );
        return cache;
      }

      final noteCount = buffer.getInt32(offset, Endian.little);
      offset += 4;

      for (int i = 0; i < noteCount; i++) {
        final pathLen = buffer.getInt32(offset, Endian.little);
        offset += 4;

        final pathBytes = Uint8List.sublistView(
          bytes,
          offset,
          offset + pathLen,
        );
        offset += pathLen;
        final path = utf8.decode(pathBytes);

        final lastModifiedMs = buffer.getInt64(offset, Endian.little);
        offset += 8;

        final segmentCount = buffer.getInt32(offset, Endian.little);
        offset += 4;

        final segments = <CachedSegment>[];
        for (int j = 0; j < segmentCount; j++) {
          final textLen = buffer.getInt32(offset, Endian.little);
          offset += 4;

          final textBytes = Uint8List.sublistView(
            bytes,
            offset,
            offset + textLen,
          );
          offset += textLen;
          final text = utf8.decode(textBytes);

          final vector = Float32List(dimensions);
          for (int d = 0; d < dimensions; d++) {
            vector[d] = buffer.getFloat32(offset, Endian.little);
            offset += 4;
          }

          segments.add(CachedSegment(text, vector));
        }

        cache._notes[path] = CachedNote(
          path: path,
          lastModifiedMs: lastModifiedMs,
          segments: segments,
        );
      }

      _logger.info(
        'Loaded ${cache.noteCount} notes from cache: $cacheFilePath',
      );
    } catch (e, st) {
      _logger.warning('Failed to load cache from $cacheFilePath: $e', e, st);
    }

    return cache;
  }

  /// Atomically saves the in-memory cache to a binary file.
  Future<void> save(String cacheFilePath, {int dimensions = 768}) async {
    _logger.info('Saving ${_notes.length} notes to cache: $cacheFilePath');
    final file = File(cacheFilePath);
    await file.parent.create(recursive: true);

    final builder = BytesBuilder(copy: false);

    // Header: magic (4), version (4), dimensions (4), noteCount (4)
    final header = ByteData(16);
    header.setUint32(0, magicNumber, Endian.little);
    header.setInt32(4, formatVersion, Endian.little);
    header.setInt32(8, dimensions, Endian.little);
    header.setInt32(12, _notes.length, Endian.little);
    builder.add(header.buffer.asUint8List());

    for (final note in _notes.values) {
      final pathBytes = utf8.encode(note.path);
      final noteMeta = ByteData(4 + pathBytes.length + 8 + 4);
      int offset = 0;

      noteMeta.setInt32(offset, pathBytes.length, Endian.little);
      offset += 4;
      for (int i = 0; i < pathBytes.length; i++) {
        noteMeta.setUint8(offset++, pathBytes[i]);
      }
      noteMeta.setInt64(offset, note.lastModifiedMs, Endian.little);
      offset += 8;
      noteMeta.setInt32(offset, note.segments.length, Endian.little);
      offset += 4;

      builder.add(noteMeta.buffer.asUint8List());

      for (final segment in note.segments) {
        final textBytes = utf8.encode(segment.text);
        final segmentMeta = ByteData(4 + textBytes.length + (dimensions * 4));
        int segOffset = 0;

        segmentMeta.setInt32(segOffset, textBytes.length, Endian.little);
        segOffset += 4;
        for (int i = 0; i < textBytes.length; i++) {
          segmentMeta.setUint8(segOffset++, textBytes[i]);
        }
        for (int d = 0; d < dimensions; d++) {
          segmentMeta.setFloat32(
            segOffset,
            segment.embedding[d],
            Endian.little,
          );
          segOffset += 4;
        }

        builder.add(segmentMeta.buffer.asUint8List());
      }
    }

    final tempFile = File('$cacheFilePath.tmp');
    await tempFile.writeAsBytes(builder.takeBytes(), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(cacheFilePath);
    _logger.info('Cache saved successfully.');
  }
}
