/// Regular expression that matches any integer with exactly 13 digits.
///
/// Such a number is most probably a timestamp. It corresponds to the range
/// from about the the year 2001 (`1000000000000`)
/// to the year 2286 (`9999999999999`).
final _thirteenDigitRegExp = RegExp(r'\b\d{13}\b');

String rewriteTimestamps(String full) {
  const delimiter = '\n';
  final lines = full.trim().split(delimiter);

  final buf = StringBuffer();

  for (final line in lines) {
    final out = line.replaceAllMapped(_thirteenDigitRegExp, (match) {
      final milliseconds = int.parse(match.group(0)!);

      final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      return dateTime.toIso8601String();
    });
    buf.writeln(out);
  }

  return buf.toString();
}
