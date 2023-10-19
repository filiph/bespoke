import 'package:bespoke/src/ai/open_ai.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter95/flutter95.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_area.g.dart';

@riverpod
TextEditingController textController(TextControllerRef ref) {
  return TextEditingController();
}

final isProcessingProvider = StateProvider<bool>((ref) => false);

class AiArea extends HookConsumerWidget {
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
                  // Show "thinking" indicator
                  ref.read(isProcessingProvider.notifier).state = true;

                  final openAi = ref.read(openAiControllerProvider);
                  final paragraphs = text.trim().split('\n\n');
                  final editedParagraphs = <String>[];
                  final httpClient = http.Client();
                  for (final paragraph in paragraphs) {
                    final model = await openAi.instance.chat.create(
                      model: 'gpt-3.5-turbo',
                      messages: [
                        OpenAIChatCompletionChoiceMessageModel(
                          role: OpenAIChatMessageRole.system,
                          content: "You are a copy editor. "
                              "Rewrite the paragraphs that will be given "
                              "to you by the user. "
                              "Assume the user is an ESL person. "
                              "Keep the original meaning and tone. "
                              "Do not make the text more formal than it is. "
                              "Only edit if there are "
                              "wrongly used phrasal verbs, "
                              "or if a particular sentence would be "
                              "written differently by a native speaker. "
                              "If you find any of the original text acceptable,"
                              "keep it as is. Don't fix what isn't broken. "
                              "Output only the corrected text. ",
                        ),
                        OpenAIChatCompletionChoiceMessageModel(
                          role: OpenAIChatMessageRole.user,
                          content: paragraph,
                        )
                      ],
                      n: 1,
                      client: httpClient,
                    );
                    editedParagraphs.add(model.choices.first.message.content);
                  }

                  textController.text = editedParagraphs.join('\n\n');
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
              Spacer(),
              SizedBox(
                width: 120,
                child: Consumer(
                  builder: (context, ref, _) {
                    final isProcessing = ref.watch(isProcessingProvider);
                    return Progress95(value: isProcessing ? null : 1.0);
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
