import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../state/chat_provider.dart';

class AiBuddyScreen extends StatefulWidget {
  const AiBuddyScreen({super.key});

  @override
  State<AiBuddyScreen> createState() => _AiBuddyScreenState();
}

class _AiBuddyScreenState extends State<AiBuddyScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('AI Buddy')),
      body: Column(
        children: [
          if (chat.error != null)
            Container(
              key: const Key('ai_buddy_error'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(chat.error!),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: chat.messages.length,
              itemBuilder: (context, index) => _MessageBubble(message: chat.messages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(key: const Key('ai_buddy_input'), controller: _controller),
                ),
                IconButton(
                  key: const Key('ai_buddy_send'),
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    _controller.clear();
                    context.read<ChatProvider>().sendMessage(text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(message.text),
          ),
          if (message.correction != null)
            Container(
              key: const Key('ai_feedback_card'),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Correction: ${message.correction}'),
                  if (message.explanation != null) Text(message.explanation!),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
