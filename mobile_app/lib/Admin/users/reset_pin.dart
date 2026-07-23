// ไฟล์: reset_pin_dialog.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'employee_model.dart';
import 'confirm_reset_pin.dart'; // ดึงหน้ายืนยันมาใช้

class ResetPinDialog extends StatelessWidget {
  final Employee employee;

  const ResetPinDialog({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // เบลอฉากหลัง
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset รหัสผ่านพนักงาน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kanit',
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'แผนก (Department) / ตำแหน่ง',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Kanit',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                // 🟢 ดึงข้อมูลแผนกและตำแหน่งจาก Model ปัจจุบันมาแสดงผล
                controller: TextEditingController(
                  text: '${employee.departmentName} / ${employee.positionName}',
                ),
                readOnly: true, // 🔒 ป้องกันการแก้ไข
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'ชื่อ-นามสกุล (ชื่อเล่น)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Kanit',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                // 🟢 เปลี่ยนจาก name เป็น fullName
                controller: TextEditingController(text: employee.fullName),
                readOnly: true, // 🔒 ป้องกันการแก้ไข
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // ปิดหน้าต่างตัวเอง
                    // 🚀 เปิดหน้าต่างยืนยันต่อ
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.3),
                      builder: (context) => const ConfirmResetPinDialog(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0096C7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'รีเซ็ตรหัสผ่าน',
                    style: TextStyle(
                      color: Colors.white,
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
    );
  }
}
