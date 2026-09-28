import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class BuddyReply {
  const BuddyReply({required this.reply, this.correction, this.explanation});

  final String reply;
  final String? correction;
  final String? explanation;

  factory BuddyReply.fromJson(Map<String, dynamic> json) => BuddyReply(
        reply: json['reply'] as String,
        correction: json['correction'] as String?,
        explanation: json['explanation'] as String?,
      );
}

class BuddyChatException implements Exception {
  BuddyChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BuddyChatApi {
  BuddyChatApi({required this.baseUrl, this.appToken = '', http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String appToken;
  final http.Client _client;

  Future<BuddyReply> sendMessage({
    required List<ChatMessage> history,
    required String message,
    required String level,
  }) async {
    final body = jsonEncode({
      'history': history
          .map((m) => {
                'role': m.sender == 'user' ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList(),
      'message': message,
      'level': level,
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/buddy/chat'),
            headers: {
              'Content-Type': 'application/json',
              if (appToken.isNotEmpty) 'X-App-Token': appToken,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw BuddyChatException("Can't reach your practice partner right now.");
    }

    if (response.statusCode == 429) {
      throw BuddyChatException('Daily practice limit reached, try again tomorrow.');
    }
    if (response.statusCode != 200) {
      throw BuddyChatException("Can't reach your practice partner right now.");
    }
    return BuddyReply.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
