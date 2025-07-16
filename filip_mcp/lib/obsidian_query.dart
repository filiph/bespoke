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
