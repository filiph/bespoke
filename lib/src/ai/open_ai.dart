import 'package:dart_openai/dart_openai.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'open_ai.g.dart';

@riverpod
OpenAiController openAiController(OpenAiControllerRef ref) {
  const apiKey = String.fromEnvironment('OPENAI_API_KEY');
  if (apiKey.isEmpty) {
    throw Exception('OPENAI_API_KEY is not set');
  }
  OpenAI.apiKey = apiKey;
  return OpenAiController(OpenAI.instance);
}

class OpenAiController {
  final OpenAI _instance;

  OpenAiController(this._instance);

  @experimental
  OpenAI get instance => _instance;
}
