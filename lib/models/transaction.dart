class Transaction {
  final int id;
  final int? serviceId;
  final double amount;
  final String paymentStatus; // pending, paid, cancelled
  final String? paymentMethod;
  final DateTime? transactionDate;
  // Joined fields
  final String? serviceCode;
  final String? customerName;

  Transaction({
    required this.id,
    this.serviceId,
    required this.amount,
    this.paymentStatus = 'pending',
    this.paymentMethod,
    this.transactionDate,
    this.serviceCode,
    this.customerName,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      serviceId: json['service_id'] != null
          ? int.tryParse(json['service_id'].toString())
          : null,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      paymentStatus: json['payment_status'] ?? 'pending',
      paymentMethod: json['payment_method'],
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'])
          : null,
      serviceCode: json['service_code'],
      customerName: json['customer_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service_id': serviceId,
      'amount': amount,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
    };
  }

  String get statusLabel {
    switch (paymentStatus) {
      case 'pending':
        return 'Menunggu';
      case 'paid':
        return 'Lunas';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return paymentStatus;
    }
  }
}
