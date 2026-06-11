import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String scriptUrl =
    "https://script.google.com/macros/s/AKfycbz5wgOLcrdL1XvjI4htOmue82s7TcWNavmG2B9r4tAPcGhjlwFYvXM21PzI9FT1VpBH/exec";

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {

  // ===============================
  // 🔧 VAQTNI TO'G'RI PARSE QILISH
  // "2026-06-09 15:44:59" formatini qabul qiladi
  // ===============================
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str == '-') return null;

    try {
      // Format 1: "2026-06-09 15:44:59" → ISO ga aylantir
      if (str.contains(' ') && !str.contains('T')) {
        final isoStr = str.replaceFirst(' ', 'T');
        return DateTime.parse(isoStr);
      }
      // Format 2: standart ISO "2026-06-09T15:44:59"
      return DateTime.parse(str);
    } catch (e) {
      // Format 3: timestamp (milliseconds)
      final ts = int.tryParse(str);
      if (ts != null) {
        return DateTime.fromMillisecondsSinceEpoch(ts);
      }
      return null;
    }
  }

  // ===============================
  // 🕐 VAQTNI CHIROYLI KO'RSATISH
  // ===============================
  static String formatDateTime(dynamic value) {
    final dt = parseDateTime(value);
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ===============================
  // 📡 POST so'rov yuborish
  // ===============================
  Future<http.Response> _sendPost(Map<String, dynamic> bodyData) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(scriptUrl))
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(bodyData)
        ..followRedirects = false;

      final streamedResponse = await client.send(request);
      var response = await http.Response.fromStream(streamedResponse);

      // 🔁 Redirect handle
      if (response.statusCode == 302 || response.statusCode == 303) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await http.get(Uri.parse(redirectUrl));
        }
      }

      return response;
    } finally {
      client.close();
    }
  }

  // ===============================
  // 📋 GET ALL
  // ===============================
  Future<List<dynamic>> getAll(String table) async {
    try {
      final response = await _sendPost({"action": "getAll", "table": table});
      final decoded = jsonDecode(response.body);

      if (decoded['status'] == 'success') {
        return decoded['data'] as List<dynamic>;
      } else {
        throw Exception(decoded['message']);
      }
    } catch (e) {
      throw Exception("Xatolik: $e");
    }
  }

  // ===============================
  // ➕ CREATE
  // ===============================
  Future<bool> addData(String table, Map<String, dynamic> data) async {
    try {
      final response = await _sendPost({
        "action": "add",
        "table": table,
        "data": data,
      });

      final decoded = jsonDecode(response.body);
      return decoded['status'] == 'success';
    } catch (e) {
      throw Exception("Qo'shishda xatolik: $e");
    }
  }

  // ===============================
  // ✏️ UPDATE
  // ===============================
  Future<bool> updateData(String table, Map<String, dynamic> data) async {
    if (!data.containsKey('id')) {
      throw Exception("'id' majburiy!");
    }

    try {
      final response = await _sendPost({
        "action": "update",
        "table": table,
        "id": data['id'],
        "data": data,
      });

      final decoded = jsonDecode(response.body);
      if (decoded['status'] == 'success') {
        return true;
      } else {
        throw Exception(decoded['message']);
      }
    } catch (e) {
      throw Exception("Update xato: $e");
    }
  }

  // ===============================
  // ❌ DELETE
  // ===============================
  Future<bool> deleteData(String table, String id) async {
    try {
      final response = await _sendPost({
        "action": "delete",
        "table": table,
        "id": id,
        "data": {"id": id},
      });

      final decoded = jsonDecode(response.body);
      if (decoded['status'] == 'success') {
        return true;
      } else {
        throw Exception(decoded['message']);
      }
    } catch (e) {
      throw Exception("Delete xato: $e");
    }
  }

  // ===============================
  // 💰 MAKE SALE
  // ===============================
  Future<bool> makeSale({
    required String serviceId,
    required String serviceName,
    required int count,
    required double totalPrice,
    required String paymentType,
    required String sellerName,
    String clientName = "-",
    String comment = "-",
  }) async {
    try {
      final requestData = {
        "action": "makeSale",
        "data": {
          "type": "product",
          "product_id": serviceId,
          "product_name": serviceName,
          "count": count,
          "total_price": totalPrice,
          "payment_type": paymentType,
          "seller_name": sellerName,
          "client_name": clientName,
          "comment": comment,
        }
      };

      final response = await _sendPost(requestData);
      final decoded = jsonDecode(response.body);

      if (decoded['status'] == 'success') {
        return true;
      } else {
        throw Exception("Server xatosi: ${decoded['message']}");
      }
    } catch (e) {
      throw Exception("Savdo xato: $e");
    }
  }

  // ===============================
  // 📊 SAVDOLARNI VAQT BO'YICHA FILTER QILISH
  // Masalan: 13:00 gacha, 13:00-16:30, kun oxiri
  // ===============================
  static List<Map<String, dynamic>> filterByTimeRange(
      List<dynamic> transactions, {
        int fromHour = 0,
        int fromMinute = 0,
        int toHour = 23,
        int toMinute = 59,
      }) {
    final result = <Map<String, dynamic>>[];

    for (final trx in transactions) {
      final map = trx as Map<String, dynamic>;
      final dt = parseDateTime(map['created_at'] ?? map['date'] ?? map['timestamp']);
      if (dt == null) continue;

      final fromMins = fromHour * 60 + fromMinute;
      final toMins = toHour * 60 + toMinute;
      final trxMins = dt.hour * 60 + dt.minute;

      if (trxMins >= fromMins && trxMins <= toMins) {
        result.add(map);
      }
    }

    return result;
  }
}