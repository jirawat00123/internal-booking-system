import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // 💡 นำเข้า SharedPreferences

import 'digitel.dart';
import '/Booking_room/Room_model.dart'; 
import 'Booking_vehicle/Vehicle_model.dart' as v_model; // 💡 นำเข้าตัวแปรของระบบจองรถ

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  // ✅ เก็บข้อมูล แผนก และ พนักงาน เป็นข้อความ String ป้องกัน Dropdown ค้าง
  String? _selectedDepartmentText;
  String? _selectedEmployeeText;

  Map<String, dynamic>? _selectedDepartmentObj;
  Map<String, dynamic>? _selectedEmployeeObj;

  // ตัวแปรเก็บข้อมูลลิสต์จาก API
  List<dynamic> _departments = [];
  List<dynamic> _names = [];
  bool _isLoadingDepartments = true;
  bool _isLoadingEmployees = false;

  final String baseUrl = 'http://localhost:3001/api';

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  // 🔄 ดึงข้อมูลแผนกทั้งหมด
  Future<void> _fetchDepartments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/departments'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        setState(() {
          _departments = responseData['data'] ?? [];
          _isLoadingDepartments = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingDepartments = false);
      print('Error fetching departments: $e');
    }
  }

  // 🔄 ดึงข้อมูลพนักงานตามแผนก
  Future<void> _fetchEmployees(String departmentId) async {
    setState(() {
      _isLoadingEmployees = true;
      _names = [];
      _selectedEmployeeText = null;
      _selectedEmployeeObj = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees?departmentId=$departmentId'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        setState(() {
          _names = responseData['data'] ?? [];
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingEmployees = false);
      print('Error fetching employees: $e');
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
      builder: (BuildContext context) {
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
                            child: Icon(Icons.circle, size: 6, color: Color(0xFF00529B)),
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
                            child: Icon(Icons.circle, size: 6, color: Color(0xFF00529B)),
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
                        // 🚀 เปลี่ยนเป็น async เพื่อให้บันทึกข้อมูล SharedPreferences ได้
                        onPressed: () async {
                          if (_selectedEmployeeText != null && _selectedEmployeeText!.isNotEmpty) {
                            
                            // 💡 0. โค้ดใหม่: พยายามขุดหา User ID ตัวจริงจากข้อมูล Employee
                            int selectedId = 0;
                            if (_selectedEmployeeObj != null) {
                              if (_selectedEmployeeObj!['userId'] != null) {
                                // กรณีมีฟิลด์ userId คืนค่ามาตรงๆ
                                selectedId = _selectedEmployeeObj!['userId'];
                              } else if (_selectedEmployeeObj!['user'] != null && _selectedEmployeeObj!['user']['id'] != null) {
                                // กรณีข้อมูล user ซ้อนอยู่ข้างใน
                                selectedId = _selectedEmployeeObj!['user']['id'];
                              } else {
                                // ถ้าไม่มีเลยจริงๆ ค่อยใช้ id ของพนักงาน (ซึ่งเสี่ยงพังถ้าไม่ตรงตาราง User)
                                selectedId = _selectedEmployeeObj!['id'] ?? 0;
                              }
                            }

                            // พิมพ์เช็กดูใน Console ว่าได้ ID อะไรมา
                            print("👉 ข้อมูลพนักงานก้อนเต็ม: $_selectedEmployeeObj");
                            print("👉 ได้ User ID เพื่อส่งไปจองรถ: $selectedId");

                            // 💡 1. อัปเดตชื่อ และ ID ให้ระบบ
                            globalCurrentUserName = _selectedEmployeeText!; 
                            
                            
                            // 💡 2. อัปเดตชื่อ และ ID ให้ระบบจองรถ
                            v_model.globalCurrentUserName = _selectedEmployeeText!; 
                            v_model.globalCurrentUserId = selectedId;
                            
                            // 💡 3. บันทึกชื่อและ ID ลง SharedPreferences
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('name', _selectedEmployeeText!);
                            await prefs.setInt('userId', selectedId); 
                          }
                          
                          if (!mounted) return;
                          
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/digitel',
                            arguments: _selectedEmployeeObj,
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