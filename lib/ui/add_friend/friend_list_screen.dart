import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_app/ui/add_friend/friend_service.dart';
import 'package:study_app/ui/add_friend/add_friend_screen.dart';

class FriendListScreen extends StatefulWidget {
  const FriendListScreen({super.key});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  String? _processingRequestId;
  String? _processingFriendId;

  @override
  Widget build(BuildContext context) {
    final friendService = Provider.of<FriendService>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bạn bè'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Danh sách bạn bè'),
              Tab(text: 'Lời mời kết bạn'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFriendsList(friendService),
            _buildFriendRequestsList(friendService),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddFriendScreen()),
            );
          },
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }

  Widget _buildFriendsList(FriendService friendService) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: friendService.getFriendsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final friends = snapshot.data ?? [];

        if (friends.isEmpty) {
          return const Center(child: Text('Bạn chưa có bạn bè nào'));
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(friend['name'].isNotEmpty ? friend['name'][0] : '?'),
              ),
              title: Text(friend['name']),
              subtitle: Text(friend['email']),
              trailing: _processingFriendId == friend['id']
                  ? const CircularProgressIndicator()
                  : IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeFriend(friend['id'], friendService),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendRequestsList(FriendService friendService) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: friendService.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return const Center(child: Text('Không có lời mời kết bạn nào'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(request['name']),
              subtitle: Text(request['email']),
              trailing: _processingRequestId == request['id']
                  ? const CircularProgressIndicator()
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _acceptRequest(request['id'], friendService),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _rejectRequest(request['id'], friendService),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _acceptRequest(String requestId, FriendService friendService) async {
    try {
      setState(() => _processingRequestId = requestId);
      await friendService.acceptFriendRequest(requestId);
      _showSuccessSnackBar('Đã chấp nhận lời mời');
    } catch (e) {
      _showErrorSnackBar('Lỗi: ${e.toString()}');
    } finally {
      setState(() => _processingRequestId = null);
    }
  }

  Future<void> _rejectRequest(String requestId, FriendService friendService) async {
    try {
      setState(() => _processingRequestId = requestId);
      await friendService.rejectFriendRequest(requestId);
      _showSuccessSnackBar('Đã từ chối lời mời');
    } catch (e) {
      _showErrorSnackBar('Lỗi: ${e.toString()}');
    } finally {
      setState(() => _processingRequestId = null);
    }
  }

  Future<void> _removeFriend(String friendId, FriendService friendService) async {
    try {
      setState(() => _processingFriendId = friendId);
      await friendService.removeFriend(friendId);
      _showSuccessSnackBar('Đã hủy kết bạn');
    } catch (e) {
      _showErrorSnackBar('Lỗi: ${e.toString()}');
    } finally {
      setState(() => _processingFriendId = null);
    }
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
}