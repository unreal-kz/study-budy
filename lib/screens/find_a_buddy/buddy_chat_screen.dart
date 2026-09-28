import 'package:flutter/material.dart';

import '../../data/seed_repository.dart';
import '../../models/buddy.dart';
import '../../widgets/buddy_card.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/initial_avatar.dart';

class BuddyChatScreen extends StatefulWidget {
  const BuddyChatScreen({required this.buddyId, super.key});

  final String buddyId;

  @override
  State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}

class _BuddyChatScreenState extends State<BuddyChatScreen> {
  late Future<List<BuddyChatDemoMessage>> _demo;
  late Future<Buddy?> _buddy;

  @override
  void initState() {
    super.initState();
    _demo = SeedRepository().loadBuddyChatDemo();
    _buddy = SeedRepository().loadBuddies().then(
          (buddies) => buddies.where((b) => b.id == widget.buddyId).firstOrNull,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: FutureBuilder<Buddy?>(
          future: _buddy,
          builder: (context, snapshot) {
            final buddy = snapshot.data;
            final name = buddy?.name ?? widget.buddyId;
            return Row(
              children: [
                InitialAvatar(
                  initial: name.isEmpty ? '?' : name[0].toUpperCase(),
                  color: buddy == null ? Colors.grey : avatarColorForId(buddy.id),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(name),
              ],
            );
          },
        ),
        actions: const [
          IconButton(onPressed: null, icon: Icon(Icons.call_outlined)),
          IconButton(onPressed: null, icon: Icon(Icons.videocam_outlined)),
          SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<BuddyChatDemoMessage>>(
        future: _demo,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final messages = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return ChatBubble(text: message.text, isMine: message.sender == 'me');
            },
          );
        },
      ),
    );
  }
}
