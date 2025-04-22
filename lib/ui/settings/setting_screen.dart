import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_app/ui/service/auth/login_screen.dart';
import 'package:study_app/ui/add_friend/friend_list_screen.dart';
import 'package:study_app/ui/settings/profile_screen.dart'; // Thêm import này

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt cá nhân'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSettingsItem(
            context,
            Icons.person,
            'Hồ sơ người dùng',
            onTap: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      onLoginSuccess: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              }
            },
          ),
          _buildSettingsItem(
            context,
            Icons.notifications,
            'Thông báo',
            onTap: () {
              // Xử lý khi nhấn vào Thông báo
            },
          ),
          _buildSettingsItem(
            context,
            Icons.palette,
            'Giao diện',
            onTap: () {
              // Xử lý khi nhấn vào Giao diện
            },
          ),
          _buildSettingsItem(
            context,
            Icons.chat,
            'Thiết lập trò chuyện',
            onTap: () {
              // Xử lý khi nhấn vào Thiết lập trò chuyện
            },
          ),
          _buildSettingsItem(
            context,
            Icons.people,
            'Danh sách bạn bè',
            onTap: () {
              // Kiểm tra đăng nhập trước khi vào màn hình bạn bè
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      onLoginSuccess: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const FriendListScreen()),
                        );
                      },
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendListScreen()),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
      BuildContext context,
      IconData icon,
      String title, {
        required Function() onTap,
      }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.purple),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () async {
        try {
          await FirebaseAuth.instance.signOut();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi đăng xuất: ${e.toString()}')),
          );
        }
      },
      child: const Text('Đăng xuất'),
    );
  }
}