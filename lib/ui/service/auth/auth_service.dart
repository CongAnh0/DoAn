import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      _log('Lỗi khi lấy user data: $e');
      return null;
    }
  }

  Future<void> enrollInCourse(String courseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Chưa đăng nhập';

    final db = FirebaseDatabase.instance.ref();

    // Thêm user vào khóa học
    await db.child('userCourses/${user.uid}/$courseId').set(true);

    // Thêm user vào group chat
    await db.child('courses/$courseId/chatGroup/members/${user.uid}').set(true);

    // Tạo entry trong userChats
    final courseSnapshot = await db.child('courses/$courseId').once();
    final courseData = courseSnapshot.snapshot.value as Map<dynamic, dynamic>;

    await db.child('userChats/${user.uid}/${courseData['chatGroup']['groupId']}').set({
      'courseId': courseId,
      'lastMessage': 'Bạn đã tham gia nhóm',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'unreadCount': 0
    });
  }

  Future<bool> isEnrolledInCourse(String courseId) async {
    try {
      final data = await getCurrentUserData();
      final enrolledCourses = data?['enrolledCourses'] as List? ?? [];
      return enrolledCourses.contains(courseId);
    } catch (e) {
      _log('Lỗi khi kiểm tra enrollment: $e');
      return false;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AuthService] $message');
    }
  }

  Future<String?> getUserRole() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return null;

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      return userDoc.get('role') as String?;
    } catch (e) {
      _log('Lỗi khi lấy role: $e');
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      _log('Đang xác thực...');
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _firestore.collection('users').doc(credential.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      final userDoc = await _firestore.collection('users').doc(
          credential.user!.uid).get();
      final role = userDoc.get('role') ?? 'student';

      _log('Đăng nhập thành công với role: $role');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    } catch (e) {
      throw 'Lỗi đăng nhập: ${e.toString()}';
    }
  }

  Future<User?> register({
    required String email,
    required String password,
    required String fullName,
    required DateTime dateOfBirth,
    required String address,
    required String role,
  }) async {
    try {
      _log('Đang tạo tài khoản...');
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email.trim(),
        'fullName': fullName.trim(),
        'dateOfBirth': Timestamp.fromDate(dateOfBirth),
        'address': address.trim(),
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Bỏ phần gửi email xác thực
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    } catch (e) {
      throw 'Lỗi đăng ký: ${e.toString()}';
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'Người dùng hủy đăng nhập';

      final credential = GoogleAuthProvider.credential(
        accessToken: (await googleUser.authentication).accessToken,
        idToken: (await googleUser.authentication).idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(
          credential);
      if (result.user == null) throw 'Đăng nhập thất bại';

      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': result.user!.email,
        'fullName': result.user!.displayName ?? 'Người dùng Google',
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'friends': [],
        'friendRequests': [],
      }, SetOptions(merge: true));

      return result.user;
    } catch (e) {
      throw 'Lỗi Google Sign-In: ${e.toString()}';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e.code);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      throw 'Lỗi đăng xuất: ${e.toString()}';
    }
  }

  String _handleAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'user-disabled':
        return 'Tài khoản bị vô hiệu hóa';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản';
      case 'wrong-password':
        return 'Mật khẩu không đúng';
      case 'email-already-in-use':
        return 'Email đã được sử dụng';
      case 'weak-password':
        return 'Mật khẩu quá yếu';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Thử lại sau';
      default:
        return 'Lỗi xác thực: $code';
    }
  }
}