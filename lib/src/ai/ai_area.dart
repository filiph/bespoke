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
                  // TODO: show "thinking" indicator

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
                              "Only edit if there are "
                              "wrongly used phrasal verbs, "
                              "or if a particular sentence would be "
                              "written differently by a native speaker. "
                              "Output only the corrected text. "
                              "If the input text is exactly as it would be "
                              "written by a native speaker, then just "
                              "copy it verbatim.",
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

                  // TODO: stop showing "thinking" indicator
                  textController.text = editedParagraphs.join('\n\n');
                  httpClient.close();
                },
                child: const Text('English'),
              ),
              SizedBox(height: 4),
              Button95(
                onTap: () {},
                child: const Text('→ Markdown'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
