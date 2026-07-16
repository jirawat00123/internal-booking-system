import 'package:flutter/material.dart';
import '../Book_history.dart';

class RoomCompletedScreen extends StatelessWidget {
  const RoomCompletedScreen({
    super.key,
  }); // 💡 ปรับให้ใช้ Super parameters ตามมาตรฐาน Dart ปัจจุบันconst RoomCompletedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // พื้นหลังสีกรมท่าเข้มโทนลึกตามดีไซน์
      backgroundColor: const Color(0xFF1E293B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // วงกลมไอคอนเครื่องหมายติ๊กถูกสีเขียวมินต์
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF2EC4B6,
                  ).withOpacity(0.2), // วงแหวนจาง ๆ รอบนอก
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2EC4B6), // วงกลมหลักสีเขียวมินต์
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 55),
                ),
              ),
              const SizedBox(height: 32),

              // ข้อความ จองห้องประชุมสำเร็จ
              const Text(
                'จองห้องประชุมสำเร็จ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                ),
              ),
              const SizedBox(height: 60),

              // ปุ่มแรก: ไปที่ประวัติการจอง (ปุ่มสีขาว ตัวหนังสือสีกรมท่า)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // 💡 แก้ไขการจัดการ Stack: เคลียร์หน้าก่อนหน้าทั้งหมด (เช่น หน้าฟอร์มจอง) จนถึงหน้าหลัก แล้วเปิดหน้าประวัติ ป้องกันการกดย้อนกลับไปจองซ้ำ
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BookingHistoryScreen(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text(
                    'ไปที่ประวัติการจอง',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ปุ่มที่สอง: กลับหน้าหลัก (ปุ่มสีเทาเข้มโปร่งแสง)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.12),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    elevation: 0,
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  onPressed: () {
                    // เคลียร์ Stack ของหน้าต่าง ๆ ออกทั้งหมด แล้วกลับไปหน้าแรกสุด
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
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
    );
  }
}
