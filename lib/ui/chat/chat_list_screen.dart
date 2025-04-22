import 'dart:async'; // THÊM DÒNG NÀY

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_group_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _chats = [];

  StreamSubscription<DatabaseEvent>? _chatSubscription; // <-- THÊM DÒNG NÀY

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  void _loadChats() {
    if (_currentUser == null) return;

    _chatSubscription = _dbRef
        .child('userChats/${_currentUser!.uid}')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _chats = data.entries.map((entry) {
            return {
              'groupId': entry.key.toString(),
              ...(entry.value as Map<dynamic, dynamic>).map((k, v) => MapEntry(k.toString(), v)),
            };
          }).toList();
          _chats.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        });
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel(); // <-- HỦY ĐĂNG KÝ STREAM KHI RỜI MÀN
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tin nhắn')),
      body: _currentUser == null
          ? const Center(child: Text('Vui lòng đăng nhập'))
          : ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(chat['name']?.substring(0, 1) ?? '?'),
            ),
            title: Text(chat['name'] ?? 'Group chat'),
            subtitle: Text(chat['lastMessage'] ?? ''),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatTimestamp(chat['timestamp']),
                  style: const TextStyle(fontSize: 12),
                ),
                if ((chat['unreadCount'] ?? 0) > 0)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chat['unreadCount'].toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatGroupScreen(
                    courseId: chat['courseId'],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    } else if (date.year == now.year) {
      return DateFormat('dd/MM').format(date);
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }
}
