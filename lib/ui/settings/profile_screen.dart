import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  late User _currentUser;
  late TextEditingController _fullNameController;
  DateTime? _dateOfBirth;
  String? _address;
  String? _avatarUrl;
  bool _isLoading = true;
  File? _selectedImage;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _fullNameController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _fullNameController.text = data['fullName'] ?? 'Chưa cập nhật';
          _dateOfBirth = data['dateOfBirth']?.toDate();
          _address = data['address'] ?? 'Chưa cập nhật';
          _avatarUrl = data['avatarUrl'];
        });
      } else {
        await _initializeUserProfile();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải dữ liệu: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeUserProfile() async {
    await _firestore.collection('users').doc(_currentUser.uid).set({
      'fullName': 'Chưa cập nhật',
      'dateOfBirth': null,
      'address': 'Chưa cập nhật',
      'email': _currentUser.email,
      'avatarUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateProfile() async {
    try {
      await _firestore.collection('users').doc(_currentUser.uid).update({
        'fullName': _fullNameController.text.trim(),
      });

      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi cập nhật: ${e.toString()}')),
      );
    }
  }

  Future<void> _uploadAvatar() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedImage = File(pickedFile.path);
        _isLoading = true;
      });

      final fileName = 'avatars/${_currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child(fileName);
      await storageRef.putFile(_selectedImage!);
      final downloadUrl = await storageRef.getDownloadURL();

      await _firestore.collection('users').doc(_currentUser.uid).update({
        'avatarUrl': downloadUrl,
      });

      setState(() {
        _avatarUrl = downloadUrl;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật ảnh đại diện thành công')),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi upload ảnh: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Avatar Section - Đã sửa để xử lý lỗi URL
            GestureDetector(
              onTap: _uploadAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? ClipOval(
                      child: Image.network(
                        _avatarUrl!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, size: 60, color: Colors.white);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const CircularProgressIndicator();
                        },
                      ),
                    )
                        : const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Họ và tên (chỉ cho phép sửa trường này)
            _buildEditableProfileField(
              'Họ và tên',
              _fullNameController,
              isEditable: _isEditing,
            ),
            const SizedBox(height: 20),

            // Ngày sinh (chỉ hiển thị)
            _buildProfileInfoCard(
              'Ngày sinh',
              _dateOfBirth != null
                  ? DateFormat('dd/MM/yyyy').format(_dateOfBirth!)
                  : 'Chưa cập nhật',
              icon: Icons.cake,
            ),
            const SizedBox(height: 15),

            // Địa chỉ (chỉ hiển thị)
            _buildProfileInfoCard(
              'Địa chỉ',
              _address ?? 'Chưa cập nhật',
              icon: Icons.location_on,
            ),
            const SizedBox(height: 15),

            // Email (không chỉnh sửa)
            _buildProfileInfoCard(
              'Email',
              _currentUser.email ?? 'Chưa có email',
              icon: Icons.email,
            ),
            const SizedBox(height: 15),

            // Ngày tham gia (không chỉnh sửa)
            _buildProfileInfoCard(
              'Ngày tham gia',
              _currentUser.metadata.creationTime != null
                  ? DateFormat('dd/MM/yyyy').format(_currentUser.metadata.creationTime!.toLocal())
                  : 'Không rõ',
              icon: Icons.calendar_today,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableProfileField(String label, TextEditingController controller, {required bool isEditable}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
            suffixIcon: isEditable ? const Icon(Icons.edit) : null,
          ),
          readOnly: !isEditable,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard(String title, String value, {IconData? icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(icon, color: Colors.purple),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}