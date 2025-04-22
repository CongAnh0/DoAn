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

  @override
  void initState() {
    super.initState();
    _checkSubmission();
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
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _hasSubmitted = true;
          _submissions = [{
            'id': snapshot.snapshot.key,
            ...data.map((k, v) => MapEntry(k.toString(), v)),
          }];
          _imageUrl = data['fileUrl'];
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
              ],
            ],
            if (widget.userRole == 'teacher') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubmissionReviewScreen(
                        courseId: widget.courseId,
                        assignmentId: widget.assignmentId,
                        assignmentTitle: widget.assignmentTitle,
                      ),
                    ),
                  );
                },
                child: const Text('Xem bài nộp của học sinh'),
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