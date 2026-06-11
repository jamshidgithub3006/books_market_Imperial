import 'dart:async';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/telegram_bot.dart';

class AutoReportService {
  static DateTime? _lastSentTime;

  static void startTimer(ApiService api) {
    print("🤖 AutoReportService ishga tushdi...");

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      final now = DateTime.now().toLocal();

      bool isTushki  = now.hour == 13 && now.minute == 30;
      bool isYakuniy = now.hour == 18 && now.minute == 0;

      if (!isTushki && !isYakuniy) return;

      if (_lastSentTime != null &&
          _lastSentTime!.day    == now.day &&
          _lastSentTime!.hour   == now.hour &&
          _lastSentTime!.minute == now.minute) return;

      _lastSentTime = now;
      String reportType = isTushki ? "tushki" : "yakuniy";
      await _generateAndSendReport(api, now, reportType: reportType);
    });
  }

  static DateTime? _parseDate(dynamic rawDate) {
    if (rawDate == null || rawDate.toString().isEmpty) return null;
    String dateStr = rawDate.toString().trim();
    try {
      return DateTime.parse(dateStr).toLocal();
    } catch (_) {
      try {
        String clean = dateStr.replaceAll("Z", "").replaceAll("T", " ");
        if (clean.length > 19) clean = clean.substring(0, 19);
        return DateFormat("yyyy-MM-dd HH:mm:ss").parse(clean).toLocal();
      } catch (_) {
        return null;
      }
    }
  }

  static String fmt(double amount) {
    return "${NumberFormat.decimalPattern('vi').format(amount).replaceAll('.', ' ')} UZS";
  }

  static Future<void> _generateAndSendReport(
      ApiService api,
      DateTime now, {
        required String reportType,
      }) async {
    try {
      final savdoData = await api.getAll("savdo_tarixlari");
      final qarzData  = await api.getAll("qarzdorlar");

      final localNow  = now.toLocal();
      String todayStr = DateFormat('yyyy-MM-dd').format(localNow);

      double s1Naqd = 0, s1Plastik = 0, s1QarzTolovi = 0, s1YangiQarz = 0;
      int    s1Soni = 0;

      double s2Naqd = 0, s2Plastik = 0, s2QarzTolovi = 0, s2YangiQarz = 0;
      int    s2Soni = 0;

      for (var item in savdoData) {
        DateTime? date = _parseDate(item['created_at'] ?? item['createdAt'] ?? item['date']);
        if (date == null) continue;
        if (DateFormat('yyyy-MM-dd').format(date) != todayStr) continue;

        String rawPrice   = (item['total_price'] ?? item['price'] ?? item['summa'] ?? 0).toString();
        String cleanPrice = rawPrice.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '');
        double price      = double.tryParse(cleanPrice) ?? 0;

        String type      = (item['payment_type'] ?? item['type'] ?? "").toString().toLowerCase().trim();
        String itemName  = (item['product_name']  ?? item['item_name'] ?? "").toString().toLowerCase();

        bool isDebtPayment = itemName.contains("qarz to'lovi") ||
            itemName.contains("qarz to")      ||
            itemName.contains("qarz tolovi");

        if (date.hour >= 8 && date.hour < 13) {
          if (isDebtPayment)                                     s1QarzTolovi += price;
          else if (type == 'naqd')                               s1Naqd       += price;
          else if (type == 'plastic' || type == 'plastik')       s1Plastik    += price;
          else if (type == 'qarz')                               s1YangiQarz  += price;
          s1Soni++;
        } else if (date.hour >= 13 && date.hour < 18) {
          if (isDebtPayment)                                     s2QarzTolovi += price;
          else if (type == 'naqd')                               s2Naqd       += price;
          else if (type == 'plastic' || type == 'plastik')       s2Plastik    += price;
          else if (type == 'qarz')                               s2YangiQarz  += price;
          s2Soni++;
        }
      }

      int    faolSoni   = 0;
      double umumiyQarz = 0;

      for (var debtor in qarzData) {
        String status = (debtor['status'] ?? "").toString().toLowerCase();
        if (status == 'paid' || status == 'returned') continue;

        double debt   = double.tryParse((debtor['qarz_price']    ?? 0).toString().replaceAll(RegExp(r'\s+'), '')) ?? 0;
        double paid   = double.tryParse((debtor['tolanga_summa'] ?? 0).toString().replaceAll(RegExp(r'\s+'), '')) ?? 0;
        double qoldiq = debt - paid;

        if (qoldiq > 0) { faolSoni++; umumiyQarz += qoldiq; }
      }

      const oylar = ["Yanvar","Fevral","Mart","Aprel","May","Iyun",
        "Iyul","Avgust","Sentabr","Oktabr","Noyabr","Dekabr"];
      String oyNomi  = oylar[localNow.month - 1];
      String message = '';

      if (reportType == "tushki") {
        message = """
🌅 <b>TUSHKI KASSA HISOBOTI</b>
📅 SANA: <code>${localNow.day} $oyNomi, ${localNow.year}</code>
⏰ SMENA: <code>08:00 → 13:00</code>
━━━━━━━━━━━━━━━━━━━━━━

💵 Naqd tushum:    <code>${fmt(s1Naqd)}</code>
💳 Plastik tushum: <code>${fmt(s1Plastik)}</code>
🤝 Qarz to'lovi:   <code>${fmt(s1QarzTolovi)}</code>
📙 Yangi qarzlar:  <code>${fmt(s1YangiQarz)}</code>
🧾 Cheklar soni:   <code>$s1Soni ta</code>

- — — — — — — — — — — •
💰 <b>SMENA JAMI:</b>    <code>${fmt(s1Naqd + s1Plastik)}</code>
━━━━━━━━━━━━━━━━━━━━━━

👥 <b>QARZDORLIK HOLATI:</b>
⚠️ Faol mijozlar:  <code>$faolSoni kishi</code>
📉 Umumiy qarz:    <code>${fmt(umumiyQarz)}</code>

#tushki_hisobot #smena1 #$oyNomi
""";
      } else {
        double kunlikNaqd       = s1Naqd       + s2Naqd;
        double kunlikPlastik    = s1Plastik    + s2Plastik;
        double kunlikQarzTolovi = s1QarzTolovi + s2QarzTolovi;
        double kunlikYangiQarz  = s1YangiQarz  + s2YangiQarz;
        int    kunlikSoni       = s1Soni       + s2Soni;

        message = """
🏁 <b>YAKUNIY KASSA HISOBOTI</b>
📅 SANA: <code>${localNow.day} $oyNomi, ${localNow.year}</code>
⏰ SMENA: <code>13:00 → 18:00</code>
━━━━━━━━━━━━━━━━━━━━━━

🏢 <b>KECHKI SMENA (13:00 – 18:00):</b>
💵 Naqd:           <code>${fmt(s2Naqd)}</code>
💳 Plastik:        <code>${fmt(s2Plastik)}</code>
🤝 Qarz to'lovi:   <code>${fmt(s2QarzTolovi)}</code>
📙 Qarzga berildi: <code>${fmt(s2YangiQarz)}</code>
🧾 Cheklar soni:   <code>$s2Soni ta</code>
💎 <b>SMENA JAMI:</b>     <code>${fmt(s2Naqd + s2Plastik)}</code>

━━━━━━━━━━━━━━━━━━━━━━

📊 <b>BUGUNGI UMUMIY (08:00 – 18:00):</b>
💵 Jami Naqd:      <code>${fmt(kunlikNaqd)}</code>
💳 Jami Plastik:   <code>${fmt(kunlikPlastik)}</code>
🤝 Jami undiruv:   <code>${fmt(kunlikQarzTolovi)}</code>
📙 Jami berildi:   <code>${fmt(kunlikYangiQarz)}</code>
🧾 Jami cheklar:   <code>$kunlikSoni ta</code>
🔥 <b>KUNLIK JAMI:</b>    <code>${fmt(kunlikNaqd + kunlikPlastik)}</code>

━━━━━━━━━━━━━━━━━━━━━━

👥 <b>QARZDORLIK STATISTIKASI:</b>
⚠️ Faol mijozlar:  <code>$faolSoni kishi</code>
📉 Jami qarzlar:   <code>${fmt(umumiyQarz)}</code>

#yakuniy_hisobot #kassa_yakun #kunlik #$oyNomi
""";
      }

      await TelegramBotService.sendMessage(message);
      print("✅ [$reportType] Telegram'ga yuborildi.");

    } catch (e) {
      print("❌ Xatolik: $e");
    }
  }
}