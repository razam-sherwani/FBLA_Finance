import 'package:http/http.dart' as http;
import 'package:fbla_finance/backend/api_key.dart';

class ChatService {
  static final Uri chatUri = Uri.parse('https://api.openai.com/v1/chat/completions');

  static final Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${ApiKey.openAIApiKey}',
  };

  Future<String?> request(String text) async {
    String prompt = "Where are the places to visit in Istanbul?";
    try {
      var response = await http.post(
        chatUri,
        headers: headers,
        body: {},
      );
      return null;
    } catch (e) {
      print("error $e");
    }
  }
}