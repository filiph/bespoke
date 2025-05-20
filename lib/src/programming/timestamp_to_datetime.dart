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
  DateTime? previous;

  String format(DateTime dateTime) {
    final buf = StringBuffer();
    buf.write(dateTime.toIso8601String());
    if (previous != null) {
      final duration = dateTime.difference(previous!);
      final ms = duration.inMilliseconds;
      buf.write('\t+');
      buf.write(ms.toString());
      buf.write('ms');
    }
    return buf.toString();
  }

  for (final line in lines) {
    bool lineHasTimestamp = false;
    final out = line.replaceAllMapped(_thirteenDigitRegExp, (match) {
      lineHasTimestamp = true;
      final milliseconds = int.parse(match.group(0)!);

      final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
      final formatted = format(dateTime);
      previous = dateTime;
      return formatted;
    });
    if (lineHasTimestamp) {
      buf.writeln(out);
    }
  }

  return buf.toString();
}
