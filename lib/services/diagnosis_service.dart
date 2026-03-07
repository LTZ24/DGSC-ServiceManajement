import '../config/api_config.dart';
import '../models/diagnosis.dart';
import 'api_service.dart';

class DiagnosisService {
  /// Get diagnosis device categories
  static Future<List<DiagnosisCategory>> getCategories() async {
    final response = await ApiService.get(
      ApiConfig.diagnosis,
      queryParams: {'action': 'categories'},
    );
    if (response.success) {
      final list = response.data['data'] ?? [];
      return (list as List)
          .map((e) => DiagnosisCategory.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Get symptoms for a category
  static Future<List<DiagnosisSymptom>> getSymptoms(int categoryId) async {
    final response = await ApiService.get(
      ApiConfig.diagnosis,
      queryParams: {
        'action': 'symptoms',
        'category_id': categoryId.toString(),
      },
    );
    if (response.success) {
      final list = response.data['data'] ?? [];
      return (list as List)
          .map((e) => DiagnosisSymptom.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Get possible damages for a category
  static Future<List<DiagnosisDamage>> getDamages(int categoryId) async {
    final response = await ApiService.get(
      ApiConfig.diagnosis,
      queryParams: {
        'action': 'damages',
        'category_id': categoryId.toString(),
      },
    );
    if (response.success) {
      final list = response.data['data'] ?? [];
      return (list as List)
          .map((e) => DiagnosisDamage.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Calculate diagnosis using Certainty Factor
  static Future<List<DiagnosisResult>> calculate({
    required int categoryId,
    required List<int> symptomIds,
  }) async {
    final response = await ApiService.post(
      '${ApiConfig.diagnosis}?action=calculate',
      body: {
        'category_id': categoryId,
        'symptoms': symptomIds,
      },
    );
    if (response.success) {
      final list = response.data['data'] ?? response.data['results'] ?? [];
      return (list as List)
          .map((e) => DiagnosisResult.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Save diagnosis result
  static Future<ApiResponse> saveDiagnosis(Map<String, dynamic> data) async {
    return await ApiService.post(
      '${ApiConfig.diagnosis}?action=save',
      body: data,
    );
  }

  /// Get diagnosis history
  static Future<List<DiagnosisHistory>> getHistory() async {
    final response = await ApiService.get(
      ApiConfig.diagnosis,
      queryParams: {'action': 'history'},
    );
    if (response.success) {
      final list = response.data['data'] ?? [];
      return (list as List)
          .map((e) => DiagnosisHistory.fromJson(e))
          .toList();
    }
    return [];
  }
}
