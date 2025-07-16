import 'scored_result.dart';

/// A container for search results that includes metadata about the result set.
class OrderedResultsList {
  /// The list of scored search results.
  final List<ScoredResult> results;

  /// The total number of results that matched the query before any limits were applied.
  final int totalResults;

  /// The number of results actually returned after limits were applied.
  final int returnedResults;

  /// Creates a new ordered results list.
  OrderedResultsList({
    required this.results,
    required this.totalResults,
    required this.returnedResults,
  });
}
