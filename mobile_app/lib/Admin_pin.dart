import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // สำหรับแปลงข้อมูล JSON
import 'PinError.dart'; 
import 'AdminGroupPage.dart'; 

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
  Future<void> _verifyPin() async {
    setState(() {
      isLoading = true; 
    });

    try {
      // 🚨 เปลี่ยนจาก localhost เป็น 10.0.2.2 สำหรับมือถือจำลอง (Android Emulator)
      // (ถ้าคุณปิ่นรันบนเว็บ Chrome ให้ใช้ localhost เหมือนเดิมได้เลยนะครับ)
      final url = Uri.parse('http://localhost:3001/api/login-pin'); 
      
      print('📱 [Flutter] กำลังส่งรหัส $pin ไปหาหลังบ้าน...'); 

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pin': pin,
          'expectedRole': 'ADMIN' // 👈 กระซิบบอกหลังบ้านว่า นี่คือหน้าจอของแอดมิน!
        }), 
      ).timeout(const Duration(seconds: 5)); // ให้เวลารอแค่ 5 วิ

      print('📱 [Flutter] หลังบ้านตอบกลับ Code: ${response.statusCode}'); 
      print('📱 [Flutter] ข้อมูลจากหลังบ้าน: ${response.body}'); 

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // 🛑 ด่านตรวจสิทธิ์: เช็กว่าใช่ ADMIN จริงไหม?
        if (responseData['role'] == 'ADMIN') {
          // 🟢 รหัสถูก สิทธิ์ถูกต้อง พาเข้าหน้า AdminGroupPage เลย
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminGroupPage()), // 👈 เปลี่ยนเป็นหน้าของแอดมิน
          );
        } else {
          // 🛑 รหัสถูก แต่สิทธิ์ไม่ใช่แอดมิน (เช่น เอารหัส รปภ. มาใส่) เด้ง Popup!
          setState(() { isLoading = false; });
          _showErrorDialog(); 
        }
      } else {
        // 🛑 รหัสผิด (เช่น 401 หรือ 403) เด้ง Popup ตัวเก่งของคุณปิ่น!
        setState(() { isLoading = false; });
        _showErrorDialog(); 
      }
    } catch (error) {
      // 🔌 กรณีที่ติดต่อเซิร์ฟเวอร์ไม่ได้เลย
      print('📱 [Flutter] ❌ เชื่อมต่อเซิร์ฟเวอร์ไม่ได้! สาเหตุ: $error'); 
      if (mounted) {
        setState(() { isLoading = false; });
        _showErrorDialog(); 
      }
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'กรอกรหัส PIN',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Kanit'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_outline, size: 30, color: Color(0xFF00529B)),
                            SizedBox(width: 8),
                            Text(
                              'ผู้ดูแลระบบ',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00529B), fontFamily: 'Kanit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('ระบุรหัส PIN', style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Kanit')),
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
                                border: Border.all(color: isFilled ? const Color(0xFF00529B) : Colors.grey.shade400, width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: Text(
                                  isFilled ? (isObscured ? '●' : pin[index]) : '',
                                  style: TextStyle(fontSize: isObscured ? 20 : 24, color: const Color(0xFF00529B), fontWeight: FontWeight.bold),
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
                            isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
                                icon: const Icon(Icons.cancel_outlined, size: 32, color: Colors.blueAccent),
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
                            onPressed: isLoading ? null : () { // ถ้ากำลังโหลดอยู่ให้ปุ่มกดไม่ได้
                              if (pin.length == 6) {
                                _verifyPin(); // เรียกฟังก์ชันเช็ก API
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('กรุณากรอกรหัส PIN ให้ครบ 6 หลัก', style: TextStyle(fontFamily: 'Kanit')),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0096C7),
                              disabledBackgroundColor: Colors.grey.shade400, // สีปุ่มตอนจางลง
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('ดำเนินการต่อ', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Container(height: 1, width: 250, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'MENAM MECHANIKA © 2026',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
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
        children: numbers.map((num) => _buildNumButton(num)).toList(),
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
          shape: const CircleBorder(),
        ),
        child: Text(
          number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
    );
  }
}