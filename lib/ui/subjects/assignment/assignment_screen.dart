import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'assignment_submission_screen.dart';
import 'package:url_launcher/url_launcher.dart';


class AssignmentScreen extends StatefulWidget {
  final String courseId;
  final String? userRole; // Thêm userRole từ CourseDetailScreen

  const AssignmentScreen({
    super.key,
    required this.courseId,
    this.userRole,
  });

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  // THÊM MỚI: Khai báo biến auth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  // PHẦN GIỮ NGUYÊN
  Future<void> _loadAssignments() async {
    final dbRef = FirebaseDatabase.instance.ref().child('courses/${widget.courseId}/assignments');
    final snapshot = await dbRef.once();

    setState(() {
      _isLoading = false;
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        _assignments = data.entries.map((entry) {
          return {
            'id': entry.key.toString(),
            ...(entry.value as Map<dynamic, dynamic>).map((k, v) => MapEntry(k.toString(), v)),
          };
        }).toList();
        _assignments.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.userRole == 'teacher'
          ? FloatingActionButton(
        onPressed: () => _showAssignmentTypeDialog(),
        child: const Icon(Icons.add),
      )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Chưa có bài tập nào',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (widget.userRole == 'teacher') ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showAssignmentTypeDialog(),
                child: const Text('Thêm bài tập đầu tiên'),
              ),
            ],
          ],
        ),
      )
          : ListView.builder(
        itemCount: _assignments.length,
        itemBuilder: (context, index) {
          final assignment = _assignments[index];
          final isEssayType = assignment['type'] == 'essay';

          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: Icon(isEssayType ? Icons.description : Icons.quiz),
              title: Text(assignment['title']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assignment['description'] ?? ''),
                  if (assignment['dueDate'] != null)
                    Text('Hạn nộp: ${assignment['dueDate']}'),
                  Text('Loại: ${isEssayType ? 'Tự luận' : 'Trắc nghiệm'}'),
                ],
              ),
              trailing: widget.userRole == 'teacher'
                  ? IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteAssignment(assignment['id']),
              )
                  : null,
              onTap: () {
                if (isEssayType) {
                  // THAY ĐỔI: Thêm kiểm tra đăng nhập và lấy userId thực
                  final user = _auth.currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng đăng nhập để nộp bài')),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignmentSubmissionScreen(
                        courseId: widget.courseId,
                        assignmentId: assignment['id'],
                        assignmentTitle: assignment['title'],
                        fileUrl: assignment['fileUrl'],
                        userRole: widget.userRole,
                        userId: user.uid, // THAY ĐỔI: Dùng UID thực
                      ),
                    ),
                  );
                } else {
                  if (assignment['formUrl'] != null) {
                    launchUrl(Uri.parse(assignment['formUrl']));
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }

  // PHẦN GIỮ NGUYÊN CÁC PHƯƠNG THỨC KHÁC
  Future<void> _showAssignmentTypeDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn loại bài tập'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Tự luận (PDF)'),
              onTap: () => Navigator.pop(context, 'essay'),
            ),
            ListTile(
              leading: const Icon(Icons.quiz),
              title: const Text('Trắc nghiệm (Google Form)'),
              onTap: () => Navigator.pop(context, 'quiz'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (result == 'essay') {
        await _navigateToAddEssayAssignment();
      } else {
        await _navigateToAddQuizAssignment();
      }
      _loadAssignments();
    }
  }

  Future<void> _navigateToAddEssayAssignment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEssayAssignmentScreen(courseId: widget.courseId),
      ),
    );
    if (result == true) _loadAssignments();
  }

  Future<void> _navigateToAddQuizAssignment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddQuizAssignmentScreen(courseId: widget.courseId),
      ),
    );
    if (result == true) _loadAssignments();
  }

  Future<void> _deleteAssignment(String assignmentId) async {
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('courses/${widget.courseId}/assignments/$assignmentId')
          .remove();
      _loadAssignments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa bài tập: $e')),
      );
    }
  }
}

// PHẦN GIỮ NGUYÊN CÁC LỚP DƯỚI ĐÂY
class AddEssayAssignmentScreen extends StatefulWidget {
  final String courseId;

  const AddEssayAssignmentScreen({super.key, required this.courseId});

  @override
  State<AddEssayAssignmentScreen> createState() => _AddEssayAssignmentScreenState();
}

class _AddEssayAssignmentScreenState extends State<AddEssayAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();
  bool _isLoading = false;
  String? _filePath;
  PlatformFile? _pickedFile;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
        allowCompression: false,
      );

      if (result != null) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _pickedFile = file;
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi file picker: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở file: ${e.toString()}')),
      );
    }
  }

  Future<String?> _uploadFile() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) return null;

    try {
      final ref = FirebaseStorage.instance.ref()
          .child('assignments/${widget.courseId}/${_pickedFile!.name}');

      await ref.putData(_pickedFile!.bytes!);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload thất bại: $e')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm bài tập tự luận')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tiêu đề bài tập *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Mô tả bài tập'),
                maxLines: 3,
              ),
              TextFormField(
                controller: _dueDateController,
                decoration: const InputDecoration(
                  labelText: 'Hạn nộp (VD: 30/12/2023)',
                  hintText: 'Để trống nếu không có hạn nộp',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('Chọn file PDF'),
              ),
              if (_pickedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'File: ${_pickedFile!.name}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAssignment,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Thêm bài tập'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn file PDF')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fileUrl = await _uploadFile();
      if (fileUrl == null) return;

      final dbRef = FirebaseDatabase.instance.ref();
      final assignmentRef = dbRef
          .child('courses/${widget.courseId}/assignments')
          .push();

      await assignmentRef.set({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'dueDate': _dueDateController.text.isEmpty ? null : _dueDateController.text,
        'type': 'essay',
        'fileUrl': fileUrl,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi thêm bài tập: $e')),
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
    _dueDateController.dispose();
    super.dispose();
  }
}

class AddQuizAssignmentScreen extends StatefulWidget {
  final String courseId;

  const AddQuizAssignmentScreen({super.key, required this.courseId});

  @override
  State<AddQuizAssignmentScreen> createState() => _AddQuizAssignmentScreenState();
}

class _AddQuizAssignmentScreenState extends State<AddQuizAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _formUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm bài tập trắc nghiệm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tiêu đề bài tập *'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Mô tả bài tập'),
                maxLines: 3,
              ),
              TextFormField(
                controller: _dueDateController,
                decoration: const InputDecoration(
                  labelText: 'Hạn nộp (VD: 30/12/2023)',
                  hintText: 'Để trống nếu không có hạn nộp',
                ),
              ),
              TextFormField(
                controller: _formUrlController,
                decoration: const InputDecoration(
                  labelText: 'Link Google Form *',
                  hintText: 'https://forms.google.com/...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập link Google Form';
                  }
                  if (!value.startsWith('http')) {
                    return 'Link không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAssignment,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Thêm bài tập'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final assignmentRef = dbRef
          .child('courses/${widget.courseId}/assignments')
          .push();

      await assignmentRef.set({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'dueDate': _dueDateController.text.isEmpty ? null : _dueDateController.text,
        'type': 'quiz',
        'formUrl': _formUrlController.text,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi thêm bài tập: $e')),
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
    _dueDateController.dispose();
    _formUrlController.dispose();
    super.dispose();
  }
}