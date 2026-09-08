class WalletTransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type; // deposit, withdrawal, prize_credit, entry_fee
  final String description;
  final String status;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    this.status = 'completed',
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'deposit',
      description: json['description'] as String? ?? 'Transaction',
      status: json['status'] as String? ?? 'completed',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
