import 'package:flutter/material.dart';
import 'package:study_app/ui/subjects/assignment/assignment_screen.dart';
import 'package:study_app/ui/chat/chat_group_screen.dart';

import '../lecture/lecture_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final String courseId;
  final String courseName;
  final String? userRole;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(courseName),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.video_library), text: 'Bài giảng'),
              Tab(icon: Icon(Icons.assignment), text: 'Bài tập'),
              Tab(icon: Icon(Icons.chat), text: 'Nhóm thảo luận'),
            ],
            indicatorColor: Colors.purple,
            labelColor: Colors.purple,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            // Tab Bài giảng - Truyền userRole xuống LectureScreen
            LectureScreen(courseId: courseId, userRole: userRole),

            // Tab Bài tập
            AssignmentScreen(courseId: courseId, userRole: userRole),

            // Tab Nhóm thảo luận
            ChatGroupScreen(courseId: courseId),
          ],
        ),
      ),
    );
  }

  // Bạn có thể giữ nguyên phần _buildLectureTab() nếu cần sử dụng ở nơi khác
  Widget _buildLectureTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library, size: 50, color: Colors.blue),
          const SizedBox(height: 20),
          Text(
            'Bài giảng cho khóa học ${courseId.replaceAll('_', ' ')}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              // Xử lý khi nhấn vào xem bài giảng
            },
            child: const Text('Xem bài giảng'),
          ),
        ],
      ),
    );
  }
}