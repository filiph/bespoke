import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:filip_mcp/vector_search.dart';
import 'package:stream_channel/stream_channel.dart';

import 'obsidian_note.dart';
import 'obsidian_query.dart';
import 'obsidian_vault.dart';

/// Allows querying a database of notes.
final class ObsidianServer extends MCPServer
    with LoggingSupport, RootsTrackingSupport, ToolsSupport {
  static final noteSearchResultSchema = Schema.object(
    title: 'Description of a found note',
    description:
        "Object returned by a query or listing "
        "that represents a user's note. "
        "Doesn't contain the full note, only the relevant parts.",
    properties: {
      'title': Schema.string(title: 'title', description: "The note's title"),
      'createdAt': Schema.combined(
        title: 'createdAt',
        description:
            "The date on which the note was created, in ISO-8601 format.",
        oneOf: [Schema.nil(), Schema.string()],
      ),
      'snippet': Schema.string(
        title: 'snippet',
        description:
            "A limited snippet of content. "
            "Typically centered around the found string, "
            "or at the top of the note.",
      ),
      'score': Schema.num(
        title: 'score',
        description: "The score of the match. Higher is better.",
      ),
    },
  );

  final ObsidianVault _vault;

  final queryTool = Tool(
    name: 'query',
    description: "Returns the user's notes that match the given query.",
    inputSchema: Schema.object(
      properties: {
        'searchPhrase': Schema.combined(
          description:
              'A fuzzy search phrase to use, or null. '
              'Notes that contain the given phrase '
              'or something semantically similar '
              'will be returned with an appropriate similarity score. '
              'When null is given as the search phrase, '
              'all notes that conform to the other filters of this query '
              'will be returned.',
          oneOf: [Schema.nil(), Schema.string()],
        ),
        // 'mustIncludeAllOf': Schema.list(
        //   description:
        //       "A list of strings that must all be included in "
        //       "the note's title or contents. "
        //       "Can be empty.",
        //   items: Schema.string(),
        //   minItems: 0,
        // ),
        // 'mustIncludeAnyOf': Schema.list(
        //   description:
        //       "A list of exact strings of which at least one "
        //       "must be included in the note's title or contents. "
        //       "Can be empty.",
        //   items: Schema.string(),
        //   minItems: 0,
        // ),
        // 'mustExcludeAllOf': Schema.list(
        //   description:
        //       "A list of exact strings that mustn't be included in "
        //       "the note's title or contents. "
        //       "Can be empty.",
        //   items: Schema.string(),
        //   minItems: 0,
        // ),
        'createdAfter': Schema.combined(
          description:
              'A date to filter the query with, or null. '
              'If specified, only notes created at or after this date '
              'will be returned. '
              'Must be in the format: YYYY-MM-DD.',
          oneOf: [Schema.nil(), Schema.string()],
        ),
        'createdBefore': Schema.combined(
          description:
              'A date to filter the query with, or null. '
              'If specified, only notes created before or at this date '
              'will be returned. '
              'Must be in the format: YYYY-MM-DD.',
          oneOf: [Schema.nil(), Schema.string()],
        ),
      },
    ),
    outputSchema: Schema.object(
      title: 'Query results',
      description: 'A list of search results',
      properties: {'results': Schema.list(items: noteSearchResultSchema)},
    ),
    annotations: ToolAnnotations(readOnlyHint: true),
  );

  ObsidianServer.fromStreamChannel({
    required String vaultPath,
    required VectorSearchEngine vectorSearchEngine,
    required StreamChannel<String> channel,
  }) : _vault = ObsidianVault(vaultPath, vectorSearchEngine),
       super.fromStreamChannel(
         channel,
         instructions:
             "Ask this server questions about the user's database of notes.",
         implementation: Implementation(
           name: 'obsidian notes',
           version: '0.0.1',
         ),
       );

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    log(LoggingLevel.info, 'Initializing vault.');
    await _vault.initialize();
    registerTool(queryTool, _query, validateArguments: true);
    return super.initialize(request);
  }

  Future<CallToolResult> _query(CallToolRequest request) async {
    final searchPhrase = request.arguments!['searchPhrase'] as String?;

    final createdAfterString = request.arguments!['createdAfter'] as String?;
    final createdAfter = createdAfterString != null
        ? ObsidianNote.extractCreatedAtFromString(createdAfterString)
        : null;

    final createdBeforeString = request.arguments!['createdBefore'] as String?;
    final createdBefore = createdBeforeString != null
        ? ObsidianNote.extractCreatedAtFromString(createdBeforeString)
        : null;

    final query = ObsidianQuery(
      searchPhrase: searchPhrase,
      createdAfter: createdAfter,
      createdBefore: createdBefore,
    );

    try {
      final results = await _vault.query(query);
      return CallToolResult(
        content: [
          for (final (index, result) in results.indexed)
            TextContent(
              text:
                  '#${index + 1}) '
                  'Result with score ${result.score} '
                  'created at ${result.createdAt?.toIso8601String()} '
                  'with title "${result.title}". '
                  'Snippet: ... ${result.matchedText} ...',
            ),
        ],
        structuredContent: {
          'results': [
            for (final result in results)
              {
                'title': result.title,
                'createdAt': result.createdAt?.toIso8601String(),
                'snippet': result.matchedText,
                'score': result.score,
              },
          ],
        },
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: e.toString())],
        isError: true,
      );
    }
  }
}
