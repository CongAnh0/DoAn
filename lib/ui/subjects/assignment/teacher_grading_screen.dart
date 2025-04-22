import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'submission_review_screen.dart';

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
        final courseSnapshot = await _dbRef.child('courses/$courseId').once();
        if (courseSnapshot.snapshot.value != null) {
          final courseData = courseSnapshot.snapshot.value as Map<dynamic, dynamic>;

          final submissionsSnapshot = await _dbRef
              .child('submissions/$courseId')
              .once();

          if (submissionsSnapshot.snapshot.value != null) {
            coursesWithSubmissions.add({
              'id': courseId,
              'name': courseData['name'] ?? 'Toán cơ bản lớp 1  ',
              'subject': courseData['subject'] ?? 'Không có môn',
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
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.data() ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bài nộp - ${widget.courseName}')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _assignments.isEmpty
          ? Center(child: Text('Chưa có bài nộp nào'))
          : ListView.builder(
        itemCount: _assignments.length,
        itemBuilder: (context, index) {
          final assignment = _assignments[index];
          return ExpansionTile(
            title: Text(assignment['title']),
            subtitle: Text('Loại: ${assignment['type']}'),
            children: (assignment['submissions'] as Map).entries.map<Widget>((entry) {
              final userId = entry.key;
              final submission = Map<String, dynamic>.from(entry.value);

              return FutureBuilder<Map<String, dynamic>>(
                future: _getUserData(userId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return SizedBox();

                  final user = snapshot.data!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['avatar'] != null
                          ? NetworkImage(user['avatar'])
                          : null,
                      child: user['avatar'] == null ? Icon(Icons.person) : null,
                    ),
                    title: Text(user['name'] ?? 'Không rõ'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (submission['score'] != null)
                          Text('Điểm: ${submission['score']}'),
                        if (submission['feedback'] != null)
                          Text('Nhận xét: ${submission['feedback']}'),
                      ],
                    ),
                    trailing: Icon(Icons.grade),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubmissionReviewScreen(
                            courseId: widget.courseId,
                            assignmentId: assignment['id'],
                            assignmentTitle: assignment['title'],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}