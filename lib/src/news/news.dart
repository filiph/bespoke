import 'package:flutter/widgets.dart';
import 'package:flutter95/flutter95.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wnews/wnews.dart';

part 'news.g.dart';

@riverpod
Stream<int> slowCounter(SlowCounterRef ref) async* {
  var i = 0;
  while (true) {
    await Future.delayed(const Duration(hours: 4));
    yield i++;
  }
}

@riverpod
Future<List<NewsItem>> fetchNews(FetchNewsRef ref) async {
  ref.watch(slowCounterProvider);
  print('fetching news');
  final response = await http.get(
    Uri.parse('https://en.wikipedia.org/wiki/Main_Page'),
  );
  return extractNews(response.body);
}

class NewsView extends HookConsumerWidget {
  const NewsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(fetchNewsProvider);

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: switch (news) {
        AsyncData<List<NewsItem>>(:final value) ||
        AsyncLoading(hasValue: true, :final value!) =>
          ListView(
            children: [
              for (final item in value)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Text(item.text)),
                      SizedBox(width: 8.0),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            launchUrlString(
                                'https://en.wikipedia.org${item.link!}');
                          },
                          child: Text(
                            'Link',
                            style: TextStyle(
                              color: Flutter95.headerLight,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        AsyncLoading(hasValue: false) => const Text('Loading...'),
        AsyncError(:final error) => Text('Error: $error'),
        AsyncValue<List<NewsItem>>() => Text('what?'),
      },
    );
  }
}
