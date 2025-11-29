class Expense {
  final int? id;
  final double amount;
  final String? categoryId;
  final String? description;
  final DateTime date;
  final String type; // 'income' or 'expense'
  final String? paymentMethod;
  final String? receiptImagePath;

  Expense({
    this.id,
    required this.amount,
    this.categoryId,
    this.description,
    required this.date,
    required this.type,
    this.paymentMethod,
    this.receiptImagePath,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      amount: (json['amount'] is int)
          ? (json['amount'] as int).toDouble()
          : (json['amount'] as double? ?? 0.0),
      categoryId: json['category_id']?.toString(),
      description: json['description'],
      date: DateTime.parse(json['date']),
      type: json['type'] ?? 'expense',
      paymentMethod: json['payment_method'],
      receiptImagePath: json['receipt_image_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'category_id': categoryId,
      'description': description,
      'date': date.toIso8601String(),
      'type': type,
      'payment_method': paymentMethod,
      'receipt_image_path': receiptImagePath,
    };
  }
}
