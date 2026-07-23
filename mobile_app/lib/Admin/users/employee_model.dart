// ไฟล์: lib/Admin/users/employee_model.dart

class Employee {
  final String id;
  final String employeeCode;
  final String fullName;
  final String positionName;
  final String departmentName;

  Employee({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.positionName,
    required this.departmentName,
  });

  // แมปข้อมูลจาก JSON Response ของ Prisma ให้ตรงโครงสร้าง
  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id']?.toString() ?? '',
      employeeCode: json['employeeCode'] ?? '-',
      fullName: json['fullName'] ?? 'ไม่ระบุชื่อ',
      // ดึงจาก object position ที่ซ้อนอยู่ข้างใน
      positionName: json['position']?['positionName'] ?? '-',
      // ดึงจาก object department ที่ซ้อนอยู่ข้างใน
      departmentName: json['department']?['departmentName'] ?? 'ไม่ระบุแผนก',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeCode': employeeCode,
      'fullName': fullName,
      'positionName': positionName,
      'departmentName': departmentName,
    };
  }
}
