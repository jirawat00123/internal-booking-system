import 'package:flutter/material.dart';
import 'Admin_roompage.dart';
import '../../AdminGroupPage.dart'; // ดึงเข้ามารองรับปุ่มออกจากระบบ เพื่อกลับไปหน้าเลือกสิทธิ์

class MobileFrameSuccessContainer extends StatelessWidget {
  const MobileFrameSuccessContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[900], // พื้นหลังรอบนอกตู้มือถือ
      child: Center(
        child: Container(
          width: 400, // ความกว้างหน้าจอมือถือ
          height: 800, // ความสูงหน้าจอมือถือ
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30), // ขอบมนโทรศัพท์
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: const AdminAddSuccessPage(), // เรียกใช้หน้าจอสำเร็จด้านใน
        ),
      ),
    );
  }
}

class AdminAddSuccessPage extends StatelessWidget {
  const AdminAddSuccessPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 พื้นหลังสีกรมท่าเข้ม (Dark Navy)
      backgroundColor: const Color(0xFF1E293B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // 1. วงกลมเครื่องหมายถูกสีเขียวมินต์ (Success Icon)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2EC4B6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.shade500.withOpacity(0.4),
                    width: 6,
                  ),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 65),
              ),

              const SizedBox(height: 32),

              // 2. ข้อความ "เพิ่มห้องประชุมสำเร็จ"
              const Text(
                'เพิ่มห้องประชุมสำเร็จ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                  letterSpacing: 0.5,
                ),
              ),

              const Spacer(flex: 2),

              // 3. ปุ่มกดตัวเลือกทั้งสอง
              Column(
                children: [
                  // ปุ่มด้านบน: "กลับไปหน้าห้องประชุม" (แก้ไขการเชื่อมโยงแล้ว)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // 🟢 ใช้ pushAndRemoveUntil เพื่อล้างประวัติหน้าจอ ป้องกันการกดย้อนกลับมาหน้า Success
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MobileFrameContainer(),
                          ),
                          (Route<dynamic> route) =>
                              false, // ลบทิ้งทุกหน้าใน Stack
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E293B),
                        elevation: 3,
                        shadowColor: Colors.black38,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'กลับไปหน้าห้องประชุม',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ปุ่มด้านล่าง: "กลับไปหน้า Login
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // 🟢 ใช้ pushAndRemoveUntil เพื่อล้างประวัติหน้าจอทั้งหมดเช่นกัน
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminGroupPage(),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'กลับไปหน้า Login',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
