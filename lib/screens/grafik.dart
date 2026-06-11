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
  String _selectedFilter = 'Bugun';
  int _selectedTab = 0;

  late AnimationController _cardAnimController;
  late AnimationController _barAnimController;
  late Animation<double> _cardAnim;
  late Animation<double> _barAnim;

  final List<String> _filters = ['Bugun', 'Kecha', 'Shu hafta', 'Shu oy'];

  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color bgColor = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _barAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _cardAnim =
        CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutBack);
    _barAnim =
        CurvedAnimation(parent: _barAnimController, curve: Curves.easeOutCubic);
    _cardAnimController.forward();
    _barAnimController.forward();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _barAnimController.dispose();
    super.dispose();
  }

  void _restartAnimations() {
    _cardAnimController
      ..reset()
      ..forward();
    _barAnimController
      ..reset()
      ..forward();
  }

  // ==========================================
  // SANA PARSE — UTC ni lokal vaqtga o'girish
  // ==========================================

  /// Serverdan kelgan sana stringni LOCAL DateTime ga o'giradi.
  /// Server O'zbekiston vaqtida (UTC+5) saqlaydi lekin timezone belgisiz,
  /// shuning uchun uni UTC deb emas, LOCAL deb o'qiymiz.
  DateTime? _parseDate(dynamic rawDate) {
    if (rawDate == null) return null;
    String s = rawDate.toString().trim();
    if (s.isEmpty) return null;

    // Agar "Z" yoki "+HH:MM" bor bo'lsa — olib tashlaymiz
    // Chunki server O'zbekiston vaqtini timezone belgisiz saqlaydi
    s = s
        .replaceAll('Z', '')
        .replaceAllMapped(RegExp(r'[+-]\d{2}:?\d{2}$'), (_) => '')
        .trim();

    // "T" ni bo'sh joy bilan almashtirish
    s = s.replaceAll('T', ' ');

    // "2026-06-11 8:44:22" — bir xonali soat ham bo'lishi mumkin
    // DateTime.tryParse faqat ISO formatni qabul qiladi, shuning uchun
    // soatni ikki xonali qilamiz: "8:44" → "08:44"
    s = s.replaceAllMapped(
        RegExp(r'^(\d{4}-\d{2}-\d{2}) (\d):'), (m) => '${m[1]} 0${m[2]}:');

    DateTime? dt = DateTime.tryParse(s);
    if (dt != null) return dt.add(const Duration(hours: 5));

    // Qo'shimcha formatlar
    for (final fmt in [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
    ]) {
      try {
        return DateFormat(fmt).parseStrict(s).add(const Duration(hours: 5));
      } catch (_) {}
    }
    return null;
  }

  // ==========================================
  // FILTRLASH
  // ==========================================

  bool _isMatchingFilter(dynamic item) {
    if (item == null) return false;
    final rawDate = item['created_at'] ??
        item['createdAt'] ??
        item['date'] ??
        item['sana'];
    final date = _parseDate(rawDate);
    if (date == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(date.year, date.month, date.day);

    switch (_selectedFilter) {
      case 'Bugun':
        return itemDay == today;
      case 'Kecha':
        return itemDay == today.subtract(const Duration(days: 1));
      case 'Shu hafta':
        final weekStart =
        today.subtract(Duration(days: today.weekday - 1));
        return !itemDay.isBefore(weekStart) && !itemDay.isAfter(today);
      case 'Shu oy':
        return date.year == now.year && date.month == now.month;
      default:
        return true;
    }
  }

  // ==========================================
  // YORDAMCHILAR
  // ==========================================

  String formatMoney(double amount) {
    return NumberFormat('#,##0', 'en_US')
        .format(amount)
        .replaceAll(',', ' ');
  }

  String _getFilterDateLabel(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'Bugun':
        return DateFormat('dd.MM.yyyy').format(now);
      case 'Kecha':
        return DateFormat('dd.MM.yyyy')
            .format(now.subtract(const Duration(days: 1)));
      case 'Shu hafta':
        final weekStart =
        now.subtract(Duration(days: now.weekday - 1));
        return '${DateFormat('dd.MM').format(weekStart)} - ${DateFormat('dd.MM').format(now)}';
      case 'Shu oy':
        const months = [
          'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
          'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
        ];
        return '${months[now.month - 1]} ${now.year}';
      default:
        return '';
    }
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesProvider);
    final debtorsAsync = ref.watch(debtorsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: salesAsync.when(
        loading: () => _buildLoading(),
        error: (err, _) => _buildError("Savdolar yuklanmadi: $err"),
        data: (allSales) => debtorsAsync.when(
          loading: () => _buildLoading(),
          error: (err, _) => _buildError("Qarzdorlar yuklanmadi: $err"),
          data: (allDebtors) =>
              _buildBody(allSales: allSales, allDebtors: allDebtors),
        ),
      ),
    );
  }

  // ==========================================
  // APP BAR
  // ==========================================

  AppBar _buildAppBar() {
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
                letterSpacing: 0.5),
          ),
          Text(
            _getFilterDateLabel(_selectedFilter),
            style:
            const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
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
  // BODY — butun ekran CustomScrollView
  // ==========================================

  Widget _buildBody({
    required List<dynamic> allSales,
    required List<dynamic> allDebtors,
  }) {
    // Ma'lumotlarni hisoblash
    final currentSales = allSales.where(_isMatchingFilter).toList();

    double jamiNaqd = 0;
    double jamiPlastik = 0;
    double jamiQarz = 0;
    final List<dynamic> kassaTushumlari = [];
    final List<dynamic> qarzSavdolar = [];

    for (var sale in currentSales) {
      final price =
          double.tryParse((sale['total_price'] ?? 0).toString()) ?? 0.0;
      final type =
      (sale['payment_type'] ?? '').toString().toLowerCase().trim();

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

    // Faqat to'langan qarzlar
    final paidDebtors = allDebtors
        .where((d) =>
    (d['status'] ?? '').toString().toLowerCase() == 'paid')
        .toList();

    final jamiTushum = jamiNaqd + jamiPlastik;

    // Tab bo'yicha ro'yxat
    List<dynamic> activeList;
    switch (_selectedTab) {
      case 0:
        activeList = [...kassaTushumlari]..sort((a, b) =>
            (_parseDate(b['created_at'] ?? b['createdAt'] ?? b['date']) ??
                DateTime(0))
                .compareTo(_parseDate(
                a['created_at'] ?? a['createdAt'] ?? a['date']) ??
                DateTime(0)));
        break;
      case 1:
        activeList = [...paidDebtors];
        break;
      default:
        activeList = [...qarzSavdolar]..sort((a, b) =>
            (_parseDate(b['created_at'] ?? b['createdAt'] ?? b['date']) ??
                DateTime(0))
                .compareTo(_parseDate(
                a['created_at'] ?? a['createdAt'] ?? a['date']) ??
                DateTime(0)));
    }

    // ==========================================
    // BUTUN EKRAN SCROLLABLE
    // ==========================================
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // --- Header: filter + kartalar ---
        SliverToBoxAdapter(
          child: Container(
            color: primaryColor,
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                _buildFilterBar(),
                const SizedBox(height: 16),
                _buildStatsCards(
                  jamiNaqd: jamiNaqd,
                  jamiPlastik: jamiPlastik,
                  jamiTushum: jamiTushum,
                  jamiQarz: jamiQarz,
                ),
              ],
            ),
          ),
        ),

        // --- Bar grafik ---
        SliverToBoxAdapter(
          child: _buildBarChart(
            jamiNaqd: jamiNaqd,
            jamiPlastik: jamiPlastik,
            jamiQarz: jamiQarz,
          ),
        ),

        // --- Tab bar ---
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabHeaderDelegate(
            child: _buildTabBar(),
          ),
        ),

        // --- Ro'yxat elementlari ---
        if (activeList.isEmpty)
          SliverFillRemaining(
            child: _buildEmpty(_emptyMessage()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = activeList[index];
                  return _buildListTile(item, index);
                },
                childCount: activeList.length,
              ),
            ),
          ),
      ],
    );
  }

  String _emptyMessage() {
    switch (_selectedTab) {
      case 0:
        return "Bu davrda kassa tushumi yo'q";
      case 1:
        return "To'langan qarzlar topilmadi";
      default:
        return "Bu davrda qarzga savdo yo'q";
    }
  }

  // ==========================================
  // FILTR BAR
  // ==========================================

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isActive = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedFilter = filter);
                  _restartAnimations();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                      isActive ? Colors.white : Colors.white30,
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
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================
  // STATISTIKA KARTALAR
  // ==========================================

  Widget _buildStatsCards({
    required double jamiNaqd,
    required double jamiPlastik,
    required double jamiTushum,
    required double jamiQarz,
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
                    child: _statCard("NAQD", jamiNaqd,
                        Icons.payments_rounded, const Color(0xFF10B981))),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard("PLASTIK", jamiPlastik,
                        Icons.credit_card_rounded, const Color(0xFF3B82F6))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _statCard("UMUMIY TUSHUM", jamiTushum,
                        Icons.account_balance_wallet_rounded, Colors.white,
                        isHighlight: true)),
                const SizedBox(width: 10),
                Expanded(
                    child: _statCard("QARZLAR", jamiQarz,
                        Icons.pending_actions_rounded,
                        const Color(0xFFF59E0B))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, double amount, IconData icon, Color color,
      {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlight
            ? Colors.white.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlight ? Colors.white : color.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isHighlight
                        ? Colors.white70
                        : color.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const Text("so'm",
              style: TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  // ==========================================
  // BAR GRAFIK
  // ==========================================

  Widget _buildBarChart({
    required double jamiNaqd,
    required double jamiPlastik,
    required double jamiQarz,
  }) {
    final maxVal = [jamiNaqd, jamiPlastik, jamiQarz]
        .reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Statistika",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: primaryColor)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar("Naqd", jamiNaqd, maxVal, const Color(0xFF10B981)),
              const SizedBox(width: 12),
              _bar("Plastik", jamiPlastik, maxVal, const Color(0xFF3B82F6)),
              const SizedBox(width: 12),
              _bar("Qarz", jamiQarz, maxVal, const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, double maxVal, Color color) {
    const double maxH = 72.0;
    final ratio = maxVal > 0 ? (value / maxVal) : 0.0;
    return Expanded(
      child: Column(
        children: [
          Text(
            formatMoney(value),
            style: TextStyle(
                fontSize: 9, color: color, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _barAnim,
            builder: (_, __) => Container(
              height: maxH * ratio * _barAnim.value + 4,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ==========================================
  // TAB BAR
  // ==========================================

// ==========================================
// TAB BAR
// ==========================================

  Widget _buildTabBar() {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), // <-- Yuqori padding 8 dan 4 ga tushirildi
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            _tabItem(0, "Kassa", Icons.receipt_long_rounded),
            _tabItem(1, "To'langan", Icons.task_alt_rounded),
            _tabItem(2, "Qarz savdo", Icons.pending_actions_rounded),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(int index, String label, IconData icon) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4), // <-- 6 dan 4 ga tushirildi
          decoration: BoxDecoration(
            color: isActive ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? Colors.white : Colors.grey, size: 15),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
        ),
      ),
    );
  }


  // ==========================================
  // TILE BUILDER — tab ga qarab mos tile
  // ==========================================

  Widget _buildListTile(dynamic item, int index) {
    switch (_selectedTab) {
      case 0:
        return _kassaTile(item);
      case 1:
        return _paidDebtTile(item);
      default:
        return _qarzSavdoTile(item);
    }
  }

  // Kassa tushum tile
  Widget _kassaTile(dynamic item) {
    final rawDate =
        item['created_at'] ?? item['createdAt'] ?? item['date'];
    final date = _parseDate(rawDate) ?? DateTime.now();
    final timeStr = DateFormat('dd.MM.yyyy, HH:mm').format(date);
    final price =
        double.tryParse((item['total_price'] ?? 0).toString()) ?? 0;
    final type =
    (item['payment_type'] ?? '').toString().toLowerCase().trim();
    final isNaqd = type == 'naqd';
    final color =
    isNaqd ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final typeLabel = isNaqd ? 'NAQD' : 'PLASTIK';
    final icon =
    isNaqd ? Icons.payments_rounded : Icons.credit_card_rounded;

    return _tileCard(
      icon: icon,
      iconColor: color,
      title: (item['product_name'] ?? "Noma'lum").toString(),
      subtitle: (item['client_name'] ?? '').toString(),
      timeStr: timeStr,
      amountText: "+ ${formatMoney(price)}",
      amountColor: color,
      badgeText: typeLabel,
      badgeColor: color,
    );
  }

  // To'langan qarz tile
  Widget _paidDebtTile(dynamic item) {
    final price =
        double.tryParse((item['qarz_price'] ?? 0).toString()) ?? 0;
    final rawDate =
        item['updated_at'] ?? item['created_at'] ?? item['createdAt'];
    final date = _parseDate(rawDate) ?? DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy, HH:mm').format(date);

    return _tileCard(
      icon: Icons.task_alt_rounded,
      iconColor: Colors.blue,
      title: (item['client_name'] ?? 'Mijoz').toString(),
      subtitle: (item['service_name'] ?? '').toString(),
      timeStr: dateStr,
      amountText: formatMoney(price),
      amountColor: Colors.blue,
      badgeText: "TO'LANDI",
      badgeColor: Colors.blue,
    );
  }

  // Qarzga savdo tile
  Widget _qarzSavdoTile(dynamic item) {
    const color = Color(0xFFF59E0B);
    final rawDate =
        item['created_at'] ?? item['createdAt'] ?? item['date'];
    final date = _parseDate(rawDate) ?? DateTime.now();
    final timeStr = DateFormat('dd.MM.yyyy, HH:mm').format(date);
    final price =
        double.tryParse((item['total_price'] ?? 0).toString()) ?? 0;

    return _tileCard(
      icon: Icons.pending_actions_rounded,
      iconColor: color,
      title: (item['product_name'] ?? "Noma'lum").toString(),
      subtitle: (item['client_name'] ?? '').toString(),
      timeStr: timeStr,
      amountText: formatMoney(price),
      amountColor: color,
      badgeText: "QARZGA",
      badgeColor: color,
      borderColor: color.withOpacity(0.3),
    );
  }

  // Umumiy tile template
// Umumiy tile template
  Widget _tileCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String timeStr,
    required String amountText,
    required Color amountColor,
    required String badgeText,
    required Color badgeColor,
    Color? borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null
            ? Border.all(color: borderColor)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // <-- To'g'rilandi
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: TextStyle(
                          color: iconColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 2),
                Text(timeStr,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min, // <-- To'g'rilandi
            children: [
              Text(amountText,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: amountColor)),
              const SizedBox(height: 3),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(badgeText,
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
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
          CircularProgressIndicator(color: primaryColor),
          SizedBox(height: 12),
          Text("Yuklanmoqda...",
              style: TextStyle(color: Colors.grey, fontSize: 13)),
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
          Text(msg,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_rounded,
            color: Colors.grey.shade300, size: 60),
        const SizedBox(height: 12),
        Text(msg,
            style:
            TextStyle(color: Colors.grey.shade400, fontSize: 14)),
      ],
    );
  }
}

// ==========================================
// PINNED TAB BAR DELEGATE
// ==========================================

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _TabHeaderDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  double get maxExtent => 58;

  @override
  double get minExtent => 58;

  @override
  bool shouldRebuild(_TabHeaderDelegate old) => old.child != child;
}
