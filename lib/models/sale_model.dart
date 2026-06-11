// lib/models/sale_model.dart
class SaleItem {
  final String id;
  final String productName;
  final int count;
  final double totalPrice;
  final String paymentType; // naqd, plastic, qarz, aralash
  final String clientName;
  final String comment;
  final DateTime createdAt;
  final String sellerName;

  SaleItem({
    required this.id,
    required this.productName,
    required this.count,
    required this.totalPrice,
    required this.paymentType,
    required this.clientName,
    required this.comment,
    required this.createdAt,
    required this.sellerName,
  });

  // JSON dan Obyektga o'girish (Google Sheet dan kelganda)
  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Noma\'lum mahsulot',
      count: int.tryParse(json['count']?.toString() ?? '1') ?? 1,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      paymentType: json['payment_type']?.toString() ?? 'naqd',
      clientName: json['client_name']?.toString() ?? '-',
      comment: json['comment']?.toString() ?? '-',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      sellerName: json['seller_name']?.toString() ?? '-',
    );
  }
}