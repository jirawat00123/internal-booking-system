// ไฟล์: confirm_reset_pin_dialog.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'reset_pin_success_page.dart'; // ดึงหน้าสำเร็จมาใช้
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConfirmResetPinDialog extends StatefulWidget {
  final int userId; // 👈 เพิ่มการรับค่า userId

  const ConfirmResetPinDialog({super.key, required this.userId});

  @override
  State<ConfirmResetPinDialog> createState() => _ConfirmResetPinDialogState();
}

class _ConfirmResetPinDialogState extends State<ConfirmResetPinDialog> {
  bool _isLoading = false; // 👈 เพิ่มสถานะ Loading

  // 👈 เพิ่มฟังก์ชันเรียก API
  Future<void> _resetPin() async {
    setState(() => _isLoading = true);

    // 🔴 Evidence Log: ก่อนยิง API
    print("[Reset PIN] userId = ${widget.userId}");

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // ✅ นำ Config จริงมาใส่แทน Placeholder (สมมติว่าเป็น Android Emulator port 3000)
      // หากคุณมีไฟล์ ApiConfig (เช่น ApiConfig.baseUrl) ให้เปลี่ยนมาเรียกใช้ตัวแปรแทนเพื่อไม่ให้ Hardcode
      final String baseUrl = 'http://localhost:3001';
      final url = Uri.parse(
        '$baseUrl/api/users/admin/users/${widget.userId}/reset-pin',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // 🔴 Evidence Log: ผลลัพธ์ API
      print("[Reset PIN] Status Code: ${response.statusCode}");
      print("[Reset PIN] Response Body: ${response.body}");

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context); // ปิด Popup

        // ไปหน้า Success Page
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const ResetPinSuccessPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      } else {
        // จัดการ Error (แจ้งเตือน)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${response.body}')),
        );
      }
    } catch (e) {
      print("[Reset PIN] Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // เบลอฉากหลัง
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 50, color: Color(0xFF003E77)),
              const SizedBox(height: 20),
              const Text(
                'ยืนยันการรีเซ็ตรหัสผ่าน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                  color: Color(0xFF003E77),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'คุณต้องการรีเซ็ตรหัสผ่านใช่หรือไม่?',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Kanit',
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        // 👈 ป้องกันการกดซ้ำขณะโหลด
                        onPressed: _isLoading ? null : _resetPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0096C7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'ตกลง',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC60000), // สีแดง
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
