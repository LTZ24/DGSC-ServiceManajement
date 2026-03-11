import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backend_service.dart';
import 'cf_engine.dart';

class DiagnosisConfigService {
  static const String _cacheFolder = 'diagnosis';
  static const String _cacheFileName = 'diagnosis_dataset.json';
  static const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

  static Future<void> loadLocalDatasetIntoEngine() async {
    final payload = await _readLocalPayload();
    if (payload == null) {
      CfEngine.resetToDefaults();
      return;
    }

    try {
      final normalized = _normalizeDatasetMap(payload);
      CfEngine.loadDatasetMap(
        normalized,
        version: _asInt(normalized['dataset_version'], fallback: 1),
        publishedAtIso: normalized['published_at']?.toString(),
      );
    } catch (_) {
      CfEngine.resetToDefaults();
    }
  }

  static Future<bool> syncPublishedDataset({bool force = false}) async {
    try {
      final config = await BackendService.getDiagnosisConfig();
      if (config == null) {
        await loadLocalDatasetIntoEngine();
        return false;
      }

      final remoteVersion = _asInt(config['published_version']);
      final publishedPath = config['published_file_path']?.toString() ?? '';
      final localPayload = await _readLocalPayload();
      final localVersion = localPayload == null
          ? 0
          : _asInt(localPayload['dataset_version'], fallback: 0);

      if (!force && localPayload != null && remoteVersion <= localVersion) {
        final normalized = _normalizeDatasetMap(localPayload);
        CfEngine.loadDatasetMap(
          normalized,
          version: localVersion,
          publishedAtIso: normalized['published_at']?.toString(),
        );
        return false;
      }

      if (publishedPath.isNotEmpty) {
        final remoteJson = await BackendService.downloadDiagnosisFile(publishedPath);
        if (remoteJson != null && remoteJson.isNotEmpty) {
          final normalized = _normalizeDatasetMap(
            jsonDecode(remoteJson) as Map<String, dynamic>,
          );
          normalized['dataset_version'] = remoteVersion > 0
              ? remoteVersion
              : _asInt(normalized['dataset_version'], fallback: 1);
          normalized['published_at'] =
              _timestampToIso(config['published_at']) ?? normalized['published_at'];
          await _writeLocalPayload(normalized);
          CfEngine.loadDatasetMap(
            normalized,
            version: _asInt(normalized['dataset_version'], fallback: 1),
            publishedAtIso: normalized['published_at']?.toString(),
          );
          return true;
        }
      }
    } catch (_) {
      // Fall back to local/default data.
    }

    await loadLocalDatasetIntoEngine();
    return false;
  }

  static Future<Map<String, dynamic>> loadEditorDocument() async {
    final config = await BackendService.getDiagnosisConfig();
    Map<String, dynamic> payload;

    if (config?['draft_data'] is Map<String, dynamic>) {
      payload = _normalizeDatasetMap(config!['draft_data'] as Map<String, dynamic>);
    } else if (config?['draft_data'] is Map) {
      payload = _normalizeDatasetMap(
        Map<String, dynamic>.from(config!['draft_data'] as Map),
      );
    } else {
      final localPayload = await _readLocalPayload();
      if (localPayload != null) {
        payload = _normalizeDatasetMap(localPayload);
      } else {
        payload = CfEngine.exportDefaultDatasetMap();
      }
    }

    return {
      'config': config,
      'payload': payload,
      'jsonText': _prettyEncoder.convert(payload),
      'summary': summarizePayload(payload),
    };
  }

  static Future<String> loadPublishedJsonText() async {
    final config = await BackendService.getDiagnosisConfig();
    final publishedPath = config?['published_file_path']?.toString() ?? '';
    if (publishedPath.isNotEmpty) {
      final remoteJson = await BackendService.downloadDiagnosisFile(publishedPath);
      if (remoteJson != null && remoteJson.isNotEmpty) {
        final normalized = _normalizeDatasetMap(
          jsonDecode(remoteJson) as Map<String, dynamic>,
        );
        normalized['dataset_version'] = _asInt(
          config?['published_version'],
          fallback: _asInt(normalized['dataset_version'], fallback: 1),
        );
        normalized['published_at'] =
            _timestampToIso(config?['published_at']) ?? normalized['published_at'];
        return _prettyEncoder.convert(normalized);
      }
    }

    final localPayload = await _readLocalPayload();
    if (localPayload != null) {
      return _prettyEncoder.convert(_normalizeDatasetMap(localPayload));
    }

    return _prettyEncoder.convert(CfEngine.exportDefaultDatasetMap());
  }

  static Map<String, int> summarizeJson(String jsonText) {
    final normalized = _normalizeDatasetMap(
      jsonDecode(jsonText) as Map<String, dynamic>,
    );
    return summarizePayload(normalized);
  }

  static Map<String, int> summarizePayload(Map<String, dynamic> payload) {
    return {
      'categories': (payload['categories'] as List?)?.length ?? 0,
      'symptoms': (payload['symptoms'] as List?)?.length ?? 0,
      'damages': (payload['damages'] as List?)?.length ?? 0,
      'rules': (payload['rules'] as List?)?.length ?? 0,
    };
  }

  static Future<Map<String, int>> saveDraft({
    required String jsonText,
    required String password,
  }) async {
    await BackendService.verifyCurrentPassword(password);
    final normalized = _normalizeDatasetMap(
      jsonDecode(jsonText) as Map<String, dynamic>,
    );
    final config = await BackendService.getDiagnosisConfig();
    final publishedVersion = _asInt(config?['published_version'], fallback: 1);
    final draftVersion = max(
      _asInt(config?['draft_version'], fallback: publishedVersion + 1),
      publishedVersion + 1,
    );
    final nowIso = DateTime.now().toUtc().toIso8601String();

    normalized['dataset_version'] = draftVersion;
    normalized['updated_at'] = nowIso;

    final jsonContent = _prettyEncoder.convert(normalized);
    await BackendService.uploadDiagnosisFile(
      path: 'drafts/current.json',
      content: jsonContent,
    );
    await BackendService.upsertDiagnosisConfig({
      'draft_data': jsonDecode(jsonContent),
      'draft_file_path': 'drafts/current.json',
      'draft_version': draftVersion,
      'draft_updated_at': nowIso,
      'draft_updated_by': BackendService.currentUser?.uid,
    });

    return summarizePayload(normalized);
  }

  static Future<Map<String, dynamic>> publishDataset({
    required String jsonText,
    required String password,
  }) async {
    await BackendService.verifyCurrentPassword(password);
    final normalized = _normalizeDatasetMap(
      jsonDecode(jsonText) as Map<String, dynamic>,
    );
    final config = await BackendService.getDiagnosisConfig();
    final nextVersion = max(
      _asInt(config?['published_version'], fallback: 0) + 1,
      _asInt(normalized['dataset_version'], fallback: 1),
    );
    final publishedAt = DateTime.now().toUtc().toIso8601String();

    normalized['dataset_version'] = nextVersion;
    normalized['published_at'] = publishedAt;

    final jsonContent = _prettyEncoder.convert(normalized);
    await BackendService.uploadDiagnosisFile(
      path: 'drafts/current.json',
      content: jsonContent,
    );
    await BackendService.uploadDiagnosisFile(
      path: 'published/latest.json',
      content: jsonContent,
    );
    await BackendService.upsertDiagnosisConfig({
      'draft_data': jsonDecode(jsonContent),
      'draft_file_path': 'drafts/current.json',
      'draft_version': nextVersion,
      'draft_updated_at': publishedAt,
      'draft_updated_by': BackendService.currentUser?.uid,
      'published_file_path': 'published/latest.json',
      'published_version': nextVersion,
      'published_at': publishedAt,
      'published_by': BackendService.currentUser?.uid,
    });

    await _writeLocalPayload(normalized);
    CfEngine.loadDatasetMap(
      normalized,
      version: nextVersion,
      publishedAtIso: publishedAt,
    );

    return {
      'version': nextVersion,
      'publishedAt': publishedAt,
      'summary': summarizePayload(normalized),
    };
  }

  static Future<void> clearLocalCache() async {
    final file = await _getCacheFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<Map<String, dynamic>?> _readLocalPayload() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(content) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeLocalPayload(Map<String, dynamic> payload) async {
    final file = await _getCacheFile();
    await file.writeAsString(_prettyEncoder.convert(payload), flush: true);
  }

  static Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final diagnosisDir = Directory(p.join(dir.path, _cacheFolder));
    if (!await diagnosisDir.exists()) {
      await diagnosisDir.create(recursive: true);
    }
    return File(p.join(diagnosisDir.path, _cacheFileName));
  }

  static Map<String, dynamic> _normalizeDatasetMap(Map<String, dynamic> raw) {
    final categories = ((raw['categories'] as List?) ?? const [])
        .map((item) => CfCategory.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final symptoms = ((raw['symptoms'] as List?) ?? const [])
        .map((item) => CfSymptom.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final damages = ((raw['damages'] as List?) ?? const [])
        .map((item) => CfDamage.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final rules = ((raw['rules'] as List?) ?? const [])
        .map((item) => CfRule.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    if (categories.isEmpty) {
      throw const FormatException('Minimal harus ada 1 kategori diagnosis.');
    }
    if (symptoms.isEmpty) {
      throw const FormatException('Minimal harus ada 1 gejala diagnosis.');
    }
    if (damages.isEmpty) {
      throw const FormatException('Minimal harus ada 1 kerusakan diagnosis.');
    }
    if (rules.isEmpty) {
      throw const FormatException('Minimal harus ada 1 rule Certainty Factor.');
    }

    return {
      'schema_version': _asInt(raw['schema_version'], fallback: 1),
      'dataset_version': _asInt(raw['dataset_version'], fallback: 1),
      'published_at': _timestampToIso(raw['published_at']),
      'updated_at': _timestampToIso(raw['updated_at']),
      'categories': categories.map((item) => item.toMap()).toList(),
      'symptoms': symptoms.map((item) => item.toMap()).toList(),
      'damages': damages.map((item) => item.toMap()).toList(),
      'rules': rules.map((item) => item.toMap()).toList(),
    };
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _timestampToIso(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is String) return value;
    if (value is Map && value['value'] != null) {
      return value['value']?.toString();
    }
    if (value.runtimeType.toString() == 'Timestamp') {
      try {
        final date = (value as dynamic).toDate() as DateTime;
        return date.toUtc().toIso8601String();
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }
}
