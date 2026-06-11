import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

final posServicesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return await ref.read(apiServiceProvider).getAll("materials");
});

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

// Raqamlarni 10 000 ko'rinishida formatlash
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.selection.baseOffset == 0) return newValue;
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.isEmpty) return newValue.copyWith(text: '');
    double value = double.parse(newText);
    final formatter = NumberFormat.decimalPattern('vi');
    String formattedText = formatter.format(value).replaceAll('.', ' ');
    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final List<Map<String, dynamic>> _cart = [];
  final _clientNameController = TextEditingController();
  String _searchQuery = "";
  final Color primaryBlue = const Color(0xFF1E3A8A);
  final Color accentOrange = const Color(0xFFEA580C);

  double parsePrice(dynamic v) =>
      double.tryParse(v.toString().replaceAll(' ', '').replaceAll(',', '')) ?? 0.0;

  double get _totalPrice {
    double total = 0;
    for (var item in _cart) {
      total += parsePrice(item['price']) * item['qty'];
    }
    return total;
  }

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
                // Aylanuvchi animatsiya (Kassa stili uchun ko'k rangda)
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
                const Text(
                  "Savdo tasdiqlanmoqda...",
                  style: TextStyle(
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

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      int index = _cart.indexWhere((element) => element['id'] == product['id']);
      if (index != -1) {
        _cart[index]['qty']++;
      } else {
        _cart.add({
          'id': product['id'],
          'name': product['name'],
          'price': product['price'],
          'qty': 1,
        });
      }
    });
  }

  void _updateCartQty(int index, int delta) {
    setState(() {
      if (delta > 0) {
        _cart[index]['qty']++;
      } else {
        if (_cart[index]['qty'] > 1) {
          _cart[index]['qty']--;
        } else {
          _cart.removeAt(index);
        }
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _clientNameController.clear();
    });
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        width: 400, // Desktop uchun mos o'lcham
      ),
    );
  }

  // ==========================================
  // TO'LOV OYNASI (Dialog) - Desktop uchun moslashtirilgan
  // ==========================================
  void _showPaymentDialog() {
    double naqdVal = 0;
    double plastikVal = 0;
    final nCtrl = TextEditingController();
    final pCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double jami = naqdVal + plastikVal;
            double qarz = _totalPrice - jami;
            if (qarz < 0) qarz = 0;
            double qaytim = jami - _totalPrice;
            if (qaytim < 0) qaytim = 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("To'lovni yakunlash"),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              // Desktop ekranlar uchun dialog kengligini cheklaymiz
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Jami summa:", style: TextStyle(fontSize: 16)),
                          Text(
                            "${_totalPrice.toInt()} so'm",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      TextField(
                        controller: nCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: "Naqd to'lov",
                          prefixIcon: const Icon(Icons.money, color: Colors.green),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setDialogState(
                              () => naqdVal = double.tryParse(v.replaceAll(' ', '')) ?? 0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: pCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: "Plastik (Karta)",
                          prefixIcon: const Icon(Icons.credit_card, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setDialogState(
                              () => plastikVal = double.tryParse(v.replaceAll(' ', '')) ?? 0,
                        ),
                      ),
                      if (jami < _totalPrice) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Qoldiq qarz: ${qarz.toInt()} so'm",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _clientNameController,
                                decoration: const InputDecoration(
                                  labelText: "Mijoz ismi (Qarz uchun)",
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (qaytim > 0) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Qaytim: ", style: TextStyle(fontSize: 18)),
                              Text(
                                "${qaytim.toInt()} so'm",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.all(24),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("BEKOR QILISH", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _confirmSale(naqdVal, plastikVal, qarz),
                  child: const Text("TASDIQLASH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmSale(double naqd, double plastik, double qarz) async {
    if (qarz > 0 && _clientNameController.text.trim().isEmpty) {
      _showToast("Qarz uchun mijoz ismini yozing!", Colors.red);
      return;
    }

    // 1. To'lov dialogini yopamiz
    Navigator.pop(context);

    // 2. 🔥 LOADING OYNASINI CHAQIRAMIZ 🔥
    _showLoadingOverlay(context);

    try {
      final api = ref.read(apiServiceProvider);
      String cartDetails = _cart.map((e) => "${e['name']} (${e['qty']} ta)").join(", ");

      for (var item in _cart) {
        await api.makeSale(
          serviceId: item['id'].toString(),
          serviceName: item['name'],
          count: item['qty'],
          totalPrice: parsePrice(item['price']) * item['qty'],
          paymentType: qarz > 0 ? "qarz" : (plastik > 0 ? "plastic" : "naqd"),
          sellerName: "Asosiy Sotuvchi",
          clientName: _clientNameController.text.trim(),
          comment: "Multi-savdo: $cartDetails. Naqd: $naqd, Plastik: $plastik, Qarz: $qarz",
        );
      }

      if (mounted) {
        Navigator.pop(context); // 3. Loading oynasini yopamiz
        _showToast("✅ Savdo tasdiqlandi!", Colors.green);
        _clearCart();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Xato bo'lsa ham Loading oynasini yopamiz
        _showToast("❌ Xato: $e", Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Sal yorqinroq fon
      appBar: AppBar(
        backgroundColor: primaryBlue,
        title: const Text(
          'KASSA (SAVDO)',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Yangilash",
            onPressed: () => ref.refresh(posServicesProvider),
          ),
          const SizedBox(width: 16),
        ],
      ),
      // DESKTOP LAYOUT: Ekranni 2 ga bo'lamiz (Chap: Mahsulotlar, O'ng: Savatcha)
      body: Row(
        children: [
          // ==================== CHAP QISM: MAHSULOTLAR ====================
          Expanded(
            flex: 7, // Kenglikning 7 qismini oladi
            child: Column(
              children: [
                // Qidiruv paneli
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Mahsulot qidirish...",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),

                // Mahsulotlar (Desktop Grid - Responsive)
                Expanded(
                  child: ref.watch(posServicesProvider).when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, s) => Center(child: Text("Xato: $err")),
                    data: (items) {
                      final filtered = items.where(
                            (i) => i['name'].toString().toLowerCase().contains(_searchQuery),
                      ).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text("Mahsulot topilmadi", style: TextStyle(fontSize: 18)));
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        // Desktop uchun moslashuvchan Grid: Har bir kartochka maksimal 220px joy oladi
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.9,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _addToCart(item),
                              borderRadius: BorderRadius.circular(16),
                              hoverColor: primaryBlue.withOpacity(0.05),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: primaryBlue.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.inventory_2, color: primaryBlue, size: 32),
                                    ),
                                    const Spacer(),
                                    Text(
                                      item['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${item['price']} so'm",
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

          // ==================== O'NG QISM: SAVATCHA SIDEBAR ====================
          Container(
            width: 400, // Qotirilgan kenglik
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(-5, 0)),
              ],
            ),
            child: Column(
              children: [
                // Sidebar Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  color: primaryBlue.withOpacity(0.05),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_cart_checkout, color: primaryBlue),
                          const SizedBox(width: 10),
                          Text(
                            "SAVATCHA (${_cart.length})",
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_cart.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep, color: Colors.red),
                          tooltip: "Tozalash",
                          onPressed: _clearCart,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Cart Items List
                Expanded(
                  child: _cart.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("Savatcha bo'sh", style: TextStyle(color: Colors.grey.shade500, fontSize: 18)),
                      ],
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${item['price']} so'm",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.red, size: 20),
                                  onPressed: () => _updateCartQty(index, -1),
                                  splashRadius: 20,
                                ),
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    "${item['qty']}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, color: Colors.green, size: 20),
                                  onPressed: () => _updateCartQty(index, 1),
                                  splashRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Bottom Checkout Panel
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "JAMI:",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          Text(
                            "${_totalPrice.toInt()} UZS",
                            style: TextStyle(color: accentOrange, fontSize: 26, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cart.isEmpty ? Colors.grey.shade300 : primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: _cart.isEmpty ? 0 : 2,
                          ),
                          onPressed: _cart.isEmpty ? null : _showPaymentDialog,
                          icon: const Icon(Icons.payment, size: 24),
                          label: const Text("TO'LOVGA O'TISH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}