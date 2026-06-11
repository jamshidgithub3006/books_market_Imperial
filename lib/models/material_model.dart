class MaterialItem {
  final String id;
  final String name;
  final String type;
  final double quantity;
  final double price; // 🔥 YANGI: Narx maydoni qo'shildi
  final String unit;

  MaterialItem({
    required this.id,
    required this.name,
    required this.type,
    required this.quantity,
    required this.price, // 🔥
    required this.unit,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Noma\'lum',
      type: json['type']?.toString() ?? 'boshqa',
      // Miqdorni xavfsiz o'qish
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      // 🔥 Narxni xavfsiz o'qish
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      unit: json['unit']?.toString() ?? 'dona',
    );
  }

  // Ma'lumotni JSON formatiga o'tkazish (kerak bo'lib qolsa)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'quantity': quantity,
      'price': price,
      'unit': unit,
    };
  }
}