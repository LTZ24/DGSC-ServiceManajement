class CounterTransaction {
  final int id;
  final String? transactionDate;
  final int? categoryId;
  final String? categoryName;
  final String? productName;
  final String? customerInfo;
  final double modalPrice;
  final double sellingPrice;
  final double profit;
  final String? paymentMethod;
  final String? receiptImage;
  final String? notes;
  final DateTime? createdAt;

  CounterTransaction({
    required this.id,
    this.transactionDate,
    this.categoryId,
    this.categoryName,
    this.productName,
    this.customerInfo,
    this.modalPrice = 0,
    this.sellingPrice = 0,
    this.profit = 0,
    this.paymentMethod,
    this.receiptImage,
    this.notes,
    this.createdAt,
  });

  factory CounterTransaction.fromJson(Map<String, dynamic> json) {
    return CounterTransaction(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      transactionDate: json['transaction_date'],
      categoryId: json['category_id'] != null
          ? int.tryParse(json['category_id'].toString())
          : null,
      categoryName: json['category_name'],
      productName: json['product_name'],
      customerInfo: json['customer_info'],
      modalPrice:
          double.tryParse(json['modal_price']?.toString() ?? '0') ?? 0,
      sellingPrice:
          double.tryParse(json['selling_price']?.toString() ?? '0') ?? 0,
      profit: double.tryParse(json['profit']?.toString() ?? '0') ?? 0,
      paymentMethod: json['payment_method'],
      receiptImage: json['receipt_image'],
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_date': transactionDate,
      'category_id': categoryId,
      'product_name': productName,
      'customer_info': customerInfo,
      'modal_price': modalPrice,
      'selling_price': sellingPrice,
      'payment_method': paymentMethod,
      'notes': notes,
    };
  }
}

class CounterCategory {
  final int id;
  final String name;
  final String? icon;
  final String? color;
  final bool isActive;
  final int sortOrder;

  CounterCategory({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory CounterCategory.fromJson(Map<String, dynamic> json) {
    return CounterCategory(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'],
      color: json['color'],
      isActive: json['is_active'] == 1 ||
          json['is_active'] == '1' ||
          json['is_active'] == true,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
    );
  }
}

class CounterExpense {
  final int id;
  final String? expenseDate;
  final String description;
  final double amount;
  final String? category;
  final String? receiptImage;
  final DateTime? createdAt;

  CounterExpense({
    required this.id,
    this.expenseDate,
    required this.description,
    required this.amount,
    this.category,
    this.receiptImage,
    this.createdAt,
  });

  factory CounterExpense.fromJson(Map<String, dynamic> json) {
    return CounterExpense(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      expenseDate: json['expense_date'],
      description: json['description'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      category: json['category'],
      receiptImage: json['receipt_image'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_date': expenseDate,
      'description': description,
      'amount': amount,
      'category': category,
    };
  }
}

class CounterSummary {
  final double totalIncome;
  final double totalModal;
  final double totalProfit;
  final double totalExpenses;
  final double netProfit;
  final int totalTransactions;

  CounterSummary({
    this.totalIncome = 0,
    this.totalModal = 0,
    this.totalProfit = 0,
    this.totalExpenses = 0,
    this.netProfit = 0,
    this.totalTransactions = 0,
  });

  factory CounterSummary.fromJson(Map<String, dynamic> json) {
    return CounterSummary(
      totalIncome:
          double.tryParse(json['total_income']?.toString() ?? '0') ?? 0,
      totalModal:
          double.tryParse(json['total_modal']?.toString() ?? '0') ?? 0,
      totalProfit:
          double.tryParse(json['total_profit']?.toString() ?? '0') ?? 0,
      totalExpenses:
          double.tryParse(json['total_expenses']?.toString() ?? '0') ?? 0,
      netProfit:
          double.tryParse(json['net_profit']?.toString() ?? '0') ?? 0,
      totalTransactions:
          int.tryParse(json['total_transactions']?.toString() ?? '0') ?? 0,
    );
  }
}
