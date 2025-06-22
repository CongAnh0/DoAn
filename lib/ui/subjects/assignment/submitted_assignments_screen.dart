import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'assignment_submission_screen.dart';

class SubmittedAssignmentsScreen extends StatefulWidget {
  const SubmittedAssignmentsScreen({super.key});

  @override
  State<SubmittedAssignmentsScreen> createState() => _SubmittedAssignmentsScreenState();
}

class _SubmittedAssignmentsScreenState extends State<SubmittedAssignmentsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  List<Map<String, dynamic>> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    if (_user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("Đang tìm bài tập của user: ${_user.uid}");

      // Truy vấn trực tiếp danh sách submissions
      final submissionsSnapshot = await _dbRef.child('submissions').once();
      if (submissionsSnapshot.snapshot.value == null) {
        debugPrint("Không tìm thấy submissions nào");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final allSubmissions = Map<String, dynamic>.from(submissionsSnapshot.snapshot.value as Map);
      List<Map<String, dynamic>> userSubmissions = [];

      // Duyệt qua từng course
      for (var courseEntry in allSubmissions.entries) {
        final courseId = courseEntry.key;
        final courseSubmissions = Map<String, dynamic>.from(courseEntry.value as Map);

        debugPrint("Đang kiểm tra khóa học: $courseId");

        // Duyệt qua từng assignment trong course
        for (var assignmentEntry in courseSubmissions.entries) {
          final assignmentId = assignmentEntry.key;
          final assignmentSubmissions = Map<String, dynamic>.from(assignmentEntry.value as Map);

          debugPrint("Kiểm tra assignment: $assignmentId có userId: ${_user.uid}");

          // Kiểm tra xem người dùng hiện tại có nộp assignment này không
          if (assignmentSubmissions.containsKey(_user.uid)) {
            debugPrint("Tìm thấy bài nộp cho assignment: $assignmentId");

            final submissionData = Map<String, dynamic>.from(
                assignmentSubmissions[_user.uid] as Map);

            // Lấy thông tin assignment để có title và course name
            String assignmentTitle = 'Bài tập #$assignmentId';
            String courseName = 'Khóa học #$courseId';

            try {
              // Lấy thông tin assignment
              final assignmentSnapshot = await _dbRef
                  .child('courses')
                  .child(courseId)
                  .child('assignments')
                  .child(assignmentId)
                  .once();

              if (assignmentSnapshot.snapshot.value != null) {
                final assignmentData = Map<String, dynamic>.from(assignmentSnapshot.snapshot.value as Map);
                assignmentTitle = assignmentData['title'] ?? 'Bài tập #$assignmentId';
              }

              // Lấy tên khóa học
              final courseSnapshot = await _dbRef
                  .child('courses')
                  .child(courseId)
                  .child('name')
                  .once();

              if (courseSnapshot.snapshot.value != null) {
                courseName = courseSnapshot.snapshot.value.toString();
              }
            } catch (e) {
              debugPrint('Lỗi khi lấy thông tin assignment hoặc course: $e');
            }

            userSubmissions.add({
              'courseId': courseId,
              'courseName': courseName,
              'assignmentId': assignmentId,
              'assignmentTitle': assignmentTitle,
              ...submissionData,
            });

            debugPrint("Đã thêm bài nộp cho assignment: $assignmentTitle vào danh sách");
          }
        }
      }

      setState(() {
        _submissions = userSubmissions;
        debugPrint("Tổng số bài nộp tìm thấy: ${_submissions.length}");
      });
    } catch (e) {
      debugPrint('Lỗi khi tải bài nộp: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xảy ra lỗi: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(
        body: Center(child: Text("Bạn chưa đăng nhập.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bài tập đã nộp"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubmissions,
            tooltip: 'Làm mới danh sách',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissions.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "Chưa có bài tập nào được nộp",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Các bài tập bạn đã nộp sẽ hiển thị ở đây",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Làm mới"),
              onPressed: _loadSubmissions,
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _submissions.length,
        itemBuilder: (context, index) {
          final submission = _submissions[index];
          final submittedAt = submission['submittedAt'] ?? submission['completedAt'];
          final formattedDate = submittedAt != null
              ? _formatDate(submittedAt)
              : 'Không rõ thời gian';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade800,
                child: const Icon(Icons.assignment_turned_in),
              ),
              title: Text(
                submission['assignmentTitle'] ?? 'Bài tập không rõ tên',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text("Môn học: ${submission['courseName'] ?? 'Không rõ môn học'}"),
                  Text("Nộp vào: $formattedDate"),
                  if (submission['score'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Text("Điểm: "),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${submission['score']}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (submission['feedback'] != null && submission['feedback'].toString().trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Nhận xét: ${submission['feedback']}",
                        style: const TextStyle(fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    submission['score'] != null
                        ? Icons.check_circle
                        : Icons.pending,
                    color: submission['score'] != null
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    submission['score'] != null ? 'Đã chấm' : 'Chờ chấm',
                    style: TextStyle(
                      fontSize: 12,
                      color: submission['score'] != null
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssignmentSubmissionScreen(
                      assignmentId: submission['assignmentId'],
                      courseId: submission['courseId'],
                      assignmentTitle: submission['assignmentTitle'] ?? 'Bài tập không rõ tên',
                      userRole: 'student',
                      userId: _user.uid,
                      fileUrl: submission['fileUrl'],
                    ),
                  ),
                ).then((_) {
                  // Refresh the list when coming back
                  _loadSubmissions();
                });
              },
            ),
          );
        },
      ),
    );
  }
}