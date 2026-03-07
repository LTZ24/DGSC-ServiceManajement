class SparePart {
  final int id;
  final String partName;
  final String? category;
  final int stockQuantity;
  final double unitPrice;
  final String? supplier;
  final int minimumStock;
  final DateTime? createdAt;

  SparePart({
    required this.id,
    required this.partName,
    this.category,
    required this.stockQuantity,
    required this.unitPrice,
    this.supplier,
    this.minimumStock = 5,
    this.createdAt,
  });

  bool get isLowStock => stockQuantity <= minimumStock;

  factory SparePart.fromJson(Map<String, dynamic> json) {
    return SparePart(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      partName: json['part_name'] ?? '',
      category: json['category'],
      stockQuantity:
          int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0,
      unitPrice:
          double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      supplier: json['supplier'],
      minimumStock:
          int.tryParse(json['minimum_stock']?.toString() ?? '5') ?? 5,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'part_name': partName,
      'category': category,
      'stock_quantity': stockQuantity,
      'unit_price': unitPrice,
      'supplier': supplier,
      'minimum_stock': minimumStock,
    };
  }
}
