import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:filip_mcp/cli_shared.dart';
import 'package:filip_mcp/obsidian_query.dart';

Future<void> main(List<String> arguments) async {
  final argParser = buildBaseArgParser();

  try {
    final ArgResults parsedArgs = argParser.parse(arguments);

    if (parsedArgs.flag('help')) {
      _printUsage(argParser);
      return;
    }
    if (parsedArgs.flag('version')) {
      print('filip_search version: $filipMcpVersion');
      return;
    }

    final verbose = parsedArgs.flag('verbose');
    setupLogging(parsedArgs, logToConsole: verbose);

    final vaultPath = parsedArgs.option('vault')!;
    io.stderr.writeln('Initializing index for vault: $vaultPath');

    final stopwatch = Stopwatch()..start();
    var hadProgress = false;
    final (vault, _) = await initializeVaultFromArgs(
      parsedArgs,
      onProgress: (processed, total, status) {
        hadProgress = true;
        io.stderr.write('\r\x1b[K$status');
      },
    );
    stopwatch.stop();
    if (hadProgress) {
      io.stderr.writeln();
    }
    io.stderr.writeln('Index ready in ${stopwatch.elapsedMilliseconds} ms.');

    // Get search query from rest arguments or interactive prompt
    String query;
    if (parsedArgs.rest.isNotEmpty) {
      query = parsedArgs.rest.join(' ').trim();
    } else {
      io.stdout.write('Enter search query: ');
      final input = io.stdin.readLineSync();
      if (input == null || input.trim().isEmpty) {
        return;
      }
      query = input.trim();
    }

    final queryResult = await vault.query(
      ObsidianQuery(
        searchPhrase: query,
        createdAfter: null,
        createdBefore: null,
        limit: 20,
      ),
    );

    if (queryResult.results.isEmpty) {
      print('No matching notes found for "$query".');
      return;
    }

    for (final result in queryResult.results) {
      final score = result.score.toStringAsFixed(4);
      print('[$score] ${result.path}');
    }
  } on FormatException catch (e) {
    print(e.message);
    print('');
    _printUsage(argParser);
    io.exitCode = 1;
  }
}

void _printUsage(ArgParser argParser) {
  print('Usage: dart filip_search.dart [flags] <query>');
  print(argParser.usage);
}
