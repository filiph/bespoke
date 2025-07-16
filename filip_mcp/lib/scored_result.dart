import 'obsidian_note.dart';

/// A search result containing the note, its similarity score, and the matched text segment
class ScoredResult {
  /// The title of the note.
  final String title;

  /// The full path of the note.
  final String path;

  /// The date of creation.
  final DateTime? createdAt;

  /// The cosine similarity score between the query and the matched text
  /// Range is 0.0 to 1.0, where 1.0 is a perfect match
  final double score;

  /// The specific text segment from the note that matched the query.
  final String matchedText;

  /// Creates a new search result
  ScoredResult(ObsidianNote note, this.score, this.matchedText)
    : path = note.path,
      title = note.title,
      createdAt = note.createdAt;

  @override
  String toString() {
    return 'Score: ${score.toStringAsFixed(4)} - $matchedText ($title)';
  }
}