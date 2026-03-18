import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppLogService {
  static const String _androidMediaLogDir =
      '/storage/emulated/0/Android/media/com.dgsc.mobile/log';
  static const String _logFileName = 'app.log';

  // ✅ FIX: Completer-based init so concurrent callers all wait for the same
  //         future, eliminating the race between _initialized=true and
  //         _logFile assignment.
  static Completer<void>? _initCompleter;
  static File? _logFile;
  static File? _mirrorLogFile;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> initialize() async {
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      _logFile = await _resolveLogFile();
      _mirrorLogFile = await _resolveAndroidMirrorLogFile();
      await log('=== App start ===');
      _initCompleter!.complete();
    } catch (e, st) {
      _initCompleter!.completeError(e, st);
      _initCompleter = null; // allow retry
      rethrow;
    }
  }

  static Future<void> _ensureInitialized() async {
    if (_initCompleter == null) {
      await initialize();
    } else {
      await _initCompleter!.future;
    }
  }

  static Future<File> _resolveLogFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'log'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, _logFileName));
  }

  static Future<File?> _resolveAndroidMirrorLogFile() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final dir = Directory(_androidMediaLogDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      return File(p.join(dir.path, _logFileName));
    } catch (_) {
      return null;
    }
  }

  static String _ts() => DateTime.now().toIso8601String();

  static Future<void> log(
    String message, {
    String level = 'INFO',
    Object? error,
    StackTrace? stackTrace,
  }) {
    final line = StringBuffer()
      ..write('[${_ts()}] [$level] ')
      ..write(message);
    if (error != null) line.write(' | error=$error');
    if (stackTrace != null) line.write('\n$stackTrace');
    return _appendLine(line.toString());
  }

  static Future<void> logError(
    Object error,
    StackTrace stackTrace, {
    String message = 'Unhandled error',
  }) =>
      log(message, level: 'ERROR', error: error, stackTrace: stackTrace);

  static Future<void> logFlutterError(FlutterErrorDetails details) {
    final stack = details.stack ?? StackTrace.current;
    return log('FlutterError',
        level: 'ERROR', error: details.exception, stackTrace: stack);
  }

  static Future<void> _appendLine(String text) async {
    await _ensureInitialized();
    _writeQueue = _writeQueue.then((_) async {
      try {
        await _logFile!
            .writeAsString('$text\n', mode: FileMode.append, flush: true);
      } catch (_) {}
      if (_mirrorLogFile != null) {
        try {
          await _mirrorLogFile!
              .writeAsString('$text\n', mode: FileMode.append, flush: true);
        } catch (_) {}
      }
    });
    return _writeQueue;
  }

  /// Returns the log file after flushing all pending writes.
  static Future<File?> getLogFile() async {
    await _ensureInitialized();
    await _writeQueue;
    if (_mirrorLogFile != null) {
      try {
        if (await _mirrorLogFile!.exists()) return _mirrorLogFile;
      } catch (_) {}
    }
    return _logFile;
  }

  /// Returns all log content after flushing all pending writes.
  static Future<String> readAll() async {
    await _ensureInitialized();
    await _writeQueue; // ✅ wait for all writes to flush
    try {
      if (!await _logFile!.exists()) return '';
      return await _logFile!.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Clears both primary and mirror log files.
  static Future<void> clear() async {
    await _ensureInitialized();
    await _writeQueue;
    try {
      await _logFile?.writeAsString('', mode: FileMode.write, flush: true);
    } catch (_) {}
    try {
      await _mirrorLogFile
          ?.writeAsString('', mode: FileMode.write, flush: true);
    } catch (_) {}
  }
}