import 'package:flutter/material.dart';
import 'dart:ui'; // สำหรับทำภาพเบลอ (BackdropFilter)
import 'package:http/http.dart' as http;
import 'dart:convert';
// 🔗 Import ไฟล์ที่เราแยกไว้
import 'add_user_page.dart';
import 'edit_user_page.dart';
import 'employee_model.dart';
import 'reset_pin.dart'; // 🟢 ดึงไฟล์ Popup ตัวแรกมา (ตามชื่อที่พี่ตั้งไว้)
import 'delete_user_success_page.dart'; // 🟢 ดึงหน้าลบสำเร็จมาใช้

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  // 🟢 1. สร้าง State สำหรับเก็บข้อมูลจาก API จริง
  List<Employee> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployees(); // 🟢 สั่งดึงข้อมูลเมื่อเปิดหน้า
  }

  // 🟢 ฟังก์ชันเชื่อมต่อกับ Node.js / Prisma Backend
  Future<void> _fetchEmployees() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3001/api/employees'),
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          setState(() {
            _employees = (body['data'] as List)
                .map((json) => Employee.fromJson(json))
                .toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  final List<String> departments = [
    'ทั้งหมด',
    'ไอที (IT)',
    'บุคคล (HR)',
    'แมคคาทรอนิกส์',
    'ผู้บริหาร',
  ];
  String selectedDepartment = 'ทั้งหมด';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🗑️ ฟังก์ชัน Popup ยืนยันการลบพนักงาน
  // ==========================================
  void _showDeleteConfirmDialog(Employee emp) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // เบลอฉากหลัง
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔴 ไอคอนเครื่องหมายตกใจสีแดง
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
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
                    'ยืนยันการลบพนักงาน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Kanit',
                      color: Color(0xFF003E77),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'คุณต้องการลบพนักงานใช่หรือไม่?',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Kanit',
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      // 🔘 ปุ่มตกลง (สีแดง)
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () {
                              // 🚀 สั่งลบข้อมูลผ่าน API จริง (ตัวอย่าง)
                              // await http.delete(Uri.parse('http://10.0.2.2:3000/api/employees/${emp.id}'));

                              setState(() {
                                // 🟢 เปลี่ยนจาก globalEmployees เป็น List ของ State เราเอง
                                _employees.removeWhere((e) => e.id == emp.id);
                              });
                              Navigator.pop(context); // ปิด Popup
                              // เด้งไปหน้าสำเร็จ
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const DeleteUserSuccessPage(),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC60000),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'ตกลง',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 🔘 ปุ่มยกเลิก (สีฟ้าอมเขียว)
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009CB4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'ยกเลิก',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 เปลี่ยนจาก globalEmployees เป็น _employees
    List<Employee> filteredEmployees = _employees.where((emp) {
      bool matchesDept =
          selectedDepartment == 'ทั้งหมด' ||
          emp.departmentName == selectedDepartment; // 🟢 แก้เป็น departmentName
      bool matchesSearch = emp.fullName.toLowerCase().contains(
        // 🟢 แก้เป็น fullName
        searchQuery.toLowerCase(),
      );
      return matchesDept && matchesSearch;
    }).toList();

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
          'จัดการพนักงาน',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'แผนก (Department) / ตำแหน่ง',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2B48),
                fontFamily: 'Kanit',
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1.2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDepartment,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF004481),
                  ),
                  items: departments.map((String dept) {
                    return DropdownMenuItem<String>(
                      value: dept,
                      child: Text(
                        dept,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null)
                      setState(() => selectedDepartment = newValue);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (context, _, __) =>
                                const AddUserPage(),
                          ),
                        ).then(
                          (_) => _fetchEmployees(),
                        ); // 🟢 บังคับโหลดจาก API ใหม่หลังทำรายการเสร็จ
                      },
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'เพิ่มพนักงานใหม่',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BEC9),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BEC9),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Filter',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFD9D9D9), thickness: 1),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    fontFamily: 'Kanit',
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              // 🟢 เพิ่มเช็ก _isLoading
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF004481),
                      ),
                    )
                  : filteredEmployees.isEmpty
                  ? Center(
                      child: Text(
                        'ไม่พบข้อมูลพนักงาน',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final emp = filteredEmployees[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        emp.fullName, // 🟢 เปลี่ยน name เป็น fullName
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                          fontFamily: 'Kanit',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'รหัส: ${emp.employeeCode} | แผนก: ${emp.departmentName}\nตำแหน่ง: ${emp.positionName}', // 🟢 แสดงข้อมูลครบถ้วนจาก Database
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Kanit',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ✏️ ปุ่มแก้ไข (สีเหลือง)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        opaque: false,
                                        pageBuilder: (context, _, __) =>
                                            EditUserPage(
                                              employee: emp,
                                              index: index,
                                            ),
                                      ),
                                    ).then(
                                      (_) => _fetchEmployees(),
                                    ); // 🟢 บังคับโหลดจาก API ใหม่หลังทำรายการเสร็จ
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD54F),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 🗑️ ปุ่มลบ (สีแดง) 🟢 เปลี่ยนมาเรียกฟังก์ชัน Popup แทนการลบทันที
                                InkWell(
                                  onTap: () {
                                    _showDeleteConfirmDialog(emp);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF44336),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 🔒 ปุ่มรีเซ็ตรหัสผ่าน (สีน้ำเงินเข้ม)
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black.withOpacity(
                                        0.3,
                                      ),
                                      builder: (context) =>
                                          ResetPinDialog(employee: emp),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF003E77),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.lock,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
