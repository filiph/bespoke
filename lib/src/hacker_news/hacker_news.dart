import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hackernews_api/hackernews_api.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'hacker_news.g.dart';

final _log = Logger('Hacker News');

void checkHackerNews(Timer timer) async {
  try {
    _log.info('Fetching from hacker news');
    final news = HackerNews(newsType: NewsType.newStories);
    final stories = await news.getStories();
    final relevantStories = stories.where(_relevant);
    if (relevantStories.isNotEmpty) {
      Process.run('osascript', [
        '-e',
        'display notification '
            '"${relevantStories.length} new relevant article(s) found '
            'on Hacker News." '
            'with title "News article found" '
            'subtitle "Hacker News" '
            'sound name "Frog"',
      ]);
    } else {
      debugPrint('No new relevant articles found.');
    }
  } catch (e) {
    debugPrint(e.toString());
  }
}

@riverpod
Future<List<Story>> fetchHackerNews(FetchHackerNewsRef ref) async {
  // TODO: use this when https://github.com/rrousselGit/riverpod/issues/3768
  //       is resolved
  ref.watch(slowCounterProvider);
  _log.info('fetching new stories');
  final news = HackerNews(newsType: NewsType.newStories);
  final stories = await news.getStories();
  return stories;
}

@riverpod
Stream<int> slowCounter(SlowCounterRef ref) async* {
  var i = 0;
  while (true) {
    await Future.delayed(const Duration(hours: 1));
    yield i++;
  }
}

bool _relevant(Story story) {
  if (story.url.contains('filiph.net')) return true;
  if (story.url.contains('raindead.com')) return true;
  if (story.url.contains('selfimproving.dev')) return true;
  if (story.url.contains('egamebook.com')) return true;
  if (story.url.contains('giantrobotgame.com')) return true;
  if (story.url.contains('starmap2d.appspot.com')) return true;
  if (story.url.contains('mastodon.social/@filiph')) return true;
  if (story.url.contains('twitter.com/filiphracek')) return true;
  if (story.url.contains('x.com/filiphracek')) return true;
  if (story.url.contains('github.com/filiph')) return true;
  if (story.url.contains('medium.com/@filiph')) return true;
  if (story.url.contains('youtube.com/filiphracek')) return true;

  bool contains(Pattern pattern) => story.title.toLowerCase().contains(pattern);

  if (contains(RegExp(r'\bfiliph\b'))) return true;
  if (contains(RegExp(r'\braindead\b'))) return true;
  if (contains(RegExp(r'filip.+hracek'))) return true;
  if (contains(RegExp(r'filip.+hráček'))) return true;
  if (contains(RegExp(r'giant\s+robot\s+game'))) return true;
  if (contains(RegExp(r'knights\s+of\s+san\s+francisco'))) return true;
  if (contains(RegExp(r'unsure\s+calculator'))) return true;
  if (contains(RegExp(r'\blinkcheck\b'))) return true;

  return false;
}
