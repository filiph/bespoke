import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter95/flutter95.dart';
import 'package:url_launcher/url_launcher_string.dart';

List<Item95> getToolbarActions() => [
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
              launchUrlString('https://filiph.github.io/napkin/'),
          'Unsure': () async =>
              launchUrlString('https://filiph.github.io/unsure/'),
          'Wope': () async => launchUrlString('https://filiph.github.io/wope/'),
          'YouTube subs prettifier': () async =>
              launchUrlString('https://filiph.github.io/youtube_subs/'),
          'Script prompter': () async =>
              launchUrlString('https://filiph.net/prompter/'),
          'Lorem ipsumize': () async =>
              launchUrlString('https://filiph.net/lorem/'),
          'Calendar linker': () async =>
              launchUrlString('https://filiph.net/gcal/'),
          'docs2html': () async => launchUrlString('https://filiph.net/d2b/'),
        }).asMenu95,
      ),
      Item95(label: 'Edit'),
      Item95(
        label: 'Blog',
        menu: _Submenu(items: {
          'Serve': () async {
            await _runTerminal('cd /Users/filiph/dev/filiphnet && make serve');
            await launchUrlString('http://localhost:3474/');
          },
          'Publish': () async {
            await _runTerminal('cd /Users/filiph/dev/filiphnet && make deploy');
            await launchUrlString("https://filiph.net/text");
          },
        }).asMenu95,
      ),
      Item95(
        label: 'Anti-Ř',
        menu: _Submenu(items: {
          'Serve': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/fajfka.cz && make serve_retezak');
            await launchUrlString('http://localhost:3474/');
          },
          'Publish': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/fajfka.cz && make deploy_retezak');
            await launchUrlString("https://anti-retezak.cz/");
          },
          'Send': () async {
            await _runTerminal('cd /Users/filiph/dev/fajfka.cz && make send');
          },
        }).asMenu95,
      ),
      Item95(
        label: 'Fajfka',
        menu: _Submenu(items: {
          'Serve': () async {
            await _runTerminal('cd /Users/filiph/dev/fajfka.cz && make serve');
            await launchUrlString('http://localhost:3474/');
          },
          'Publish': () async {
            await _runTerminal('cd /Users/filiph/dev/fajfka.cz && make deploy');
            await launchUrlString("https://fajfka.cz/");
          },
        }).asMenu95,
      ),
      Item95(
        label: 'Blaničtí',
        menu: _Submenu(items: {
          'Build': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/blanictiroboti.cz && make build');
          },
          'Serve': () async {
            await _runTerminal(
                'cd /Users/filiph/dev/blanictiroboti.cz && make build && make serve');
            await launchUrlString('http://localhost:3474/');
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
        //     await launchUrlString('http://localhost:3474/');
        //   },
        //   'Publish': () async {
        //     await _runTerminal('cd /Users/filiph/dev/selfimproving-dev && make deploy');
        //     await launchUrlString("https://selfimproving.dev");
        //   },
        // }).asMenu95,
      ),
      Item95(label: 'Help'),
    ];

Future<void> _runTerminal(String command) async {
  if (command.contains('"')) {
    throw ArgumentError(command);
  }

  final result = Process.run('osascript', [
    '-e',
    'tell app "Terminal" to do script "$command"',
  ]);

  var r = await result;
  debugPrint(r.stdout);
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
