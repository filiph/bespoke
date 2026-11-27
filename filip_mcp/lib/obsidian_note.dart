import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Represents a note in an Obsidian vault.
class ObsidianNote {
  /// The full path to the note file.
  final String path;

  /// The contents of the note.
  final String contents;

  /// The last modified timestamp of the underlying file, if known.
  final DateTime? fileModifiedAt;

  /// Creates a new note with the given path and contents.
  /// This constructor is private because notes should be created
  /// through the ObsidianVault class.
  ObsidianNote(this.path, this.contents, {this.fileModifiedAt});

  /// The title of the note, derived from the filename without the date tag.
  late final String title = _deriveTitle();

  /// The creation date of the note, resolved in order of precedence:
  /// 1. YAML front matter `date` or `created` property.
  /// 2. Filename date prefix (YYYY-MM-DD).
  /// 3. File modification timestamp.
  late final DateTime? createdAt = _resolveCreatedAt();

  /// The set of lowercase tags associated with this note, extracted from both
  /// YAML front matter (`tags`) and inline `#tag` tokens.
  late final Set<String> tags = _extractTags();

  String _deriveTitle() {
    final stripped = p
        .basenameWithoutExtension(path)
        .replaceFirst(_dateTag, '')
        .trim();
    return stripped.isEmpty ? p.basenameWithoutExtension(path) : stripped;
  }

  DateTime? _resolveCreatedAt() {
    final fmDate = _extractDateFromFrontMatter();
    if (fmDate != null) return fmDate;

    final filenameDate = extractCreatedAtFromString(p.basename(path));
    if (filenameDate != null) return filenameDate;

    return fileModifiedAt;
  }

  YamlMap? _parseFrontMatter() {
    final match = frontMatterRegex.firstMatch(contents);
    if (match == null) return null;
    try {
      final doc = loadYaml(match.group(1)!);
      if (doc is YamlMap) {
        return doc;
      }
    } catch (_) {
      // Ignore malformed YAML in front matter
    }
    return null;
  }

  DateTime? _extractDateFromFrontMatter() {
    final fm = _parseFrontMatter();
    if (fm == null) return null;
    for (final key in const ['date', 'created', 'createdAt', 'created_at']) {
      final val = fm[key];
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
        final fromString = extractCreatedAtFromString(val);
        if (fromString != null) return fromString;
      }
    }
    return null;
  }

  Set<String> _extractTags() {
    final result = <String>{};

    final fm = _parseFrontMatter();
    if (fm != null) {
      final rawTags = fm['tags'];
      if (rawTags is YamlList || rawTags is List) {
        for (final tag in rawTags as Iterable) {
          final normalized = normalizeTag(tag.toString());
          if (normalized != null) result.add(normalized);
        }
      } else if (rawTags is String) {
        for (final part in rawTags.split(RegExp(r'[, ]+'))) {
          final normalized = normalizeTag(part);
          if (normalized != null) result.add(normalized);
        }
      }
    }

    for (final match in _inlineTagRegex.allMatches(contents)) {
      final tagStr = match.group(1);
      if (tagStr != null) {
        final normalized = normalizeTag(tagStr);
        if (normalized != null) result.add(normalized);
      }
    }

    return result;
  }

  static final RegExp frontMatterRegex = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---\r?\n?',
  );

  static final RegExp _inlineTagRegex = RegExp(
    r"""(?:^|[\s(\[{<"'])#([^\s#,.;:!?)}\]"'`>]+)""",
  );

  /// Cleans and normalizes a tag to lowercase without leading `#` or trailing punctuation.
  static String? normalizeTag(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('#')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = cleaned.replaceAll(RegExp(r"""[.,;:!?)}\]"'`]+$"""), '');
    cleaned = cleaned.toLowerCase().trim();
    return cleaned.isEmpty ? null : cleaned;
  }

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
