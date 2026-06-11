import 'dart:async';
import 'package:intl/intl.dart';
// Fayl manzillarini o'zingizdagi papkalarga qarab to'g'rilang:
import '../services/api_service.dart';
import '../models/telegram_bot.dart';

class AutoReportService {
  static DateTime? _lastSentTime;

  static void startTimer(ApiService api) {
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      final now = DateTime.now();

      // Faqat soat 13:00 va 18:00 da triggersiz ishlashi uchun
      bool isTimeToSend = (now.hour == 13 && now.minute == 0) ||
          (now.hour == 18 && now.minute == 0);

      if (isTimeToSend) {
        if (_lastSentTime != null &&
            _lastSentTime!.day == now.day &&
            _lastSentTime!.hour == now.hour &&
            _lastSentTime!.minute == now.minute) {
          return;
        }
        _lastSentTime = now;
        await _generateAndSendReport(api, now);
      }
    });
  }

  static DateTime? _parseDate(dynamic rawDate) {
    if (rawDate == null || rawDate.toString().isEmpty) return null;
    String dateStr = rawDate.toString().trim();

    RegExp regExp = RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}');
    final match = regExp.firstMatch(dateStr);

    if (match != null) {
      dateStr = match.group(0)!;
    } else {
      dateStr = dateStr.replaceAll("Z", "").replaceAll("T", " ");
      if (dateStr.length > 19) {
        dateStr = dateStr.substring(0, 19);
      }
    }

    try {
      return DateTime.parse(dateStr.replaceAll(" ", "T"));
    } catch (e) {
      try {
        return DateFormat("yyyy-MM-dd HH:mm:ss").parse(dateStr);
      } catch (e2) {
        return null;
      }
    }
  }

  // Pullarni chiroyli formatlash + "UZS" qo'shimchasi bilan
  static String fmt(double amount) {
    return "${NumberFormat.decimalPattern('vi').format(amount).replaceAll('.', ' ')} UZS";
  }

  static Future<void> _generateAndSendReport(ApiService api, DateTime now) async {
    try {
      final savdoData = await api.getAll("savdo_tarixlari");
      final qarzData = await api.getAll("qarzdorlar");

      String todayStr = DateFormat('yyyy-MM-dd').format(now);

      // TUSHKI SMENA (08:00 - 13:00)
      double mNaqd = 0, mPlastik = 0, mQarzTolovi = 0, mYangiQarz = 0;
      int mSavdoSoni = 0;

      // KECHKI SMENA (13:00 - 18:00)
      double aNaqd = 0, aPlastik = 0, aQarzTolovi = 0, aYangiQarz = 0;
      int aSavdoSoni = 0;

      for (var item in savdoData) {
        DateTime? date = _parseDate(item['created_at'] ?? item['createdAt']);

        if (date != null && DateFormat('yyyy-MM-dd').format(date) == todayStr) {
          double price = double.tryParse((item['total_price'] ?? 0).toString()) ?? 0;
          String type = (item['payment_type'] ?? "").toString().toLowerCase();
          String itemName = (item['product_name'] ?? item['item_name'] ?? "").toString().toLowerCase();
          bool isDebtPayment = itemName.contains("qarz to'lovi") || itemName.contains("qarz");

          if (date.hour >= 8 && date.hour < 13) {
            if (type == 'naqd') mNaqd += price;
            if (type == 'plastic' || type == 'plastik') mPlastik += price;
            if (type == 'qarz') mYangiQarz += price;
            if (isDebtPayment) mQarzTolovi += price;
            mSavdoSoni++;
          } else if (date.hour >= 13 && date.hour < 18) {
            if (type == 'naqd') aNaqd += price;
            if (type == 'plastic' || type == 'plastik') aPlastik += price;
            if (type == 'qarz') aYangiQarz += price;
            if (isDebtPayment) aQarzTolovi += price;
            aSavdoSoni++;
          }
        }
      }

      int faolQarzdorlarSoni = 0;
      double umumiyQarzSummasi = 0;

      for (var debtor in qarzData) {
        String status = (debtor['status'] ?? "").toString().toLowerCase();
        if (status != 'paid' && status != 'returned') {
          double debt = double.tryParse((debtor['qarz_price'] ?? 0).toString()) ?? 0;
          double paid = double.tryParse((debtor['tolanga_summa'] ?? 0).toString()) ?? 0;
          double qoldiq = debt - paid;

          if (qoldiq > 0) {
            faolQarzdorlarSoni++;
            umumiyQarzSummasi += qoldiq;
          }
        }
      }

      List<String> oylar = ["Yanvar", "Fevral", "Mart", "Aprel", "May", "Iyun", "Iyul", "Avgust", "Sentabr", "Oktabr", "Noyabr", "Dekabr"];
      String oyNomi = oylar[now.month - 1];
      String message = "";

      if (now.hour == 13 && now.minute >= 30 && now.minute < 32) {
        // ☀️ ULTRA TUSHKI HISOBOT (08:00 - 13:30)
        message = """
🚀 <b>TUSHKI KASSA HISOBOTI</b>
📅 SANA: <code>${now.day} $oyNomi, ${now.year}</code>
⏰ VAQT: <code>13:00</code> (Smena: 08:00 - 13:30)
━━━━━━━━━━━━━━━━━━━━━━

💵 Naqd tushum:    <code>${fmt(mNaqd)}</code>
💳 Plastik tushum: <code>${fmt(mPlastik)}</code>
🤝 Qarz to'lovi:   <code>${fmt(mQarzTolovi)}</code>
📙 Yangi qarzlar:  <code>${fmt(mYangiQarz)}</code>
🧾 Cheklar soni:   <code>$mSavdoSoni ta</code>

• — — — — — — — — — — •
💰 <b>TUSHKI JAMI:</b>   <code>${fmt(mNaqd + mPlastik)}</code>
━━━━━━━━━━━━━━━━━━━━━━

👥 <b>QARZDORLIK STATISTIKASI:</b>
⚠️ Faol mijozlar:  <code>$faolQarzdorlarSoni kishi</code>
📉 Umumiy qarz:    <code>${fmt(umumiyQarzSummasi)}</code>

#hisobot #tushki_kassa #savdo #$oyNomi
""";

      } else if (now.hour == 18 && now.minute >= 30 && now.minute < 32) {
        // 🌙 ULTRA YAKUNIY HISOBOT (13:00 - 18:00 va Kunlik)
        double kunlikNaqd = mNaqd + aNaqd;
        double kunlikPlastik = mPlastik + aPlastik;
        double kunlikQarzTolovi = mQarzTolovi + aQarzTolovi;
        double kunlikYangiQarz = mYangiQarz + aYangiQarz;
        int kunlikSavdo = mSavdoSoni + aSavdoSoni;

        message = """
🏁 <b>YAKUNIY KASSA HISOBOTI</b>
📅 SANA: <code>${now.day} $oyNomi, ${now.year}</code>
⏰ VAQT: <code>18:00</code> (Kunlik yakun)
━━━━━━━━━━━━━━━━━━━━━━

🏢 <b>KECHKI SMENA (13:30 - 18:00):</b>
💵 Naqd:           <code>${fmt(aNaqd)}</code>
💳 Plastik:        <code>${fmt(aPlastik)}</code>
🤝 Qarz yopildi:   <code>${fmt(aQarzTolovi)}</code>
📙 Qarzga berildi: <code>${fmt(aYangiQarz)}</code>
🧾 Cheklar soni:   <code>$aSavdoSoni ta</code>
💎 <b>SMENA JAMI:</b>     <code>${fmt(aNaqd + aPlastik)}</code>

━━━━━━━━━━━━━━━━━━━━━━

📊 <b>BUGUNGI UMUMIY (08:00 - 18:00):</b>
💵 Jami Naqd:      <code>${fmt(kunlikNaqd)}</code>
💳 Jami Plastik:   <code>${fmt(kunlikPlastik)}</code>
🤝 Jami undiruv:   <code>${fmt(kunlikQarzTolovi)}</code>
📙 Jami berildi:   <code>${fmt(kunlikYangiQarz)}</code>
🧾 Jami cheklar:   <code>$kunlikSavdo ta</code>
🔥 <b>KUNLIK JAMI:</b>    <code>${fmt(kunlikNaqd + kunlikPlastik)}</code>

━━━━━━━━━━━━━━━━━━━━━━

👥 <b>QARZDORLIK STATISTIKASI:</b>
⚠️ Faol mijozlar:  <code>$faolQarzdorlarSoni kishi</code>
📉 Jami qarzlar:   <code>${fmt(umumiyQarzSummasi)}</code>

#yakuniy_hisobot #kassa_yakun #kunlik #$oyNomi
""";
      }

      if (message.isNotEmpty) {
        await TelegramBotService.sendMessage(message);
      }

    } catch (e) {
      print("❌ Avtomatik hisobot yuborishda xatolik !");
    }
  }
}