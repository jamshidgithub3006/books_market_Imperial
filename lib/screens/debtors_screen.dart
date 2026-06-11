import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/api_service.dart';
import '../models/debtor_model.dart';

// Ma'lumotlarni tortib keluvchi Provayder
final debtorsProvider = FutureProvider<List<DebtorItem>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final data = await apiService.getAll("qarzdorlar");
  return data.map((json) => DebtorItem.fromJson(json)).toList();
});

// Qidiruv so'zini saqlab turuvchi Provayder
final searchQueryProvider = StateProvider<String>((ref) => '');

class DebtorsScreen extends ConsumerStatefulWidget {
  const DebtorsScreen({super.key});

  @override
  ConsumerState<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends ConsumerState<DebtorsScreen> {
  final Color bgLight = const Color(0xFFF3F4F6); // Windows uchun toza kulrang
  final Color primaryNavy = const Color(0xFF0F172A);
  final Color primaryBlue = const Color(0xFF2563EB); // Windows ko'k rangi
  final Color cardWhite = Colors.white;

  // =====================================
  // 🔥 CHIROYLI LOADING OYNASI (Anime Loading)
  // =====================================
  void _showLoadingOverlay(BuildContext context, {String message = "Kuting..."}) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    color: primaryBlue,
                    strokeWidth: 4,
                    backgroundColor: primaryBlue.withOpacity(0.2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    decoration: TextDecoration.none,
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

  // ==========================================
  // O'NG TOMON PANEL DILOGLARI (Windows UI)
  // ==========================================

  // 1. QARZ QO'SHISH/TAHRIRLASH DIALOGI
  void _showAddOrEditDialog(BuildContext context, WidgetRef ref, {DebtorItem? item}) {
    final clientCtrl = TextEditingController(text: item?.clientName ?? "");
    final serviceCtrl = TextEditingController(text: item?.serviceName ?? "");
    final amountCtrl = TextEditingController(text: item?.qarzPrice.toStringAsFixed(0) ?? "");
    final isEdit = item != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: cardWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 450, // Windows ekrani uchun kenglik
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isEdit ? "Qarzni Tahrirlash" : "Yangi Qarzdor", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const Divider(height: 32),

                    _buildInput("Mijoz Ismi", clientCtrl, Icons.person),
                    const SizedBox(height: 16),
                    _buildInput("Nima oldi / Xizmat turi", serviceCtrl, Icons.shopping_bag),
                    const SizedBox(height: 16),
                    _buildInput(isEdit ? "Umumiy Qarz (O'zgartirish)" : "Qarz Summasi (UZS)", amountCtrl, Icons.payments, isNum: true),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Bekor qilish', style: TextStyle(color: Colors.grey, fontSize: 16))),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                              if (clientCtrl.text.isEmpty || amount <= 0) return;

                              final nav = Navigator.of(context);
                              final scaffold = ScaffoldMessenger.of(context);

                              // 🔥 LOADING OYNASINI CHAQIRAMIZ
                              _showLoadingOverlay(context, message: "Serverga yozilmoqda...");

                              try {
                                final api = ref.read(apiServiceProvider);

                                if (isEdit) {
                                  String yangiStatus = item!.tolangaSumma >= amount ? 'paid' : 'active';
                                  await api.updateData('qarzdorlar', {
                                    'id': item.id,
                                    'client_name': clientCtrl.text.trim(),
                                    'service_name': serviceCtrl.text.trim(),
                                    'qarz_price': amount,
                                    'status': yangiStatus,
                                  });
                                } else {
                                  await api.addData('qarzdorlar', {
                                    'client_name': clientCtrl.text.trim(),
                                    'service_name': serviceCtrl.text.trim(),
                                    'qarz_price': amount,
                                    'tolanga_summa': 0,
                                    'status': 'active',
                                    'created_at': DateTime.now().toIso8601String(),
                                  });
                                }

                                nav.pop(); // 1. Loadingni yopamiz
                                nav.pop(); // 2. Dialogni yopamiz
                                ref.refresh(debtorsProvider);

                              } catch (e) {
                                nav.pop(); // Xato bo'lsa Loadingni yopamiz
                                scaffold.showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
                              }
                            },
                            child: const Text('SAQLASH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. TO'LOV QILISH DIALOGI
  void _showPaymentDialog(BuildContext context, WidgetRef ref, DebtorItem item) {
    final amountController = TextEditingController();
    String selectedPaymentType = 'naqd';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: cardWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 480, // Windows ekrani uchun aniq eni
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("To'lov Qabul Qilish", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            Text(item.clientName, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.payments, color: Colors.green, size: 28),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    // Qoldiq summasi bloki
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("QOLDIQ QARZ:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 16)),
                          Text("${item.qoldiqQarz.toStringAsFixed(0)} UZS", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: "To'lanayotgan summa (UZS)",
                        prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.green),
                        filled: true,
                        fillColor: cardWhite,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => setState(() => amountController.text = item.qoldiqQarz.toStringAsFixed(0)),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text("To'liq qoplash", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text("To'lov Turi:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Naqd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            value: 'naqd',
                            groupValue: selectedPaymentType,
                            activeColor: Colors.green,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => selectedPaymentType = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Plastik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            value: 'plastic',
                            groupValue: selectedPaymentType,
                            activeColor: primaryBlue,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => selectedPaymentType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Bekor qilish', style: TextStyle(color: Colors.grey, fontSize: 16))),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0
                            ),
                            onPressed: () async {
                              final payAmount = double.tryParse(amountController.text.trim()) ?? 0;
                              if (payAmount <= 0) return;
                              if (payAmount > item.qoldiqQarz) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Qoldiqdan ortiqcha pul kiritdingiz!")));
                                return;
                              }

                              final nav = Navigator.of(context);
                              final scaffold = ScaffoldMessenger.of(context);

                              // 🔥 LOADING OYNASINI CHAQIRAMIZ
                              _showLoadingOverlay(context, message: "To'lov qabul qilinmoqda...");

                              try {
                                final api = ref.read(apiServiceProvider);

                                final yangiTolanganSumma = item.tolangaSumma + payAmount;
                                final yangiStatus = (yangiTolanganSumma >= item.qarzPrice) ? 'paid' : 'active';

                                await api.updateData('qarzdorlar', {
                                  'id': item.id,
                                  'tolanga_summa': yangiTolanganSumma,
                                  'status': yangiStatus,
                                });

                                // Tushumga yozish
                                await api.addData('savdo_tarixlari', {
                                  'product_name': "Qarz to'lovi: ${item.clientName}",
                                  'count': 1,
                                  'total_price': payAmount,
                                  'payment_type': selectedPaymentType,
                                  'client_name': item.clientName,
                                  'created_at': DateTime.now().toIso8601String(),
                                });

                                nav.pop(); // 1. Loadingni yopamiz
                                nav.pop(); // 2. Dialogni yopamiz
                                ref.refresh(debtorsProvider);
                                scaffold.showSnackBar(const SnackBar(content: Text("✅ To'lov qabul qilindi!"), backgroundColor: Colors.green));

                              } catch (e) {
                                nav.pop(); // Xato bo'lsa Loadingni yopamiz
                                scaffold.showSnackBar(SnackBar(content: Text("❌ Xato: $e"), backgroundColor: Colors.red));
                              }
                            },
                            child: const Text('QABUL QILISH', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =====================================
  // 🔥 3. VOZVRAT (QAYTARISH) DIALOGI
  // =====================================
  void _showReturnDialog(BuildContext context, WidgetRef ref, DebtorItem item) {
    final countController = TextEditingController(text: "1");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: cardWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Vozvrat (Qaytarish)", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
                    Icon(Icons.assignment_return, color: Colors.orange.shade400, size: 28),
                  ],
                ),
                const Divider(height: 32),

                Text("Mijoz: ${item.clientName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text("Maxsulot: ${item.serviceName}", style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    "Diqqat: Ushbu amal maxsulotni qayta omborga qo'shadi va ushbu qarz yozuvini yopadi.",
                    style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Nechta qaytaryapti?",
                    prefixIcon: const Icon(Icons.format_list_numbered),
                    filled: true, fillColor: bgLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish', style: TextStyle(color: Colors.grey, fontSize: 16)))),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () async {
                          final count = int.tryParse(countController.text.trim()) ?? 1;
                          final nav = Navigator.of(context);
                          final scaffold = ScaffoldMessenger.of(context);

                          _showLoadingOverlay(context, message: "Omborga qaytarilmoqda...");

                          try {
                            final api = ref.read(apiServiceProvider);

                            // Call the special returnSale action or update directly if relying on that.
                            // Assuming backend is ready or we just close the debt here:
                            await api.updateData('qarzdorlar', {
                              'id': item.id,
                              'tolanga_summa': item.qarzPrice, // Yopildi
                              'status': 'returned',
                            });

                            nav.pop(); nav.pop();
                            ref.refresh(debtorsProvider);
                            scaffold.showSnackBar(const SnackBar(content: Text("✅ Vozvrat qabul qilindi. Qarz yopildi!"), backgroundColor: Colors.orange));

                          } catch (e) {
                            nav.pop(); scaffold.showSnackBar(SnackBar(content: Text("❌ Xato: $e"), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('VOZVRAT QILISH', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {bool isNum = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        filled: true, fillColor: bgLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryBlue, width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final debtorsData = ref.watch(debtorsProvider);
    final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

    return Scaffold(
      backgroundColor: bgLight,
      body: Row(
        children: [
          // ==========================================
          // CHAP TOMON: QARZDORLAR RO'YXATI
          // ==========================================
          Expanded(
            flex: 7, // Ekranning katta qismi
            child: Column(
              children: [
                // Windows Header (Orqaga tugmasi + Qidiruv)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      // 🔥 ORQAGA TUGMASI (BACK BUTTON)
                      Container(
                        margin: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(12)),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
                          tooltip: "Bosh menyuga qaytish",
                        ),
                      ),

                      const Text("QARZDORLAR", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      const SizedBox(width: 40),

                      Expanded(
                        child: TextField(
                          onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
                          decoration: InputDecoration(
                            hintText: "Ism yoki xizmat orqali qidiring...",
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            filled: true, fillColor: bgLight,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => ref.refresh(debtorsProvider),
                        icon: const Icon(Icons.refresh),
                        tooltip: "Yangilash",
                      )
                    ],
                  ),
                ),

                // Ro'yxat
                Expanded(
                  child: debtorsData.when(
                    loading: () => Center(child: CircularProgressIndicator(color: primaryBlue)),
                    error: (err, stack) => Center(child: Text('Xatolik: $err', style: const TextStyle(color: Colors.red))),
                    data: (allItems) {
                      if (allItems.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text("Ajoyib, hech qanday qarz yo'q! 🎉", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                            ],
                          ),
                        );
                      }

                      allItems.sort((a, b) => b.qoldiqQarz.compareTo(a.qoldiqQarz));
                      final items = allItems.where((item) => item.clientName.toLowerCase().contains(searchQuery) || item.serviceName.toLowerCase().contains(searchQuery)).toList();

                      return ListView.builder(
                        padding: const EdgeInsets.all(40),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final bool isReturned = item.status == 'returned';
                          final bool isPaid = item.qoldiqQarz <= 0 || isReturned;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isReturned ? Colors.orange.shade200 : (isPaid ? Colors.green.shade200 : Colors.white)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              children: [
                                // Ikonka
                                Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(color: isReturned ? Colors.orange.shade50 : (isPaid ? Colors.green.shade50 : Colors.red.shade50), borderRadius: BorderRadius.circular(16)),
                                  child: Icon(isReturned ? Icons.assignment_return : (isPaid ? Icons.task_alt : Icons.person_outline), color: isReturned ? Colors.orange : (isPaid ? Colors.green : Colors.redAccent), size: 28),
                                ),
                                const SizedBox(width: 24),

                                // Ma'lumot
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.clientName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isReturned ? Colors.grey : Colors.black87, decoration: isReturned ? TextDecoration.lineThrough : null)),
                                      const SizedBox(height: 6),
                                      Text(item.serviceName, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),

                                // Summalar (Desktop stili)
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildDesktopStat("Umumiy qarz", item.qarzPrice, Colors.black54),
                                      _buildDesktopStat("To'landi", item.tolangaSumma, Colors.green),
                                      _buildDesktopStat("Qoldiq", item.qoldiqQarz, isReturned ? Colors.orange : (isPaid ? Colors.green : Colors.redAccent), isBold: true),
                                    ],
                                  ),
                                ),

                                // Tugmalar
                                Row(
                                  children: [
                                    if (!isReturned) ...[
                                      IconButton(
                                        onPressed: () => _showAddOrEditDialog(context, ref, item: item),
                                        icon: Icon(Icons.edit_outlined, color: Colors.blue.shade300),
                                        tooltip: "Tahrirlash",
                                      ),
                                      const SizedBox(width: 8),
                                      if (!isPaid)
                                        IconButton(
                                          onPressed: () => _showReturnDialog(context, ref, item),
                                          icon: Icon(Icons.assignment_return_outlined, color: Colors.orange.shade400),
                                          tooltip: "Vozvrat qilish",
                                        ),
                                      const SizedBox(width: 16),
                                    ],
                                    if (!isPaid)
                                      ElevatedButton.icon(
                                        onPressed: () => _showPaymentDialog(context, ref, item),
                                        icon: const Icon(Icons.account_balance_wallet, size: 18),
                                        label: const Text("PUL OLISH", style: TextStyle(letterSpacing: 1)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                        ),
                                      )
                                    else if (isReturned)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                                        child: const Row(children: [Icon(Icons.assignment_return, color: Colors.orange, size: 16), SizedBox(width: 8), Text("Vozvrat qilingan", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                                            SizedBox(width: 8),
                                            Text("Yopilgan", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
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
          ),

          // ==========================================
          // O'NG TOMON: HISOBOT VA QO'SHISH PANELI
          // ==========================================
          Container(
            width: 350, // O'ng tomon kengligi
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(-5, 0))],
            ),
            child: debtorsData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const SizedBox.shrink(),
              data: (allItems) {
                final activeItems = allItems.where((i) => i.status != 'returned');
                final totalDebt = activeItems.fold<double>(0, (sum, item) => sum + item.qoldiqQarz);
                final activeDebtors = activeItems.where((i) => i.qoldiqQarz > 0).length;

                return Column(
                  children: [
                    // Paneldagi Bosh qism
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A), // To'q Ko'k (Navy)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.insights, color: Colors.white70, size: 32),
                          const SizedBox(height: 22),
                          const Text("Umumiy qarzdorlarning sum::", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text("${totalDebt.toStringAsFixed(0)} UZS", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text("$activeDebtors ta faol qarzdor mavjud", style: const TextStyle(color: Colors.white, fontSize: 13)),
                          )
                        ],
                      ),
                    ),

                    const Spacer(), // Qolgan qismini pastga suramiz

                    // Pastki "Qo'shish" tugmasi
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddOrEditDialog(context, ref),
                          icon: const Icon(Icons.person_add, size: 24),
                          label: const Text("YANGI QARZDOR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopStat(String label, double amount, Color color, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text("${amount.toStringAsFixed(0)} UZS", style: TextStyle(fontSize: isBold ? 20 : 16, color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}