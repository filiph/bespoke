import 'package:riverpod/riverpod.dart';

final tabProvider = StateProvider((ref) => Tab.news);

enum Tab {
  news,
}
