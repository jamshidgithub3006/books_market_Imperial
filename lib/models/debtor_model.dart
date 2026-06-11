class DebtorItem {
  final String id;
  final String clientName;
  final String serviceName;
  final double qarzPrice;
  final double tolangaSumma;
  final String status;
  final String sellerName;
  final String createdAt;

  DebtorItem({
    required this.id,
    required this.clientName,
    required this.serviceName,
    required this.qarzPrice,
    required this.tolangaSumma,
    required this.status,
    required this.sellerName,
    required this.createdAt,
  });

  factory DebtorItem.fromJson(Map<String, dynamic> json) {
    return DebtorItem(
      id: json['id']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? 'Noma\'lum mijoz',
      serviceName: json['service_name']?.toString() ?? '-',
      qarzPrice: double.tryParse(json['qarz_price']?.toString() ?? '0') ?? 0.0,
      tolangaSumma: double.tryParse(json['tolanga_summa']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'active',
      sellerName: json['seller_name']?.toString() ?? '-',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  // UI da ishlatish uchun qulay qoldiq hisoblagich
  double get qoldiqQarz => qarzPrice - tolangaSumma;
}