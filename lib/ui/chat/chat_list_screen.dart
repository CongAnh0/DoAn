import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_group_screen.dart';
import 'private_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Chat nhóm
  List<Map<String, dynamic>> _groupChats = [];
  bool _isLoadingGroupChats = true;
  Map<String, String> _courseNames = {}; // Lưu cache tên khóa học
  StreamSubscription<DatabaseEvent>? _groupChatSubscription;

  // Chat cá nhân
  List<Map<String, dynamic>> _privateChats = [];
  bool _isLoadingPrivateChats = true;
  StreamSubscription<QuerySnapshot>? _privateChatSubscription;

  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCourseNames(); // Tải tên khóa học trước
    _loadPrivateChats(); // Tải danh sách chat cá nhân
  }

  // Hàm này tải tất cả tên khóa học từ Firebase
  Future<void> _loadCourseNames() async {
    try {
      DataSnapshot snapshot = await _dbRef.child('courses').get();
      if (snapshot.value != null) {
        final coursesData = snapshot.value as Map<dynamic, dynamic>;

        // Lưu tên của tất cả khóa học
        coursesData.forEach((key, value) {
          if (value is Map && value.containsKey('name')) {
            _courseNames[key.toString()] = value['name'].toString();
          }
        });

        // Sau khi có tên khóa học, tải danh sách chat nhóm
        _loadGroupChats();
      } else {
        _loadGroupChats(); // Vẫn tải chat nếu không có dữ liệu khóa học
      }
    } catch (e) {
      print('Error loading course names: $e');
      _loadGroupChats(); // Vẫn tải chat nếu có lỗi
    }
  }

  void _loadGroupChats() {
    if (_currentUser == null) {
      setState(() {
        _isLoadingGroupChats = false;
      });
      return;
    }

    _groupChatSubscription = _dbRef
        .child('userChats/${_currentUser.uid}')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> chatsList = [];

        data.forEach((key, value) {
          String courseId = key.toString();
          Map<dynamic, dynamic> chatData = value as Map<dynamic, dynamic>;

          chatsList.add({
            'groupId': courseId,
            'courseId': courseId,
            // Sử dụng tên khóa học từ cache, nếu không có thì dùng fallback
            'name': _courseNames[courseId] ?? 'Khóa học $courseId',
            'lastMessage': chatData['lastMessage'] ?? '',
            'timestamp': chatData['timestamp'] ?? 0,
            'unreadCount': chatData['unreadCount'] ?? 0,
            'isGroup': true,
          });
        });

        // Sắp xếp chat theo timestamp
        chatsList.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

        if (mounted) {
          setState(() {
            _groupChats = chatsList;
            _isLoadingGroupChats = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _groupChats = [];
            _isLoadingGroupChats = false;
          });
        }
      }
    }, onError: (error) {
      print('Error loading group chats: $error');
      if (mounted) {
        setState(() {
          _isLoadingGroupChats = false;
        });
      }
    });
  }

  void _loadPrivateChats() {
    if (_currentUser == null) {
      setState(() {
        _isLoadingPrivateChats = false;
      });
      return;
    }

    _privateChatSubscription = _firestore
        .collection('userPrivateChats')
        .doc(_currentUser.uid)
        .collection('chats')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final List<Map<String, dynamic>> chatsList = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final timestamp = data['timestamp'] as Timestamp?;

          chatsList.add({
            'userId': data['userId'] ?? '',
            'name': data['name'] ?? 'Người dùng',
            'email': data['email'] ?? '',
            'lastMessage': data['lastMessage'] ?? '',
            'timestamp': timestamp != null ? timestamp.millisecondsSinceEpoch : 0,
            'unreadCount': data['unreadCount'] ?? 0,
            'isGroup': false,
          });
        }

        if (mounted) {
          setState(() {
            _privateChats = chatsList;
            _isLoadingPrivateChats = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _privateChats = [];
            _isLoadingPrivateChats = false;
          });
        }
      }
    }, onError: (error) {
      print('Error loading private chats: $error');
      if (mounted) {
        setState(() {
          _isLoadingPrivateChats = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _groupChatSubscription?.cancel();
    _privateChatSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Nhóm'),
            Tab(text: 'Cá nhân'),
          ],
        ),
      ),
      body: _currentUser == null
          ? const Center(child: Text('Vui lòng đăng nhập'))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildGroupChatList(),
          _buildPrivateChatList(),
        ],
      ),
    );
  }

  Widget _buildGroupChatList() {
    if (_isLoadingGroupChats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_groupChats.isEmpty) {
      return const Center(child: Text('Không có cuộc trò chuyện nhóm nào'));
    }

    return ListView.builder(
      itemCount: _groupChats.length,
      itemBuilder: (context, index) {
        final chat = _groupChats[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Text(
              chat['name']?.isNotEmpty == true
                  ? chat['name'].substring(0, 1)
                  : '?',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            chat['name'] ?? 'Nhóm chat',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(chat['lastMessage'] ?? ''),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(chat['timestamp'] ?? 0),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
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
    );
  }

  Widget _buildPrivateChatList() {
    if (_isLoadingPrivateChats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_privateChats.isEmpty) {
      return const Center(child: Text('Không có cuộc trò chuyện cá nhân nào'));
    }

    return ListView.builder(
      itemCount: _privateChats.length,
      itemBuilder: (context, index) {
        final chat = _privateChats[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Text(
              chat['name']?.isNotEmpty == true
                  ? chat['name'].substring(0, 1)
                  : '?',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            chat['name'] ?? 'Người dùng',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(chat['lastMessage'] ?? ''),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(chat['timestamp'] ?? 0),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
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
                builder: (context) => PrivateChatScreen(
                  friendId: chat['userId'],
                  friendName: chat['name'] ?? 'Người dùng',
                  friendEmail: chat['email'],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return '';

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