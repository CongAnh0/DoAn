import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_app/ui/add_friend/friend_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';




class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isSendingRequest = false; // Thêm biến mới để track trạng thái gửi request

  @override
  Widget build(BuildContext context) {
    final friendService = Provider.of<FriendService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm bạn bè'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSendingRequest ? null : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              enabled: !_isSendingRequest,
              decoration: InputDecoration(
                hintText: 'Nhập email hoặc tên người dùng',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const CircularProgressIndicator()
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _isSendingRequest ? null : () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _hasSearched = false;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
              onSubmitted: _isSendingRequest ? null : (query) => _searchUsers(query, friendService),
            ),
          ),
          Expanded(
            child: _buildSearchResults(friendService),
          ),
        ],
      ),
    );
  }

  Future<void> _searchUsers(String query, FriendService friendService) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await friendService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      _showErrorSnackBar('Lỗi tìm kiếm: ${e.toString()}');
    }
  }

  Widget _buildSearchResults(FriendService friendService) {
    if (_isSendingRequest) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Nhập email hoặc tên người dùng để tìm kiếm',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'Không tìm thấy người dùng phù hợp',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserItem(user, friendService);
      },
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user, FriendService friendService) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.purple[100],
        child: Text(
          user['name'].isNotEmpty ? user['name'][0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.purple),
        ),
      ),
      title: Text(user['name']),
      subtitle: Text(user['email']),
      trailing: _isSendingRequest
          ? const CircularProgressIndicator()
          : ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        onPressed: () => _sendFriendRequest(user['id'], friendService),
        child: const Text('Kết bạn'),
      ),
    );
  }

  Future<void> _sendFriendRequest(String userId, FriendService friendService) async {
    try {
      setState(() => _isSendingRequest = true);
      await friendService.sendFriendRequest(userId);
      _showSuccessSnackBar('Đã gửi lời mời kết bạn thành công');
    } on FirebaseException catch (e) {
      debugPrint('Firestore error details: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        _showErrorSnackBar('Không có quyền thực hiện thao tác này');
      } else {
        _handleFirebaseError(e);
      }
    } catch (e) {
      debugPrint('Full error: $e');
      _showErrorSnackBar('Lỗi: ${e.toString()}');
    } finally {
      setState(() => _isSendingRequest = false);
    }
  }

  void _handleFirebaseError(FirebaseException e) {
    String message = 'Lỗi khi gửi lời mời';
    switch (e.code) {
      case 'permission-denied':
        message = 'Bạn không có quyền thực hiện thao tác này';
        break;
      case 'not-found':
        message = 'Người dùng không tồn tại';
        break;
      default:
        message = 'Lỗi: ${e.message ?? e.code}';
    }
    _showErrorSnackBar(message);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}