import 'package:flutter/material.dart';

import '../../data/seed_repository.dart';

class BuddyChatScreen extends StatefulWidget {
  const BuddyChatScreen({required this.buddyId, super.key});

  final String buddyId;

  @override
  State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}

class _BuddyChatScreenState extends State<BuddyChatScreen> {
  late Future<List<BuddyChatDemoMessage>> _demo;

  @override
  void initState() {
    super.initState();
    _demo = SeedRepository().loadBuddyChatDemo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat: ${widget.buddyId}')),
      body: FutureBuilder<List<BuddyChatDemoMessage>>(
        future: _demo,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final messages = snapshot.data!;
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isMe = message.sender == 'me';
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(message.text),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
