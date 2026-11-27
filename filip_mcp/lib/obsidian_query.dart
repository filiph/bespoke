/// A query for searching Obsidian notes.
class ObsidianQuery {
  /// The search phrase to match against note contents.
  final String? searchPhrase;

  /// If specified, only notes created at or after this date will be returned.
  final DateTime? createdAfter;

  /// If specified, only notes created before or at this date will be returned.
  final DateTime? createdBefore;

  /// The maximum number of results to return.
  final int? limit;

  /// Creates a new query with the specified filters.
  const ObsidianQuery({
    required this.searchPhrase,
    required this.createdAfter,
    required this.createdBefore,
    required this.limit,
  });

  @override
  String toString() {
    return 'ObsidianQuery{searchPhrase: $searchPhrase, '
        'createdAfter: $createdAfter, '
        'createdBefore: $createdBefore, '
        'limit: $limit}';
  }
}

/// A structured query for listing and filtering Obsidian notes.
class ObsidianListQuery {
  /// If specified, only notes created at or after this date will be returned.
  /// Evaluated inclusively from start of day (00:00:00).
  ///
  /// Notes without a parseable creation date are excluded when this is set;
  /// omit [from] and [to] to also list undated notes.
  final DateTime? from;

  /// If specified, only notes created at or before this date will be returned.
  /// Evaluated inclusively to end of day (23:59:59.999).
  ///
  /// Notes without a parseable creation date are excluded when this is set;
  /// omit [from] and [to] to also list undated notes.
  final DateTime? to;

  /// If specified, notes must contain all of these tags (case-insensitive).
  final List<String>? tags;

  /// If specified, a string or regular expression pattern to match against
  /// note titles and contents.
  final String? pattern;

  /// If true, [pattern] is evaluated as a regular expression.
  /// Defaults to false (case-insensitive plain text substring match).
  final bool isRegExp;

  /// The maximum number of results to return.
  final int limit;

  /// The number of results to skip before returning.
  final int offset;

  const ObsidianListQuery({
    this.from,
    this.to,
    this.tags,
    this.pattern,
    this.isRegExp = false,
    this.limit = 20,
    this.offset = 0,
  });

  @override
  String toString() {
    return 'ObsidianListQuery{from: $from, to: $to, tags: $tags, '
        'pattern: $pattern, isRegExp: $isRegExp, limit: $limit, offset: $offset}';
  }
}

/// A single note item returned by a list query.
class NoteListResult {
  final String title;
  final String path;
  final DateTime? createdAt;
  final List<String> tags;
  final String snippet;

  const NoteListResult({
    required this.title,
    required this.path,
    required this.createdAt,
    required this.tags,
    required this.snippet,
  });
}

/// The paginated response returned by a note list query.
class NoteListResponse {
  final List<NoteListResult> results;
  final int totalResults;
  final int returnedResults;
  final int offset;
  final bool hasMore;

  const NoteListResponse({
    required this.results,
    required this.totalResults,
    required this.returnedResults,
    required this.offset,
    required this.hasMore,
  });
}
