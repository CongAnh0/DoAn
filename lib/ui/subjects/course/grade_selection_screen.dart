import 'package:flutter/material.dart';
import 'package:study_app/ui/subjects/course/subject_selection_screen.dart';

class GradeSelectionScreen extends StatelessWidget {
  const GradeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn lớp')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 5,
        itemBuilder: (context, index) {
          final grade = index + 1;
          return Card(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubjectSelectionScreen(grade: grade),
                  ),
                );
              },
              child: Center(
                child: Text(
                  'Lớp $grade',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}