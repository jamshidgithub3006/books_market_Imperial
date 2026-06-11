import 'package:books_market/screens/debtors_screen.dart';
import 'package:books_market/screens/grafik.dart';
import 'package:books_market/screens/orders_screen.dart';
import 'package:books_market/screens/sales_screen.dart';
import 'package:books_market/screens/services_screen.dart';
import 'package:books_market/screens/tasks_screen.dart';
import 'package:books_market/screens/warehouse_screen.dart';
import 'package:books_market/services/api_service.dart';
import 'package:books_market/services/auto_report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';



// Butun ilova bo'ylab foydalanuvchi ismini saqlash uchun provayder
final cashierNameProvider = StateProvider<String>((ref) => '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final String? savedName = prefs.getString('cashier_name');
  WidgetsFlutterBinding.ensureInitialized();

  // Api xizmatini yurgizamiz
  final apiService = ApiService();

  // 🔥 AVTOMATIK HISOBOT TAYMERINI ISHGA TUSHIRAMIZ!
  AutoReportService.startTimer(apiService);
  runApp(ProviderScope(child: MyApp(savedName: savedName)));
}

class MyApp extends ConsumerWidget {
  final String? savedName;
  const MyApp({super.key, this.savedName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (savedName != null && savedName!.isNotEmpty) {
        ref.read(cashierNameProvider.notifier).state = savedName!;
      }
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Tizimi (JMD)',
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
        useMaterial3: true,
      ),
      // MANTIQ: Ism yo'q -> Login, Ism bor -> To'g'ridan-to'g'ri Bosh Menyuga!
      home: (savedName == null || savedName!.isEmpty)
          ? const CashierLoginScreen()
          : const MainMenuScreen(),
    );
  }
}

// ==========================================
// 1. ISMNI SO'RASH EKRANI (Ultra Minimal)
// ==========================================
class CashierLoginScreen extends ConsumerStatefulWidget {
  const CashierLoginScreen({super.key});

  @override
  ConsumerState<CashierLoginScreen> createState() => _CashierLoginScreenState();
}

class _CashierLoginScreenState extends ConsumerState<CashierLoginScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  void _saveAndStart() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ismingizni kiriting!"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cashier_name', name);

    ref.read(cashierNameProvider.notifier).state = name;

    if (mounted) {
      // Ism kiritilgach Bosh Menyuga o'tkazamiz
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: Container(
          width: 450, // Windows ekranida markazda ixcham turishi uchun
          padding: const EdgeInsets.all(40.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.computer_rounded, size: 64, color: Color(0xFF0F172A)),
              const SizedBox(height: 24),
              const Text(
                "TIZIMGA KIRISH",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                "Ishni boshlash uchun o'z ismingizni kiriting",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Ismingiz",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _saveAndStart,
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("KIRISH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. WINDOWS UCHUN BOSH MENYU (DASHBOARD)
// ==========================================
class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  final Color primaryNavy = const Color(0xFF0F172A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String cashierName = ref.watch(cashierNameProvider);

    // Barcha ekranlarni bitta ro'yxatga yig'amiz
    final List<Map<String, dynamic>> menuItems = [
      {"title": "Kassa", "subtitle": "Savdo va to'lov terminali", "icon": Icons.point_of_sale, "color": const Color(0xFF3B82F6), "screen": const SalesScreen()},
      {"title": "Sklad", "subtitle": "Sklad qoldig'i va kirim", "icon": Icons.inventory_2, "color": const Color(0xFFEA580C), "screen": const WarehouseScreen()},
      {"title": "Analitika", "subtitle": "Grafiklar va hisobotlar", "icon": Icons.analytics, "color": const Color(0xFF10B981), "screen": const GrafikScreen()},
      {"title": "Qarzlar", "subtitle": "Nasiyalar va to'lovlar", "icon": Icons.account_balance_wallet, "color": const Color(0xFFE11D48), "screen": const DebtorsScreen()},
      {"title": "Xizmatlar", "subtitle": "Narxlar va katalog", "icon": Icons.design_services, "color": const Color(0xFF8B5CF6), "screen": const ServicesScreen()},
      {"title": "Buyurtmalar", "subtitle": "Maxsus loyihalar", "icon": Icons.menu_book, "color": const Color(0xFF0D9488), "screen": const OrdersScreen()},
      {"title": "Topshiriqlar", "subtitle": "Hodimlar uchun rejalar", "icon": Icons.assignment_turned_in, "color": const Color(0xFFF59E0B), "screen": const TasksScreen()},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Asosiy Kontent
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Windows uchun Top Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Xush kelibsiz, $cashierName 👋", style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text("Boshqaruv Paneli", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryNavy)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              "${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                // Responsive Grid Menu
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(40),
                    // Windows ekraniga moslashuvchan Grid: Har bir karta kamida 280px kenglikda bo'ladi
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 1.1, // Karta shakli
                    ),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final itemColor = item['color'] as Color;

                      return InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['screen'])),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: itemColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(item['icon'], size: 32, color: itemColor),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                item['title'],
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item['subtitle'],
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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