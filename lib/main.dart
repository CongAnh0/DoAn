import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:study_app/ui/add_friend/add_friend_screen.dart';
import 'package:study_app/ui/add_friend/friend_list_screen.dart';
import 'package:study_app/ui/add_friend/friend_service.dart';
import 'package:study_app/ui/subjects/course/course_list_screen.dart';
import 'ui/home/home.dart';
import 'ui/AI_chat/ai_chat_screen.dart';
import 'package:study_app/ui/service/auth/login_screen.dart';
import 'package:study_app/ui/service/auth/auth_service.dart';
import 'package:study_app/ui/settings/setting_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug, //playIntegrity
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FriendService>(create: (_) => FriendService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: _AuthWrapper(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/subjects': (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return LoginScreen(
              onLoginSuccess: () => Navigator.pushReplacementNamed(context, '/subjects'),
            );
          }
          return const CourseListScreen(grade: 1, subject: 'math');
        },
        '/ai-chat': (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return LoginScreen(
              onLoginSuccess: () => Navigator.pushReplacementNamed(context, '/ai-chat'),
            );
          }
          return const AiChatScreen();
        },
        '/login': (context) => const LoginScreen(),
        '/settings': (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return LoginScreen(
              onLoginSuccess: () => Navigator.pushReplacementNamed(context, '/settings'),
            );
          }
          return const SettingsScreen();
        },
        '/add-friend': (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return LoginScreen(
              onLoginSuccess: () => Navigator.pushReplacementNamed(context, '/add-friend'),
            );
          }
          return const AddFriendScreen();
        },
        '/friend-list': (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return LoginScreen(
              onLoginSuccess: () => Navigator.pushReplacementNamed(context, '/friend-list'),
            );
          }
          return const FriendListScreen();
        },
      },
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const HomeScreen(); // Hoặc có thể chuyển hướng đến LoginScreen nếu muốn
      },
    );
  }
}
