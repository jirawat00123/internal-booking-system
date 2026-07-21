import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/Digitel.dart'; // 🚨 ตรวจสอบตัวพิมพ์เล็ก/ใหญ่ของไฟล์ให้ดี (เช่น digital.dart หรือ Digital.dart)
import 'Booking_room/Room_model.dart';

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  String? _selectedDepartmentText;
  String? _selectedEmployeeText;

  Map<String, dynamic>? _selectedDepartmentObj;
  Map<String, dynamic>? _selectedEmployeeObj;

  List<dynamic> _departments = [];
  List<dynamic> _names = [];
  bool _isLoadingDepartments = true;
  bool _isLoadingEmployees = false;
  bool _isLoggingIn = false;

  // 🌐 Base URL สำหรับเชื่อมต่อ Backend
  final String baseUrl = 'http://localhost:3001/api';

  Future<void> _loginUser(BuildContext dialogContext) async {
    final empCode = _selectedEmployeeObj?['employeeCode'];
    if (empCode == null) return;

    setState(() => _isLoggingIn = true);

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'employeeCode': empCode}),
          )
          .timeout(
            const Duration(seconds: 10),
          ); // 🟢 ดักไม่ให้แอปค้างถ้าเซิร์ฟเวอร์ไม่มีการตอบรับ

      // 🟢 ป้องกันแครชจาก Non-JSON Response (เช่น Server return 502 HTML)
      dynamic responseData;
      try {
        responseData = json.decode(response.body);
      } catch (_) {
        responseData = {
          'success': false,
          'error': 'รูปแบบข้อมูลเซิร์ฟเวอร์ไม่ถูกต้อง',
        };
      }

      if (response.statusCode == 200 && responseData['success'] == true) {
        final token = responseData['token'] ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        // 🟢 เพิ่มโค้ดส่วนนี้เพื่อเซฟ userId และ role จาก Token ลงเครื่อง 🟢
        try {
          if (token.isNotEmpty) {
            // ถอดรหัส JWT Token ด้วย Base64
            final parts = token.split('.');
            if (parts.length == 3) {
              final payload = parts[1];
              final normalized = base64Url.normalize(payload);
              final decoded = utf8.decode(base64Url.decode(normalized));
              final payloadMap = json.decode(decoded);

              if (payloadMap['userId'] != null) {
                // บันทึก userId และ Role ลงเครื่อง
                await prefs.setInt('userId', payloadMap['userId']);
                await prefs.setString('role', payloadMap['role'] ?? 'USER');
                debugPrint('✅ บันทึก userId: ${payloadMap['userId']} สำเร็จ');
              }
            }
          }
        } catch (e) {
          debugPrint('❌ เกิดข้อผิดพลาดในการดึง userId จาก Token: $e');
        }
        // 🟢 สิ้นสุดโค้ดที่เพิ่มใหม่ 🟢

        if (!dialogContext.mounted) return;
        Navigator.pop(dialogContext); // ปิด Dialog ทันทีเมื่อทำงานสำเร็จ

        if (!mounted) return; // 🟢 ตรวจสอบความปลอดภัยของ Context หลักก่อนนำทาง
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserMenuPage()),
        );
      } else {
        if (dialogContext.mounted) {
          Navigator.pop(
            dialogContext,
          ); // 🟢 สั่งปิด Dialog ทันทีเพื่อให้ไปแก้ไขข้อมูลใหม่
        }
        if (!mounted)
          return; // 🟢 ตรวจสอบความปลอดภัยของ Context หลักก่อนใช้ ScaffoldMessenger
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['error'] ?? 'เข้าสู่ระบบไม่สำเร็จ'),
          ),
        );
      }
    } catch (e) {
      if (dialogContext.mounted) {
        Navigator.pop(
          dialogContext,
        ); // 🟢 สั่งปิด Dialog ทันทีเมื่อ API ค้าง/ล่ม
      }
      if (!mounted)
        return; // 🟢 ตรวจสอบความปลอดภัยของ Context หลักก่อนแจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/departments'));

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);

        if (!mounted) return; // 🟢 เพิ่มเช็ค mounted หลัง await

        // 🟢 ตรวจสอบประเภทข้อมูลว่าเป็น List (Array) หรือไม่
        if (decodedData is List) {
          setState(() {
            _departments = decodedData;
            _isLoadingDepartments = false;
          });
        }
        // 🟢 หากหลังบ้านห่อข้อมูลไว้ในคีย์ย่อย เช่น {"data": [...]} หรือ {"departments": [...]}
        else if (decodedData is Map &&
            decodedData.containsKey('data') &&
            decodedData['data'] is List) {
          setState(() {
            _departments = decodedData['data'];
            _isLoadingDepartments = false;
          });
        } else if (decodedData is Map &&
            decodedData.containsKey('departments') &&
            decodedData['departments'] is List) {
          setState(() {
            _departments = decodedData['departments'];
            _isLoadingDepartments = false;
          });
        } else {
          throw Exception('รูปแบบโครงสร้างข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'บัญชีนี้ถูกเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } else {
        // 🟢 จัดการกรณี HTTP status code ไม่ใช่ 200 (เช่น 401, 404, 500)
        final errorData = json.decode(response.body);
        String errMsg = errorData is Map
            ? (errorData['message'] ?? errorData['error'] ?? 'เกิดข้อผิดพลาด')
            : 'Server Error';
        throw Exception('HTTP ${response.statusCode}: $errMsg');
      }
    } catch (e) {
      print('Error fetching departments: $e');
      setState(() {
        _departments = []; // Fallback ให้เป็นลิสต์ว่าง Dropdown จะได้ไม่ค้างพัง
        _isLoadingDepartments = false;
      });

      // แสดงบันทึกเตือนให้ผู้ใช้ทราบ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถดึงข้อมูลแผนกได้: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _fetchEmployees(String departmentId) async {
    setState(() {
      _isLoadingEmployees = true;
      _names = [];
      _selectedEmployeeText = null;
      _selectedEmployeeObj = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/employees?departmentId=$departmentId'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);

        setState(() {
          _names = List<Map<String, dynamic>>.from(body['data'] ?? []);
          _isLoadingEmployees = false;
        });
      } else if (response.statusCode == 401) {
        setState(() => _isLoadingEmployees = false);
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'บัญชีนี้ถูกเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } else {
        setState(() => _isLoadingEmployees = false);
      }
    } catch (e) {
      setState(() => _isLoadingEmployees = false);
      debugPrint('Error fetching employees: $e');
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
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
                  'ข้อมูลไม่ครบถ้วน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E77),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'กรุณาเลือกแผนกและชื่อ-สกุลก่อนดำเนินการต่อ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF00529B),
                    fontFamily: 'Kanit',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 160,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0096C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ตกลง',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBF3F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: Color(0xFF00529B),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ยืนยันการดำเนินการ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E77),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2EFF2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6.0),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF00529B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'แผนก',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003E77),
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _selectedDepartmentText ?? '',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF007AD6),
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Divider(height: 1, color: Color(0xFFE2EFF2)),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 6.0),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF00529B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ชื่อ-สกุล',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003E77),
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _selectedEmployeeText ?? '',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF007AD6),
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        // เอาการปิด null ออก เพราะ Dialog ไม่ได้ rebuild ตามหน้าหลัก
                        onPressed: () async {
                          // 🟢 เพิ่มการดักจับสถานะด้านในฟังก์ชันแทน หากกำลังล็อกอินอยู่ให้ข้ามการทำงานไปเลย (ป้องกันกดรัว)
                          if (_isLoggingIn) return;

                          // กำหนดค่าตัวแปร global (ถ้ามี)
                          if (_selectedEmployeeText != null &&
                              _selectedEmployeeText!.isNotEmpty) {
                            // globalCurrentUserName = _selectedEmployeeText!;
                          }

                          // เรียกฟังก์ชัน _loginUser เพื่อทำ API Login และสลับหน้าจออย่างสมบูรณ์
                          await _loginUser(dialogContext);

                          debugPrint(
                            "เปลี่ยนเส้นทางไปหน้าดิจิทัลสำเร็จ: $_selectedEmployeeText",
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0096C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'ยืนยัน',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF0096C7),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          foregroundColor: const Color(0xFF0096C7),
                        ),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Kanit',
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
            child: Center(
              child: _isLoadingDepartments
                  ? const CircularProgressIndicator(color: Colors.white)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'จัดการผู้ใช้งาน',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 8),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_alt_outlined,
                                      color: Color(0xFF00529B),
                                      size: 36,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'ผู้ใช้งาน',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00529B),
                                        fontFamily: 'Kanit',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                _buildLabel('แผนก'),
                                _buildDropdownField(
                                  hint: 'เลือกแผนก',
                                  selectedValue: _selectedDepartmentText,
                                  items: _departments,
                                  labelKey: 'departmentName',
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      final matchedObj = _departments
                                          .firstWhere(
                                            (item) =>
                                                item['departmentName']
                                                    .toString() ==
                                                newValue,
                                          );
                                      setState(() {
                                        _selectedDepartmentText = newValue;
                                        _selectedDepartmentObj = matchedObj;
                                        _selectedEmployeeText = null;
                                        _selectedEmployeeObj = null;
                                        _names = [];
                                      });
                                      _fetchEmployees(
                                        matchedObj['id'].toString(),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 24),
                                _buildLabel('ชื่อ-สกุล'),
                                _isLoadingEmployees
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 14.0,
                                        ),
                                        child: LinearProgressIndicator(
                                          color: Color(0xFF00529B),
                                        ),
                                      )
                                    : _buildDropdownField(
                                        hint: _selectedDepartmentText == null
                                            ? 'เลือกรายชื่อ'
                                            : 'เลือกชื่อ-สกุล',
                                        selectedValue: _selectedEmployeeText,
                                        items: _names,
                                        labelKey: 'fullName',
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            final matchedObj = _names
                                                .firstWhere(
                                                  (item) =>
                                                      item['fullName']
                                                          .toString() ==
                                                      newValue,
                                                );
                                            setState(() {
                                              _selectedEmployeeText = newValue;
                                              _selectedEmployeeObj = matchedObj;
                                            });
                                          }
                                        },
                                      ),
                                const SizedBox(height: 40),
                                SizedBox(
                                  width: 240,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_selectedDepartmentText == null ||
                                          _selectedEmployeeText == null) {
                                        _showErrorDialog();
                                      } else {
                                        _showConfirmDialog();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0096C7),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'ดำเนินการต่อ',
                                      style: TextStyle(
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
                          const SizedBox(height: 40),
                          Text(
                            'MENAM MECHANIKA © 2026',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003E77),
            fontFamily: 'Kanit',
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String hint,
    required String? selectedValue,
    required List<dynamic> items,
    required String labelKey,
    required ValueChanged<String?> onChanged,
  }) {
    final List<String> dropdownStrings = items
        .map((item) => item[labelKey].toString())
        .toSet()
        .toList();
    final bool hasValidValue = dropdownStrings.contains(selectedValue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00529B).withOpacity(0.6),
          width: 1.2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: hasValidValue ? selectedValue : null,
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
              fontFamily: 'Kanit',
            ),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF00529B),
            size: 24,
          ),
          items: dropdownStrings.map((String textVal) {
            return DropdownMenuItem<String>(
              value: textVal,
              child: Text(
                textVal,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontFamily: 'Kanit',
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
