import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';

final ordersProvider = FutureProvider<List<OrderItem>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final data = await apiService.getAll("buyurtmalar");
  return data.map((json) => OrderItem.fromJson(json)).toList();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final Color bgLight = const Color(0xFFF8FAFC);
  final Color primaryTeal = const Color(0xFF0D9488);
  final Color darkNavy = const Color(0xFF0F172A);
  final Color cardWhite = Colors.white;

  // =====================================
  // 🔥 CHIROYLI LOADING OYNASI (Anime Loading)
  // =====================================
  void _showLoadingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Ekran chetini bossa yopilmaydi
      builder: (context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Aylanuvchi animatsiya
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    color: primaryTeal,
                    strokeWidth: 4,
                    backgroundColor: primaryTeal.withOpacity(0.2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Serverga yuborilmoqda...",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    decoration: TextDecoration.none, // Dialog ichida chiziqsiz chiqishi uchun
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Iltimos, kutib turing ⏳",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================
  // 1. YANGI BUYURTMA OYNASI (Mobilga moslangan)
  // =====================================
  void _showAddOrderDialog() {
    final tNameCtrl = TextEditingController();
    final bNameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: "1");
    final priceCtrl = TextEditingController(text: "0");

    int targetWeekday = 1;
    double calculatedPrice = 0;
    String deadlineText = "";

    void recalculate(StateSetter updateState) {
      updateState(() {
        int qty = int.tryParse(qtyCtrl.text) ?? 1;
        double price = double.tryParse(priceCtrl.text) ?? 0.0;
        calculatedPrice = qty * price;

        int today = DateTime.now().weekday;
        int daysToAdd = targetWeekday - today;
        String prefix = "Shu hafta";

        if (daysToAdd <= 0) {
          daysToAdd += 7;
          prefix = "Keyingi hafta";
        }

        DateTime deadlineDate = DateTime.now().add(Duration(days: daysToAdd));
        deadlineText = "$prefix (${deadlineDate.day}-${_getMonth(deadlineDate.month)})";
      });
    }

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 20, right: 20, top: 24
                  ),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.auto_stories, color: primaryTeal, size: 24)),
                            const SizedBox(width: 12),
                            const Expanded(child: Text("Yangi Buyurtma", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

                        // Form Inputs
                        _buildInput("O'qituvchi / Mijoz ismi", tNameCtrl, Icons.person, (v) => recalculate(setState)),
                        const SizedBox(height: 12),
                        _buildInput("Kitob yoki Konspekt nomi", bNameCtrl, Icons.book, (v) => recalculate(setState)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildInput("Bitta narxi", priceCtrl, Icons.monetization_on, (v) => recalculate(setState), isNum: true)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildInput("Nechta?", qtyCtrl, Icons.control_point_duplicate, (v) => recalculate(setState), isNum: true)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Muddat (Dropdown)
                        const Text("Qaysi kunga tayyor bo'lishi kerak?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: targetWeekday,
                          isExpanded: true,
                          decoration: InputDecoration(
                              filled: true, fillColor: bgLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text("Dushanba")), DropdownMenuItem(value: 2, child: Text("Seshanba")),
                            DropdownMenuItem(value: 3, child: Text("Chorshanba")), DropdownMenuItem(value: 4, child: Text("Payshanba")),
                            DropdownMenuItem(value: 5, child: Text("Juma")), DropdownMenuItem(value: 6, child: Text("Shanba")),
                          ],
                          onChanged: (val) { targetWeekday = val!; recalculate(setState); },
                        ),
                        const SizedBox(height: 8),
                        if (deadlineText.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.event_available, color: deadlineText.contains("Keyingi") ? Colors.orange : primaryTeal, size: 16),
                              const SizedBox(width: 8),
                              Text(deadlineText, style: TextStyle(color: deadlineText.contains("Keyingi") ? Colors.orange.shade800 : primaryTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Umumiy hisob
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(color: primaryTeal, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("UMUMIY HISOB:", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                              Text("${calculatedPrice.toStringAsFixed(0)} UZS", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: darkNavy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            onPressed: () async {
                              if (tNameCtrl.text.isEmpty || calculatedPrice <= 0) return;

                              final nav = Navigator.of(context);
                              final scaffold = ScaffoldMessenger.of(context);
                              final api = ref.read(apiServiceProvider);

                              // 🔥 LOADING OYNASINI CHAQIRAMIZ
                              _showLoadingOverlay(context);

                              try {
                                final bookNameStr = bNameCtrl.text.isEmpty ? "Maxsus buyurtma" : bNameCtrl.text;

                                await api.addData('buyurtmalar', {
                                  'teacher_name': tNameCtrl.text.trim(),
                                  'book_name': bookNameStr,
                                  'page_count': 0,
                                  'total_price': calculatedPrice,
                                  'material_type': 'Standart',
                                  'status': 'Jarayonda',
                                  'seller_name': 'Asosiy Sotuvchi',
                                  'created_at': DateTime.now().toIso8601String(),
                                });

                                nav.pop(); // 1. Loadingni yopish
                                nav.pop(); // 2. BottomSheetni yopish
                                ref.refresh(ordersProvider);
                                scaffold.showSnackBar(const SnackBar(content: Text("✅ Buyurtma qabul qilindi!"), backgroundColor: Colors.green));

                              } catch (e) {
                                nav.pop(); // Xato bo'lsa ham Loadingni yopish
                                scaffold.showSnackBar(SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red));
                              }
                            },
                            child: const Text('Buyurtmani Saqlash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, Function(String) onChanged, {bool isNum = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryTeal.withOpacity(0.6)),
        filled: true, fillColor: bgLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  String _getMonth(int m) {
    const months = ["Yan", "Fev", "Mar", "Apr", "May", "Iyun", "Iyul", "Avg", "Sen", "Okt", "Noy", "Dek"];
    return months[m - 1];
  }

  // =====================================
  // 2. STATUSNI O'ZGARTIRISH VA TO'LOV DIALOGI
  // =====================================
  void _changeStatus(OrderItem item) async {
    final api = ref.read(apiServiceProvider);
    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    // ==========================================
    // JARAYONDA -> TAYYOR
    // ==========================================
    if (item.status == 'Jarayonda') {
      _showLoadingOverlay(context); // 🔥 LOADING
      try {
        await api.updateData('buyurtmalar', {'id': item.id, 'status': 'Tayyor'});
        ref.refresh(ordersProvider);
      } finally {
        nav.pop(); // Loadingni yopish
      }
    }
    // ==========================================
    // TAYYOR -> BERILDI (Qarz yoki To'lov)
    // ==========================================
    else if (item.status == 'Tayyor') {
      showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.handshake, color: Colors.orange, size: 24),
                  SizedBox(width: 10),
                  Text("Topshirish", style: TextStyle(fontSize: 18)),
                ],
              ),
              content: Text("${item.teacherName} ga kitoblarni topshiryapsiz.\nSumma: ${item.totalPrice} so'm.\n\nTo'lov holatini belgilang:"),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                // QARZGA YOZISH TUGMASI
                TextButton(
                  onPressed: () async {
                    final dialogNav = Navigator.of(ctx);
                    _showLoadingOverlay(ctx); // 🔥 LOADING
                    try {
                      await api.updateData('buyurtmalar', {'id': item.id, 'status': 'Berildi'});
                      await api.addData('qarzdorlar', {
                        'client_name': item.teacherName,
                        'service_name': "Buyurtma: ${item.bookName} (${item.quantity} ta)",
                        'qarz_price': item.totalPrice,
                        'tolanga_summa': 0,
                        'status': 'active',
                        'created_at': DateTime.now().toIso8601String(),
                      });

                      dialogNav.pop(); // Loadingni yopish
                      dialogNav.pop(); // Dialogni yopish
                      ref.refresh(ordersProvider);
                      scaffold.showSnackBar(const SnackBar(content: Text("Qarzdorlarga yozildi!"), backgroundColor: Colors.orange));
                    } catch (e) {
                      dialogNav.pop(); // Xato bo'lsa Loadingni yopish
                      scaffold.showSnackBar(SnackBar(content: Text("Xatolik: $e")));
                    }
                  },
                  child: const Text("Qarzga yozish", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                ),

                // TO'LOV QILDI TUGMASI
                ElevatedButton(
                  onPressed: () async {
                    final dialogNav = Navigator.of(ctx);
                    _showLoadingOverlay(ctx); // 🔥 LOADING
                    try {
                      await api.updateData('buyurtmalar', {'id': item.id, 'status': 'Berildi'});

                      dialogNav.pop(); // Loadingni yopish
                      dialogNav.pop(); // Dialogni yopish
                      ref.refresh(ordersProvider);
                      scaffold.showSnackBar(const SnackBar(content: Text("To'lov qabul qilindi!"), backgroundColor: Colors.green));
                    } catch (e) {
                      dialogNav.pop(); // Xato bo'lsa Loadingni yopish
                      scaffold.showSnackBar(SnackBar(content: Text("Xatolik: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  child: const Text("To'lov qildi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            );
          }
      );
    }
    // ==========================================
    // BERILDI -> ORQAGA QAYTARISH
    // ==========================================
    else if (item.status == 'Berildi') {
      _showLoadingOverlay(context); // 🔥 LOADING
      try {
        await api.updateData('buyurtmalar', {'id': item.id, 'status': 'Jarayonda'});
        ref.refresh(ordersProvider);
      } finally {
        nav.pop(); // Loadingni yopish
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(ordersProvider);
    final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text('MAXSUS BUYURTMA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: primaryTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.refresh(ordersProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOrderDialog,
        backgroundColor: darkNavy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Qidiruv paneli (Mobilga moslangan)
          Container(
            color: primaryTeal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: "Mijoz yoki kitob qidirish...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true, fillColor: cardWhite,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Ro'yxat
          Expanded(
            child: data.when(
              loading: () => Center(child: CircularProgressIndicator(color: primaryTeal)),
              error: (err, stack) => Center(child: Text('Xatolik: $err', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
              data: (allItems) {
                final items = allItems.where((i) => i.teacherName.toLowerCase().contains(searchQuery) || i.bookName.toLowerCase().contains(searchQuery)).toList();
                if (items.isEmpty) return const Center(child: Text("Hozircha buyurtmalar yo'q.", style: TextStyle(fontSize: 16, color: Colors.grey)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isReady = item.status == 'Tayyor';
                    final isGiven = item.status == 'Berildi';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isGiven ? Colors.grey.shade100 : cardWhite,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
                        border: Border.all(color: isReady ? Colors.green : (isGiven ? Colors.transparent : Colors.grey.shade200)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ikonka
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(color: primaryTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.menu_book, color: primaryTeal, size: 20),
                          ),
                          const SizedBox(width: 12),

                          // Asosiy ma'lumot (Markaziy qism)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.teacherName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isGiven ? Colors.grey : darkNavy), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text("${item.bookName} (${item.quantity} ta)", style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(item.deadline, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Summa va Holat (O'ng tomon)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("${item.totalPrice}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isGiven ? Colors.grey : darkNavy)),
                              Text("UZS", style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () => _changeStatus(item),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: isGiven ? Colors.grey.shade300 : (isReady ? Colors.green : Colors.orange.shade100),
                                      borderRadius: BorderRadius.circular(8)
                                  ),
                                  child: Text(
                                      item.status,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isGiven ? Colors.grey.shade600 : (isReady ? Colors.white : Colors.orange.shade800))
                                  ),
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}