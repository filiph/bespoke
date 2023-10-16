import 'package:bespoke/src/ai/ai_area.dart';
import 'package:bespoke/src/glyphs/glyphs.dart';
import 'package:bespoke/src/main_area.dart';
import 'package:bespoke/src/shortcuts/shortcuts.dart';
import 'package:bespoke/src/status_line.dart';
import 'package:flutter/material.dart' hide Tab;
import 'package:flutter/services.dart';
import 'package:flutter95/flutter95.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:macos_window_utils/window_manipulator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowManipulator.initialize();

  WindowManipulator.makeTitlebarTransparent();
  WindowManipulator.enableFullSizeContentView();
  WindowManipulator.hideTitle();
  WindowManipulator.hideCloseButton();
  WindowManipulator.hideMiniaturizeButton();
  WindowManipulator.hideZoomButton();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends HookConsumerWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold95(
      title: 'Bespoke app',
      onClosePressed: (context) {
        SystemNavigator.pop();
      },
      toolbar: Toolbar95(
        actions: [
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
          Item95(label: 'Help'),
        ],
      ),
      body: Expanded(
        child: DefaultTextStyle(
          style: Flutter95.textStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Elevation95(
                  type: Elevation95Type.down,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShortcutsView(),
                      Expanded(child: MainArea()),
                      Glyphs(),
                      Expanded(child: AiArea()),
                    ],
                  ),
                ),
              ),
              // Row(
              //   children: [
              //     Button95(
              //       child: Text('News'),
              //       onTap: () =>
              //           ref.read(tabProvider.notifier).state = Tab.news,
              //     ),
              //     Button95(
              //       child: Text('Grammar'),
              //     ),
              //   ],
              // ),
              SizedBox(height: 2),
              StatusLine(),
              // Some breathing room for the status line.
              SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
