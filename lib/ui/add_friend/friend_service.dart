import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[FriendService] $message');
    }
  }


  Future<void> sendFriendRequest(String targetUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Chưa đăng nhập';
      if (currentUser.uid == targetUserId) throw 'Không thể gửi lời mời cho chính mình';

      // Kiểm tra user tồn tại
      final targetUserDoc = await _firestore.collection('users').doc(targetUserId).get();
      if (!targetUserDoc.exists) throw 'Người dùng không tồn tại';

      // Kiểm tra đã gửi request trước đó chưa
      final existingRequest = await _firestore
          .collection('friendships')
          .where('userId', isEqualTo: targetUserId)
          .where('friendId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) throw 'Đã gửi lời mời trước đó';

      // Tạo document mới trong collection friendships
      await _firestore.collection('friendships').add({
        'userId': targetUserId,       // Người nhận
        'friendId': currentUser.uid,  // Người gửi
        'status': 'pending',
        'initiatedBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _log('Đã gửi lời mời đến $targetUserId');
    } catch (e) {
      _log('Lỗi khi gửi lời mời: $e');
      rethrow;
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Chưa đăng nhập';

      final requestRef = _firestore.collection('friendships').doc(requestId);

      await _firestore.runTransaction((transaction) async {
        // Bước đọc document - cần quyền read
        final requestDoc = await transaction.get(requestRef);
        if (!requestDoc.exists) throw 'Lời mời không tồn tại';

        final data = requestDoc.data()!;
        if (data['userId'] != currentUser.uid) {
          throw 'Bạn không có quyền chấp nhận lời mời này';
        }

        // Cập nhật document gốc
        transaction.update(requestRef, {
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Tạo document ngược lại - ĐẢM BẢO CÙNG initiatedBy
        final newDocRef = _firestore.collection('friendships').doc();
        transaction.set(newDocRef, {
          'userId': data['friendId'],
          'friendId': currentUser.uid,
          'status': 'accepted',
          'initiatedBy': data['initiatedBy'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      _log('Lỗi khi chấp nhận lời mời: $e');
      rethrow;
    }
  }

  // REFACTORED METHOD
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Chưa đăng nhập';

      final requestRef = _firestore.collection('friendships').doc(requestId);
      final requestDoc = await requestRef.get();

      // Kiểm tra quyền
      if (requestDoc.data()?['userId'] != currentUser.uid) {
        throw 'Không có quyền từ chối';
      }

      await requestRef.update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _log('Lỗi khi từ chối lời mời: $e');
      throw 'Lỗi khi từ chối lời mời: ${e.toString()}';
    }
  }


  Future<void> removeFriend(String friendId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Chưa đăng nhập';

      // Xóa cả 2 chiều của friendship
      final query = await _firestore
          .collection('friendships')
          .where('status', isEqualTo: 'accepted')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: friendId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.delete();
      }

      // Xóa bản ghi đối xứng (nếu có)
      final reverseQuery = await _firestore
          .collection('friendships')
          .where('status', isEqualTo: 'accepted')
          .where('userId', isEqualTo: friendId)
          .where('friendId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (reverseQuery.docs.isNotEmpty) {
        await reverseQuery.docs.first.reference.delete();
      }
    } catch (e) {
      _log('Lỗi khi hủy kết bạn: $e');
      throw 'Lỗi khi hủy kết bạn: ${e.toString()}';
    }
  }

  // NO CHANGES NEEDED
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Chưa đăng nhập';

    return _firestore
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      return await Future.wait(
        snapshot.docs.map((doc) async {
          final friendDoc = await _firestore.collection('users').doc(doc['friendId']).get();
          return {
            'id': doc['friendId'],
            'name': friendDoc.get('fullName') ?? 'Không tên',
            'email': friendDoc.get('email') ?? '',
          };
        }),
      );
    });
  }

  // REFACTORED METHOD
  Stream<List<Map<String, dynamic>>> getPendingRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw 'Chưa đăng nhập';

    return _firestore
        .collection('friendships')
        .where('userId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      final requests = await Future.wait(
        snapshot.docs.map((doc) async {
          final senderDoc = await _firestore.collection('users').doc(doc['friendId']).get();
          return {
            'id': doc.id,
            'senderId': doc['friendId'],
            'name': senderDoc.get('fullName') ?? 'Không tên',
            'email': senderDoc.get('email') ?? '',
            'createdAt': doc['createdAt']?.toDate(),
          };
        }),
      );
      return requests;
    });
  }

  // NO CHANGES NEEDED
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw 'Chưa đăng nhập';

      final results = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThan: '${query}z')
          .get();

      return results.docs
          .where((doc) => doc.id != currentUser.uid)
          .map((doc) => {
        'id': doc.id,
        'name': doc.get('fullName') ?? 'Không tên',
        'email': doc.get('email') ?? '',
      })
          .toList();
    } catch (e) {
      _log('Lỗi khi tìm kiếm người dùng: $e');
      throw 'Lỗi khi tìm kiếm: ${e.toString()}';
    }
  }
}