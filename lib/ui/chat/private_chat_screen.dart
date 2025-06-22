import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum MessageType {
  text,
  image,
  file,
}

class PrivateChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String friendEmail;

  const PrivateChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    required this.friendEmail,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _chatId;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    if (_auth.currentUser == null) return;

    final currentUserId = _auth.currentUser!.uid;

    // Cách tạo chat ID: sắp xếp 2 ID người dùng theo thứ tự để đảm bảo tính nhất quán
    final userIds = [currentUserId, widget.friendId]..sort();
    _chatId = '${userIds[0]}_${userIds[1]}';

    // Kiểm tra xem đã có chat tồn tại chưa
    final chatDoc = await _firestore.collection('privateChats').doc(_chatId).get();

    if (!chatDoc.exists) {
      // Tạo mới chat nếu chưa tồn tại
      await _firestore.collection('privateChats').doc(_chatId).set({
        'participants': [currentUserId, widget.friendId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    // Cập nhật trạng thái đọc cho người dùng hiện tại
    await _firestore.collection('privateChats').doc(_chatId).collection('readStatus').doc(currentUserId).set({
      'lastRead': FieldValue.serverTimestamp(),
    });

    setState(() {}); // Cập nhật UI sau khi đã có chatId
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({
    required MessageType type,
    String? text,
    String? fileUrl,
    String? fileName,
    String? fileType,
  }) async {
    if (_chatId == null || _auth.currentUser == null) return;

    if (type == MessageType.text && (text == null || text.trim().isEmpty)) return;
    if ((type == MessageType.image || type == MessageType.file) && fileUrl == null) return;

    final currentUser = _auth.currentUser!;
    final messageText = text?.trim() ?? '';
    if (type == MessageType.text) {
      _messageController.clear();
    }

    try {
      // Tạo dữ liệu tin nhắn tùy thuộc vào loại tin nhắn
      Map<String, dynamic> messageData = {
        'senderId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type.toString().split('.').last,
      };

      // Thêm dữ liệu tùy theo loại tin nhắn
      switch (type) {
        case MessageType.text:
          messageData['text'] = messageText;
          break;
        case MessageType.image:
          messageData['imageUrl'] = fileUrl;
          messageData['text'] = 'Đã gửi một hình ảnh';
          break;
        case MessageType.file:
          messageData['fileUrl'] = fileUrl;
          messageData['fileName'] = fileName;
          messageData['fileType'] = fileType;
          messageData['text'] = 'Đã gửi một tệp: $fileName';
          break;
      }

      // Thêm tin nhắn vào collection messages của chat
      await _firestore.collection('privateChats').doc(_chatId).collection('messages').add(messageData);

      // Cập nhật thông tin tin nhắn cuối cùng
      String lastMessagePreview = '';
      switch (type) {
        case MessageType.text:
          lastMessagePreview = messageText;
          break;
        case MessageType.image:
          lastMessagePreview = '📷 Hình ảnh';
          break;
        case MessageType.file:
          lastMessagePreview = '📄 Tệp: $fileName';
          break;
      }

      await _firestore.collection('privateChats').doc(_chatId).update({
        'lastMessage': lastMessagePreview,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Cập nhật trạng thái đọc cho người gửi
      await _firestore.collection('privateChats').doc(_chatId).collection('readStatus').doc(currentUser.uid).set({
        'lastRead': FieldValue.serverTimestamp(),
      });

      // Cập nhật thông tin tin nhắn chưa đọc cho người nhận
      _firestore.collection('privateChats').doc(_chatId).collection('readStatus').doc(widget.friendId).get().then((doc) {
        if (!doc.exists) {
          _firestore.collection('privateChats').doc(_chatId).collection('readStatus').doc(widget.friendId).set({
            'lastRead': null,
          });
        }
      });

      // Cập nhật danh sách chat của người dùng
      _updateUserChatsList(currentUser.uid, widget.friendId, lastMessagePreview);
      _updateUserChatsList(widget.friendId, currentUser.uid, lastMessagePreview);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateUserChatsList(String userId, String otherId, String lastMessage) async {
    // Lấy thông tin người dùng kia
    DocumentSnapshot otherUserDoc = await _firestore.collection('users').doc(otherId).get();
    String otherName = 'Người dùng';

    if (otherUserDoc.exists) {
      final data = otherUserDoc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('fullName')) {
        otherName = data['fullName'] ?? 'Người dùng';
      }
    }

    // Cập nhật danh sách chat cá nhân cho người dùng
    await _firestore.collection('userPrivateChats').doc(userId).collection('chats').doc(otherId).set({
      'chatId': _chatId,
      'userId': otherId,
      'name': otherName,
      'lastMessage': lastMessage,
      'timestamp': FieldValue.serverTimestamp(),
      'unreadCount': FieldValue.increment(userId == otherId ? 0 : 1),
    }, SetOptions(merge: true));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _isUploading = true;
        });

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(pickedFile.path)}';
        final destination = 'chat_images/$_chatId/$fileName';

        final file = File(pickedFile.path);
        final ref = _storage.ref().child(destination);
        final uploadTask = ref.putFile(file);

        final snapshot = await uploadTask.whenComplete(() {});
        final downloadUrl = await snapshot.ref.getDownloadURL();

        await _sendMessage(
          type: MessageType.image,
          fileUrl: downloadUrl,
        );

        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải ảnh lên: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isUploading = true;
        });

        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final fileExtension = fileName.split('.').last.toLowerCase();

        final destination = 'chat_files/$_chatId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

        final file = File(filePath);
        final ref = _storage.ref().child(destination);
        final uploadTask = ref.putFile(file);

        final snapshot = await uploadTask.whenComplete(() {});
        final downloadUrl = await snapshot.ref.getDownloadURL();

        await _sendMessage(
          type: MessageType.file,
          fileUrl: downloadUrl,
          fileName: fileName,
          fileType: fileExtension,
        );

        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải tệp lên: ${e.toString()}')),
      );
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Gửi tệp (PDF, DOC, ...)'),
              onTap: () {
                Navigator.of(context).pop();
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải tệp, vui lòng đợi...')),
      );

      // Trong ứng dụng thực tế, bạn cần tải tệp xuống bộ nhớ tạm trước khi mở
      // Ở đây sử dụng thư viện open_file để mở URL (lưu ý: có thể không hoạt động với một số URL)
      await OpenFile.open(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở tệp: ${e.toString()}')),
      );
    }
  }

  Widget _buildMessageItem(Map<String, dynamic> message, bool isMe) {
    final messageType = message['type'] as String? ?? 'text';
    final timestamp = message['timestamp'] as Timestamp?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị tin nhắn dựa trên loại
            if (messageType == 'text')
              Text(
                message['text'] ?? '',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              )
            else if (messageType == 'image')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      onTap: () {
                        // Hiển thị ảnh full màn hình khi nhấn vào
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                iconTheme: const IconThemeData(color: Colors.white),
                              ),
                              backgroundColor: Colors.black,
                              body: Center(
                                child: InteractiveViewer(
                                  panEnabled: true,
                                  boundaryMargin: const EdgeInsets.all(20),
                                  minScale: 0.5,
                                  maxScale: 4,
                                  child: CachedNetworkImage(
                                    imageUrl: message['imageUrl'] ?? '',
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: CachedNetworkImage(
                        imageUrl: message['imageUrl'] ?? '',
                        placeholder: (context, url) => const SizedBox(
                          height: 150,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                        fit: BoxFit.cover,
                        width: 200,
                        height: 150,
                      ),
                    ),
                  ),
                ],
              )
            else if (messageType == 'file')
                GestureDetector(
                  onTap: () => _openFile(message['fileUrl'] ?? '', message['fileName'] ?? 'file'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue.shade800 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (message['fileType'] == 'pdf') ? Icons.picture_as_pdf : Icons.insert_drive_file,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['fileName'] ?? 'File',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                maxLines: 1,
                              ),
                              Text(
                                'Nhấn để mở',
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 2),
            Text(
              timestamp != null
                  ? DateFormat('HH:mm').format(timestamp.toDate())
                  : '',
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.friendName),
            Text(
              widget.friendEmail,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: _chatId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('privateChats')
                      .doc(_chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Lỗi: ${snapshot.error}'));
                    }

                    final messages = snapshot.data?.docs ?? [];

                    if (messages.isEmpty) {
                      return const Center(child: Text('Chưa có tin nhắn'));
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(10),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index].data() as Map<String, dynamic>;
                        final isMe = message['senderId'] == _auth.currentUser?.uid;

                        return _buildMessageItem(message, isMe);
                      },
                    );
                  },
                ),
                if (_isUploading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Đang tải tệp lên...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.blue,
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    maxLines: 5,
                    minLines: 1,
                    onSubmitted: (_) => _sendMessage(
                      type: MessageType.text,
                      text: _messageController.text,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.blue,
                  onPressed: () {
                    _sendMessage(
                      type: MessageType.text,
                      text: _messageController.text,
                    );
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