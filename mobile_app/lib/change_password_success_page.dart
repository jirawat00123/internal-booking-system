import 'package:flutter/material.dart';

class ChangePasswordSuccessPage extends StatelessWidget {
  const ChangePasswordSuccessPage({super.key});

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
                // 🟢 ไอคอนเครื่องหมายถูก
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
                  'เปลี่ยนรหัสสำเร็จ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ระบบได้เปลี่ยนรหัสให้คุณแล้ว',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 48),

                // 🔘 ปุ่มกลับหน้าหลัก
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // 🚀 กลับไปยังหน้าเมนูหลัก (สมมติว่าหน้าหลักคือหน้าที่ 2 ใน Stack)
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
                      'กลับหน้าหลัก',
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
