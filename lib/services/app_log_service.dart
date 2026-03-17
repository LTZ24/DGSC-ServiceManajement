import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppLogService {
  static const String _androidMediaLogDir =
      '/storage/emulated/0/Android/media/com.dgsc.mobile/log';
  static const String _logFileName = 'app.log';

  static bool _initialized = false;
  static File? _logFile;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final file = await _resolveLogFile();
    _logFile = file;

    await log('=== App start ===');
  }

  static Future<File> _resolveLogFile() async {
    Directory dir;

    if (!kIsWeb && Platform.isAndroid) {
      dir = Directory(_androidMediaLogDir);
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } catch (_) {
        // Fallback to app documents if media dir is not writable.
        final docs = await getApplicationDocumentsDirectory();
        dir = Directory(p.join(docs.path, 'log'));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory(p.join(docs.path, 'log'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    return File(p.join(dir.path, _logFileName));
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

    if (error != null) {
      line.write(' | error=$error');
    }
    if (stackTrace != null) {
      line.write('\n$stackTrace');
    }

    return _appendLine(line.toString());
  }

  static Future<void> logError(Object error, StackTrace stackTrace,
      {String message = 'Unhandled error'}) {
    return log(message, level: 'ERROR', error: error, stackTrace: stackTrace);
  }

  static Future<void> logFlutterError(FlutterErrorDetails details) {
    final stack = details.stack ?? StackTrace.current;
    return log('FlutterError',
        level: 'ERROR', error: details.exception, stackTrace: stack);
  }

  static Future<void> _appendLine(String text) async {
    if (!_initialized) {
      await initialize();
    }

    final file = _logFile ?? await _resolveLogFile();

    _writeQueue = _writeQueue.then((_) async {
      try {
        await file.writeAsString('$text\n', mode: FileMode.append, flush: true);
      } catch (_) {
        // Ignore logging failures to avoid cascading crashes.
      }
    });

    return _writeQueue;
  }

  static Future<File?> getLogFile() async {
    if (!_initialized) {
      await initialize();
    }
    return _logFile;
  }

  static Future<String> readAll() async {
    final file = await getLogFile();
    if (file == null) return '';
    try {
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }
}
