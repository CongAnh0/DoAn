import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'submission_review_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'submissions_sync_checker.dart ';

class TeacherGradingScreen extends StatefulWidget {
  const TeacherGradingScreen({super.key});

  @override
  State<TeacherGradingScreen> createState() => _TeacherGradingScreenState();
}

class _TeacherGradingScreenState extends State<TeacherGradingScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final User? _user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoursesWithSubmissions();
  }

  Future<void> _loadCoursesWithSubmissions() async {
    try {
      // Lấy danh sách khóa học của giáo viên
      final teacherCoursesSnapshot = await _dbRef
          .child('userCourses/${_user?.uid}')
          .once();

      if (teacherCoursesSnapshot.snapshot.value == null) {
        setState(() => _isLoading = false);
        return;
      }

      final teacherCourses = teacherCoursesSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final courseIds = teacherCourses.keys.map((key) => key.toString()).toList();

      final coursesWithSubmissions = <Map<String, dynamic>>[];

      for (final courseId in courseIds) {
        // Lấy thông tin chi tiết về khóa học
        final courseSnapshot = await _dbRef.child('courses/$courseId').once();
        if (courseSnapshot.snapshot.value != null) {
          final courseData = courseSnapshot.snapshot.value as Map<dynamic, dynamic>;
          final courseName = courseData['name'];

          // Kiểm tra xem có bài nộp nào trong khóa học này không
          final submissionsSnapshot = await _dbRef
              .child('submissions/$courseId')
              .once();

          if (submissionsSnapshot.snapshot.value != null) {
            // Chỉ thêm khóa học có bài nộp vào danh sách
            coursesWithSubmissions.add({
              'id': courseId,
              'name': courseName != null ? courseName : courseId,  // Hiển thị ID nếu không có tên
              'subject': courseData['subject'] ?? '',
            });
          }
        }
      }

      setState(() {
        _courses = coursesWithSubmissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải khóa học: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm điểm bài tập'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCoursesWithSubmissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
          ? const Center(child: Text('Chưa có bài nộp nào từ học sinh'))
          : ListView.builder(
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              leading: const Icon(Icons.school, color: Colors.blue),
              title: Text(course['name']),
              subtitle: Text(course['subject']),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentSubmissionListScreen(
                      courseId: course['id'],
                      courseName: course['name'],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class StudentSubmissionListScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const StudentSubmissionListScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudentSubmissionListScreen> createState() => _StudentSubmissionListScreenState();
}

class _StudentSubmissionListScreenState extends State<StudentSubmissionListScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignmentsWithSubmissions();
  }

  Future<void> _loadAssignmentsWithSubmissions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final assignmentsSnapshot = await _dbRef
          .child('courses/${widget.courseId}/assignments')
          .once();

      if (assignmentsSnapshot.snapshot.value == null) {
        setState(() => _isLoading = false);
        return;
      }

      final assignmentsData = assignmentsSnapshot.snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> assignments = [];

      for (final entry in assignmentsData.entries) {
        final assignmentId = entry.key.toString();
        final submissionSnapshot = await _dbRef
            .child('submissions/${widget.courseId}/$assignmentId')
            .once();

        if (submissionSnapshot.snapshot.value != null) {
          final Map submissionsMap = submissionSnapshot.snapshot.value as Map;
          assignments.add({
            'id': assignmentId,
            'title': entry.value['title'],
            'type': entry.value['type'],
            'submissions': submissionsMap,
            'dueDate': entry.value['dueDate'],
          });
        }
      }

      setState(() {
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải bài nộp: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      // Thử lấy từ Firestore trước
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()!;
      }

      // Nếu không có trong Firestore, thử lấy từ Realtime Database
      final userSnapshot = await _dbRef.child('users/$userId').once();
      if (userSnapshot.snapshot.value != null) {
        return Map<String, dynamic>.from(userSnapshot.snapshot.value as Map);
      }

      return {'name': 'Không rõ', 'avatar': null};
    } catch (e) {
      return {'name': 'Không rõ', 'avatar': null};
    }
  }

  void _showSubmissionDetails(Map<String, dynamic> submission, String userName) {
    if (submission['submissionImageUrl'] == null && submission['fileUrl'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy hình ảnh bài nộp')),
      );
      return;
    }

    final imageUrl = submission['submissionImageUrl'] ?? submission['fileUrl'];
    final TextEditingController scoreController = TextEditingController(text: submission['score']?.toString() ?? '');
    final TextEditingController feedbackController = TextEditingController(text: submission['feedback'] ?? '');
    final String studentId = submission['userId'] ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: Text('Bài làm của $userName'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thời gian nộp: ${_formatDateTime(submission['submittedAt'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (submission['score'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Điểm: ${submission['score']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (submission['feedback'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nhận xét: ${submission['feedback']}',
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImageView(imageUrl: imageUrl),
                        ),
                      );
                    },
                    child: const Text('Xem toàn màn hình'),
                  ),
                  if (studentId.isNotEmpty)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showQuickGradingDialog(studentId, userName, submission);
                      },
                      child: Text(submission['score'] != null ? 'Sửa điểm' : 'Chấm điểm ngay'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickGradingDialog(String studentId, String studentName, Map<String, dynamic> submission) {
    final TextEditingController scoreController = TextEditingController(text: submission['score']?.toString() ?? '');
    final TextEditingController feedbackController = TextEditingController(text: submission['feedback'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Chấm điểm - $studentName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              decoration: const InputDecoration(labelText: 'Điểm số'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
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
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newScore = double.tryParse(scoreController.text.trim());
              final feedback = feedbackController.text.trim();

              if (newScore != null) {
                Navigator.pop(context);

                // Hiển thị loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Đang lưu điểm...'),
                      ],
                    ),
                  ),
                );

                // Sử dụng class kiểm tra đồng bộ để đảm bảo điểm được lưu đúng
                bool success = await SubmissionSyncChecker.verifyGradeSync(
                  context: context,
                  courseId: widget.courseId,
                  assignmentId: submission['assignmentId'] ?? '',
                  studentId: studentId,
                  newScore: newScore,
                  feedback: feedback,
                );

                // Đóng dialog loading
                Navigator.of(context).pop();

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã chấm điểm cho $studentName')),
                  );

                  // Refresh submission list
                  _loadAssignmentsWithSubmissions();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Điểm không hợp lệ')),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Không rõ';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Không rõ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bài nộp - ${widget.courseName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssignmentsWithSubmissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
          ? const Center(child: Text('Chưa có bài nộp nào'))
          : ListView.builder(
        itemCount: _assignments.length,
        itemBuilder: (context, index) {
          final assignment = _assignments[index];
          final submissions = assignment['submissions'] as Map;
          int totalSubmissions = submissions.length;
          int gradedSubmissions = 0;

          submissions.forEach((_, value) {
            if ((value as Map)['status'] == 'graded' || (value as Map)['score'] != null) {
              gradedSubmissions++;
            }
          });

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 3,
            child: ExpansionTile(
              title: Text(
                assignment['title'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loại: ${assignment['type']}'),
                  const SizedBox(height: 4),
                  Text('Đã chấm: $gradedSubmissions/$totalSubmissions'),
                ],
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(),
                ),
                ...submissions.entries.map<Widget>((entry) {
                  final userId = entry.key;
                  final submission = Map<String, dynamic>.from(entry.value);

                  return FutureBuilder<Map<String, dynamic>>(
                    future: _getUserData(userId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final user = snapshot.data!;
                      final userName = user['name'] ?? user['fullName'] ?? 'Học sinh';
                      final isGraded = submission['score'] != null;
                      final submittedAt = submission['submittedAt'] != null
                          ? _formatDateTime(submission['submittedAt'])
                          : 'Không rõ';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['avatar'] != null || user['avatarUrl'] != null
                                ? NetworkImage(user['avatar'] ?? user['avatarUrl'] ?? '')
                                : null,
                            child: (user['avatar'] == null && user['avatarUrl'] == null)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            userName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nộp lúc: $submittedAt'),
                              if (isGraded)
                                Text('Điểm: ${submission['score']}',
                                    style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.blue),
                                tooltip: 'Xem bài nộp',
                                onPressed: () {
                                  _showSubmissionDetails(submission, userName);
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  isGraded ? Icons.edit : Icons.grade,
                                  color: isGraded ? Colors.green : Colors.orange,
                                ),
                                tooltip: isGraded ? 'Sửa điểm' : 'Chấm điểm',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SubmissionReviewScreen(
                                        courseId: widget.courseId,
                                        assignmentId: assignment['id'],
                                        assignmentTitle: assignment['title'],
                                        studentId: userId,
                                        studentName: userName,
                                      ),
                                    ),
                                  ).then((_) => _loadAssignmentsWithSubmissions());
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubmissionReviewScreen(
                                  courseId: widget.courseId,
                                  assignmentId: assignment['id'],
                                  assignmentTitle: assignment['title'],
                                  studentId: userId,
                                  studentName: userName,
                                ),
                              ),
                            ).then((_) => _loadAssignmentsWithSubmissions());
                          },
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageView({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2.5,
          initialScale: PhotoViewComputedScale.contained,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Text('Không thể tải hình ảnh', style: TextStyle(color: Colors.white)));
          },
        ),
      ),
    );
  }
}