import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter95/flutter95.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:open_file_macos/open_file_macos.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ShortcutsView extends HookConsumerWidget {
  static final _openFileMacOS = OpenFileMacos();

  const ShortcutsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          Button95(
            child: const Text('Snippets'),
            onTap: () {
              Process.run('open', ['-a', 'QuickTime Player']);
              _openFileMacOS.open(
                  '/Users/filiph/Google Drive/notes/memex/projects/snippets/Video snippets How To.md');
              // Process.run('open', [
              //   // '-a',
              //   // 'Obsidian',
              //   // 'TextMate',
              //   // '-t',
              //   '/Users/filiph/Google Drive/notes/memex/projects/snippets/Video snippets How To.md'
              // ]).then((value) => debugPrint(value.stderr));
            },
          ),
          Button95(
            child: const Text('Rhythm'),
            onTap: () => launchUrlString(
                "https://docs.google.com/document/d/11awjNmeUFSgA1lGNE4pHi-4UevZBV2Q8HMSAzTx1dmc/edit"),
          ),
          Button95(
            child: const Text('Projects'),
            onTap: () {
              _openFileMacOS.open(
                  '/Users/filiph/Google Drive/Projects/Giant Robot Game/',
                  viewInFinder: true);
            },
          ),
          Button95(
            child: const Text('Účto'),
            onTap: () {
              launchUrlString(
                  "https://ib.fio.cz/ib/fio/page/nastenka-vsechny-ucty");
              launchUrlString(
                  "https://app.fakturoid.cz/raindeadcompany/dashboard");
            },
          ),
          Button95(
            child: const Text('Scan'),
            onTap: () =>
                launchUrlString("https://v4.camscanner.com/file/manager"),
          ),
          Button95(
            child: const Text('Status'),
            onTap: () {
              // Roughly 80 years in weeks.
              const weeksInLife = 4000;
              final week =
                  DateTime.now().difference(DateTime(1982, 5, 9)).inDays ~/ 7;

              Process.run('osascript', [
                '-e',
                'say "Year progress is at 78%. '
                    'Out of $weeksInLife weeks of your life, '
                    'this is week number $week. '
                    'Expect same weather tomorrow."',
              ]);
            },
          ),
        ],
      ),
    );
  }
}
