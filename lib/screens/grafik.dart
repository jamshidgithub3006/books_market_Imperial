import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

// ==========================================
// PROVIDERS
// ==========================================

final salesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    return await ref.read(apiServiceProvider).getAll("savdo_tarixlari");
  } catch (e) {
    return [];
  }
});

final debtorsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    return await ref.read(apiServiceProvider).getAll("qarzdorlar");
  } catch (e) {
    return [];
  }
});

// ==========================================
// MAIN SCREEN
// ==========================================

class GrafikScreen extends ConsumerStatefulWidget {
  const GrafikScreen({super.key});

  @override
  ConsumerState<GrafikScreen> createState() => _GrafikScreenState();
}

class _GrafikScreenState extends ConsumerState<GrafikScreen>
    with TickerProviderStateMixin {
  // --- Filter holati ---
  String _selectedFilter = 'Bugun';
  int _selectedTab = 0;

  // --- Animatsiya kontrollerlar ---
  late AnimationController _cardAnimController;
  late AnimationController _listAnimController;
  late AnimationController _barAnimController;

  late Animation<double> _cardAnim;
  late Animation<double> _listAnim;
  late Animation<double> _barAnim;

  // --- Filtr ro'yxati (aniq kun bilan) ---
  final List<String> _filters = ['Bugun', 'Kecha', 'Shu hafta', 'Shu oy'];

  @override
  void initState() {
    super.initState();

    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _barAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _cardAnim = CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutBack);
    _listAnim = CurvedAnimation(parent: _listAnimController, curve: Curves.easeOut);
    _barAnim = CurvedAnimation(parent: _barAnimController, curve: Curves.easeOutCubic);

    _cardAnimController.forward();
    _listAnimController.forward();
    _barAnimController.forward();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _listAnimController.dispose();
    _barAnimController.dispose();
    super.dispose();
  }

  void _restartAnimations() {
    _cardAnimController.reset();
    _listAnimController.reset();
    _barAnimController.reset();
    _cardAnimController.forward();
    _listAnimController.forward();
    _barAnimController.forward();
  }

  // ==========================================
  // YORDAMCHI FUNKSIYALAR
  // ==========================================

  /// Pulni chiroyli formatlash: 125000 → "125 000"
  String formatMoney(double amount) {
    return NumberFormat('#,##0', 'en_US')
        .format(amount)
        .replaceAll(',', ' ');
  }

  /// Serverdan keladigan barcha sana formatlarini o'qish:
  /// "2026-06-10 10:23:27", "2026-06-10T10:23:27Z", "2026-06-10T10:23:27" va h.k.
  DateTime? _parseDate(dynamic rawDate) {
    if (rawDate == null) return null;
    String s = rawDate.toString().trim();
    if (s.isEmpty) return null;

    // Timezone belgilarini olib tashlash: Z, +05:00, +0500
    s = s
        .replaceAll('Z', '')
        .replaceAllMapped(RegExp(r'[+-]\d{2}:?\d{2}$'), (_) => '')
        .trim();

    // "T" ni bo'sh joy bilan almashtirish: "2026-06-10T10:23:27" → "2026-06-10 10:23:27"
    s = s.replaceAll('T', ' ');

    // To'g'ridan-to'g'ri parse qilish
    DateTime? dt = DateTime.tryParse(s);
    if (dt != null) return dt;

    // Qo'lda formatlashga urinish
    for (final fmt in [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
      'dd.MM.yyyy HH:mm:ss',
      'dd.MM.yyyy',
    ]) {
      try {
        return DateFormat(fmt).parseStrict(s);
      } catch (_) {}
    }
    return null;
  }

  /// Filtrlash: faqat tanlangan kunni ko'rsatish
  bool _isMatchingFilter(dynamic item) {
    if (item == null) return false;
    final rawDate = item['created_at'] ??
        item['createdAt'] ??
        item['date'] ??
        item['sana'];
    final date = _parseDate(rawDate);
    if (date == null) return false;

    final now = DateTime.now();
    // Soat/minut ta'sirini yo'qotish uchun faqat yil-oy-kun
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(date.year, date.month, date.day);

    switch (_selectedFilter) {
      case 'Bugun':
        return itemDay == today;
      case 'Kecha':
        return itemDay == today.subtract(const Duration(days: 1));
      case 'Shu hafta':
      // Dushanba boshlanish
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return !itemDay.isBefore(weekStart) && !itemDay.isAfter(today);
      case 'Shu oy':
        return date.year == now.year && date.month == now.month;
      default:
        return true;
    }
  }

  /// Filter uchun odam tushunadigan sana labelini olish
  String _getFilterDateLabel(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'Bugun':
        return DateFormat('dd.MM.yyyy').format(now);
      case 'Kecha':
        return DateFormat('dd.MM.yyyy').format(now.subtract(const Duration(days: 1)));
      case 'Shu hafta':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return '${DateFormat('dd.MM').format(weekStart)} - ${DateFormat('dd.MM').format(now)}';
      case 'Shu oy':
        const monthNames = [
          'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
          'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
        ];
        return '${monthNames[now.month - 1]} ${now.year}';
      default:
        return '';
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1E3A8A);
    const Color accentColor = Color(0xFF3B82F6);
    const Color bgColor = Color(0xFFF1F5F9);

    final salesAsync = ref.watch(salesProvider);
    final debtorsAsync = ref.watch(debtorsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(primaryColor),
      body: salesAsync.when(
        loading: () => _buildLoading(),
        error: (err, _) => _buildError("Savdolar yuklanmadi: $err"),
        data: (allSales) {
          return debtorsAsync.when(
            loading: () => _buildLoading(),
            error: (err, _) => _buildError("Qarzdorlar yuklanmadi: $err"),
            data: (allDebtors) {
              return _buildBody(
                context,
                allSales: allSales,
                allDebtors: allDebtors,
                primaryColor: primaryColor,
                accentColor: accentColor,
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // APP BAR
  // ==========================================

  AppBar _buildAppBar(Color primaryColor) {
    return AppBar(
      elevation: 0,
      backgroundColor: primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TUSHUMLAR VA QARZLAR",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            _getFilterDateLabel(_selectedFilter),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: "Yangilash",
          onPressed: () {
            ref.refresh(salesProvider);
            ref.refresh(debtorsProvider);
            _restartAnimations();
          },
        ),
      ],
    );
  }

  // ==========================================
  // BODY
  // ==========================================

  Widget _buildBody(
      BuildContext context, {
        required List<dynamic> allSales,
        required List<dynamic> allDebtors,
        required Color primaryColor,
        required Color accentColor,
      }) {
    // --- Ma'lumotlarni filtrlash ---
    final currentSales = allSales.where(_isMatchingFilter).toList();

    double jamiNaqd = 0;
    double jamiPlastik = 0;
    double jamiQarz = 0;
    final List<dynamic> kassaTushumlari = [];
    final List<dynamic> qarzSavdolar = [];

    for (var sale in currentSales) {
      final price = double.tryParse((sale['total_price'] ?? 0).toString()) ?? 0.0;
      final type = (sale['payment_type'] ?? '').toString().toLowerCase().trim();

      if (type == 'naqd') {
        jamiNaqd += price;
        kassaTushumlari.add(sale);
      } else if (type == 'plastic' || type == 'plastik') {
        jamiPlastik += price;
        kassaTushumlari.add(sale);
      } else if (type == 'qarz') {
        jamiQarz += price;
        qarzSavdolar.add(sale);
      }
    }

    // Faqat to'langan qarzlar (debtors jadvalidan)
    final paidDebtors = allDebtors
        .where((d) => (d['status'] ?? '').toString().toLowerCase() == 'paid')
        .toList();

    final jamiTushum = jamiNaqd + jamiPlastik;

    return Column(
      children: [
        // Filtr + Kartalar (scroll qilmaydigan qism)
        Container(
          color: const Color(0xFF1E3A8A),
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              // Filtr tugmalari
              _buildFilterBar(primaryColor),
              const SizedBox(height: 16),
              // Statistika kartalar
              _buildStatsSection(
                jamiNaqd: jamiNaqd,
                jamiPlastik: jamiPlastik,
                jamiTushum: jamiTushum,
                jamiQarz: jamiQarz,
                primaryColor: primaryColor,
                accentColor: accentColor,
              ),
            ],
          ),
        ),

        // Bar grafik
        _buildBarChart(
          jamiNaqd: jamiNaqd,
          jamiPlastik: jamiPlastik,
          jamiQarz: jamiQarz,
        ),

        // Tab va ro'yxat
        Expanded(
          child: Column(
            children: [
              _buildTabBar(primaryColor),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey(_selectedTab),
                    color: const Color(0xFFF1F5F9),
                    child: _selectedTab == 0
                        ? _buildTushumlarList(kassaTushumlari)
                        : _selectedTab == 1
                        ? _buildQarzlarList(paidDebtors)
                        : _buildQarzSavdoList(qarzSavdolar),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // FILTR BAR
  // ==========================================

  Widget _buildFilterBar(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isActive = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    _restartAnimations();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive ? Colors.white : Colors.white30,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          filter,
                          style: TextStyle(
                            color: isActive ? primaryColor : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _getFilterDateLabel(filter),
                          style: TextStyle(
                            color: isActive
                                ? primaryColor.withOpacity(0.6)
                                : Colors.white54,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================
  // STATISTIKA KARTALAR
  // ==========================================

  Widget _buildStatsSection({
    required double jamiNaqd,
    required double jamiPlastik,
    required double jamiTushum,
    required double jamiQarz,
    required Color primaryColor,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ScaleTransition(
        scale: _cardAnim,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "NAQD",
                    jamiNaqd,
                    Icons.payments_rounded,
                    const Color(0xFF10B981),
                    isLight: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    "PLASTIK",
                    jamiPlastik,
                    Icons.credit_card_rounded,
                    const Color(0xFF3B82F6),
                    isLight: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "UMUMIY TUSHUM",
                    jamiTushum,
                    Icons.account_balance_wallet_rounded,
                    Colors.white,
                    isLight: true,
                    bigText: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    "QARZLAR",
                    jamiQarz,
                    Icons.pending_actions_rounded,
                    const Color(0xFFF59E0B),
                    isLight: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title,
      double amount,
      IconData icon,
      Color color, {
        bool isLight = false,
        bool bigText = false,
      }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight ? Colors.white30 : color.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isLight ? Colors.white70 : color.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(amount),
            style: TextStyle(
              color: Colors.white,
              fontSize: bigText ? 18 : 16,
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            "so'm",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BAR GRAFIK (Animatsiyali)
  // ==========================================

  Widget _buildBarChart({
    required double jamiNaqd,
    required double jamiPlastik,
    required double jamiQarz,
  }) {
    final maxVal = [jamiNaqd, jamiPlastik, jamiQarz].reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Statistika",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar("Naqd", jamiNaqd, maxVal, const Color(0xFF10B981)),
              const SizedBox(width: 12),
              _buildBar("Plastik", jamiPlastik, maxVal, const Color(0xFF3B82F6)),
              const SizedBox(width: 12),
              _buildBar("Qarz", jamiQarz, maxVal, const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double value, double maxVal, Color color) {
    const double maxHeight = 70.0;
    final ratio = maxVal > 0 ? (value / maxVal) : 0.0;

    return Expanded(
      child: Column(
        children: [
          Text(
            formatMoney(value),
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _barAnim,
            builder: (_, __) {
              return Container(
                height: maxHeight * ratio * _barAnim.value + 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB BAR
  // ==========================================

  Widget _buildTabBar(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabItem(0, "Kassa", Icons.receipt_long_rounded, primaryColor),
          _buildTabItem(1, "To'langan", Icons.task_alt_rounded, primaryColor),
          _buildTabItem(2, "Qarz savdo", Icons.pending_actions_rounded, primaryColor),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon, Color primaryColor) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.grey,
                size: 16,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // RO'YXATLAR
  // ==========================================

  Widget _buildTushumlarList(List<dynamic> items) {
    if (items.isEmpty) {
      return _buildEmpty("Bu davrda kassa tushumi yo'q", Icons.receipt_long_rounded);
    }
    final sorted = [...items]..sort((a, b) {
      final da = _parseDate(a['created_at'] ?? a['createdAt'] ?? a['date']);
      final db = _parseDate(b['created_at'] ?? b['createdAt'] ?? b['date']);
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return FadeTransition(
          opacity: _listAnim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.1 * (index + 1)),
              end: Offset.zero,
            ).animate(_listAnim),
            child: _buildTushumTile(sorted[index]),
          ),
        );
      },
    );
  }

  Widget _buildTushumTile(dynamic item) {
    final rawDate = item['created_at'] ?? item['createdAt'] ?? item['date'];
    final date = _parseDate(rawDate) ?? DateTime.now();
    final timeStr = DateFormat('dd.MM.yyyy, HH:mm').format(date);
    final price = double.tryParse((item['total_price'] ?? 0).toString()) ?? 0;
    final type = (item['payment_type'] ?? '').toString().toLowerCase().trim();
    final isNaqd = type == 'naqd';
    final color = isNaqd ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final typeLabel = isNaqd ? 'NAQD' : 'PLASTIK';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isNaqd ? Icons.payments_rounded : Icons.credit_card_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['product_name'] ?? "Noma'lum").toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "+ ${formatMoney(price)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQarzlarList(List<dynamic> items) {
    if (items.isEmpty) {
      return _buildEmpty("To'langan qarzlar topilmadi", Icons.task_alt_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[items.length - 1 - index];
        final price = double.tryParse((item['qarz_price'] ?? 0).toString()) ?? 0;
        final rawDate = item['updated_at'] ?? item['created_at'] ?? item['createdAt'];
        final date = _parseDate(rawDate) ?? DateTime.now();
        final dateStr = DateFormat('dd.MM.yyyy, HH:mm').format(date);

        return FadeTransition(
          opacity: _listAnim,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['client_name'] ?? 'Mijoz').toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(price),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blue,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "TO'LANDI",
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildQarzSavdoList(List<dynamic> items) {
    if (items.isEmpty) {
      return _buildEmpty("Bu davrda qarzga savdo yo'q", Icons.pending_actions_rounded);
    }
    final sorted = [...items]..sort((a, b) {
      final da = _parseDate(a['created_at'] ?? a['createdAt'] ?? a['date']);
      final db = _parseDate(b['created_at'] ?? b['createdAt'] ?? b['date']);
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        final rawDate = item['created_at'] ?? item['createdAt'] ?? item['date'];
        final date = _parseDate(rawDate) ?? DateTime.now();
        final timeStr = DateFormat('dd.MM.yyyy, HH:mm').format(date);
        final price = double.tryParse((item['total_price'] ?? 0).toString()) ?? 0;

        return FadeTransition(
          opacity: _listAnim,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pending_actions_rounded,
                      color: Color(0xFFF59E0B), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['product_name'] ?? "Noma'lum").toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (item['client_name'] ?? '').toString(),
                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(price),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "QARZGA",
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
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

  // ==========================================
  // YORDAMCHI WIDGETLAR
  // ==========================================

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E3A8A)),
          SizedBox(height: 12),
          Text("Yuklanmoqda...", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey.shade300, size: 56),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
        ],
      ),
    );
  }
}