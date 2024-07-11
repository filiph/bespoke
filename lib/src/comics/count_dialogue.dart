import 'dart:collection';

Dialogue extractDialogue(String full) {
  const delimiter = '\n';
  final paragraphs = full.trim().split(delimiter).map((e) => e.trim());

  final panelPattern = RegExp(r'^Panel\s+(\d+)\s*$');
  final dialoguePattern = RegExp(r'^([A-ZĚŠČŘŽÝÁÍÉÚŮÓŇŤ ]+)(\s\(.+?\))?:(.+)$');

  bool beforeFirstPanel = true;
  final panels = <Panel>[];
  final bubbles = <SpeechBubble>[];

  void finalizePanel() {
    if (beforeFirstPanel) {
      bubbles.clear();
      beforeFirstPanel = false;
      return;
    }

    final panel = Panel(speechBubbles: bubbles);
    panels.add(panel);
    bubbles.clear();
  }

  for (final paragraph in paragraphs) {
    if (panelPattern.hasMatch(paragraph)) {
      finalizePanel();
      continue;
    }

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
  finalizePanel();

  return Dialogue(panels: panels);
}

final class Dialogue {
  final List<Panel> _panels;

  late final UnmodifiableListView<Panel> panels = UnmodifiableListView(_panels);

  Dialogue({required Iterable<Panel> panels})
      : _panels = panels.toList(growable: false);

  Iterable<SpeechBubble> get bubbles => panels.expand((p) => p.speechBubbles);

  Iterable<String> get words => bubbles.expand((b) => b.words);

  double get wordsPerBubbleAverage => words.length / bubbles.length;

  double get wordsPerPanelAverage => words.length / panels.length;

  double get bubblesPerPanelAverage => bubbles.length / panels.length;

  int countPanelsWithBubbleCount(int count) {
    return panels.where((p) => p.speechBubbles.length == count).length;
  }
}

final class Panel {
  final List<SpeechBubble> _speechBubbles;

  late final UnmodifiableListView<SpeechBubble> speechBubbles =
      UnmodifiableListView(_speechBubbles);

  Panel({required Iterable<SpeechBubble> speechBubbles})
      : _speechBubbles = speechBubbles.toList(growable: false);

  int get bubbleCount => speechBubbles.length;

  int get wordCount =>
      speechBubbles.fold(0, (prev, e) => prev + e.words.length);
}

final class SpeechBubble {
  final List<String> _words;

  late final UnmodifiableListView<String> words = UnmodifiableListView(_words);

  SpeechBubble(Iterable<String> words) : _words = words.toList(growable: false);
}
