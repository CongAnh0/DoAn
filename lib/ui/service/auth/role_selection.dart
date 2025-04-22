import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';


class RoleSelectionScreen extends StatefulWidget {
  final String email;
  final String password;
  final String fullName;
  final DateTime dateOfBirth;
  final String address;

  const RoleSelectionScreen({
    super.key,
    required this.email,
    required this.password,
    required this.fullName,
    required this.dateOfBirth,
    required this.address,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _role = 'student';
  final _teacherCodeController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _teacherCodeController.dispose();
    super.dispose();
  }

  Future<void> _completeRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await Provider.of<AuthService>(context, listen: false)
          .register(
        email: widget.email,
        password: widget.password,
        fullName: widget.fullName,
        dateOfBirth: widget.dateOfBirth,
        address: widget.address,
        role: _role,
      );

      if (user != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseError(e);
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi hệ thống: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'email-already-in-use':
        errorMessage = 'Email đã được sử dụng';
        break;
      case 'invalid-email':
        errorMessage = 'Email không hợp lệ';
        break;
      case 'weak-password':
        errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự';
        break;
      default:
        errorMessage = 'Lỗi đăng ký: ${e.message}';
    }
    setState(() => _errorMessage = errorMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn vai trò')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn đăng ký với vai trò:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            RadioListTile<String>(
              title: const Text('Học sinh'),
              value: 'student',
              groupValue: _role,
              onChanged: (value) => setState(() => _role = value!),
            ),
            RadioListTile<String>(
              title: const Text('Giáo viên'),
              value: 'teacher',
              groupValue: _role,
              onChanged: (value) => setState(() => _role = value!),
            ),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                ),
              ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme
                      .of(context)
                      .primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _completeRegistration,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'HOÀN TẤT ĐĂNG KÝ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}