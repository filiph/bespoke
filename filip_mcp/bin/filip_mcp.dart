import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:filip_mcp/cli_shared.dart';
import 'package:filip_mcp/obsidian_mcp.dart';
import 'package:filip_mcp/vector_search.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> main(List<String> arguments) async {
  final argParser = buildBaseArgParser();

  try {
    final ArgResults parsedArgs = argParser.parse(arguments);

    // Process the parsed arguments.
    if (parsedArgs.flag('help')) {
      _printUsage(argParser);
      return;
    }
    if (parsedArgs.flag('version')) {
      print('filip_mcp version: $filipMcpVersion');
      return;
    }

    final logSink = setupLogging(parsedArgs);

    final vaultPath = parsedArgs.option('vault')!;
    final cacheFilePath =
        parsedArgs.option('cache-file') ?? resolveDefaultCacheFile(vaultPath);
    final ollamaUrl = parsedArgs.option('ollama-url')!;
    final model = parsedArgs.option('model')!;

    final vectorSearchEngine = await VectorSearchEngine.initialize(
      baseUrl: ollamaUrl,
      model: model,
      dimensions: 768,
      windowSize: 300,
      windowOverlap: 100,
      cachePath: cacheFilePath,
    );

    // Start the server.
    ObsidianServer.fromStreamChannel(
      vaultPath: vaultPath,
      vectorSearchEngine: vectorSearchEngine,
      onDone: () {
        logSink?.writeln('------ CLOSING LOG ------');
        logSink?.close();
      },
      channel: StreamChannel.withCloseGuarantee(io.stdin, io.stdout)
          .transform(StreamChannelTransformer.fromCodec(utf8))
          .transformStream(const LineSplitter())
          .transformSink(
            StreamSinkTransformer.fromHandlers(
              handleData: (data, sink) {
                sink.add('$data\n');
              },
            ),
          ),
    );
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    _printUsage(argParser);
  }
}

void _printUsage(ArgParser argParser) {
  print('Usage: dart filip_mcp.dart <flags> [arguments]');
  print(argParser.usage);
}
