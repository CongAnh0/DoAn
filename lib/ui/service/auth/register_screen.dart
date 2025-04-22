import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'role_selection.dart';
import 'package:intl/intl.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  // --- PHẦN SỬA: Đổi từ TextEditingController sang DateTime ---
  DateTime? _selectedDate; // Thay thế cho _dateOfBirthController
  final _addressController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  // --- PHẦN THÊM MỚI: Hàm chọn ngày ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // --- PHẦN SỬA: Kiểm tra ngày sinh đã được chọn ---
    if (_selectedDate == null) {
      setState(() => _errorMessage = 'Vui lòng chọn ngày sinh');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Mật khẩu không khớp');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Provider.value(
            value: authService,
            child: RoleSelectionScreen(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
              fullName: _fullNameController.text.trim(),
              // --- PHẦN SỬA: Truyền DateTime thay vì String ---
              dateOfBirth: _selectedDate!,
              address: _addressController.text.trim(),
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              // --- PHẦN GIỮ NGUYÊN ---
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập họ tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // --- PHẦN SỬA: Thay thế TextFormField bằng Button chọn ngày ---
              ElevatedButton(
                onPressed: () => _selectDate(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  _selectedDate == null
                      ? 'Chọn ngày sinh (dd/MM/yyyy)'
                      : 'Đã chọn: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                ),
              ),
              const SizedBox(height: 16),
              // --- PHẦN GIỮ NGUYÊN (Các trường khác) ---
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập địa chỉ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu (ít nhất 6 ký tự)',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu';
                  }
                  if (value != _passwordController.text) {
                    return 'Mật khẩu không khớp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('TIẾP TỤC'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã có tài khoản? Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}