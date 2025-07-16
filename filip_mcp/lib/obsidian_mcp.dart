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

  final void Function() onDone;

  final ObsidianVault _vault;

  final fetchTool = Tool(
    name: 'fetch',
    description: "Returns the note provided by its path.",
    inputSchema: Schema.object(
      properties: {
        'path': Schema.string(
          title: 'path',
          description:
              "The path of the note. Ends with '.md'. "
              "Can be obtained from a query search result, for example.",
        ),
      },
    ),
    // outputSchema: Schema.object(
    //   title: 'Query results',
    //   description: 'A list of search results',
    //   properties: {'results': Schema.list(items: noteSearchResultSchema)},
    // ),
    annotations: ToolAnnotations(readOnlyHint: true),
  );

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
        'limit': Schema.combined(
          description:
              'The maximum number of results to return. '
              'If null, then the limit is arbitrary '
              'but tends to be very large. '
              'You should generally limit the number of results '
              'to something sane, like 10 items. '
              'Only go further than that if really needed.',
          oneOf: [Schema.nil(), Schema.int()],
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
    required this.onDone,
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
  Future<void> shutdown() {
    onDone();
    return super.shutdown();
  }

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    log(LoggingLevel.info, 'Initializing vault.');
    await _vault.initialize();
    registerTool(queryTool, _query, validateArguments: true);
    registerTool(fetchTool, _fetch, validateArguments: true);
    return super.initialize(request);
  }

  Future<CallToolResult> _fetch(CallToolRequest request) async {
    final path = request.arguments!['path'] as String;

    final note = _vault.fetch(path);

    if (note == null) {
      return CallToolResult(
        content: [TextContent(text: 'Note with specified path not found.')],
        isError: true,
      );
    }

    final String contents;
    const maxContentsLength = 10000;
    if (note.contents.length > maxContentsLength) {
      contents =
          '${note.contents.substring(0, maxContentsLength)} ... (trimmed)';
    } else {
      contents = note.contents;
    }

    return CallToolResult(
      content: [
        TextContent(text: 'Title: ${note.title}'),
        TextContent(text: 'Created at: ${note.createdAt?.toIso8601String()}'),
        TextContent(
          text:
              'Contents:\n'
              '$contents',
        ),
        // ResourceLink(
        //   name: note.path,
        //   title: note.title,
        //   description:
        //       'The note file itself. '
        //       'Can be provided to the user for further inspection.',
        //   mimeType: 'text/markdown',
        //   uri: Uri.file(note.path).toString(),
        // ),
      ],
      structuredContent: {
        'title': note.title,
        'createdAt': note.createdAt?.toIso8601String(),
        'contents': contents,
      },
    );
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

    final limit = request.arguments!['limit'] as int?;

    final query = ObsidianQuery(
      searchPhrase: searchPhrase,
      createdAfter: createdAfter,
      createdBefore: createdBefore,
      limit: limit,
    );

    try {
      final orderedResults = await _vault.query(query);
      return CallToolResult(
        content: [
          TextContent(
            text:
                'The query has produced '
                '${orderedResults.totalResults} total matches out of which '
                '${orderedResults.returnedResults} are returned. '
                "Use the provided path with the fetch tool "
                "to get any note's full contents.",
          ),
          for (final (index, result) in orderedResults.results.indexed)
            TextContent(
              text:
                  '- #${index + 1}) path="${result.path}"\n'
                  '  Score: ${result.score.toStringAsFixed(3)}\n'
                  '  Created at: ${result.createdAt?.toIso8601String()}\n'
                  '  Snippet: ... ${result.matchedText} ...\n',
            ),
        ],
        structuredContent: {
          'totalResults': orderedResults.totalResults,
          'returnedResults': orderedResults.returnedResults,
          'results': [
            for (final result in orderedResults.results)
              {
                'title': result.title,
                'path': result.path,
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
