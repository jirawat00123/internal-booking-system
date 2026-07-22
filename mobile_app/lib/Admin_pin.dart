import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // สำหรับแปลงข้อมูล JSON
import 'package:shared_preferences/shared_preferences.dart'; // 💡 เพิ่มแพ็กเกจนี้เพื่อใช้เซฟ Token
import 'PinError.dart';
import 'AdminGroupPage.dart';
import 'Booking_room/Room_model.dart';

class Admin_pinPage extends StatefulWidget {
  const Admin_pinPage({super.key});

  @override
  State<Admin_pinPage> createState() => _Admin_pinPageState();
}

class _Admin_pinPageState extends State<Admin_pinPage> {
  String pin = "";
  bool isObscured = true;
  bool isLoading = false; // 💡 เพิ่มตัวแปรเช็กสถานะกำลังโหลด

  void _addPin(String number) {
    if (pin.length < 6) {
      setState(() {
        pin += number;
      });
    }
  }

  void _removePin() {
    if (pin.isNotEmpty) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }

  // ฟังก์ชันเรียก Popup แจ้งเตือนเมื่อรหัสผิด
  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PinError(
          onRetry: () {
            setState(() {
              pin = ""; // เคลียร์ PIN ให้ว่างเพื่อกดใหม่
            });
          },
        );
      },
    );
  }

  // 🚀 ฟังก์ชันยิง API สำหรับแอดมิน
  // 🚀 ฟังก์ชันยิง API สำหรับแอดมิน (ฉบับ Production Ready)
  Future<void> _verifyPin() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 💡 ข้อแนะนำ: ควรดึง URL จาก Config File แทนการ Hardcode
      final url = Uri.parse('http://localhost:3001/api/login-pin');

      debugPrint(
        '📱 [Flutter] กำลังส่งรหัส $pin ไปหาหลังบ้าน...',
      ); // 💡 เพิ่ม Log จากไฟล์ 2

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pin': pin, 'expectedRole': 'ADMIN'}),
          )
          .timeout(const Duration(seconds: 5));

      debugPrint(
        '📱 [Flutter] หลังบ้านตอบกลับ Code: ${response.statusCode}',
      ); // 💡 เพิ่ม Log จากไฟล์ 2

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);

          if (responseData['role'] == 'ADMIN') {
            final token = responseData['token'] ?? '';

            // [EVIDENCE_FLUTTER] 1. ตรวจสอบโครงสร้างดิบที่ Backend ตอบกลับมาจริง ๆ
            debugPrint(
              '[EVIDENCE_FLUTTER] 1. Raw Response Body from Login API: ${response.body}',
            );
            // [EVIDENCE_FLUTTER] 2. ตรวจสอบว่าแกะตัวแปรออกมาได้ค่าอะไร และมีความยาวเท่าไหร่
            debugPrint(
              '[EVIDENCE_FLUTTER] 2. Extracted Token Value: "$token" (Length: ${token.length})',
            );

            // 💡 1. เซฟ Token อย่างปลอดภัย (ควรใช้ flutter_secure_storage ในอนาคต)
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', token);

            // [EVIDENCE_FLUTTER] 3. ตรวจสอบเพื่อรีเช็คว่า SharedPreferences บันทึกข้อมูลเข้าดิสก์สำเร็จจริงหรือไม่
            final doubleCheckToken = prefs.getString('token');
            debugPrint(
              '[EVIDENCE_FLUTTER] 3. Double Check Token from SharedPreferences right after save: "$doubleCheckToken"',
            );

            // 💡 2. เช็ค mounted อีกครั้งหลังมี await
            if (!mounted) return;
            // 🟢 รหัสถูก สิทธิ์ถูกต้อง พาเข้าหน้า AdminGroupPage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminGroupPage()),
            );
          } else {
            _handleErrorState(); // เรียกใช้ฟังก์ชันที่ยุบรวมแล้ว
          }
        } catch (e) {
          debugPrint("JSON Parse Error: $e");
          _handleErrorState();
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'บัญชีนี้ถูกเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } else {
        _handleErrorState();
      }
    } catch (error) {
      debugPrint("API Error: $error");
      _handleErrorState();
    }
  }

  // 🔥 ฟังก์ชันยุบรวมสำหรับจัดการ Error State เพื่อลด Duplicate Code
  void _handleErrorState() {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // พื้นหลัง
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF00529B),
              image: DecorationImage(
                image: AssetImage('assets/images/bgmmk.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ส่วนหัว (AppBar)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'กรอกรหัส PIN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // การ์ดสีขาวด้านล่าง
                Expanded(
                  child: Container(
                    width: 375,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 24.0,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 30,
                              color: Color(0xFF00529B),
                            ), // 👈 ไอคอนโล่ รปภ.
                            SizedBox(width: 8),
                            Text(
                              'ผู้ดูแลระบบ', // 👈 เปลี่ยนข้อความ
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00529B),
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'ระบุรหัส PIN',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // กล่องใส่รหัส 6 หลัก
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            bool isFilled = index < pin.length;
                            return Container(
                              width: 45,
                              height: 55,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isFilled
                                      ? const Color(0xFF00529B)
                                      : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  isFilled
                                      ? (isObscured ? '●' : pin[index])
                                      : '',
                                  style: TextStyle(
                                    fontSize: isObscured ? 20 : 24,
                                    color: const Color(0xFF00529B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 40),

                        // ปุ่มเปิด/ปิดตา (ดูรหัส)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isObscured = !isObscured;
                            });
                          },
                          child: Icon(
                            isObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.blueAccent.withOpacity(0.5),
                            size: 28,
                          ),
                        ),

                        const Spacer(flex: 1),

                        // แป้นตัวเลข Numpad
                        _buildNumpadRow(['1', '2', '3']),
                        _buildNumpadRow(['4', '5', '6']),
                        _buildNumpadRow(['7', '8', '9']),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(width: 60, height: 60),
                            _buildNumButton('0'),
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: IconButton(
                                onPressed: _removePin,
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 32,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Spacer(flex: 2),

                        // 🚀 ปุ่ม "ดำเนินการต่อ"
                        SizedBox(
                          width: 375 - 48,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (pin.length == 6) {
                                      _verifyPin();
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'กรุณากรอกรหัส PIN ให้ครบ 6 หลัก',
                                            style: TextStyle(
                                              fontFamily: 'Kanit',
                                            ),
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0096C7),
                              disabledBackgroundColor: Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'ดำเนินการต่อ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Container(
                          height: 1,
                          width: 250,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'MENAM MECHANIKA © 2026',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadRow(List<String> numbers) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: numbers
            .map((num) => _buildNumButton(num))
            .toList(), // 💡 Refactor ให้กระชับขึ้น
      ),
    );
  }

  Widget _buildNumButton(String number) {
    return SizedBox(
      width: 60,
      height: 60,
      child: TextButton(
        onPressed: () => _addPin(number),
        style: TextButton.styleFrom(
          shape:
              const CircleBorder(), // 💡 ใช้ TextButton.styleFrom ตามไฟล์ 2 (อ่านง่ายกว่า)
        ),
        child: Text(
          //...
          number,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
