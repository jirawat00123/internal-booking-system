import 'package:flutter/material.dart';
// 💡 อย่าลืม Import ไฟล์หน้า History ของคุณเข้ามาตรงนี้นะครับ
import '../Booking_history.dart'; 
import '../digitel.dart';

class VehicleBookingSuccessPage extends StatelessWidget {
  const VehicleBookingSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2838), // สีพื้นหลังเข้ม
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // วงกลมเครื่องหมายถูก
            Container(
              width: 120, height: 120,
              decoration: const BoxDecoration(color: Color(0xFF4CB8C4), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 70),
            ),
            const SizedBox(height: 24),
            const Text('จองรถสำเร็จ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Kanit')),
            const SizedBox(height: 12),
            const Text(
              'ระบบทำการจองรถให้คุณเรียบร้อยแล้ว\nสามารถนำรถออกได้ในวันและเวลาที่กำหนด', 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 14, color: Colors.white70, fontFamily: 'Kanit', height: 1.5)
            ),
            const SizedBox(height: 50),
            
            // 🔘 ปุ่ม: ไปที่ประวัติการจอง
            SizedBox(
              width: 280, height: 50,
              child: ElevatedButton(
                onPressed: () {
                   // 💡 เปลี่ยน MyHistoryPage() เป็นชื่อคลาสหน้าประวัติของคุณ
                   // ใช้ pushAndRemoveUntil เพื่อลบประวัติการกด Back ป้องกันผู้ใช้กดย้อนกลับมาหน้า Success
                   Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const BookingHistoryScreen()), (route) => false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('ไปที่ประวัติการจอง', style: TextStyle(color: Color(0xFF1E2838), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
              ),
            ),
            const SizedBox(height: 16),
            
            // 🔘 ปุ่ม: กลับหน้าหลัก
            SizedBox(
              width: 280, height: 50,
              child: ElevatedButton(
                onPressed: () {
                   // 💡 เปลี่ยน MyHomePage() เป็นชื่อคลาสหน้าหลักของคุณ
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const UserMenuPage()), (route) => false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('กลับหน้าหลัก', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}