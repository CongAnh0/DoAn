import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_view/photo_view.dart';

class SubmissionReviewScreen extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String assignmentTitle;
  final String studentId;
  final String studentName;

  const SubmissionReviewScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<SubmissionReviewScreen> createState() => _SubmissionReviewScreenState();
}

class _SubmissionReviewScreenState extends State<SubmissionReviewScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _submission;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    try {
      final snapshot = await _dbRef
          .child('submissions/${widget.courseId}/${widget.assignmentId}/${widget.studentId}')
          .once();

      if (snapshot.snapshot.value == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);

      setState(() {
        _submission = {
          'userId': widget.studentId,
          'name': widget.studentName,
          ...data,
        };
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải bài nộp: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  void _showGradingDialog() {
    if (_submission == null) return;

    final TextEditingController scoreController =
    TextEditingController(text: _submission!['score']?.toString() ?? '');
    final TextEditingController feedbackController =
    TextEditingController(text: _submission!['feedback'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Chấm điểm - ${widget.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              decoration: const InputDecoration(labelText: 'Điểm số'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(labelText: 'Nhận xét'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
          ElevatedButton(
              onPressed: () async {
                final newScore = double.tryParse(scoreController.text.trim());
                final feedback = feedbackController.text.trim();

                if (newScore != null) {
                  await _dbRef
                      .child('submissions/${widget.courseId}/${widget.assignmentId}/${widget.studentId}')
                      .update({
                    'score': newScore,
                    'feedback': feedback,
                    'status': 'graded',
                    'gradedAt': DateTime.now().millisecondsSinceEpoch,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã chấm điểm cho ${widget.studentName}')),
                  );

                  Navigator.pop(context);
                  _loadSubmission();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Điểm không hợp lệ')),
                  );
                }
              },
              child: const Text('Lưu')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bài nộp - ${widget.assignmentTitle}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submission == null
          ? const Center(child: Text('Không tìm thấy bài nộp'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Học sinh: ${widget.studentName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thời gian nộp: ${DateTime.fromMillisecondsSinceEpoch(_submission!['submittedAt'] ?? 0).toString()}',
                    ),
                    if (_submission!['score'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Điểm: ${_submission!['score']}'),
                    ],
                    if (_submission!['feedback'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Nhận xét: ${_submission!['feedback']}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_submission!['fileUrl'] != null || _submission!['submissionImageUrl'] != null) ...[
              const Text(
                'Bài làm:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  final imageUrl = _submission!['submissionImageUrl'] ?? _submission!['fileUrl'];
                  if (imageUrl != null) {
                    _showImageFullScreen(imageUrl);
                  }
                },
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _submission!['submissionImageUrl'] ?? _submission!['fileUrl'] ?? '',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _showGradingDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _submission!['score'] != null ? 'Sửa điểm' : 'Chấm điểm',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}