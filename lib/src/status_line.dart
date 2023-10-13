import 'dart:async';

import 'package:flutter/widgets.dart';

class StatusLine extends StatefulWidget {
  const StatusLine({super.key});

  @override
  State<StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<StatusLine> {
  Timer? _timer;

  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        return;
      }
      setState(() {
        now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startOfYear = DateTime(now.year, 1, 1);
    final nextYear = DateTime(now.year + 1, 1, 1);
    final percentOfYear = now.difference(startOfYear).inMilliseconds /
        nextYear.difference(startOfYear).inMilliseconds *
        100;

    return Center(
      child: Text('It is ${now.hour}:${now.minute.toString().padLeft(2, '0')} '
          'on ${now.day}/${now.month}/${now.year}. '
          'Year progress is at ${percentOfYear.toStringAsFixed(2)}%.'),
    );
  }
}
