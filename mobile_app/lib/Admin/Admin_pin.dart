import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // สำหรับแปลงข้อมูล JSON
import '../PinError.dart'; 
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

  // 🚀 ฟังก์ชันยิง API ตรวจสอบ PIN
  Future<void> _verifyPin() async {
    setState(() {
      isLoading = true; // เริ่มหมุนโหลด
    });

    try {
      // 💡 ข้อควรระวังเรื่อง IP Address:
      // ถ้าใช้ Android Emulator ให้ใช้: http://10.0.2.2:3000/api/login-pin
      // ถ้าใช้ iOS Simulator หรือ Web ให้ใช้: http://localhost:3000/api/login-pin
      final url = Uri.parse('http://localhost:3000/api/login-pin'); 
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin': pin}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // 🛑 ด่านตรวจสิทธิ์: เช็กว่า role ที่ตอบกลับมาเป็น ADMIN จริงๆ ใช่ไหม?
        if (responseData['role'] == 'ADMIN') {
          
          // ถ้าใช่ ADMIN ถึงจะให้ไปหน้าต่อไป
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminGroupPage()), 
          );
          
        } else {
          // ถ้าเป็นสิทธิ์อื่น (เช่น SECURITY) ให้เด้งเตือนและไม่ให้ไปต่อ
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('รหัส PIN นี้ไม่ใช่ของ Admin กรุณาลองใหม่'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // ถ้ารหัสผิด (Code 401)
        setState(() { isLoading = false; });
        _showErrorDialog(); 
      }
    } catch (error) {
      // กรณีเซิร์ฟเวอร์ปิดอยู่ หรือเน็ตหลุด
      setState(() { isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาลองใหม่', style: TextStyle(fontFamily: 'Kanit')),
            backgroundColor: Colors.red,
          ),
        );
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
                image: AssetImage('assets/bg.png'),
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