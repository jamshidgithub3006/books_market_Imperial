import 'package:http/http.dart' as http;

class TelegramBotService {
  static const String botToken = '8869478564:AAFTbch0tkeUKpEidClTG9imescE4GNu1HA';
  static const String chatId = '-1003727421583';

  static Future<void> sendMessage(String text) async {
    final url = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');

    try {
      final response = await http.post(
        url,
        body: {
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'HTML', // Yozuvlarni qalin chiqarish uchun
        },
      );

      if (response.statusCode == 200) {
      } else {
      }
    } catch (e) {
      print("❌");
    }
  }
}