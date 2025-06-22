import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:study_app/ui/service/auth/auth_service.dart';
import 'package:study_app/ui/subjects/course/course_confirmation_screen.dart';
import 'package:study_app/ui/subjects/course/add_course_screen.dart';

class CourseListScreen extends StatefulWidget {
  final int grade;
  final String subject;

  const CourseListScreen({
    super.key,
    required this.grade,
    required this.subject,
  });

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  bool _isTeacher = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _checkTeacherRole();
  }

  Future<void> _checkTeacherRole() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final role = await authService.getUserRole();
    setState(() {
      _isTeacher = role == 'teacher';
    });
  }

  Future<void> _loadCourses() async {
    final dbRef = FirebaseDatabase.instance.ref().child('courses');
    final snapshot = await dbRef
        .orderByChild('grade')
        .equalTo(widget.grade)
        .once();

    setState(() {
      _isLoading = false;
      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
        _courses = data.entries
            .where((entry) => entry.value['subject'] == widget.subject)
            .map((entry) {
          final valueMap = entry.value as Map<dynamic, dynamic>;
          return {
            'id': entry.key.toString(),
            ...valueMap.map((k, v) => MapEntry(k.toString(), v)),
          };
        }).toList();
      }
    });
  }

  String _getSubjectName(String subjectKey) {
    switch (subjectKey) {
      case 'math': return 'Toán';
      case 'literature': return 'Tiếng Việt';
      case 'english': return 'Tiếng Anh';
      default: return subjectKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_getSubjectName(widget.subject)} lớp ${widget.grade}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
          ? Center(child: Text('Chưa có khóa học nào cho môn này'))
          : ListView.builder(
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: ListTile(
              title: Text(course['title']),
              subtitle: Text(course['description'] ?? ''),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseConfirmationScreen(
                      courseId: course['id'],
                      courseTitle: course['title'],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _isTeacher
          ? FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddCourseScreen(
                grade: widget.grade,
                subject: widget.subject,
              ),
            ),
          ).then((_) => _loadCourses());
        },
      )
          : null,
    );
  }
}