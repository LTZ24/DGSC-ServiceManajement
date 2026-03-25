import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A lightweight, fire-and-forget logger.
///
/// Design principles:
///  - [initialize] NEVER throws and NEVER blocks the caller (safe in main()).
///  - Log calls made before init completes are buffered and flushed once
///    the files are ready.
///  - All file I/O runs through a serial write-queue so there are no
///    concurrent write races.
///  - [readAll] / [getLogFile] wait for both init AND the write-queue, so
///    callers always see the latest data.
class AppLogService {
  AppLogService._();

  static const String _androidMediaLogDir =
      '/storage/emulated/0/Android/media/com.dgsc.mobile/log';
  static const String _logFileName = 'app.log';

  // Files are null until init completes.
  static File? _logFile;
  static File? _mirrorLogFile;

  // Serial write-queue (always a resolved future until the first write).
  static Future<void> _writeQueue = Future<void>.value();

  // Lines buffered while init is in progress.
  static final List<String> _pendingLines = [];

  // True once _logFile has been assigned.
  static bool _ready = false;

  // Completer used so readAll/getLogFile can await init without blocking
  // the caller of initialize().
  static final Completer<void> _readyCompleter = Completer<void>();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once in [main] — completely non-blocking, never throws.
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   AppLogService.initialize(); // no await — intentional
  ///   runApp(const MyApp());
  /// }
  /// ```
  static void initialize() {
    // Kick off async work without awaiting so main() is never blocked.
    _initAsync();
  }

  static Future<void> _initAsync() async {
    try {
      _logFile = await _resolveLogFile();
      _mirrorLogFile = await _resolveAndroidMirrorLogFile();
    } catch (_) {
      // If we still can't resolve files (e.g. storage completely unavailable),
      // create a fallback temp file so logs are at least written somewhere.
      try {
        final tmp = Directory.systemTemp;
        _logFile = File(p.join(tmp.path, _logFileName));
      } catch (_) {
        // Truly nothing to write to — silently discard.
      }
    } finally {
      _ready = true;
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();

      // Flush lines that arrived before init finished.
      if (_pendingLines.isNotEmpty) {
        final snapshot = List<String>.from(_pendingLines);
        _pendingLines.clear();
        for (final line in snapshot) {
          _enqueue(line);
        }
      }
    }

    _enqueue(_buildLine('=== App start ===', 'INFO'));
  }

  static Future<void> log(
    String message, {
    String level = 'INFO',
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final line = _buildLine(message, level, error: error, stackTrace: stackTrace);

    if (!_ready) {
      // Buffer until init completes.
      _pendingLines.add(line);
      return;
    }

    _enqueue(line);
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

  /// Returns all log content. Waits for init + pending writes to complete.
  static Future<String> readAll() async {
    await _readyCompleter.future;
    await _writeQueue;

    try {
      final primary = await _readFile(_logFile);
      if (primary.trim().isNotEmpty) return primary;

      final mirror = await _readFile(_mirrorLogFile);
      if (mirror.trim().isNotEmpty) return mirror;

      return '';
    } catch (_) {
      return '';
    }
  }

  /// Returns the exportable log file. Waits for init + pending writes.
  static Future<File?> getLogFile() async {
    await _readyCompleter.future;
    await _writeQueue;

    if (_mirrorLogFile != null) {
      try {
        if (await _mirrorLogFile!.exists()) return _mirrorLogFile;
      } catch (_) {}
    }
    return _logFile;
  }

  /// Clears both primary and mirror log files.
  static Future<void> clear() async {
    await _readyCompleter.future;
    await _writeQueue;
    try {
      await _logFile?.writeAsString('', mode: FileMode.write, flush: true);
    } catch (_) {}
    try {
      await _mirrorLogFile
          ?.writeAsString('', mode: FileMode.write, flush: true);
    } catch (_) {}
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static String _buildLine(
    String message,
    String level, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buf = StringBuffer()
      ..write('[${DateTime.now().toIso8601String()}] [$level] ')
      ..write(message);
    if (error != null) buf.write(' | error=$error');
    if (stackTrace != null) buf.write('\n$stackTrace');
    return buf.toString();
  }

  static void _enqueue(String text) {
    final file = _logFile;
    if (file == null) return; // no file available — discard silently

    _writeQueue = _writeQueue.then((_) async {
      try {
        await file.writeAsString('$text\n',
            mode: FileMode.append, flush: true);
      } catch (_) {}
      if (_mirrorLogFile != null) {
        try {
          await _mirrorLogFile!.writeAsString('$text\n',
              mode: FileMode.append, flush: true);
        } catch (_) {}
      }
    });
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

  static Future<String> _readFile(File? file) async {
    if (file == null) return '';
    if (!await file.exists()) return '';
    return await file.readAsString();
  }
}
