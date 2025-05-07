import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter95/flutter95.dart';

List<Item95> getToolbarActions() => [
      Item95(
        label: 'File',
        menu: Menu95<String>(
          onItemSelected: (value) {
            if (value == 'Exit') {
              SystemNavigator.pop();
              return;
            }
          },
          items: [
            MenuItem95(value: 'Bleh', label: 'Bleh'),
            MenuItem95(value: 'Exit', label: 'Exit'),
          ],
        ),
      ),
      Item95(label: 'Edit'),
      Item95(
        label: 'Blog',
        menu: Menu95<String>(
          onItemSelected: (value) async {
            if (value == 'Serve') {
              final result = Process.run('osascript', [
                '-e',
                'tell app "Terminal" to do script '
                    '"cd /Users/filiph/dev/filiphnet && make serve"',
              ]);
              // final result = Process.run('osascript', [
              //   '-e',
              //   'do shell script '
              //       '"cd /Users/filiph/dev/filiphnet && make deploy"'
              // ]);

              var r = await result;
              debugPrint(r.stdout);
              return;
            }
            if (value == 'Publish') {
              final result = Process.run('osascript', [
                '-e',
                'tell app "Terminal" to do script '
                    '"cd /Users/filiph/dev/filiphnet && make deploy"',
              ]);
              // final result = Process.run('osascript', [
              //   '-e',
              //   'do shell script '
              //       '"cd /Users/filiph/dev/filiphnet && make deploy"'
              // ]);

              var r = await result;
              debugPrint(r.stdout);
              return;
            }
          },
          items: [
            MenuItem95(value: 'Serve', label: 'Serve'),
            MenuItem95(value: 'Publish', label: 'Publish'),
          ],
        ),
      ),
      Item95(label: 'Help'),
    ];
