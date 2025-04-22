import 'package:flutter/material.dart';
import 'package:study_app/ui/subjects/course/course_list_screen.dart';

class SubjectSelectionScreen extends StatelessWidget {
  final int grade;

  const SubjectSelectionScreen({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    final subjects = {
      'math': 'Toán',
      'literature': 'Tiếng Việt',
      'english': 'Tiếng Anh',
    };

    return Scaffold(
      appBar: AppBar(title: Text('Lớp $grade - Chọn môn')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subjectKey = subjects.keys.elementAt(index);
          final subjectName = subjects[subjectKey];
          return Card(
            child: ListTile(
              title: Text(subjectName!),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseListScreen(
                      grade: grade,
                      subject: subjectKey,
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