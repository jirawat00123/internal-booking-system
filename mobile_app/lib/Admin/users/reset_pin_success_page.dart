// ไฟล์: reset_pin_success_page.dart
import 'package:flutter/material.dart';

class ResetPinSuccessPage extends StatelessWidget {
  const ResetPinSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF222B3C), // สีพื้นหลังกรมท่าเข้ม
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ไอคอนเครื่องหมายถูกพร้อมวงแหวนสีเทา
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BEC9), // สีเขียวมิ้นท์
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.4),
                      width: 8,
                    ),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 32),

                const Text(
                  'รีเซ็ตรหัสผ่านพนักงานสำเร็จ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 48),

                // ปุ่มกลับไปหน้าจัดการพนักงาน
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      ); // ปิดหน้านี้เพื่อกลับไปหน้า UsersPage
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF222B3C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'กลับไปหน้าจัดการพนักงาน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ปุ่มกลับไปหน้า Login
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      // 🚀 กลับไปยังจุดเริ่มต้นสุดของแอป (หน้าแรก)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A5568),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'กลับไปหน้า Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
