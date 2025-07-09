import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter95/flutter95.dart';
import 'package:url_launcher/url_launcher_string.dart';

typedef TextResultCallback = void Function(String? message);

List<Item95> getToolbarActions(TextResultCallback callback) => [
      Item95(
        label: 'File',
        menu: _Submenu(items: {
          'Exit': () async => SystemNavigator.pop(),
        }).asMenu95,
      ),
      Item95(
        label: 'Go',
        menu: _Submenu(items: {
          'Napkin': () async =>
              _launchUrl('https://filiph.github.io/napkin/', callback),
          'Unsure': () async =>
              _launchUrl('https://filiph.github.io/unsure/', callback),
          'Wope': () async =>
              _launchUrl('https://filiph.github.io/wope/', callback),
          'YouTube subs prettifier': () async =>
              _launchUrl('https://filiph.github.io/youtube_subs/', callback),
          'Script prompter': () async =>
              _launchUrl('https://filiph.net/prompter/', callback),
          'Lorem ipsumize': () async =>
              _launchUrl('https://filiph.net/lorem/', callback),
          'Calendar linker': () async =>
              _launchUrl('https://filiph.net/gcal/', callback),
          'docs2html': () async =>
              _launchUrl('https://filiph.net/d2b/', callback),
        }).asMenu95,
      ),
      Item95(label: 'Edit'),
      Item95(
        label: 'Blog',
        menu: _Submenu(items: {
          'Serve': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/filiphnet && make serve', callback);
            await _launchUrl('http://localhost:3474/', callback);
          },
          'Publish': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/filiphnet && make deploy', callback);
            await _launchUrl("https://filiph.net/text", callback);
          },
        }).asMenu95,
      ),
      Item95(
        label: 'Anti-Ř',
        menu: _Submenu(items: {
          'Serve': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/fajfka.cz && make serve_retezak',
                callback);
            await _launchUrl('http://localhost:3474/', callback);
          },
          'Publish': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/fajfka.cz && make deploy_retezak',
                callback);
            await _launchUrl("https://anti-retezak.cz/", callback);
          },
          'Send': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/fajfka.cz && make send', callback);
          },
        }).asMenu95,
      ),
      Item95(
        label: 'Fajfka',
        menu: _Submenu(items: {
          'Serve': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/fajfka.cz && make serve', callback);
            await _launchUrl('http://localhost:3474/', callback);
          },
          'Publish': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/fajfka.cz && make deploy', callback);
            await _launchUrl("https://fajfka.cz/", callback);
          },
        }).asMenu95,
      ),
      Item95(
        label: 'Blaničtí',
        menu: _Submenu(items: {
          'Build': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/blanictiroboti.cz && make build',
                callback);
          },
          'Serve': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/blanictiroboti.cz && make build && make serve',
                callback);
            await _launchUrl('http://localhost:3474/', callback);
          },
          'Publish': () async {
            final result = await Process.run('osascript', [
              '-e',
              'tell application "Transmit" to activate',
            ]);
            debugPrint(result.stdout);
          },
        }).asMenu95,
      ),
      Item95(
        label: 'selfimp.dev',
        menu: Menu95(
          onItemSelected: (_) {},
          items: [
            MenuItem95(label: 'Must upgrade to NNBD', value: 'NOT IMPLEMENTED'),
          ],
        ),
        // menu: _Submenu(items: {
        //   'Serve': () async {
        //     await _runTerminal(
        //         'cd /Users/filiph/dev/selfimproving-dev && make serve');
        //     await _launchUrl('http://localhost:3474/');
        //   },
        //   'Publish': () async {
        //     await _runTerminal('cd /Users/filiph/dev/selfimproving-dev && make deploy');
        //     await _launchUrl("https://selfimproving.dev");
        //   },
        // }).asMenu95,
      ),
      Item95(label: 'Help'),
    ];

Future<void> _runTerminal(String command, TextResultCallback callback) async {
  if (command.contains('"')) {
    throw ArgumentError(command);
  }

  final ProcessResult result;
  try {
    result = await Process.run('osascript', [
      '-e',
      'tell app "Terminal" to do script "$command"',
    ]);
  } catch (e) {
    callback('Error running the process: $e');
    return;
  }

  debugPrint(result.stdout);
  if (result.exitCode != 0) {
    final buf = StringBuffer();
    buf.writeln(result.stderr);
    buf.writeln('----');
    buf.writeln(result.stdout);
    callback(buf.toString());
  }
}

Future<void> _launchUrl(String url, TextResultCallback callback) async {
  try {
    await launchUrlString(url);
  } catch (e) {
    callback(e.toString());
  }
}

typedef AsyncCallback = Future<void> Function();

class _Submenu {
  final UnmodifiableMapView<String, AsyncCallback> items;

  _Submenu({required Map<String, AsyncCallback> items})
      : items = UnmodifiableMapView(items);

  /// Creates a [Menu95] instance that shows menu items (label == key),
  /// and when clicked, runs the associated callback (onItemSelected <-- value).
  Menu95<String> get asMenu95 {
    return Menu95<String>(
      onItemSelected: (value) => items[value]?.call(),
      items: items.entries
          .map((entry) => MenuItem95(value: entry.key, label: entry.key))
          .toList(growable: false),
    );
  }
}
