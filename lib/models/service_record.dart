class ServiceRecord {
  final int id;
  final String? serviceCode;
  final int? originBookingId;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? deviceType;
  final String? deviceBrand;
  final String? model;
  final String? problem;
  final String? diagnosis;
  final String? solution;
  final String? sparePartsUsed;
  final double? cost;
  final String? technician;
  final String status; // pending, in_progress, completed, sudah_diambil
  final String? paymentStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ServiceRecord({
    required this.id,
    this.serviceCode,
    this.originBookingId,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.deviceType,
    this.deviceBrand,
    this.model,
    this.problem,
    this.diagnosis,
    this.solution,
    this.sparePartsUsed,
    this.cost,
    this.technician,
    this.status = 'pending',
    this.paymentStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory ServiceRecord.fromJson(Map<String, dynamic> json) {
    return ServiceRecord(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      serviceCode: json['service_code'],
      originBookingId: json['origin_booking_id'] != null
          ? int.tryParse(json['origin_booking_id'].toString())
          : null,
      customerId: json['customer_id'] != null
          ? int.tryParse(json['customer_id'].toString())
          : null,
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      deviceType: json['device_type'],
      deviceBrand: json['device_brand'],
      model: json['model'],
      problem: json['problem'],
      diagnosis: json['diagnosis'],
      solution: json['solution'],
      sparePartsUsed: json['spare_parts_used'],
      cost: json['cost'] != null
          ? double.tryParse(json['cost'].toString())
          : null,
      technician: json['technician'],
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'],
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
      'device_type': deviceType,
      'device_brand': deviceBrand,
      'model': model,
      'problem': problem,
      'diagnosis': diagnosis,
      'solution': solution,
      'spare_parts_used': sparePartsUsed,
      'cost': cost,
      'technician': technician,
      'status': status,
      if (originBookingId != null) 'origin_booking_id': originBookingId,
    };
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'in_progress':
        return 'Sedang Dikerjakan';
      case 'completed':
        return 'Selesai';
      case 'sudah_diambil':
        return 'Sudah Diambil';
      default:
        return status;
    }
  }
}
