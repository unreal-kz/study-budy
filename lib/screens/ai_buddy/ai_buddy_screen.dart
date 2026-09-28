import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../state/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/correction_card.dart';

enum AiBuddyViewMode { feedback, chat }

class AiBuddyScreen extends StatefulWidget {
  const AiBuddyScreen({super.key});

  @override
  State<AiBuddyScreen> createState() => _AiBuddyScreenState();
}

class _AiBuddyScreenState extends State<AiBuddyScreen> {
  final _controller = TextEditingController();
  AiBuddyViewMode _mode = AiBuddyViewMode.feedback;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ChatMessage> _lastExchange(List<ChatMessage> messages) {
    final lastUserIndex = messages.lastIndexWhere((m) => m.sender == 'user');
    if (lastUserIndex == -1) return const [];
    return messages.sublist(lastUserIndex);
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final isFeedback = _mode == AiBuddyViewMode.feedback;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Buddy'),
        actions: [
          IconButton(
            key: const Key('ai_buddy_mode_toggle'),
            icon: Icon(isFeedback ? Icons.forum_outlined : Icons.spellcheck),
            tooltip: isFeedback ? 'Switch to Chat' : 'Switch to Feedback',
            onPressed: () => setState(() {
              _mode = isFeedback ? AiBuddyViewMode.chat : AiBuddyViewMode.feedback;
            }),
          ),
          IconButton(
            key: const Key('ai_buddy_start_conversation'),
            icon: const Icon(Icons.mic_none),
            tooltip: 'Voice conversation — coming soon',
            onPressed: null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (chat.isSending)
            Column(
              children: [
                const LinearProgressIndicator(key: Key('ai_buddy_sending')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'Waking up your buddy — the first reply can take up to a minute.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.neutral500),
                  ),
                ),
              ],
            ),
          if (chat.error != null)
            Container(
              key: const Key('ai_buddy_error'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                chat.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          Expanded(
            child: isFeedback
                ? _FeedbackView(messages: _lastExchange(chat.messages))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) => _MessageBubble(message: chat.messages[index]),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.neutral150)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('ai_buddy_input'),
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: isFeedback ? 'Type a sentence to check…' : 'Type your message…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(color: AppColors.pine800, shape: BoxShape.circle),
                  child: IconButton(
                    key: const Key('ai_buddy_send'),
                    icon: Icon(isFeedback ? Icons.spellcheck : Icons.mic, color: Colors.white),
                    onPressed: chat.isSending
                        ? null
                        : () {
                            final text = _controller.text.trim();
                            if (text.isEmpty) return;
                            _controller.clear();
                            context.read<ChatProvider>().sendMessage(text);
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackView extends StatelessWidget {
  const _FeedbackView({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      final textTheme = Theme.of(context).textTheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Type a sentence below and get instant grammar feedback.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.neutral500),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [for (final message in messages) _MessageBubble(message: message)],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ChatBubble(text: message.text, isMine: isUser),
        if (message.correction != null)
          CorrectionCard(correction: message.correction!, explanation: message.explanation),
      ],
    );
  }
}
