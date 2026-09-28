import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/buddy.dart';
import '../models/community_group.dart';

class BuddyChatDemoMessage {
  const BuddyChatDemoMessage({required this.sender, required this.text});

  final String sender; // 'buddy' | 'me'
  final String text;

  factory BuddyChatDemoMessage.fromJson(Map<String, dynamic> json) =>
      BuddyChatDemoMessage(
        sender: json['sender'] as String,
        text: json['text'] as String,
      );
}

class SeedRepository {
  Future<List<Buddy>> loadBuddies() async {
    final raw = await rootBundle.loadString('assets/seed/buddies.json');
    return (jsonDecode(raw) as List)
        .map((e) => Buddy.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityGroup>> loadCommunityGroups() async {
    final raw = await rootBundle.loadString('assets/seed/community.json');
    return (jsonDecode(raw) as List)
        .map((e) => CommunityGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BuddyChatDemoMessage>> loadBuddyChatDemo() async {
    final raw = await rootBundle.loadString('assets/seed/buddy_chat_demo.json');
    return (jsonDecode(raw) as List)
        .map((e) => BuddyChatDemoMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
