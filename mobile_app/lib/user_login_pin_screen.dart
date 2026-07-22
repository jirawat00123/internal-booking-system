import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'digitel.dart';

class UserLoginPinScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const UserLoginPinScreen({super.key, this.userData});

  @override
  State<UserLoginPinScreen> createState() => _UserLoginPinScreenState();
}

class _UserLoginPinScreenState extends State<UserLoginPinScreen> {
  String pin = "";
  bool isObscured = true;
  bool isLoading = false;

  void _addPin(String number) {
    if (pin.length < 6 && !isLoading) {
      setState(() {
        pin += number;
      });
      if (pin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _removePin() {
    if (pin.isNotEmpty && !isLoading) {
      setState(() {
        pin = pin.substring(0, pin.length - 1);
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                    child: const Icon(
                      Icons.priority_high,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'เข้าสู่ระบบไม่สำเร็จ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003E77),
                      fontFamily: 'Kanit',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontFamily: 'Kanit',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 140,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          pin = "";
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0096C7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ตกลง',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
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
      },
    );
  }

  // 🔄 ยิง API ตรวจสอบ PIN จริงกับ Backend
  Future<void> _verifyPin() async {
    setState(() {
      isLoading = true;
    });

    try {
      String? employeeCode;
      if (widget.userData != null) {
        employeeCode = widget.userData!['employeeCode'];
      }

      if (employeeCode == null) {
        setState(() {
          isLoading = false;
        });
        _showErrorDialog("ไม่พบรหัสพนักงาน กรุณาเลือกชื่อใหม่อีกครั้ง");
        return;
      }

      final response = await http.post(
        Uri.parse('http://localhost:3001/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'employeeCode': employeeCode, 'pin': pin}),
      );

      final data = json.decode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        // บันทึก Token ลง SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token']);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserMenuPage()),
        );
      } else {
        setState(() {
          isLoading = false;
        });
        _showErrorDialog(
          data['error'] ?? data['message'] ?? 'รหัส PIN ไม่ถูกต้อง',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
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
                          'จัดการผู้ใช้งาน',
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
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: 16.0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 24.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'กรุณาใส่รหัส PIN เพื่อเข้าสู่ระบบ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF003E77),
                            fontFamily: 'Kanit',
                          ),
                        ),
                        const SizedBox(height: 30),
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
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => setState(() => isObscured = !isObscured),
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
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.blueAccent.withOpacity(0.5),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(flex: 2),
                        SizedBox(
                          height: 30,
                          child: isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF00529B),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'กำลังตรวจสอบรหัส...',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF00529B),
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Kanit',
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        const Spacer(flex: 1),
                        const SizedBox(height: 8),
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
