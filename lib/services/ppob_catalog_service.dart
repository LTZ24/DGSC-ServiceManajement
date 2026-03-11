import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PpobCatalogService {
  static const String appsAssetPath = 'assets/data/ppob_apps.json';
  static const String categoriesAssetPath = 'assets/data/ppob_categories.json';
  static const String appsBackupFileName = 'ppob_apps_backup.json';
  static const String categoriesBackupFileName = 'ppob_categories_backup.json';

  static Future<List<Map<String, dynamic>>> loadDefaultApps() async {
    final raw = await rootBundle.loadString(appsAssetPath);
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> loadDefaultCategories() async {
    final raw = await rootBundle.loadString(categoriesAssetPath);
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> ensureLocalBackups() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(directory.path, 'ppob_backup'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    await Future.wait([
      _writeBackupFile(
        backupDir,
        appsBackupFileName,
        await rootBundle.loadString(appsAssetPath),
      ),
      _writeBackupFile(
        backupDir,
        categoriesBackupFileName,
        await rootBundle.loadString(categoriesAssetPath),
      ),
    ]);
  }

  static Future<void> saveCatalogBackups({
    required List<Map<String, dynamic>> apps,
    required List<Map<String, dynamic>> categories,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(directory.path, 'ppob_backup'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final encoder = const JsonEncoder.withIndent('  ');
    await Future.wait([
      _writeBackupFile(
        backupDir,
        appsBackupFileName,
        encoder.convert(apps),
      ),
      _writeBackupFile(
        backupDir,
        categoriesBackupFileName,
        encoder.convert(categories),
      ),
    ]);
  }

  static Future<String> getBackupDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'ppob_backup');
  }

  static Future<void> _writeBackupFile(
    Directory directory,
    String fileName,
    String content,
  ) async {
    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(content, flush: true);
  }
}
