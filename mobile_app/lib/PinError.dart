import 'package:flutter/material.dart';

class PinError extends StatelessWidget {
  final VoidCallback onRetry; // รับคำสั่งเพื่อนำไปรีเซ็ตค่า PIN ในหน้าหลัก

  const PinError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.priority_high, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'รหัสผ่านไม่ถูกต้อง',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF003E77), 
                fontFamily: 'Kanit'
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'โปรดลองอีกครั้ง',
              style: TextStyle(
                fontSize: 14, 
                color: Colors.grey, 
                fontFamily: 'Kanit'
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // ปิดหน้าต่าง Popup
                  onRetry(); // สั่งให้รีเซ็ตตัวเลข PIN กลับเป็นค่าว่าง
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0096C7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'ตกลง', 
                  style: TextStyle(
                    fontSize: 16, 
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    fontFamily: 'Kanit'
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