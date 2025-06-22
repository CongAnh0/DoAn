import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_app/ui/service/auth/auth_service.dart';
import 'package:study_app/ui/home/home.dart'; // Đảm bảo bạn đã import màn hình chính

class CourseConfirmationScreen extends StatelessWidget {
  final String courseId;
  final String courseTitle;

  const CourseConfirmationScreen({
    Key? key,
    required this.courseId,
    required this.courseTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đăng ký')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bạn có chắc muốn đăng ký khóa học:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              courseTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await Provider.of<AuthService>(context, listen: false)
                          .enrollInCourse(courseId);
                      // Sau khi đăng ký xong thì quay về Home và hiển thị thông báo
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                            (Route<dynamic> route) => false,
                      );
                      // Hiển thị thông báo sau một khung hình để tránh lỗi context
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đăng ký khóa học thành công!')),
                        );
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi: ${e.toString()}')),
                      );
                    }
                  },
                  child: const Text('Đăng ký'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
