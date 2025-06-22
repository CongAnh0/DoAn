import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

class ChatGroupScreen extends StatefulWidget {
  final String courseId;
  final bool isNewMember;

  const ChatGroupScreen({
    Key? key,
    required this.courseId,
    this.isNewMember = false,
  }) : super(key: key);

  @override
  State<ChatGroupScreen> createState() => _ChatGroupScreenState();
}

class _ChatGroupScreenState extends State<ChatGroupScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final JitsiMeet _jitsiMeet = JitsiMeet(); // Khởi tạo JitsiMeet instance
  List<Map<String, dynamic>> _messages = [];
  String _groupName = '';
  bool _isUploading = false;
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadGroupData();
    _setupMessagesListener();
    _markAsRead();
  }

  Future<void> _loadGroupData() async {
    final snapshot = await _dbRef.child('courses/${widget.courseId}').once();
    final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
    setState(() {
      _groupName = data['title'] ?? 'Nhóm thảo luận';
    });
  }

  void _setupMessagesListener() {
    _dbRef
        .child('courses/${widget.courseId}/chatGroup/messages')
        .orderByChild('timestamp')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _messages = data.entries.map((entry) {
            return {
              'id': entry.key.toString(),
              ...(entry.value as Map<dynamic, dynamic>)
                  .map((k, v) => MapEntry(k.toString(), v)),
            };
          }).toList();
          _messages.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _currentUser == null) return;

    final messageRef =
    _dbRef.child('courses/${widget.courseId}/chatGroup/messages').push();

    await messageRef.set({
      'senderId': _currentUser.uid,
      'text': _messageController.text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'text',
    });

    _updateLastMessage(_messageController.text);
    _messageController.clear();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || _currentUser == null) return;

    setState(() => _isUploading = true);

    try {
      final file = File(image.path);
      final ref = _storage.ref().child(
          'chat_images/${widget.courseId}/${DateTime.now().millisecondsSinceEpoch}');
      final uploadTask = await ref.putFile(file);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      final messageRef =
      _dbRef.child('courses/${widget.courseId}/chatGroup/messages').push();

      await messageRef.set({
        'senderId': _currentUser.uid,
        'imageUrl': imageUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'image',
      });

      _updateLastMessage('Đã gửi 1 ảnh');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _updateLastMessage(String lastMessage) {
    if (_currentUser == null) return;

    final userChatsRef = _dbRef.child('userChats');
    final courseRef = _dbRef.child('courses/${widget.courseId}');

    courseRef.once().then((snapshot) {
      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final groupId = data['chatGroup']['groupId'].toString();
      userChatsRef.child('${_currentUser?.uid}/$groupId').update({
        'lastMessage': lastMessage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _markAsRead() {
    if (_currentUser == null) return;

    final userChatsRef = _dbRef.child('userChats');
    final courseRef = _dbRef.child('courses/${widget.courseId}');

    courseRef.once().then((snapshot) {
      final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
      final groupId = data['chatGroup']['groupId'].toString();
      userChatsRef.child('${_currentUser?.uid}/$groupId').update({
        'unreadCount': 0,
      });
    });
  }

  Future<void> _startVideoCall() async {
    try {
      final meetingId = 'course_${widget.courseId}'; // Phòng riêng theo từng khóa học

      // Sử dụng instance JitsiMeet đã được khởi tạo ở trên
      // Cấu hình cho cuộc họp - phải phù hợp với API version 10.1.0
      var options = JitsiMeetConferenceOptions(
        room: meetingId,
        serverURL: "https://meet.jit.si", // String thay vì Uri
        configOverrides: {
          "subject": 'Lớp học trực tuyến - $_groupName',
          "userInfo": {
            "displayName": _currentUser?.displayName ?? 'Thành viên',
            "email": _currentUser?.email ?? '',
          },
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
        },
      );
      // Tham gia cuộc họp
      await _jitsiMeet.join(options);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tạo phòng họp: $error')),
      );
    }
  }

  void _notifyMembersAboutCall(List<dynamic> members, String meetingId) {
    final callData = {
      'type': 'video_call',
      'courseId': widget.courseId,
      'meetingId': meetingId,
      'initiator': _currentUser?.uid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    for (final memberId in members) {
      if (memberId != _currentUser?.uid) {
        _dbRef.child('userNotifications/$memberId').push().set(callData);
      }
    }
  }

  void _navigateToHomePage() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fullName = userDoc.data()?['fullName'] ?? 'Người dùng';
      _userNameCache[userId] = fullName;
      return fullName;
    } catch (e) {
      return 'Người dùng';
    }
  }

  Widget _buildTextMessage(Map<String, dynamic> message, bool isMe, String senderName) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[600] : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            Text(
              message['text'] ?? '',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm dd/MM').format(
                DateTime.fromMillisecondsSinceEpoch(message['timestamp']),
              ),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> message, bool isMe, String senderName) {
    return GestureDetector(
      onTap: () {
        // Xem ảnh toàn màn hình
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                    senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  message['imageUrl'],
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[800],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  DateFormat('HH:mm dd/MM').format(
                    DateTime.fromMillisecondsSinceEpoch(message['timestamp']),
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: _startVideoCall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['senderId'] == _currentUser?.uid;

                return FutureBuilder<String>(
                  future: _getUserName(message['senderId']),
                  builder: (context, snapshot) {
                    final senderName = snapshot.data ?? 'Người dùng';

                    switch (message['type']) {
                      case 'image':
                        return _buildImageMessage(message, isMe, senderName);
                      default:
                        return _buildTextMessage(message, isMe, senderName);
                    }
                  },
                );
              },
            ),
          ),
          if (_isUploading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}