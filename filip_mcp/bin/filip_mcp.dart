import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:filip_mcp/obsidian_mcp.dart';
import 'package:filip_mcp/vector_search.dart';
import 'package:logging/logging.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> main(List<String> arguments) async {
  final argParser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addOption(
      'vault',
      help: 'Path to the vault.',
      defaultsTo: '/Users/filiph/Google Drive/notes/memex',
    )
    ..addOption(
      'embeddings-file',
      help: 'Path to the embeddings file.',
      defaultsTo: '/Users/filiph/dev/bespoke/filip_mcp/glove/glove.6B.100d.txt',
    )
    ..addOption(
      'log-file',
      help: 'Path to a log file.',
      defaultsTo: '/Users/filiph/dev/bespoke/filip_mcp/log.txt',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.');

  try {
    final ArgResults parsedArgs = argParser.parse(arguments);
    bool verbose = false;

    // Process the parsed arguments.
    if (parsedArgs.flag('help')) {
      _printUsage(argParser);
      return;
    }
    if (parsedArgs.flag('version')) {
      print('filip_mcp version: $version');
      return;
    }
    if (parsedArgs.flag('verbose')) {
      verbose = true;
    }

    // Act on the arguments provided.
    if (verbose) {
      print('[VERBOSE] All arguments: ${parsedArgs.arguments}');
    }

    final logFile = io.File(parsedArgs.option('log-file')!);
    final logSink = logFile.openWrite(mode: io.FileMode.append);
    final timestamp = DateTime.now();
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      logSink.writeln(record);
    });
    logSink.writeln('\n\n\n====== NEW LOG: $timestamp ======\n');

    final vectorSearchEngine = await VectorSearchEngine.initialize(
      glovePath: parsedArgs.option('embeddings-file')!,
      windowSize: 20,
      windowOverlap: 10,
    );

    // Start the server.
    ObsidianServer.fromStreamChannel(
      vaultPath: parsedArgs.option('vault')!,
      vectorSearchEngine: vectorSearchEngine,
      onDone: () {
        logSink.writeln('------ CLOSING LOG: $timestamp ------');
        logSink.close();
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

const String version = '0.0.1';

void _printUsage(ArgParser argParser) {
  print('Usage: dart filip_mcp.dart <flags> [arguments]');
  print(argParser.usage);
}
