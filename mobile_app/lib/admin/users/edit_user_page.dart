import 'dart:ui';
import 'package:flutter/material.dart';
import 'users_page.dart';
import 'edituser_successpage.dart'; // 🟢 ดึงหน้าสำเร็จมาใช้

class EditUserPage extends StatefulWidget {
  final Employee employee;
  final int index;

  const EditUserPage({super.key, required this.employee, required this.index});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  late TextEditingController nameController;
  String? selectedDepartment;
  
  final List<String> deptOptions = ['ผู้บริหาร', 'ไอที (IT)', 'บุคคล (HR)', 'แมคคาทรอนิกส์'];

  @override
  void initState() {
    super.initState();
    // 🟢 ดึงข้อมูลเดิมมาแสดงในช่องกรอก
    nameController = TextEditingController(text: widget.employee.name);
    // แปลงค่าให้ตรงกับตัวเลือกใน Dropdown
    if (widget.employee.department == 'IT') {
      selectedDepartment = 'ไอที (IT)';
    } else {
      selectedDepartment = widget.employee.department;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // 🔴 ฟังก์ชันแสดง Popup ยืนยัน
  void _showConfirmDialog(BuildContext context) {
    if (selectedDepartment == null || nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'), backgroundColor: Colors.redAccent));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const Icon(Icons.person, size: 60, color: Color(0xFF003E75)),
                    Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, size: 24, color: Color(0xFF003E75)), // เปลี่ยนเป็นไอคอนดินสอ
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('ยืนยันการแก้ไขข้อมูล', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003E75))),
                const SizedBox(height: 8),
                const Text('คุณต้องการแก้ไขพนักงานใช่หรือไม่?', style: TextStyle(fontSize: 14, color: Color(0xFF003E75)), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // 1. บันทึกข้อมูลทับของเดิม
                          String saveDept = selectedDepartment == 'ไอที (IT)' ? 'IT' : selectedDepartment!;
                          // เนื่องจากเราจำลองด้วย List เราต้องหา Index จริงๆ ใน globalEmployees (ถ้าดึงจากฐานข้อมูลก็ใช้ ID)
                          int realIndex = globalEmployees.indexWhere((emp) => emp.id == widget.employee.id);
                          if (realIndex != -1) {
                            globalEmployees[realIndex] = Employee(
                              id: widget.employee.id,
                              name: nameController.text,
                              department: saveDept,
                            );
                          }
                          
                          Navigator.pop(dialogContext); 
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const EditUserSuccessPage()),
                          ); 
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009CB4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('ตกลง', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB20000),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('ยกเลิก', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 🟢 ทำให้โปร่งใส
      body: Stack(
        children: [
          // 🌫️ 1. ตัวทำพื้นหลังเบลอ
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context), 
                child: Container(color: Colors.white.withOpacity(0.3)),
              ),
            ),
          ),
          
          // 📝 2. กล่องฟอร์มกรอกข้อมูล
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('แก้ไขข้อมูลพนักงาน', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B2B48))),
                    const SizedBox(height: 24),
                    
                    // 📦 กล่อง 1: แผนก
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. แผนกและสิทธิการใช้งาน', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF009CB4))),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(color: Color(0xFFD0D9E6), thickness: 1),
                          ),
                          const Text('แผนก (Department) / ตำแหน่ง', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF009CB4)),
                            items: deptOptions.map((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)));
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() { selectedDepartment = newValue; });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 📦 กล่อง 2: ข้อมูลพนักงาน
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('2. ระบุข้อมูลพนักงาน', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF009CB4))),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(color: Color(0xFFD0D9E6), thickness: 1),
                          ),
                          const Text('ชื่อ-นามสกุล (ชื่อเล่น)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 🔘 ปุ่มบันทึก
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _showConfirmDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009CB4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('บันทึกข้อมูล', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}