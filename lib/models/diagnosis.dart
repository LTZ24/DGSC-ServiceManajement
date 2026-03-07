class DiagnosisCategory {
  final int id;
  final String name;
  final String? description;

  DiagnosisCategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory DiagnosisCategory.fromJson(Map<String, dynamic> json) {
    return DiagnosisCategory(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
    );
  }
}

class DiagnosisSymptom {
  final int id;
  final String code;
  final String name;
  final String? description;
  final int categoryId;

  DiagnosisSymptom({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.categoryId,
  });

  factory DiagnosisSymptom.fromJson(Map<String, dynamic> json) {
    return DiagnosisSymptom(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      categoryId: int.tryParse(json['category_id']?.toString() ?? '') ?? 0,
    );
  }
}

class DiagnosisDamage {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String? solution;
  final double? estimatedCost;
  final String? estimatedTime;
  final int categoryId;

  DiagnosisDamage({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.solution,
    this.estimatedCost,
    this.estimatedTime,
    required this.categoryId,
  });

  factory DiagnosisDamage.fromJson(Map<String, dynamic> json) {
    return DiagnosisDamage(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      solution: json['solution'],
      estimatedCost: json['estimated_cost'] != null
          ? double.tryParse(json['estimated_cost'].toString())
          : null,
      estimatedTime: json['estimated_time'],
      categoryId: int.tryParse(json['category_id']?.toString() ?? '') ?? 0,
    );
  }
}

class DiagnosisResult {
  final String damageCode;
  final String damageName;
  final String? description;
  final String? solution;
  final double cfValue;
  final double? estimatedCost;
  final String? estimatedTime;

  DiagnosisResult({
    required this.damageCode,
    required this.damageName,
    this.description,
    this.solution,
    required this.cfValue,
    this.estimatedCost,
    this.estimatedTime,
  });

  double get cfPercentage => cfValue * 100;

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) {
    return DiagnosisResult(
      damageCode: json['damage_code'] ?? json['code'] ?? '',
      damageName: json['damage_name'] ?? json['name'] ?? '',
      description: json['description'],
      solution: json['solution'],
      cfValue: double.tryParse(json['cf_value']?.toString() ?? '0') ?? 0,
      estimatedCost: json['estimated_cost'] != null
          ? double.tryParse(json['estimated_cost'].toString())
          : null,
      estimatedTime: json['estimated_time'],
    );
  }
}

class DiagnosisHistory {
  final int id;
  final int? categoryId;
  final String? deviceInfo;
  final String? symptoms;
  final String? results;
  final String? topDiagnosis;
  final double? cfPercentage;
  final DateTime? createdAt;

  DiagnosisHistory({
    required this.id,
    this.categoryId,
    this.deviceInfo,
    this.symptoms,
    this.results,
    this.topDiagnosis,
    this.cfPercentage,
    this.createdAt,
  });

  factory DiagnosisHistory.fromJson(Map<String, dynamic> json) {
    return DiagnosisHistory(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      categoryId: json['category_id'] != null
          ? int.tryParse(json['category_id'].toString())
          : null,
      deviceInfo: json['device_info'],
      symptoms: json['symptoms'],
      results: json['results'],
      topDiagnosis: json['top_diagnosis'],
      cfPercentage: json['cf_percentage'] != null
          ? double.tryParse(json['cf_percentage'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}
