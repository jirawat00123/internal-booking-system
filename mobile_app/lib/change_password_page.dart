import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // 🟢 เพิ่ม FocusNode สำหรับแต่ละช่อง เพื่อให้เด้งอัตโนมัติได้
  final FocusNode _oldPinFocus = FocusNode();
  final FocusNode _newPinFocus = FocusNode();
  final FocusNode _confirmPinFocus = FocusNode();

  bool _isOldPinError = false;
  bool _isConfirmPinError = false;

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

  void _handleSave() {
    setState(() {
      _isOldPinError = false;
      _isConfirmPinError = false;

      // 💡 1. ตรวจสอบรหัสผ่านเดิม
      if (_oldPinController.text.length < 6 ||
          _oldPinController.text != '123456') {
        _isOldPinError = true;
      }

      // 💡 2. ตรวจสอบรหัสผ่านใหม่
      if (_newPinController.text.length < 6 ||
          _confirmPinController.text.length < 6 ||
          _newPinController.text != _confirmPinController.text) {
        _isConfirmPinError = true;
      }
    });

    // ถ้าไม่มี Error เลย ให้พุ่งไปหน้า Success
    if (!_isOldPinError && !_isConfirmPinError) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ChangePasswordSuccessPage(),
        ),
      );
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
                    // 🔒 ไอคอนแม่กุญแจ
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
                      _isOldPinError,
                    ),
                    if (_isOldPinError)
                      _buildErrorMessage(
                        '***รหัสไม่ถูกต้อง หรือกรอกไม่ครบ 6 หลัก',
                      ),
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
                      _isConfirmPinError,
                    ),
                    if (_isConfirmPinError)
                      _buildErrorMessage(
                        '***รหัสไม่ตรงกัน หรือกรอกไม่ครบ 6 หลัก',
                      ),
                    const SizedBox(height: 48),

                    // 🔘 ปุ่มบันทึก
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009CB4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
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

                    // 🔘 ปุ่มยกเลิก
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
            // Footer
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

  // 🛠️ อัปเดต: รับ FocusNode มาเพื่อสั่งให้เด้งข้ามได้
  Widget _buildPinInputArea(
    TextEditingController controller,
    FocusNode currentFocus,
    FocusNode? nextFocus,
    bool hasError,
  ) {
    return Stack(
      children: [
        // กล่อง UI 6 ช่องที่แสดงให้เห็น
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
        // TextField ล่องหน
        Positioned.fill(
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: controller,
              focusNode: currentFocus, // 🟢 ใส่ FocusNode
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                setState(() {});
                // 🚀 ถ้าพิมพ์ครบ 6 ตัวปุ๊บ ให้เด้งไปช่องถัดไปอัตโนมัติ!
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
