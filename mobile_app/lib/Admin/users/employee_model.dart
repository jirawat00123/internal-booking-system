// ✅ ใช้ Data Model ที่แมปจาก JSON จริงเท่านั้น ห้ามมี globalEmployees
class Employee {
  final String id;
  final String employeeCode;
  final String fullName;
  final String departmentId;
  final String departmentName;
  final String positionName;
  final String role;
  final bool active;

  Employee({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.departmentId,
    required this.departmentName,
    required this.positionName,
    required this.role,
    required this.active,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] is Map<String, dynamic>
        ? json['employee'] as Map<String, dynamic>
        : json;

    final pos = emp['position'] is Map<String, dynamic>
        ? emp['position'] as Map<String, dynamic>
        : null;

    final dept = emp['department'] is Map<String, dynamic>
        ? emp['department'] as Map<String, dynamic>
        : (pos != null && pos['department'] is Map<String, dynamic>
              ? pos['department'] as Map<String, dynamic>
              : null);

    String deptId =
        dept?['id']?.toString() ??
        emp['departmentId']?.toString() ??
        emp['departments_id']?.toString() ??
        json['departmentId']?.toString() ??
        '';

    String deptName = 'ไม่ระบุแผนก';
    if (dept != null && dept['departmentName'] != null) {
      deptName = dept['departmentName'].toString().trim();
    } else if (dept != null && dept['name'] != null) {
      deptName = dept['name'].toString().trim();
    } else if (json['departmentName'] != null &&
        json['departmentName'].toString().isNotEmpty) {
      deptName = json['departmentName'].toString().trim();
    } else if (emp['departmentName'] != null &&
        emp['departmentName'].toString().isNotEmpty) {
      deptName = emp['departmentName'].toString().trim();
    } else if (emp['department'] is String) {
      deptName = emp['department'].toString().trim();
    }

    String roleStr = 'USER';
    final rawRole =
        json['role'] ??
        emp['role'] ??
        (json['users'] is List && (json['users'] as List).isNotEmpty
            ? (json['users'] as List)[0]['role']
            : null);
    if (rawRole is Map) {
      roleStr =
          rawRole['name']?.toString() ??
          rawRole['roleName']?.toString() ??
          'USER';
    } else if (rawRole is String && rawRole.isNotEmpty) {
      roleStr = rawRole;
    } else if (json['roles'] is String &&
        (json['roles'] as String).isNotEmpty) {
      roleStr = json['roles'] as String;
    }

    return Employee(
      id: json['id']?.toString() ?? emp['id']?.toString() ?? '',
      employeeCode:
          emp['employeeCode']?.toString() ??
          json['employeeCode']?.toString() ??
          '',
      fullName:
          emp['fullName']?.toString() ?? json['fullName']?.toString() ?? '',
      departmentId: deptId,
      departmentName: deptName,
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
      'departmentId': departmentId,
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
