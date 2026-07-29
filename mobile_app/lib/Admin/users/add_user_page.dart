import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'adduser_successpage.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final TextEditingController nameController = TextEditingController();
  final String baseUrl =
      'http://localhost:3001/api'; // ปรับเป็น URL ของเซิร์ฟเวอร์จริง

  // ตัวแปรเก็บข้อมูลจาก API
  List<dynamic> departments = [];
  List<dynamic> positions = [];
  List<dynamic> roles = [];

  // ตัวแปรเก็บค่าที่ถูกเลือก (เก็บเป็น ID)
  int? selectedDepartmentId;
  int? selectedPositionId;
  int? selectedRoleId;
  bool selectedStatus = true; // true = Active, false = Inactive
  String generatedEmployeeCode = '';

  bool isLoadingData = true;
  bool isPositionsLoading = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // 1️⃣ โหลด Departments, Roles และ Generate Code พร้อมกัน
  Future<void> _fetchInitialData() async {
    setState(() => isLoadingData = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/departments')),
        http.get(Uri.parse('$baseUrl/roles')),
        http.get(Uri.parse('$baseUrl/employees/generate-code')),
      ]);

      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        departments = data['data'];
      }
      if (responses[1].statusCode == 200) {
        final data = jsonDecode(responses[1].body);
        roles = data['data'];
      }
      if (responses[2].statusCode == 200) {
        final data = jsonDecode(responses[2].body);
        generatedEmployeeCode = data['code'];
      }
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลเบื้องต้น'),
          ),
        );
      }
    } finally {
      setState(() => isLoadingData = false);
    }
  }

  // 2️⃣ โหลด Positions เมื่อมีการเลือกแผนก
  Future<void> _fetchPositions(int departmentId) async {
    setState(() {
      isPositionsLoading = true;
      selectedPositionId = null; // Reset ค่าตำแหน่งเมื่อเปลี่ยนแผนก
      positions = [];
    });
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/positions?departmentId=$departmentId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          positions = data['data'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching positions: $e");
    } finally {
      setState(() => isPositionsLoading = false);
    }
  }

  // 3️⃣ ฟังก์ชันบันทึกข้อมูลและ Validation
  void _showConfirmDialog(BuildContext context) {
    if (selectedDepartmentId == null ||
        selectedPositionId == null ||
        selectedRoleId == null ||
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
                        Icons.add_circle,
                        size: 24,
                        color: Color(0xFF003E75),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'ยืนยันการเพิ่มพนักงาน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'รหัสพนักงาน: $generatedEmployeeCode\nคุณต้องการเพิ่มพนักงานใช่หรือไม่?',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF003E75),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext); // ปิด Dialog โหลดก่อน
                          await _saveEmployeeData();
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

  Future<void> _saveEmployeeData() async {
    setState(() => isSaving = true);
    try {
      final bodyData = jsonEncode({
        'employeeCode': generatedEmployeeCode,
        'fullName': nameController.text.trim(),
        'departmentId': selectedDepartmentId,
        'positionId': selectedPositionId,
        'roleId': selectedRoleId,
        'active': selectedStatus,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/employees'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AddUserSuccessPage()),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'เพิ่มข้อมูลล้มเหลว');
      }
    } catch (e) {
      debugPrint('Error adding employee: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'เกิดข้อผิดพลาด: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isSaving = false);
    }
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
                            'เพิ่มพนักงานใหม่',
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
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1. แผนก ตำแหน่ง และสิทธิ',
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

                          // --- Dropdown แผนก (ดึงจาก API) ---
                          const Text(
                            'แผนก (Department)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: selectedDepartmentId,
                            decoration: _dropdownDecoration(),
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
                              return DropdownMenuItem<int>(
                                value: dept['id'],
                                child: Text(
                                  dept['departmentName'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() => selectedDepartmentId = newValue);
                              if (newValue != null)
                                _fetchPositions(newValue); // โหลดตำแหน่งตามแผนก
                            },
                          ),
                          const SizedBox(height: 16),

                          // --- Dropdown ตำแหน่ง (ดึงจาก API ตามแผนก) ---
                          const Text(
                            'ตำแหน่ง (Position)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          isPositionsLoading
                              ? const Center(
                                  child: LinearProgressIndicator(
                                    color: Color(0xFF009CB4),
                                  ),
                                )
                              : DropdownButtonFormField<int>(
                                  value: selectedPositionId,
                                  decoration: _dropdownDecoration(),
                                  hint: const Text(
                                    'เลือกตำแหน่ง',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF009CB4),
                                  ),
                                  items: positions.map<DropdownMenuItem<int>>((
                                    pos,
                                  ) {
                                    return DropdownMenuItem<int>(
                                      value: pos['id'],
                                      child: Text(
                                        pos['positionName'],
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (newValue) => setState(
                                    () => selectedPositionId = newValue,
                                  ),
                                ),
                          const SizedBox(height: 16),

                          // --- Dropdown Role (ดึงจาก API) ---
                          const Text(
                            'สิทธิ์การใช้งาน (Role)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: selectedRoleId,
                            decoration: _dropdownDecoration(),
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
                              return DropdownMenuItem<int>(
                                value: role['id'],
                                child: Text(
                                  role['name'],
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
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '2. ระบุข้อมูลพนักงาน',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF009CB4),
                                ),
                              ),
                              Text(
                                generatedEmployeeCode,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(
                              color: Color(0xFFD0D9E6),
                              thickness: 1,
                            ),
                          ),

                          const Text(
                            'ชื่อ-นามสกุล (ชื่อเล่น)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: 'เช่น ณภัทร เสลี (โบ)',
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
                            'สถานะ (Status)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Dropdown Status ใช้ค่าคงที่ได้เนื่องจาก Mapping กับค่า Boolean ในฐานข้อมูลตรงๆ
                          DropdownButtonFormField<bool>(
                            value: selectedStatus,
                            decoration: _dropdownDecoration(),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF009CB4),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text(
                                  'Active',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text(
                                  'Inactive',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
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
                        onPressed: isSaving
                            ? null
                            : () => _showConfirmDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009CB4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
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

  // ฟังก์ชันช่วยจัดการดีไซน์กรอบ Dropdown เพื่อให้โค้ดสะอาดขึ้น
  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
