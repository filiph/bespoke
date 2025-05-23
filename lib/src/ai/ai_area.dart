import 'dart:async';

import 'package:bespoke/src/ai/open_ai.dart';
import 'package:bespoke/src/comics/count_dialogue.dart';
import 'package:bespoke/src/programming/timestamp_to_datetime.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter95/flutter95.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_area.g.dart';

@riverpod
TextEditingController textController(TextControllerRef ref) {
  return TextEditingController();
}

final isProcessingProvider = StateProvider<bool>((ref) => false);

class AiArea extends HookConsumerWidget {
  static final _log = Logger('AiArena');

  const AiArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox.expand(
              child: TextField95(
                controller: ref.watch(textControllerProvider),
                maxLines: 9999999,
                multiline: true,
              ),
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Button95(
                onTap: () async {
                  // TODO: accept also 'text/html' data (save them separately?)
                  final content = await Clipboard.getData('text/plain');
                  final text = content?.text;
                  if (text == null) {
                    debugPrint("No text in clipboard");
                  } else {
                    final textController = ref.read(textControllerProvider);
                    textController.text = text;
                  }
                },
                child: const Text('Paste'),
              ),
              SizedBox(height: 4),
              Button95(
                onTap: () {
                  final textController = ref.read(textControllerProvider);
                  textController.clear();
                },
                child: const Text('Clear'),
              ),
              SizedBox(height: 8),
              Button95(
                onTap: () async {
                  final textController = ref.read(textControllerProvider);
                  final text = textController.text;

                  if (text.trim().isEmpty) {
                    _log.info('Empty input');
                    return;
                  }

                  // Show "thinking" indicator
                  ref.read(isProcessingProvider.notifier).state = true;

                  final openAi = ref.read(openAiControllerProvider);
                  final chunks = _splitIntoChunks(text);
                  final editedChunks = <String>[];
                  final httpClient = http.Client();
                  _log.info(() => "Sending chunks to AI: "
                      "${chunks.map(_debugShortenParagraph).toList()}");
                  for (final chunk in chunks) {
                    final wrappedChunk =
                        OpenAIChatCompletionChoiceMessageContentItemModel.text(
                            chunk);
                    final model = await openAi.instance.chat.create(
                      model: 'gpt-4',
                      messages: [
                        OpenAIChatCompletionChoiceMessageModel(
                          role: OpenAIChatMessageRole.system,
                          content: [
                            OpenAIChatCompletionChoiceMessageContentItemModel.text(
                                "You are a copy editor. "
                                "Rewrite the paragraphs that will be given "
                                "to you by the user. "
                                "Assume the user is an ESL person. "
                                "Keep the original meaning and tone. "
                                "Do NOT make the text more formal than it is. "
                                "Keep it casual, almost as spoken text. "
                                "Only edit if there are "
                                "wrongly used phrasal verbs, "
                                "or if a particular sentence would be "
                                "written differently by a native speaker. "
                                "If you find any of the original text acceptable,"
                                "keep it as is. Don't fix what isn't broken. "
                                "If the input text contains Markdown or HTML "
                                "formatting, keep it. "
                                "Output only the corrected text.")
                          ], // TODO: add examples
                        ),
                        OpenAIChatCompletionChoiceMessageModel(
                          role: OpenAIChatMessageRole.user,
                          content: [wrappedChunk],
                        )
                      ],
                      n: 1,
                      client: httpClient,
                    );
                    editedChunks.addAll(model.choices.first.message.content
                            ?.map((m) => m.text!) ??
                        const []);
                  }

                  textController.text = editedChunks.join('\n\n');
                  httpClient.close();

                  // Stop showing "thinking" indicator.
                  ref.read(isProcessingProvider.notifier).state = false;
                },
                child: const Text('English'),
              ),
              SizedBox(height: 4),
              Button95(
                onTap: null,
                child: const Text('→ Markdown'),
              ),
              SizedBox(height: 4),
              Button95(
                onTap: () async {
                  final textController = ref.read(textControllerProvider);
                  final text = textController.text.trim();

                  if (text.isEmpty) {
                    _log.info('Empty input');
                    return;
                  }

                  _log.fine('Counting words in input of length '
                      '${text.length}');

                  final dialogue = extractDialogue(text);

                  _log.info("Words in the dialogue: ${dialogue.words.length}");

                  final summary = "Slov: ${dialogue.words.length}.\n"
                      "Bublin: ${dialogue.bubbles.length}.\n"
                      "Panelů: ${dialogue.panels.length}.\n"
                      "\n"
                      "To je v průměru "
                      "${dialogue.wordsPerBubbleAverage.toStringAsFixed(1)}"
                      " slov na bublinu "
                      "a "
                      "${dialogue.wordsPerPanelAverage.toStringAsFixed(1)}"
                      " slov na panel.\n"
                      "\n"
                      "Je tu ${dialogue.countPanelsWithBubbleCount(0)} "
                      "panelů bez bubliny, "
                      "${dialogue.countPanelsWithBubbleCount(1)} "
                      "panelů s jednou bublinou, "
                      "${dialogue.countPanelsWithBubbleCount(2)} "
                      "panelů se dvěma bublinama. "
                      "V průměru "
                      "${dialogue.bubblesPerPanelAverage.toStringAsFixed(1)}"
                      " bublin na panel.";

                  unawaited(showDialog95(
                    context: context,
                    title: 'Dialog word count',
                    message: summary,
                  ));

                  unawaited(Clipboard.setData(ClipboardData(text: summary)));
                },
                child: const Text('Count dialogue'),
              ),
              Button95(
                onTap: () async {
                  final textController = ref.read(textControllerProvider);
                  final text = textController.text.trim();

                  if (text.isEmpty) {
                    _log.info('Empty input');
                    return;
                  }

                  _log.fine('Converting timestamps in input of length '
                      '${text.length}');

                  final timestamped = rewriteTimestamps(text);

                  textController.text = timestamped;
                },
                child: const Text('Timestamps'),
              ),
              Spacer(),
              SizedBox(
                width: 120,
                child: Consumer(
                  builder: (context, ref, _) {
                    final isProcessing = ref.watch(isProcessingProvider);
                    return Progress95(value: isProcessing ? null : 0.0);
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  List<String> _splitIntoChunks(String full) {
    // It is unclear what the max chunk is. It seems to be 2048 tokens,
    // but tokens can be anything from one ASCII character to (maybe?) several
    // unicode characters.
    //
    // Playing it safe here.
    const maxPerChunk = 800;

    if (full.length <= maxPerChunk) {
      return [full];
    }

    const delimiter = '\n\n';
    final paragraphs = full.trim().split(delimiter);
    final chunks = <String>[];

    // String paragraphs into larger chunks up to [maxPerChunk] in size.
    final buf = StringBuffer();
    for (final paragraph in paragraphs) {
      if (buf.length + paragraph.length > maxPerChunk) {
        chunks.add(buf.toString());
        buf.clear();
      }
      buf.write(paragraph);
      buf.write(delimiter);
    }

    if (buf.isNotEmpty) {
      chunks.add(buf.toString());
    }

    return chunks;
  }

  String _debugShortenParagraph(String full) {
    const maxLength = 10;
    if (full.length <= maxLength) {
      return full;
    }
    return '${full.substring(0, maxLength - 3)}...';
  }
}
