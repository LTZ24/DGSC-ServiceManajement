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
  static File? _mirrorLogFile;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final file = await _resolveLogFile();
    _logFile = file;
    _mirrorLogFile = await _resolveAndroidMirrorLogFile();

    await log('=== App start ===');
  }

  static Future<File> _resolveLogFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'log'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return File(p.join(dir.path, _logFileName));
  }

  static Future<File?> _resolveAndroidMirrorLogFile() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final dir = Directory(_androidMediaLogDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
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
    final mirror = _mirrorLogFile ?? await _resolveAndroidMirrorLogFile();

    _writeQueue = _writeQueue.then((_) async {
      try {
        await file.writeAsString('$text\n', mode: FileMode.append, flush: true);
      } catch (_) {
        // Ignore logging failures to avoid cascading crashes.
      }

      if (mirror != null) {
        try {
          await mirror.writeAsString('$text\n', mode: FileMode.append, flush: true);
        } catch (_) {}
      }
    });

    return _writeQueue;
  }

  static Future<File?> getLogFile() async {
    if (!_initialized) {
      await initialize();
    }
    final mirror = _mirrorLogFile;
    if (mirror != null) {
      try {
        if (await mirror.exists()) {
          return mirror;
        }
      } catch (_) {}
    }
    return _logFile;
  }

  static Future<String> readAll() async {
    final source = _logFile ?? await _resolveLogFile();
    try {
      if (!await source.exists()) return '';
      return await source.readAsString();
    } catch (_) {
      return '';
    }
  }
}
