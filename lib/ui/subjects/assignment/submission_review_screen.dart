import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photo_view/photo_view.dart';

class SubmissionReviewScreen extends StatefulWidget {
  final String courseId;
  final String assignmentId;
  final String assignmentTitle;

  const SubmissionReviewScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<SubmissionReviewScreen> createState() => _SubmissionReviewScreenState();
}

class _SubmissionReviewScreenState extends State<SubmissionReviewScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    final snapshot = await _dbRef
        .child('submissions/${widget.courseId}/${widget.assignmentId}')
        .once();

    if (snapshot.snapshot.value == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final submissionsMap = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
    final List<Map<String, dynamic>> submissionsList = [];

    for (final entry in submissionsMap.entries) {
      final userId = entry.key;
      final data = Map<String, dynamic>.from(entry.value);

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final name = userDoc.data()?['name'] ?? 'Anh';
      final avatar = userDoc.data()?['avatar'] ?? '';

      submissionsList.add({
        'userId': userId,
        'name': name,
        'avatar': avatar,
        ...data,
      });
    }

    setState(() {
      _submissions = submissionsList;
      _isLoading = false;
    });
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

  void _showGradingDialog(Map<String, dynamic> submission) {
    final TextEditingController scoreController =
    TextEditingController(text: submission['score']?.toString() ?? '');
    final TextEditingController feedbackController =
    TextEditingController(text: submission['feedback'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Chấm điểm - ${submission['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              decoration: InputDecoration(labelText: 'Điểm số'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: feedbackController,
              decoration: InputDecoration(labelText: 'Nhận xét'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy')),
          ElevatedButton(
              onPressed: () async {
                final newScore = double.tryParse(scoreController.text.trim());
                final feedback = feedbackController.text.trim();

                if (newScore != null) {
                  await _dbRef
                      .child('submissions/${widget.courseId}/${widget.assignmentId}/${submission['userId']}')
                      .update({
                    'score': newScore,
                    'feedback': feedback,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã chấm điểm cho ${submission['name']}')),
                  );

                  Navigator.pop(context);
                  _loadSubmissions();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Điểm không hợp lệ')),
                  );
                }
              },
              child: Text('Lưu')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bài nộp - ${widget.assignmentTitle}')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
          ? Center(child: Text('Chưa có bài nộp nào'))
          : ListView.builder(
        itemCount: _submissions.length,
        itemBuilder: (context, index) {
          final submission = _submissions[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: submission['avatar'] != ''
                    ? NetworkImage(submission['avatar'])
                    : null,
                child: submission['avatar'] == '' ? Icon(Icons.person) : null,
              ),
              title: Text(submission['name']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (submission['score'] != null)
                    Text('Điểm: ${submission['score']}'),
                  if (submission['feedback'] != null)
                    Text('Nhận xét: ${submission['feedback']}'),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.grade),
                onPressed: () => _showGradingDialog(submission),
              ),
              onTap: () {
                final imageUrl = submission['submissionImageUrl'] ?? submission['fileUrl'];
                if (imageUrl != null && imageUrl != '') {
                  _showImageFullScreen(imageUrl);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
