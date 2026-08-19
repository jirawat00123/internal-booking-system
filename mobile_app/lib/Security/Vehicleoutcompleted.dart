import 'package:flutter/material.dart';
import 'SecurityVehiclelist.dart'; // ✅ เปลี่ยนตัว l เป็นพิมพ์เล็กให้ตรงกับชื่อไฟล์จริงบน Disk

class VehicleOutCompletedScreen extends StatelessWidget {
  const VehicleOutCompletedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2836), // สีพื้นหลังเข้มตามรูป
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF42BCA4), // สีเขียวเครื่องหมายถูก
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 8),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'ทำการปล่อยรถสำเร็จ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: 40),

            // 💡 นำปุ่มประวัติออกตามที่รีเควส เหลือแค่ปุ่มกลับหน้าหลัก
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // 🟢 ย้อนกลับไปหน้าก่อนหน้า (SecurityVehiclelist) โดยไม่ลบประวัติ Backstack ทิ้ง
                    // หมายเหตุ: หากกดแล้วย้อนไปเจอหน้ากรอกข้อมูล ให้เพิ่ม Navigator.pop(context); ซ้อนอีก 1 บรรทัด
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'กลับหน้าหลัก',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
