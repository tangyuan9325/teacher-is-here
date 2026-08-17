import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/macaron_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 设置状态栏透明
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const TeacherIsHereApp());
}

class TeacherIsHereApp extends StatelessWidget {
  const TeacherIsHereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '老师来了',
      debugShowCheckedModeBanner: false,
      theme: MacaronTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
