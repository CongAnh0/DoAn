import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCourseScreen extends StatefulWidget {
  final int grade;
  final String subject;

  const AddCourseScreen({
    super.key,
    required this.grade,
    required this.subject,
  });

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm khóa học mới'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tên khóa học'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên khóa học';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Mô tả khóa học'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitCourse,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Tạo khóa học'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dbRef = FirebaseDatabase.instance.ref().child('courses').push();
      await dbRef.set({
        'title': _titleController.text,
        'name': _titleController.text,
        'description': _descriptionController.text,
        'subject': widget.subject,
        'grade': widget.grade,
        'teacherId': user.uid,
        'teacherName': user.displayName ?? 'Giáo viên',
        'videos': {},
        'assignments': {},
        'chatGroup': {
          'groupId': dbRef.key,
          'name': 'Nhóm chat ${_titleController.text}',
          'members': {
            user.uid: true,
          },
        },
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tạo khóa học: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}