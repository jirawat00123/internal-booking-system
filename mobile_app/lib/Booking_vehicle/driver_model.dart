class CompanyDriver {
  final int id;
  final String fullName;
  final String? phone;
  final String? licenseNumber;
  final bool isAvailable;

  CompanyDriver({
    required this.id,
    required this.fullName,
    this.phone,
    this.licenseNumber,
    this.isAvailable = true,
  });

  factory CompanyDriver.fromJson(Map<String, dynamic> json) {
    final emp = json['employee'] is Map<String, dynamic>
        ? json['employee'] as Map<String, dynamic>
        : null;

    String resolvedName =
        json['fullName'] ?? json['name'] ?? json['driverName'] ?? '';
    if (resolvedName.isEmpty && emp != null) {
      final fname = emp['firstName'] ?? emp['first_name'] ?? '';
      final lname = emp['lastName'] ?? emp['last_name'] ?? '';
      resolvedName = '$fname $lname'.trim();
    }
    if (resolvedName.isEmpty) resolvedName = '-';

    return CompanyDriver(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      fullName: resolvedName,
      phone:
          json['phone'] ??
          json['phoneNumber'] ??
          emp?['phone'] ??
          emp?['mobile'],
      licenseNumber:
          json['licenseNumber'] ??
          json['licenseNo'] ??
          emp?['driverLicenseNumber'],
      isAvailable: json['isAvailable'] is bool
          ? json['isAvailable']
          : (json['status'] == 'ACTIVE' || json['status'] == 'AVAILABLE'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'phone': phone,
    'licenseNumber': licenseNumber,
    'isAvailable': isAvailable,
  };
}
