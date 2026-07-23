import 'package:flutter/material.dart';

class AddUserSuccessPage extends StatelessWidget {
  const AddUserSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2433),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ ไอคอนเครื่องหมายถูก (วงกลม)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3BCA9E), // สีเขียวมิ้นต์ด้านใน
                  border: Border.all(
                    color: Colors.grey.shade500, // สีเทาขอบด้านนอก
                    width: 6,
                  ),
                ),
                child: const Icon(Icons.check, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),

              // 📝 ข้อความสำเร็จ
              const Text(
                'เพิ่มพนักงานสำเร็จ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // 🔘 ปุ่ม "กลับไปหน้าจัดการพนักงาน" (สีขาว)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // กลับไปหน้ารายชื่อ
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'กลับไปหน้าจัดการพนักงาน',
                    style: TextStyle(
                      color: Color(0xFF1E2433),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 🔘 ปุ่ม "กลับไปหน้า Login" (สีเทาเข้ม)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    // เคลียร์หน้าต่างทั้งหมดแล้วกลับหน้าแรกสุด
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3E485B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'กลับไปหน้า Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
