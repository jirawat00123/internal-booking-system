import 'package:flutter/material.dart';
import 'package:mobile_app/Admin/users/users_page.dart';
import 'users_page.dart';
import 'employee_model.dart';
import 'edituser_successpage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditUserPage extends StatefulWidget {
  final Employee employee;
  final int index;

  const EditUserPage({super.key, required this.employee, required this.index});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  late TextEditingController nameController;
  // 🟢 1. เพิ่ม Controller สำหรับช่องกรอกรหัสพนักงาน
  late TextEditingController empCodeController;

  int? selectedDepartmentId;
  int? selectedRoleId;
  late String selectedStatus;

  List<dynamic> departments = [];
  List<dynamic> roles = [];
  bool isLoadingData = true;

  final List<String> statusOptions = ['Active', 'Inactive'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.employee.fullName);
    empCodeController = TextEditingController(
      text: widget.employee.employeeCode,
    );

    selectedStatus = widget.employee.active ? 'Active' : 'Inactive';
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => isLoadingData = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://192.168.88.25:3002/api/departments')),
        http.get(Uri.parse('https://192.168.88.25:3002/api/roles')),
      ]);

      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        final deptList = data is List
            ? data
            : (data['data'] is List ? data['data'] : []);
        departments = deptList;
        for (var d in departments) {
          final dId = d['id']?.toString();
          final dName =
              d['departmentName']?.toString().trim() ??
              d['name']?.toString().trim() ??
              '';
          if ((widget.employee.departmentId.isNotEmpty &&
                  dId == widget.employee.departmentId) ||
              dName == widget.employee.departmentName.trim()) {
            selectedDepartmentId = d['id'] is int
                ? d['id'] as int
                : int.tryParse(d['id'].toString());
            break;
          }
        }
      }

      if (responses[1].statusCode == 200) {
        final data = jsonDecode(responses[1].body);
        final roleList = data is List
            ? data
            : (data['data'] is List ? data['data'] : []);
        roles = roleList;
        for (var r in roles) {
          final rName =
              r['name']?.toString().trim() ??
              r['roleName']?.toString().trim() ??
              '';
          if (rName.toUpperCase() ==
              widget.employee.role.trim().toUpperCase()) {
            selectedRoleId = r['id'] is int
                ? r['id'] as int
                : int.tryParse(r['id'].toString());
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
    } finally {
      setState(() => isLoadingData = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    empCodeController.dispose(); // 🟢 อย่าลืม dispose
    super.dispose();
  }

  void _showConfirmDialog(BuildContext context) {
    if (selectedDepartmentId == null ||
        selectedRoleId == null ||
        empCodeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 60,
                      color: Color(0xFF003E75),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 24,
                        color: Color(0xFF003E75),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'ยืนยันการแก้ไขข้อมูล',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'คุณต้องการแก้ไขพนักงานใช่หรือไม่?',
                  style: TextStyle(fontSize: 14, color: Color(0xFF003E75)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final bodyData = jsonEncode({
                              'employeeCode': empCodeController.text.trim(),
                              'fullName': nameController.text.trim(),
                              'departmentId': selectedDepartmentId != null
                                  ? int.parse(selectedDepartmentId.toString())
                                  : null,
                              'roleId': selectedRoleId != null
                                  ? int.parse(selectedRoleId.toString())
                                  : null,
                              'active': selectedStatus == 'Active',
                            });

                            final response = await http.put(
                              Uri.parse(
                                'https://192.168.88.25:3002/api/employees/${widget.employee.id}',
                              ),
                              headers: {'Content-Type': 'application/json'},
                              body: bodyData,
                            );

                            if (response.statusCode == 200 ||
                                response.statusCode == 201) {
                              if (context.mounted) {
                                Navigator.pop(dialogContext);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EditUserSuccessPage(),
                                  ),
                                );
                              }
                            } else {
                              throw Exception('แก้ไขข้อมูลล้มเหลว');
                            }
                          } catch (e) {
                            debugPrint('Error updating employee: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009CB4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ตกลง',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB20000),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF009CB4)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'แก้ไขข้อมูลพนักงาน',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B2B48),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 28,
                          ),
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
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1. แผนกและสิทธิการใช้งาน',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF009CB4),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(
                              color: Color(0xFFD0D9E6),
                              thickness: 1,
                            ),
                          ),

                          const Text(
                            'แผนก (Department)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: selectedDepartmentId,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            hint: const Text(
                              'เลือกแผนก',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF009CB4),
                            ),
                            items: departments.map<DropdownMenuItem<int>>((
                              dept,
                            ) {
                              final intId = dept['id'] is int
                                  ? dept['id'] as int
                                  : int.tryParse(dept['id'].toString());
                              final deptName =
                                  dept['departmentName']?.toString() ??
                                  dept['name']?.toString() ??
                                  '';
                              return DropdownMenuItem<int>(
                                value: intId,
                                child: Text(
                                  deptName,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) =>
                                setState(() => selectedDepartmentId = newValue),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'สิทธิ์การใช้งาน (Role)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: selectedRoleId,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            hint: const Text(
                              'เลือกสิทธิ์การใช้งาน',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF009CB4),
                            ),
                            items: roles.map<DropdownMenuItem<int>>((role) {
                              final intId = role['id'] is int
                                  ? role['id'] as int
                                  : int.tryParse(role['id'].toString());
                              final roleName =
                                  role['name']?.toString() ??
                                  role['roleName']?.toString() ??
                                  '';
                              return DropdownMenuItem<int>(
                                value: intId,
                                child: Text(
                                  roleName,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) =>
                                setState(() => selectedRoleId = newValue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📦 กล่อง 2: ข้อมูลพนักงานและสถานะ
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '2. ระบุข้อมูลพนักงาน',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF009CB4),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(
                              color: Color(0xFFD0D9E6),
                              thickness: 1,
                            ),
                          ),

                          // 🟢 3. เพิ่มช่องกรอกรหัสพนักงานที่ดึงของเดิมมาโชว์
                          const Text(
                            'รหัสพนักงาน (Employee Code)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: empCodeController,
                            decoration: InputDecoration(
                              hintText: 'เช่น MC-AC0299',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'ชื่อ-นามสกุล (ชื่อเล่น)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'สถานะ (Status)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF009CB4),
                            ),
                            items: statusOptions
                                .map(
                                  (String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (newValue) =>
                                setState(() => selectedStatus = newValue!),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'บันทึกข้อมูล',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
