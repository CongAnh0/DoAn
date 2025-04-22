import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  // Hàm mở DeepSeek Chat trong trình duyệt
  Future<void> _openDeepSeekChat() async {
    const url = 'https://chat.deepseek.com';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication, // Mở trình duyệt bên ngoài
      );
    } else {
      throw 'Không thể mở DeepSeek Chat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý AI'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/ai_icon.png', // Thêm icon AI của bạn
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 30),
              const Text(
                'Trải nghiệm trò chuyện với AI mạnh mẽ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                'Nhấn nút bên dưới để bắt đầu trò chuyện trên DeepSeek Chat',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _openDeepSeekChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Bắt đầu chat ngay',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}