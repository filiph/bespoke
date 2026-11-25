import 'dart:convert';
import 'dart:io' as io;

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'obsidian_vault.dart';
import 'vector_search.dart';

const String filipMcpVersion = '0.1.0';

/// Resolves the default cache file path in `~/.cache/filip_mcp/`.
String resolveDefaultCacheFile(String vaultPath) {
  final home =
      io.Platform.environment['HOME'] ??
      io.Platform.environment['USERPROFILE'] ??
      '.';
  final hash = sha1
      .convert(utf8.encode(p.canonicalize(vaultPath)))
      .toString()
      .substring(0, 10);
  final slug = p.basename(vaultPath).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return p.join(home, '.cache', 'filip_mcp', '${slug}_$hash.bin');
}

/// Creates a standardized [ArgParser] with common options for both binaries.
ArgParser buildBaseArgParser({String? binaryName}) {
  return ArgParser()
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
      help: 'Path to the Obsidian vault directory.',
      defaultsTo: '/Users/filiph/Google Drive/notes/memex',
    )
    ..addOption('cache-file', help: 'Path to the binary embeddings cache file.')
    ..addOption(
      'ollama-url',
      help: 'URL of the Ollama server.',
      defaultsTo: 'http://localhost:11434',
    )
    ..addOption(
      'model',
      help: 'Ollama embedding model name.',
      defaultsTo: 'embeddinggemma-2',
    )
    ..addOption(
      'log-file',
      help: 'Path to a log file.',
      defaultsTo: '/Users/filiph/dev/bespoke/filip_mcp/log.txt',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.');
}

/// Sets up file logging and returns the log sink.
io.IOSink? setupLogging(ArgResults parsedArgs, {bool logToConsole = false}) {
  final logFilePath = parsedArgs.option('log-file');
  io.IOSink? logSink;
  if (logFilePath != null && logFilePath.isNotEmpty) {
    try {
      final logFile = io.File(logFilePath);
      logFile.parent.createSync(recursive: true);
      logSink = logFile.openWrite(mode: io.FileMode.append);
      final timestamp = DateTime.now();
      logSink.writeln('\n\n\n====== NEW LOG: $timestamp ======\n');
    } catch (_) {
      // Ignore if log file cannot be opened.
    }
  }

  final verbose = parsedArgs.flag('verbose');
  Logger.root.level = verbose ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((record) {
    logSink?.writeln(record);
    if (logToConsole && (verbose || record.level >= Level.WARNING)) {
      io.stderr.writeln('[${record.level.name}] ${record.message}');
    }
  });

  return logSink;
}

/// Initializes a [VectorSearchEngine] and [ObsidianVault] from parsed arguments.
Future<(ObsidianVault, VectorSearchEngine)> initializeVaultFromArgs(
  ArgResults parsedArgs, {
  void Function(int processed, int total, String status)? onProgress,
}) async {
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

  final vault = ObsidianVault(vaultPath, vectorSearchEngine);
  await vault.initialize(onProgress: onProgress);

  return (vault, vectorSearchEngine);
}
