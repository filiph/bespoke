import 'dart:async';

import 'package:filip_mcp/obsidian_mcp.dart';
import 'package:filip_mcp/obsidian_note.dart';
import 'package:filip_mcp/scored_result.dart';
import 'package:filip_mcp/vector_search.dart';
import 'package:stream_channel/stream_channel.dart';
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
  group('ObsidianServer tool definitions', () {
    test('defines semantic_query, list_notes, and fetch tools correctly', () {
      final clientToServer = StreamController<String>();
      final serverToClient = StreamController<String>();

      final serverChannel = StreamChannel<String>(
        clientToServer.stream,
        serverToClient.sink,
      );

      final server = ObsidianServer.fromStreamChannel(
        vaultPath: '/vault',
        vectorSearchEngine: _FakeVectorSearchEngine(),
        channel: serverChannel,
        onDone: () {},
      );

      // Verify tool names
      expect(server.semanticQueryTool.name, equals('semantic_query'));
      expect(server.listNotesTool.name, equals('list_notes'));
      expect(server.fetchTool.name, equals('fetch'));

      // Verify list_notes tool schema has all required parameters
      final listProperties = server.listNotesTool.inputSchema.properties;
      expect(listProperties, contains('from'));
      expect(listProperties, contains('to'));
      expect(listProperties, contains('tags'));
      expect(listProperties, contains('pattern'));
      expect(listProperties, contains('isRegExp'));
      expect(listProperties, contains('limit'));
      expect(listProperties, contains('offset'));

      // Verify semantic_query is registered with searchPhrase
      final semProperties = server.semanticQueryTool.inputSchema.properties;
      expect(semProperties, contains('searchPhrase'));
      expect(semProperties, contains('createdAfter'));
      expect(semProperties, contains('createdBefore'));
      expect(semProperties, contains('limit'));
    });
  });
}
