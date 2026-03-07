class Booking {
  final int id;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? deviceType;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String? issueDescription;
  final String? preferredDate;
  final String status; // pending, processed, cancelled, selesai
  final String? notes;
  // Diagnosis fields
  final String? diagnosisCategory;
  final String? diagnosisSymptoms;
  final String? diagnosisResult;
  final double? diagnosisCfPercentage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Booking({
    required this.id,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.deviceType,
    this.brand,
    this.model,
    this.serialNumber,
    this.issueDescription,
    this.preferredDate,
    this.status = 'pending',
    this.notes,
    this.diagnosisCategory,
    this.diagnosisSymptoms,
    this.diagnosisResult,
    this.diagnosisCfPercentage,
    this.createdAt,
    this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      customerId: json['customer_id'] != null
          ? int.tryParse(json['customer_id'].toString())
          : null,
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      deviceType: json['device_type'],
      brand: json['brand'],
      model: json['model'],
      serialNumber: json['serial_number'],
      issueDescription: json['issue_description'],
      preferredDate: json['preferred_date'],
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      diagnosisCategory: json['diagnosis_category'],
      diagnosisSymptoms: json['diagnosis_symptoms'],
      diagnosisResult: json['diagnosis_result'],
      diagnosisCfPercentage: json['diagnosis_cf_percentage'] != null
          ? double.tryParse(json['diagnosis_cf_percentage'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'device_type': deviceType,
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'issue_description': issueDescription,
      'preferred_date': preferredDate,
      'status': status,
      'notes': notes,
      if (diagnosisCategory != null) 'diagnosis_category': diagnosisCategory,
      if (diagnosisSymptoms != null) 'diagnosis_symptoms': diagnosisSymptoms,
      if (diagnosisResult != null) 'diagnosis_result': diagnosisResult,
      if (diagnosisCfPercentage != null)
        'diagnosis_cf_percentage': diagnosisCfPercentage,
    };
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'processed':
        return 'Diproses';
      case 'cancelled':
        return 'Dibatalkan';
      case 'selesai':
        return 'Selesai';
      default:
        return status;
    }
  }

  bool get hasDiagnosis =>
      diagnosisResult != null && diagnosisResult!.isNotEmpty;
}
