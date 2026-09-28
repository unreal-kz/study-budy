class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.correction,
    this.explanation,
    required this.createdAt,
  });

  final String id;
  final String sender; // 'user' | 'ai'
  final String text;
  final String? correction;
  final String? explanation;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'correction': correction,
        'explanation': explanation,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        sender: json['sender'] as String,
        text: json['text'] as String,
        correction: json['correction'] as String?,
        explanation: json['explanation'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
