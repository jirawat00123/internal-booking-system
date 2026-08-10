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
    // 🟢 1. แยก Object พนักงาน, ตำแหน่ง และแผนก (รองรับข้อมูล Nested จาก Backend)
    final emp = json['employee'] is Map<String, dynamic>
        ? json['employee'] as Map<String, dynamic>
        : json;

    final pos = emp['position'] is Map<String, dynamic>
        ? emp['position'] as Map<String, dynamic>
        : null;

    final dept = pos != null && pos['department'] is Map<String, dynamic>
        ? pos['department'] as Map<String, dynamic>
        : (emp['department'] is Map<String, dynamic>
              ? emp['department'] as Map<String, dynamic>
              : null);

    // 🟢 2. แปลง role เป็น String ป้องกัน Map เข้ามาแทรกจนเกิด TypeError
    String roleStr = 'USER';
    if (json['role'] is Map) {
      roleStr = json['role']['name']?.toString() ?? 'USER';
    } else if (json['role'] is String) {
      roleStr = json['role'];
    } else if (json['roles'] is String) {
      roleStr = json['roles'];
    }

    return Employee(
      id: json['id']?.toString() ?? emp['id']?.toString() ?? '',
      employeeCode:
          emp['employeeCode']?.toString() ??
          json['employeeCode']?.toString() ??
          '',
      fullName:
          emp['fullName']?.toString() ?? json['fullName']?.toString() ?? '',
      departmentName:
          dept?['departmentName']?.toString() ??
          json['departmentName']?.toString() ??
          'ไม่ระบุแผนก',
      positionName:
          pos?['positionName']?.toString() ??
          json['positionName']?.toString() ??
          'ไม่ระบุตำแหน่ง',
      role: roleStr,
      active: (json['active'] is bool)
          ? json['active'] as bool
          : ((emp['isActive'] is bool)
                ? emp['isActive'] as bool
                : (json['active'] == 1 ||
                      json['active'] == 'true' ||
                      emp['isActive'] == 1 ||
                      emp['isActive'] == 'true' ||
                      (json['active'] == null && emp['isActive'] == null))),
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

class Position {
  final String id;
  final String positionName;
  final String departmentId;

  Position({
    required this.id,
    required this.positionName,
    required this.departmentId,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id']?.toString() ?? '',
      positionName: json['positionName']?.toString() ?? '',
      departmentId: json['departmentId']?.toString() ?? '',
    );
  }
}

class Department {
  final String id;
  final String departmentName;
  final List<Position> positions;

  Department({
    required this.id,
    required this.departmentName,
    this.positions = const [],
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    var posList = <Position>[];
    if (json['positions'] is List) {
      posList = (json['positions'] as List)
          .map((p) => Position.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    return Department(
      id: json['id']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? '',
      positions: posList,
    );
  }
}
