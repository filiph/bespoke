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
      'pathForFetch': Schema.string(
        title: 'pathForFetch',
        description:
            "The file path that can be used when calling the fetch tool. "
            "You cannot access this path in a browser, nor can you embed it.",
      ),
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

  static final noteListResultSchema = Schema.object(
    title: 'Description of a listed note',
    description:
        "Object returned by note listing "
        "that represents a user's note. "
        "Contains note metadata, tags, and a snippet.",
    properties: {
      'title': Schema.string(title: 'title', description: "The note's title"),
      'pathForFetch': Schema.string(
        title: 'pathForFetch',
        description:
            "The file path that can be used when calling the fetch tool. "
            "You cannot access this path in a browser, nor can you embed it.",
      ),
      'createdAt': Schema.combined(
        title: 'createdAt',
        description:
            "The date on which the note was created or modified, in ISO-8601 format.",
        oneOf: [Schema.nil(), Schema.string()],
      ),
      'tags': Schema.list(
        title: 'tags',
        description: "Tags associated with the note.",
        items: Schema.string(),
      ),
      'snippet': Schema.string(
        title: 'snippet',
        description:
            "A limited snippet of content. "
            "Centered around the matched pattern if present, or at the top of the note.",
      ),
    },
  );

  final void Function() onDone;

  final ObsidianVault _vault;

  final fetchTool = Tool(
    name: 'fetch',
    description: "Returns the note provided by its file path.",
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

  final semanticQueryTool = Tool(
    name: 'semantic_query',
    description:
        "Searches the user's notes using semantic vector embeddings. "
        "Recommended as the default search tool for exploratory, conceptual, or topic queries, "
        "and when searching for personal thoughts, opinions, or reflections "
        "(especially because notes may be written in English or Czech or phrased differently). "
        "Returns notes matching the meaning, topic, or conceptual description of the query.",
    inputSchema: Schema.object(
      properties: {
        'searchPhrase': Schema.combined(
          description:
              'A natural language query phrase describing the topic, concept, '
              'or question to search for (e.g., "talks and conference presentations about Flutter", '
              '"my thoughts on game design"). '
              'Notes containing semantically similar concepts will be returned '
              'with an appropriate similarity score. '
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

  final listNotesTool = Tool(
    name: 'list_notes',
    description:
        "Lists and filters notes from the user's vault by date range, tags, or exact/regex text pattern. "
        "Results are ordered alphabetically by relative file path and support pagination with limit and offset. "
        "Use this tool when looking for notes from specific dates (e.g. thoughts from around a date), "
        "notes tagged with specific tags, or exact substring / regular expression matches. "
        "Notes without a parseable creation date are excluded whenever from or to is set; "
        "omit both to list all notes, including undated ones.",
    inputSchema: Schema.object(
      properties: {
        'from': Schema.combined(
          description:
              'Filter notes created at or after this date (inclusive, start of day). '
              'Accepts YYYY-MM-DD or ISO-8601 format. '
              'Notes without a parseable creation date are excluded when this is set.',
          oneOf: [Schema.nil(), Schema.string()],
        ),
        'to': Schema.combined(
          description:
              'Filter notes created at or before this date (inclusive, end of day). '
              'Accepts YYYY-MM-DD or ISO-8601 format. '
              'Notes without a parseable creation date are excluded when this is set.',
          oneOf: [Schema.nil(), Schema.string()],
        ),
        'tags': Schema.combined(
          description:
              'List of tags that notes must contain (all tags must match, case-insensitive). '
              'Can be specified with or without leading #.',
          oneOf: [
            Schema.nil(),
            Schema.list(items: Schema.string()),
          ],
        ),
        'pattern': Schema.combined(
          description:
              'A text string or regular expression to match against note title or content.',
          oneOf: [Schema.nil(), Schema.string()],
        ),
        'isRegExp': Schema.combined(
          description:
              'Whether pattern should be evaluated as a regular expression. '
              'Defaults to false (case-insensitive plain text substring match).',
          oneOf: [Schema.nil(), Schema.bool()],
        ),
        'limit': Schema.combined(
          description:
              'The maximum number of results to return. Defaults to 20.',
          oneOf: [Schema.nil(), Schema.int()],
        ),
        'offset': Schema.combined(
          description:
              'The number of matching notes to skip before returning results (for pagination). Defaults to 0.',
          oneOf: [Schema.nil(), Schema.int()],
        ),
      },
    ),
    outputSchema: Schema.object(
      title: 'List notes results',
      description: 'A paginated list of note search results',
      properties: {
        'totalResults': Schema.int(),
        'returnedResults': Schema.int(),
        'offset': Schema.int(),
        'hasMore': Schema.bool(),
        'results': Schema.list(items: noteListResultSchema),
      },
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
             "Query and retrieve notes from the user's personal markdown knowledge base (vault). "
             "The user you are interacting with is Filip Hracek, a Czech software developer. "
             "Notes in the vault that are not web clippings and use the first person are Filip's own notes. "
             "When searching for Filip's personal thoughts, opinions, or reflections on a topic, "
             "search using first-person phrasing (e.g., 'my thoughts on X' rather than 'Filip\\'s thoughts on X'), "
             "as people write their personal notes in the first person. "
             "Prefer semantic_query as the default search tool for exploratory, conceptual, or topic queries, "
             "as notes may be written in English or Czech or phrased in various ways. "
             "Use list_notes when you need to list notes from specific dates or date ranges "
             "(e.g., 'my thoughts from around May 9, 2022'), filter by specific tags, "
             "match exact filenames or regex patterns, or page through notes chronologically/alphabetically.",
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
    registerTool(semanticQueryTool, _semanticQuery, validateArguments: true);
    registerTool(listNotesTool, _listNotes, validateArguments: true);
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

  Future<CallToolResult> _semanticQuery(CallToolRequest request) async {
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
                '${orderedResults.returnedResults} are returned '
                '(sorted from best match to worst). '
                "Use the provided path with the fetch tool "
                "to get any note's full contents. "
                "Do not try to access the note's path directly, "
                "and also don't try to embed it. ",
            // "But you are encouraged to provide a link to any note "
            // "in the following format: "
            // "obsidian://open?path=URI_ENCODED_PATH_TO_NOTE. "
            // "(URI encoded means that forward slash must become %2F.)",
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
                'pathForFetch': result.path,
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

  Future<CallToolResult> _listNotes(CallToolRequest request) async {
    final fromString = request.arguments?['from'] as String?;
    final from = fromString != null
        ? (DateTime.tryParse(fromString) ??
            ObsidianNote.extractCreatedAtFromString(fromString))
        : null;

    final toString = request.arguments?['to'] as String?;
    final to = toString != null
        ? (DateTime.tryParse(toString) ??
            ObsidianNote.extractCreatedAtFromString(toString))
        : null;

    final rawTags = request.arguments?['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : null;

    final pattern = request.arguments?['pattern'] as String?;
    final isRegExp = request.arguments?['isRegExp'] as bool? ?? false;
    final limit = request.arguments?['limit'] as int? ?? 20;
    final offset = request.arguments?['offset'] as int? ?? 0;

    final query = ObsidianListQuery(
      from: from,
      to: to,
      tags: tags,
      pattern: pattern,
      isRegExp: isRegExp,
      limit: limit,
      offset: offset,
    );

    try {
      final response = await _vault.listNotes(query);
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Listing notes produced '
                '${response.totalResults} total matches; '
                'returning ${response.returnedResults} '
                '(offset ${response.offset}, hasMore: ${response.hasMore}, '
                'sorted alphabetically by path). '
                "Use the provided path with the fetch tool to get any note's full contents.",
          ),
          for (final (index, result) in response.results.indexed)
            TextContent(
              text:
                  '- #${response.offset + index + 1}) path="${result.path}"\n'
                  '  Title: ${result.title}\n'
                  '  Created at: ${result.createdAt?.toIso8601String()}\n'
                  '  Tags: ${result.tags.isEmpty ? "(none)" : result.tags.map((t) => "#$t").join(", ")}\n'
                  '  Snippet: ${result.snippet}\n',
            ),
        ],
        structuredContent: {
          'totalResults': response.totalResults,
          'returnedResults': response.returnedResults,
          'offset': response.offset,
          'hasMore': response.hasMore,
          'results': [
            for (final result in response.results)
              {
                'title': result.title,
                'pathForFetch': result.path,
                'createdAt': result.createdAt?.toIso8601String(),
                'tags': result.tags,
                'snippet': result.snippet,
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
