// ✅ ใช้ Data Model ที่แมปจาก JSON จริงเท่านั้น ห้ามมี globalEmployees
class Employee {
  final String id;
  final String employeeCode;
  final String fullName;
  final String departmentName;
  final String positionName;
  final String role;
  final bool active;

  Employee({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.departmentName,
    required this.positionName,
    required this.role,
    required this.active,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id']?.toString() ?? '',
      employeeCode: json['employeeCode'] ?? '',
      fullName: json['fullName'] ?? '',
      departmentName: json['departmentName'] ?? 'ไม่ระบุแผนก',
      positionName: json['positionName'] ?? 'ไม่ระบุตำแหน่ง',
      role: json['role'] ?? 'USER',
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeCode': employeeCode,
      'fullName': fullName,
      'departmentName': departmentName,
      'positionName': positionName,
      'role': role,
      'active': active,
    };
  }
}

class Department {
  final String id;
  final String departmentName;

  Department({required this.id, required this.departmentName});

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id']?.toString() ?? '',
      departmentName: json['departmentName'] ?? '',
    );
  }
}
