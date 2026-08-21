import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'change_password_success_page.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _oldPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  final FocusNode _oldPinFocus = FocusNode();
  final FocusNode _newPinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();

  // 🟢 เปลี่ยนจาก bool เป็น String? เพื่อเก็บข้อความ Error ที่จะแสดงผล
  String? _oldPinErrorMsg;
  String? _confirmPinErrorMsg;
  bool _isLoading = false;

  final String baseUrl = 'http://localhost:3001/api';

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    _oldPinFocus.dispose();
    _newPinFocus.dispose();
    _confirmPinFocus.dispose();
    super.dispose();
  }

  // 🟢 1. ฟังก์ชันส่ง API ไปให้ Backend ตรวจสอบและเปลี่ยนรหัส
  Future<void> _submitChangePin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/change-pin'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'oldPin': _oldPinController.text, // รหัสเดิม (ให้หลังบ้านตรวจ)
          'newPin': _newPinController.text, // รหัสใหม่
        }),
      );

      final data = json.decode(response.body);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200 && data['success'] == true) {
        // เปลี่ยนสำเร็จ ไปหน้า Success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ChangePasswordSuccessPage(),
          ),
        );
      } else {
        // 🟢 ดึง Error จากหลังบ้านมาโชว์ใต้กล่องรหัสเดิม
        setState(() {
          _oldPinErrorMsg =
              '***${data['error'] ?? data['message'] ?? 'รหัสผ่านเดิมไม่ถูกต้อง'}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['error'] ?? data['message'] ?? 'รหัสผ่านเดิมไม่ถูกต้อง',
              style: const TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'เซิร์ฟเวอร์ไม่ตอบสนอง',
            style: TextStyle(fontFamily: 'Kanit'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 28.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF003E77),
                  size: 54,
                ),
                const SizedBox(height: 16),
                const Text(
                  'ยืนยันเปลี่ยนรหัสผ่าน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E77),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'คุณต้องการเปลี่ยนรหัสผ่านนี้ใช่หรือไม่?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF003E77),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // ปิด Popup
                            _submitChangePin(); // 🟢 เรียกฟังก์ชันยิง API ตรงนี้!
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009CB4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
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
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB70000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
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
        );
      },
    );
  }

  void _handleSave() {
    setState(() {
      _oldPinErrorMsg = null;
      _confirmPinErrorMsg = null;

      // 🟢 เช็กแค่ว่ากรอกครบ 6 ตัวหรือยัง ถ้าไม่ครบให้โชว์แจ้งเตือน
      if (_oldPinController.text.length < 6) {
        _oldPinErrorMsg = '***กรุณากรอกรหัสผ่านเดิมให้ครบ 6 หลัก';
      }

      if (_newPinController.text.length < 6 ||
          _confirmPinController.text.length < 6 ||
          _newPinController.text != _confirmPinController.text) {
        _confirmPinErrorMsg = '***รหัสไม่ตรงกัน หรือกรอกไม่ครบ 6 หลัก';
      }
    });

    if (_oldPinErrorMsg == null && _confirmPinErrorMsg == null) {
      _showConfirmDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF004481),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'เปลี่ยนรหัสผ่าน',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF00529B),
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'ข้อมูลรหัสผ่าน',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B2B48),
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'กรอกรหัส PIN 6 หลักเดิมและรหัสใหม่ที่ต้องการตั้ง',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 📦 1. รหัสผ่านเดิม
                    _buildLabel('รหัสผ่านเดิม'),
                    _buildPinInputArea(
                      _oldPinController,
                      _oldPinFocus,
                      _newPinFocus,
                      _oldPinErrorMsg != null,
                    ),
                    if (_oldPinErrorMsg != null)
                      _buildErrorMessage(_oldPinErrorMsg!),
                    const SizedBox(height: 24),

                    // 📦 2. รหัสผ่านใหม่
                    _buildLabel('รหัสผ่านใหม่'),
                    _buildPinInputArea(
                      _newPinController,
                      _newPinFocus,
                      _confirmPinFocus,
                      false,
                    ),
                    const SizedBox(height: 24),

                    // 📦 3. ยืนยันรหัสผ่านใหม่
                    _buildLabel('ยืนยันรหัสผ่านใหม่'),
                    _buildPinInputArea(
                      _confirmPinController,
                      _confirmPinFocus,
                      null,
                      _confirmPinErrorMsg != null,
                    ),
                    if (_confirmPinErrorMsg != null)
                      _buildErrorMessage(_confirmPinErrorMsg!),
                    const SizedBox(height: 48),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009CB4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'บันทึกรหัสผ่านใหม่',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFFD0D9E6),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(
                            color: Color(0xFF009CB4),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: const Color(0xFFE8F1F5),
              child: const Text(
                'MENAM MECHANIKA © 2026',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF009CB4),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontFamily: 'Kanit',
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.red,
          fontFamily: 'Kanit',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPinInputArea(
    TextEditingController controller,
    FocusNode currentFocus,
    FocusNode? nextFocus,
    bool hasError,
  ) {
    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            String char = controller.text.length > index
                ? controller.text[index]
                : '';
            return Container(
              width: 48,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasError ? Colors.red : const Color(0xFFE0E5EC),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                char,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF00529B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: controller,
              focusNode: currentFocus,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                setState(() {});
                if (value.length == 6 && nextFocus != null) {
                  FocusScope.of(context).requestFocus(nextFocus);
                }
              },
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ),
      ],
    );
  }
}
