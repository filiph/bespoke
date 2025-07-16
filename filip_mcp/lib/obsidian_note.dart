import 'package:path/path.dart' as p;

/// Represents a note in an Obsidian vault.
class ObsidianNote {
  /// The full path to the note file.
  final String path;

  /// The contents of the note.
  final String contents;

  /// Creates a new note with the given path and contents.
  /// This constructor is private because notes should be created
  /// through the ObsidianVault class.
  ObsidianNote(this.path, this.contents);

  /// The title of the note, derived from the filename without the date tag.
  late final String title = p
      .basenameWithoutExtension(path)
      .replaceFirst(_dateTag, '');

  /// The creation date of the note, extracted from the filename if present.
  late final DateTime? createdAt = extractCreatedAtFromString(p.basename(path));

  @override
  String toString() {
    return '$title (${createdAt?.toIso8601String()}';
  }

  /// Extracts the creation date from a filename.
  ///
  /// The date format is expected to be YYYY-MM-DD at the beginning of the filename.
  /// Returns null if no date is found.
  static DateTime? extractCreatedAtFromString(String path) {
    final basename = p.basenameWithoutExtension(path);

    final match = _dateTag.firstMatch(basename);

    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    return DateTime(year, month, day);
  }

  /// Regular expression to match a date tag at the beginning of a filename.
  /// Format: YYYY-MM-DD followed by a space.
  static final RegExp _dateTag = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
}
