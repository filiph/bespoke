import 'package:bespoke/src/news/news.dart';
import 'package:bespoke/src/tab.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MainArea extends HookConsumerWidget {
  const MainArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);

    switch (tab) {
      case Tab.news:
        return const NewsView();
    }
  }
}
