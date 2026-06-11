class ServiceItem {
  final String id;
  final String name;
  final double price;
  final String materialId;
  final double materialQty;

  ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.materialId,
    required this.materialQty,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['id'].toString(),
      name: json['name'].toString(),
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      materialId: json['material_id'].toString(),
      materialQty: double.tryParse(json['material_qty'].toString()) ?? 0.0,
    );
  }
} 