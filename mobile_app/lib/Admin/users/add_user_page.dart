import 'package:flutter/material.dart';
import 'package:mobile_app/Admin/users/users_page.dart';
import 'package:mobile_app/admin/users/employee_model.dart';
import 'users_page.dart';
import 'adduser_successpage.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final TextEditingController nameController = TextEditingController();
  
  String? selectedDepartment;
  String? selectedRole; 
  String selectedStatus = 'Active'; 

  final List<String> deptOptions = [
    'ผู้บริหาร',
    'ไอที (IT)',
    'บุคคล (HR)',
    'แมคคาทรอนิกส์',
  ];
  
  final List<String> roleOptions = ['Admin', 'User', 'Security'];
  final List<String> statusOptions = ['Active', 'Inactive'];

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _showConfirmDialog(BuildContext context) {
    if (selectedDepartment == null || selectedRole == null || nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
          backgroundColor: Colors.redAccent,
        ),
      );
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
                      child: const Icon(Icons.add_circle, size: 24, color: Color(0xFF003E75)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('ยืนยันการเพิ่มพนักงาน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003E75))),
                const SizedBox(height: 8),
                const Text('คุณต้องการเพิ่มพนักงานใช่หรือไม่?', style: TextStyle(fontSize: 14, color: Color(0xFF003E75)), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            int roleId = 2; // Default User
                            if (selectedRole == 'Admin') roleId = 1;
                            if (selectedRole == 'Security') roleId = 3;

                            final bodyData = jsonEncode({
                              'fullName': nameController.text,
                              'departmentId': selectedDepartment == 'ไอที (IT)' ? 1 : 2,
                              'positionId': 1,
                              'employeeCode': 'EMP-${DateTime.now().millisecondsSinceEpoch}',
                              'roleId': roleId,
                              'active': selectedStatus == 'Active',
                            });

                            final response = await http.post(
                              Uri.parse('http://localhost:3001/api/employees'),
                              headers: {'Content-Type': 'application/json'},
                              body: bodyData,
                            );

                            if (response.statusCode == 200 || response.statusCode == 201) {
                              if (context.mounted) {
                                Navigator.pop(dialogContext);
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AddUserSuccessPage()));
                              }
                            } else {
                              throw Exception('เพิ่มข้อมูลล้มเหลว');
                            }
                          } catch (e) {
                            debugPrint('Error adding employee: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์')));
                            }
                          }
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
      backgroundColor: Colors.transparent, 
      body: Stack(
        children: [
          // 🌫️ 1. เอา Filter เบลอออก แล้วใช้พื้นหลังสีดำโปร่งแสงแทน
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context), 
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),
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
                    // ❌ 2. เพิ่มปุ่มกากบาทตรงหัวข้อ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text('เพิ่มพนักงานใหม่', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B2B48))),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 📦 กล่อง 1: แผนกและสิทธิ
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                          
                          const Text('แผนก (Department)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            hint: const Text('เลือกแผนก', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF009CB4)),
                            items: deptOptions.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (newValue) => setState(() => selectedDepartment = newValue),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          const Text('สิทธิ์การใช้งาน (Role)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            hint: const Text('เลือกสิทธิ์การใช้งาน', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF009CB4)),
                            items: roleOptions.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (newValue) => setState(() => selectedRole = newValue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📦 กล่อง 2: ข้อมูลพนักงานและสถานะ
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                              hintText: 'เช่น ณภัทร เสลี (โบ)',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text('สถานะ (Status)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF009CB4)),
                            items: statusOptions.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (newValue) => setState(() => selectedStatus = newValue!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

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