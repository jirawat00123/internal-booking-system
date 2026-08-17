import 'package:flutter/material.dart';
import 'package:mobile_app/Select.dart';
import 'Manage.dart';
import 'package:mobile_app/Digitel.dart';
import 'Notification/notification_page.dart'; // 👈 นำเข้า NotificationPage ใหม่
import 'Dashboard/dashboard_page.dart';

void main() {
  runApp(const WelcomeApp());
}

class WelcomeApp extends StatelessWidget {
  const WelcomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Menam Mechanika',
      theme: ThemeData(primarySwatch: Colors.blue),

      // ✅ อัปเดตแผนที่เส้นทาง (Routes) เพิ่ม /notifications
      routes: {
        '/manage': (context) => const ManagePage(),
        '/digitel': (context) => const UserMenuPage(),
        '/login': (context) => const LoginSelectionPage(),
        '/notifications': (context) =>
            const NotificationPage(), // 👈 ลงทะเบียน Route ของระบบแจ้งเตือน
        '/dashboard': (context) => const DashboardPage(),
      },

      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.grey[900],
          body: Center(
            child: Container(
              width: 400,
              height: 800,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              // เพิ่มการจัดการกรณี child เป็น null ป้องกัน Error ในบางสถานการณ์
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: const WelcomeScreen(),
    );
  }
}

// โครงสร้างคลาส WelcomeScreen ด้านล่างนี้เหมือนเดิมทุกอย่าง...
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // เปลี่ยนมาใช้ Named Route เพื่อให้สอดคล้องกับที่ลงทะเบียนไว้ใน WelcomeApp
        Navigator.pushNamed(context, '/login');
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bgmmk.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Image.asset('assets/images/MMK_logofull.png', width: 396),
              const Spacer(flex: 1),
              const SizedBox(height: 10),
              Container(width: 280, height: 2, color: Colors.white),
              const SizedBox(height: 15),
              const Text(
                'MENAM MECHANIKA © 2026',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(flex: 4),
            ],
          ),
        ),
      ),
    );
  }
}
