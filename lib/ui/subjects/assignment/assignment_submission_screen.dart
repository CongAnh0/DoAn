import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_app/ui/subjects/assignment/submission_review_screen.dart';
import 'dart:io';
import 'pdf_viewer_screen.dart';

class AssignmentSubmissionScreen extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String assignmentTitle;
  final String? fileUrl;
  final String? userRole;
  final String? userId;

  const AssignmentSubmissionScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentTitle,
    this.fileUrl,
    this.userRole,
    this.userId,
  });

  @override
  State<AssignmentSubmissionScreen> createState() => _AssignmentSubmissionScreenState();
}

class _AssignmentSubmissionScreenState extends State<AssignmentSubmissionScreen> {
  bool _isLoading = false;
  bool _hasSubmitted = false;
  List<Map<String, dynamic>> _submissions = [];
  File? _selectedImage;
  String? _imageUrl;
  Map<String, dynamic>? _submissionData;
  List<Map<String, dynamic>> _studentSubmissions = [];

  @override
  void initState() {
    super.initState();
    _checkSubmission();
    if (widget.userRole == 'teacher') {
      _loadStudentSubmissions();
    }
  }

  Future<void> _checkSubmission() async {
    if (widget.userRole != 'student' || widget.userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('submissions/${widget.courseId}/${widget.assignmentId}/${widget.userId}')
          .once();

      if (snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          _hasSubmitted = true;
          _submissionData = data;
          _submissions = [{
            'id': snapshot.snapshot.key,
            ...data,
          }];
          _imageUrl = data['fileUrl'] ?? data['submissionImageUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error checking submission: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentSubmissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('submissions/${widget.courseId}/${widget.assignmentId}')
          .once();

      if (snapshot.snapshot.value != null) {
        final submissions = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        List<Map<String, dynamic>> studentList = [];

        for (var entry in submissions.entries) {
          final studentId = entry.key;
          final submissionData = Map<String, dynamic>.from(entry.value);

          // Get student name from users database
          final userSnapshot = await FirebaseDatabase.instance
              .ref()
              .child('users/$studentId')
              .once();

          String studentName = 'Học sinh';
          if (userSnapshot.snapshot.value != null) {
            final userData = Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);
            studentName = userData['name'] ?? userData['fullName'] ?? 'Học sinh';
          }

          studentList.add({
            'studentId': studentId,
            'studentName': studentName,
            ...submissionData,
          });
        }

        setState(() {
          _studentSubmissions = studentList;
        });
      }
    } catch (e) {
      debugPrint('Error loading student submissions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _viewPdf() async {
    if (widget.fileUrl == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdfUrl: widget.fileUrl!),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn ảnh: ${e.toString()}')),
      );
    }
  }

  Future<void> _uploadSubmission() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ảnh bài làm')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Tạo tên file duy nhất
      final fileName = 'submission_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload file to storage
      final storageRef = FirebaseStorage.instance.ref()
          .child('submissions/${widget.courseId}/${widget.assignmentId}/${widget.userId}/$fileName');

      await storageRef.putFile(_selectedImage!);
      final downloadUrl = await storageRef.getDownloadURL();

      // Save submission data to database
      final dbRef = FirebaseDatabase.instance.ref();
      await dbRef
          .child('submissions/${widget.courseId}/${widget.assignmentId}/${widget.userId}')
          .set({
        'fileUrl': downloadUrl,
        'submissionImageUrl': downloadUrl,
        'submittedAt': DateTime.now().millisecondsSinceEpoch,
        'status': 'submitted',
        'grade': null,
        'fileName': fileName,
      });

      setState(() {
        _hasSubmitted = true;
        _imageUrl = downloadUrl;
        _selectedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nộp bài thành công!')),
      );

      // Refresh submission data
      _checkSubmission();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi nộp bài: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewGradeDetails() {
    if (_submissionData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chi tiết điểm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_submissionData?['score'] != null)
              Text('Điểm: ${_submissionData!['score']}'),
            if (_submissionData?['feedback'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Nhận xét: ${_submissionData!['feedback']}'),
              ),
            if (_submissionData?['gradedAt'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Chấm ngày: ${DateTime.fromMillisecondsSinceEpoch(_submissionData!['gradedAt']).toString()}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.assignmentTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.fileUrl != null) ...[
              ElevatedButton(
                onPressed: _viewPdf,
                child: const Text('Xem đề bài (PDF)'),
              ),
              const SizedBox(height: 20),
            ],
            if (widget.userRole == 'student') ...[
              if (!_hasSubmitted) ...[
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Chọn ảnh bài làm'),
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(height: 10),
                  Image.file(
                    _selectedImage!,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _uploadSubmission,
                    child: const Text('Nộp bài'),
                  ),
                ],
              ] else ...[
                const Text(
                  'Bạn đã nộp bài',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_imageUrl != null)
                  Column(
                    children: [
                      Image.network(
                        _imageUrl!,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImage(
                                imageUrl: _imageUrl!,
                              ),
                            ),
                          );
                        },
                        child: const Text('Xem bài đã nộp'),
                      ),
                    ],
                  ),
                if (_submissionData != null &&
                    (_submissionData!['score'] != null ||
                        _submissionData!['feedback'] != null)) ...[
                  const SizedBox(height: 20),
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kết quả chấm điểm',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_submissionData!['score'] != null)
                            Text('Điểm: ${_submissionData!['score']}'),
                          if (_submissionData!['feedback'] != null && _submissionData!['feedback'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Nhận xét: ${_submissionData!['feedback']}'),
                            ),
                          const SizedBox(height: 12),
                          Center(
                            child: ElevatedButton(
                              onPressed: _viewGradeDetails,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Xem chi tiết điểm'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_hasSubmitted) ...[
                  const SizedBox(height: 20),
                  const Card(
                    elevation: 3,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Bài làm đang chờ chấm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Giáo viên sẽ sớm chấm điểm bài làm của bạn',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
            if (widget.userRole == 'teacher') ...[
              const Text(
                'Danh sách bài nộp của học sinh:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _studentSubmissions.isEmpty
                    ? const Center(child: Text('Chưa có học sinh nào nộp bài'))
                    : ListView.builder(
                  itemCount: _studentSubmissions.length,
                  itemBuilder: (context, index) {
                    final submission = _studentSubmissions[index];
                    final bool isGraded = submission['score'] != null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(submission['studentName'] ?? 'Học sinh'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nộp lúc: ${DateTime.fromMillisecondsSinceEpoch(submission['submittedAt'] ?? 0).toString().substring(0, 16)}'),
                            if (isGraded)
                              Text('Điểm: ${submission['score']}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubmissionReviewScreen(
                                  courseId: widget.courseId,
                                  assignmentId: widget.assignmentId,
                                  assignmentTitle: widget.assignmentTitle,
                                  studentId: submission['studentId'],
                                  studentName: submission['studentName'] ?? 'Học sinh',
                                ),
                              ),
                            ).then((_) {
                              // Refresh the list when coming back
                              _loadStudentSubmissions();
                            });
                          },
                          child: Text(isGraded ? 'Sửa điểm' : 'Chấm điểm'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }
}