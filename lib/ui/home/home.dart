import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:study_app/ui/service/auth/auth_service.dart';
import 'package:study_app/ui/subjects/course/grade_selection_screen.dart';
import 'package:study_app/ui/ai_chat/ai_chat_screen.dart';
import 'package:study_app/ui/settings/setting_screen.dart';
import 'package:study_app/ui/service/auth/login_screen.dart';
import '../chat/chat_list_screen.dart';
import '../subjects/assignment/assignment_submission_screen.dart';
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

  // Hàm kiểm tra đăng nhập trước khi chuyển màn hình
  void _navigateWithAuthCheck(BuildContext context, Widget screen) {
    if (_user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            onLoginSuccess: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => screen),
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      );
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
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: () {
                      if (_user == null) {
                        _navigateWithAuthCheck(context, const Placeholder());
                      } else {
                        // Xử lý thêm bạn bè
                      }
                    },
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
                  _buildMenuButton(
                    context,
                    Icons.chat,
                    'AI Chat',
                    Colors.green,
                    const AiChatScreen(),
                  ),
                  if (_userRole == 'student')
                    _buildMenuButton(
                      context,
                      Icons.grade,
                      'Xem điểm',
                      Colors.teal,
                      const Placeholder(), // Thay bằng màn hình xem điểm thực tế
                    ),
                    if (_userRole == 'teacher')
                      _buildMenuButton(
                        context,
                        Icons.grading,
                        'Chấm điểm',
                        Colors.deepPurple,
                        const TeacherGradingScreen(), // Màn hình mới sẽ tạo
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
                              ? Center(
                            child: ElevatedButton(
                              onPressed: () {
                                _navigateWithAuthCheck(context, const ChatListScreen());
                              },
                              child: const Text('Đăng nhập để xem tin nhắn'),
                            ),
                          )
                              : ChatListScreen(),
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
              // Nếu là màn hình cần courseId, chúng ta sẽ xử lý trong _buildCourseList
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
        ? Center(
      child: ElevatedButton(
        onPressed: () {
          _navigateWithAuthCheck(context, const GradeSelectionScreen());
        },
        child: const Text('Đăng nhập để xem khóa học'),
      ),
    )
        : StreamBuilder<DatabaseEvent>(
      stream: _dbRef.child('userCourses/${_user!.uid}').onValue.asBroadcastStream(),
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
                      icon: const Icon(Icons.assignment),
                      onPressed: () {
                        _navigateWithAuthCheck(
                          context,
                          AssignmentScreen(
                            courseId: courseKey,
                            userRole: _userRole ?? '',
                          ),
                        );
                      },
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
      backgroundColor: Colors.black,
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