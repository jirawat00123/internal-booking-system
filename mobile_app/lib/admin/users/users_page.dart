import 'package:flutter/material.dart';
import 'add_user_page.dart';
import 'edit_user_page.dart'; // 🟢 เพิ่มบรรทัดนี้

// 💡 1. โครงสร้างข้อมูลพนักงาน
class Employee {
  final String id;
  final String name;
  final String department;

  Employee({required this.id, required this.name, required this.department});
}

// 🟢 2. ข้อมูลพนักงานตั้งต้น
List<Employee> globalEmployees = [
  Employee(id: '1', name: 'อาร์มโอ๊ตโม', department: 'IT'),
  Employee(id: '2', name: 'พี่ซัน', department: 'IT'),
  Employee(id: '3', name: 'พี่ป๊อป', department: 'บุคคล (HR)'),
  Employee(id: '4', name: 'เจฟ', department: 'แมคคาทรอนิกส์'),
];

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  // หมวดหมู่ทั้งหมด
  final List<String> departments = ['ทั้งหมด', 'ผู้บริหาร', 'ไอที (IT)', 'บุคคล HR', 'แมคคาทรอนิกส์'];
  String selectedDepartment = 'ทั้งหมด';

  @override
  Widget build(BuildContext context) {
    // 🟢 กรองรายชื่อพนักงานตามหมวดหมู่ที่เลือก
    List<Employee> filteredEmployees = selectedDepartment == 'ทั้งหมด'
        ? globalEmployees
        : globalEmployees.where((emp) {
            if (selectedDepartment == 'ไอที (IT)' && emp.department == 'IT') return true;
            if (selectedDepartment == 'บุคคล HR' && emp.department == 'บุคคล (HR)') return true;
            return emp.department == selectedDepartment;
          }).toList();

    return Scaffold(
      backgroundColor: Colors.white, // พื้นหลังสีขาวล้วนตามรูป
      appBar: AppBar(
        backgroundColor: const Color(0xFF004481), // สีน้ำเงินเข้มตามดีไซน์
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('จัดการพนักงาน', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔘 1. แถบเมนูหมวดหมู่ (Tabs)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: departments.map((dept) {
                  bool isSelected = selectedDepartment == dept;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDepartment = dept;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2C3545) : const Color(0xFFE9EDF4), // สีเข้มตอนเลือก สีเทาอ่อนตอนไม่เลือก
                        borderRadius: BorderRadius.circular(12), // ขอบมนกำลังดี
                      ),
                      child: Text(
                        dept,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF1B2B48),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // 📏 2. แถบ Scroll Indicator (เส้นบอกตำแหน่งตกแต่ง)
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9), // สีเทาอ่อน
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.centerLeft,
              child: Container(
                width: 120, // ความกว้างของเส้นที่เข้มกว่า
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFA5A5A5), // สีเทาเข้ม
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 🔘 3. ปุ่มเพิ่มพนักงานใหม่ (สีฟ้าอมเขียว)
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CB8C4).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  // 🟢 ใช้ PageRouteBuilder เพื่อรองรับฉากหลังเบลอ (Glassmorphism) ในหน้า AddUserPage
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false, 
                      pageBuilder: (BuildContext context, _, __) => const AddUserPage(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  ).then((_) => setState(() {})); 
                },
                icon: const Icon(Icons.add, color: Colors.white, size: 24),
                label: const Text('เพิ่มพนักงานใหม่', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF44B5C7), // สีฟ้าตามดีไซน์
                  elevation: 0, // ปิด elevation ของปุ่ม เพราะเราทำเงาเองแล้ว
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 📋 4. รายการพนักงาน (Cards)
            Expanded(
              child: ListView.builder(
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
                          color: Colors.black.withOpacity(0.06), // เงาฟุ้งๆ บางๆ
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          // 🟢 ข้อมูลพนักงาน (ใส่ Expanded เพื่อดันให้ข้อความใช้พื้นที่กว้างสุด)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                const SizedBox(height: 6),
                                Text('แผนก: ${emp.department}', style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          
                          // ✏️ ปุ่มแก้ไข (สีเหลือง) คืนชีพกลับมาแล้ว!
                          InkWell(
                            onTap: () { 
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  opaque: false, 
                                  pageBuilder: (BuildContext context, _, __) => EditUserPage(
                                    employee: emp, 
                                    index: index,
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                ),
                              ).then((_) => setState(() {})); 
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD54F), // สีเหลือง
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 22),
                            ),
                          ),

                          const SizedBox(width: 12),
                          
                          // 🗑️ ปุ่มลบ (สีแดง)
                          InkWell(
                            onTap: () { /* TODO: ฟังก์ชันลบพนักงาน */ },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF44336), // สีแดง
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
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