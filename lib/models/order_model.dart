class OrderItem {
  final String id;
  final String teacherName;
  final String bookName;
  final int pageCount;
  final int quantity; // Nechta kitob (YANGI)
  final double totalPrice;
  final String materialType;
  final String status;
  final String deadline; // Qachonga tayyor bo'lishi kerak (YANGI)
  final String sellerName;

  OrderItem({
    required this.id,
    required this.teacherName,
    required this.bookName,
    required this.pageCount,
    required this.quantity,
    required this.totalPrice,
    required this.materialType,
    required this.status,
    required this.deadline,
    required this.sellerName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? 'Noma\'lum',
      bookName: json['book_name']?.toString() ?? '-',
      pageCount: int.tryParse(json['page_count']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      materialType: json['material_type']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'Kutilyapti',
      deadline: json['deadline']?.toString() ?? '-',
      sellerName: json['seller_name']?.toString() ?? '-',
    );
  }
}