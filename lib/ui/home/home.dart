import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:study_app/ui/service/auth/auth_service.dart';
import 'package:study_app/ui/subjects/course/grade_selection_screen.dart';
import 'package:study_app/ui/settings/setting_screen.dart';
import 'package:study_app/ui/service/auth/login_screen.dart';
import '../chat/chat_list_screen.dart';
import '../subjects/assignment/assignment_submission_screen.dart';
import '../subjects/assignment/submitted_assignments_screen.dart';
import '../subjects/assignment/teacher_grading_screen.dart';
import '../subjects/course/course_detail_screen.dart';
import '../subjects/assignment/assignment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _userRole;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final User? _user = FirebaseAuth.instance.currentUser;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final role = await authService.getUserRole();
    setState(() {
      _userRole = role;
    });
  }

  // Hàm kiểm tra đăng nhập trước khi chuyển màn hình - CẢI TIẾN
  void _navigateWithAuthCheck(BuildContext context, Widget screen, {bool showLoginOption = true}) {
    if (_user == null) {
      if (showLoginOption) {
        // Hiển thị dialog lựa chọn cho người dùng
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Yêu cầu đăng nhập'),
              content: const Text('Bạn cần đăng nhập để sử dụng tính năng này. Bạn có muốn đăng nhập ngay?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Đóng dialog và ở lại trang chủ
                  },
                  child: const Text('Để sau'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Đóng dialog trước
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(
                          canGoBack: true, // Cho phép quay lại
                          onLoginSuccess: () {
                            // Sau khi đăng nhập thành công, quay về trang chủ
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
                                  (route) => false,
                            );
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Đăng nhập'),
                ),
              ],
            );
          },
        );
      } else {
        // Chuyển trực tiếp đến màn hình đăng nhập
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              canGoBack: true,
              onLoginSuccess: () {
                // Sau khi đăng nhập thành công, quay về trang chủ
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                );
              },
            ),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
    }
  }

  // Hàm rời khỏi khóa học
  Future<void> _leaveCourse(String courseId, String courseTitle) async {
    // Hiển thị dialog xác nhận
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận'),
          content: Text('Bạn có chắc chắn muốn rời khỏi khóa học "$courseTitle"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Rời khỏi'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && _user != null) {
      try {
        // Xóa khỏi userCourses
        await _dbRef.child('userCourses/${_user.uid}/$courseId').remove();

        // Xóa khỏi danh sách thành viên của khóa học
        await _dbRef.child('courses/$courseId/members/${_user.uid}').remove();

        // Hiển thị thông báo thành công
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã rời khỏi khóa học "$courseTitle"'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Hiển thị thông báo lỗi
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Có lỗi xảy ra: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Home',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      // Hiển thị trạng thái đăng nhập
                      if (_user == null)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(
                                  canGoBack: true,
                                  onLoginSuccess: () {
                                    // Sau khi đăng nhập thành công, quay về trang chủ
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                                          (route) => false,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text('Đăng nhập', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        )
                      else
                        Text(
                          'Xin chào, ${_user.displayName ?? _user.email ?? 'User'}',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: () {
                          _navigateWithAuthCheck(context, const Placeholder());
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildMenuButton(
                    context,
                    Icons.school,
                    'Khóa học',
                    Colors.blue,
                    const GradeSelectionScreen(),
                  ),
                  if (_userRole == 'student')
                    _buildMenuButton(
                      context,
                      Icons.grade,
                      'Xem điểm',
                      Colors.teal,
                      const SubmittedAssignmentsScreen(),
                    ),
                  if (_userRole == 'teacher')
                    _buildMenuButton(
                      context,
                      Icons.grading,
                      'Chấm điểm',
                      Colors.deepPurple,
                      const TeacherGradingScreen(),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm khóa học đang mở',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.school), text: 'Khóa học'),
                        Tab(icon: Icon(Icons.chat), text: 'Tin nhắn'),
                      ],
                      indicatorColor: Colors.purple,
                      labelColor: Colors.purple,
                      unselectedLabelColor: Colors.grey,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCourseList(),
                          _user == null
                              ? _buildLoginPrompt('Đăng nhập để xem tin nhắn', const ChatListScreen())
                              : const ChatListScreen(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Widget hiển thị thông báo đăng nhập với tùy chọn
  Widget _buildLoginPrompt(String message, Widget destination) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _navigateWithAuthCheck(context, destination, showLoginOption: false);
            },
            child: const Text('Đăng nhập ngay'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context,
      IconData icon,
      String label,
      Color color,
      Widget destination, {
        bool requireCourse = false,
      }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.23,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (requireCourse) {
              return;
            }
            _navigateWithAuthCheck(context, destination);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseList() {
    return _user == null
        ? _buildLoginPrompt('Đăng nhập để xem khóa học của bạn', const GradeSelectionScreen())
        : StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('userCourses/${_user.uid}').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('Bạn chưa tham gia khóa học nào'));
        }

        final enrolledCourses = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

        if (enrolledCourses == null || enrolledCourses.isEmpty) {
          return const Center(child: Text('Bạn chưa tham gia khóa học nào'));
        }

        return ListView.builder(
          itemCount: enrolledCourses.length,
          itemBuilder: (context, index) {
            final courseKey = enrolledCourses.keys.elementAt(index).toString();

            return StreamBuilder<DatabaseEvent>(
              stream: _dbRef.child('courses/$courseKey').onValue.asBroadcastStream(),
              builder: (context, courseSnapshot) {
                if (courseSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    leading: CircularProgressIndicator(),
                  );
                }

                if (!courseSnapshot.hasData || courseSnapshot.data!.snapshot.value == null) {
                  return ListTile(
                    title: Text('Khóa học $courseKey'),
                    subtitle: const Text('Đang tải thông tin...'),
                  );
                }

                final courseData = courseSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final courseTitle = courseData['title'] ?? 'Khóa học không có tiêu đề';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.school, color: Colors.blue),
                    title: Text(courseTitle),
                    subtitle: Text('Môn ${courseData['subject']} - Lớp ${courseData['grade']}'),
                    onTap: () {
                      _navigateWithAuthCheck(
                        context,
                        CourseDetailScreen(
                          courseId: courseKey,
                          courseName: courseTitle,
                          userRole: _userRole,
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.red),
                      onPressed: () {
                        _leaveCourse(courseKey, courseTitle);
                      },
                      tooltip: 'Rời khỏi khóa học',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      selectedItemColor: Colors.purple,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentTabIndex,
      onTap: (index) {
        setState(() {
          _currentTabIndex = index;
        });

        if (index == 1) {
          _navigateWithAuthCheck(context, const ChatListScreen());
        } else if (index == 2) {
          _navigateWithAuthCheck(context, const SettingsScreen());
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Trang chủ',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Tin nhắn',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Cá nhân',
        ),
      ],
    );
  }
}