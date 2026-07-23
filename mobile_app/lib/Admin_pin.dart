import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'PinError.dart';
import 'AdminGroupPage.dart';
import 'Booking_room/Room_model.dart';
import 'package:flutter/foundation.dart'; // สำหรับ kIsWeb
import 'dart:io' show Platform; // สำหรับ Platform.isAndroid

class Admin_pinPage extends StatefulWidget {
  const Admin_pinPage({super.key});

  @override
  State<Admin_pinPage> createState() => _Admin_pinPageState();
}

class _Admin_pinPageState extends State<Admin_pinPage> {
  String pin = "";
  bool isObscured = true;
  bool isLoading = false;

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

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PinError(
          onRetry: () {
            setState(() {
              pin = "";
            });
          },
        );
      },
    );
  }

  // 🚀 ฟังก์ชันยิง API สำหรับแอดมิน (ฉบับ Production Ready & Single Session Compliant)
  Future<void> _verifyPin() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 🟢 1. เลือก Base URL ให้ถูกต้องตาม Platform โดยอัตโนมัติ
      String baseUrl = 'http://localhost:3001/api';
      if (!kIsWeb && Platform.isAndroid) {
        baseUrl = 'http://10.0.2.2:3001/api';
      }
      final url = Uri.parse('$baseUrl/login-pin');

      debugPrint('📱 [Flutter] กำลังส่งรหัส $pin ไปหาหลังบ้าน ($url)...');

      // 🟢 2. อ่าน SharedPreferences และ Token (ประกาศจุดนี้จุดเดียว)
      final prefs = await SharedPreferences.getInstance();
      final String? existingToken = prefs.getString('token');

      // 🟢 3. ตรวจสอบว่ามี Token ในเซสชันก่อนยิง API

      // 🟢 4. ยิง API ยืนยัน PIN
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              // แนบ Header เฉพาะกรณีที่มี Token เท่านั้น
              if (existingToken != null && existingToken.isNotEmpty)
                'Authorization': 'Bearer $existingToken',
            },
            body: jsonEncode({'pin': pin, 'expectedRole': 'ADMIN'}),
          )
          .timeout(const Duration(seconds: 5));

      debugPrint('📱 [Flutter] หลังบ้านตอบกลับ Code: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          final role =
              responseData['role'] ??
              (responseData['user'] != null
                  ? responseData['user']['role']
                  : null);

          if (role == 'ADMIN') {
            // 🟢 5. อัปเดต Token ใหม่ล่าสุดลง prefs
            // ป้องกันกรณีที่ทั้ง Backend ไม่ส่ง Token มา และ existingToken ก็เป็น null
            final String? newToken = responseData['token'] ?? existingToken;
            if (newToken != null && newToken.isNotEmpty) {
              await prefs.setString('token', newToken);
            }

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminGroupPage()),
            );
          } else {
            setState(() {
              isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'สิทธิ์การใช้งานของคุณไม่ใช่ผู้ดูแลระบบ (Role: $role)',
                  style: const TextStyle(fontFamily: 'Kanit'),
                ),
                backgroundColor: Colors.orange,
              ),
            );
            _handleErrorState();
          }
        } catch (e) {
          debugPrint("JSON Parse Error: $e");
          _handleErrorState();
        }
      } else if (response.statusCode == 401) {
        // 🟢 6. กรณี PIN ไม่ถูกต้อง หรือบัญชีถูกระงับ (อ่าน message จริงจาก Backend)
        String errorMessage = 'รหัส PIN ไม่ถูกต้อง';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? errorMessage;
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.red,
          ),
        );
        _handleErrorState();
      } else {
        setState(() {
          isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error ${response.statusCode}: ${response.body}',
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        _handleErrorState();
      }
    } catch (error) {
      debugPrint("API Error: $error");
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ไม่สามารถเชื่อมต่อ Server ได้: $error',
            style: const TextStyle(fontFamily: 'Kanit'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      _handleErrorState();
    }
  }

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
                            ),
                            SizedBox(width: 8),
                            Text(
                              'ผู้ดูแลระบบ',
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
        style: TextButton.styleFrom(shape: const CircleBorder()),
        child: Text(
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
