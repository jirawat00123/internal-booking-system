import 'package:flutter/material.dart';
import 'Book_history.dart';

class RoomCompletedScreen extends StatelessWidget {
  const RoomCompletedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 ใช้สีพื้นหลังสีกรมท่าเข้มโทนลึกตามภาพดีไซน์ของคุณ
      backgroundColor: const Color(0xFF1E293B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 💡 วงกลมไอคอนเครื่องหมายติ๊กถูกสีเขียวมินต์ขนาดใหญ่ขอบวงแหวนซ้อน
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BookingHistoryScreen(),
                      ),
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

              // ปุ่มที่สอง: กลับหน้าหลัก (ปุ่มสีเทาเข้มโปร่งแสงจาง ๆ)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(
                      0.12,
                    ), // สีเทาโปร่งแสงตามดีไซน์
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
                    // 💡 แก้ไข: เด้งเคลียร์หน้าจอย้อนกลับไปหาหน้าแรกสุด (หน้าแรกของแอปคือหน้า Digital)
                    //Navigator.of(context).popUntil((route) => route.isFirst);

                    // 💡 หมายเหตุเสริม: หากหน้าแรกสุดของแอปไม่ใช่หน้า Digital แต่คุณใช้โครงสร้างระบบ Named Routes
                    // ที่เซ็ตชื่อป้ายเส้นทางไว้ในคลาสคู่ขนานย่อย (เช่น '/digital') ให้สลับมาใช้คำสั่งบรรทัดนี้แทนได้ครับ:
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/digitel', (route) => false);
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
