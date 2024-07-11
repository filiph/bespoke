import 'dart:collection';

Dialogue extractDialogue(String full) {
  const delimiter = '\n';
  final paragraphs = full.trim().split(delimiter).map((e) => e.trim());

  final dialoguePattern = RegExp(r'^([A-ZĚŠČŘŽÝÁÍÉÚŮÓŇŤ ]+)(\s\(.+?\))?:(.+)$');

  final bubbles = <SpeechBubble>[];
  for (final paragraph in paragraphs) {
    final match = dialoguePattern.firstMatch(paragraph);
    if (match == null) {
      continue;
    }
    final speaker = match.group(1)!.trim();
    if (speaker == 'SFX') {
      // We don't count SFX into dialogue.
      continue;
    }
    final bubbleContent = match.group(3)!.trim();
    final bubbleWords = bubbleContent.split(' ');
    final bubble = SpeechBubble(
        bubbleWords.map((w) => w.trim()).where((w) => w.isNotEmpty));
    bubbles.add(bubble);
  }

  return Dialogue(speechBubbles: bubbles);
}

final class Dialogue {
  final List<SpeechBubble> _speechBubbles;

  late final UnmodifiableListView<SpeechBubble> speechBubbles =
      UnmodifiableListView(_speechBubbles);

  Dialogue({required Iterable<SpeechBubble> speechBubbles})
      : _speechBubbles = speechBubbles.toList(growable: false);

  int get bubbleCount => speechBubbles.length;

  int get wordCount =>
      speechBubbles.fold(0, (prev, e) => prev + e.words.length);

  double get wordsPerBubbleAverage => wordCount / bubbleCount;
}

final class SpeechBubble {
  final List<String> _words;

  late final UnmodifiableListView<String> words = UnmodifiableListView(_words);

  SpeechBubble(Iterable<String> words) : _words = words.toList(growable: false);
}
