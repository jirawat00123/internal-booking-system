import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'edit_vehicle_page.dart';

import 'add_vehicle_page.dart';
import 'deletevehicle_successpage.dart';
import '../../../../auth_service.dart';

class Vehicle {
  final dynamic id;
  final String vehicleName;
  final String plate;
  final String brand;
  final String model;
  final int seats;
  final String status;
  final String? uploadUrl;
  
  // 🟢 แก้ไขให้รองรับค่า null จาก Database ได้อย่างปลอดภัย
  final String? province;

  final bool isDeleted;
  final String type;
  final bool hasFutureBooking;

  String get name => vehicleName;
  String? get imagePath => uploadUrl;
  int get capacity => seats;

  Vehicle({
    required this.id,
    required this.vehicleName,
    required this.plate,
    required this.brand,
    required this.model,
    required this.seats,
    required this.status,
    this.uploadUrl,
    this.province, // 🟢 เอา default ออกเพื่อให้รับค่า null ได้
    this.isDeleted = false,
    this.type = 'รถยนต์',
    this.hasFutureBooking = false,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      vehicleName:
          json['vehicleName'] ??
          json['vehicle_name'] ??
          json['name'] ??
          '${json['brand'] ?? ''} ${json['model'] ?? ''}'.trim(),
      plate:
          json['plateNumber'] ?? json['license_plate'] ?? json['plate'] ?? '-',
      brand: json['brand'] ?? '-',
      model: json['model'] ?? '-',
      seats: json['seats'] != null
          ? int.tryParse(json['seats'].toString()) ?? 4
          : 4,
      status: json['status'] ?? 'AVAILABLE',
      uploadUrl: json['uploadUrl'] ?? json['upload_url'] ?? json['imagePath'],
      // 🟢 ดักจับ null ด้วย ?.toString() ป้องกันแอปพัง 100%
      province: json['province']?.toString() ?? '', 
      isDeleted: json['isDeleted'] ?? json['is_deleted'] ?? false,
      type: json['type'] ?? 'รถยนต์',
      hasFutureBooking: json['hasFutureBooking'] ?? false,
    );
  }

  Vehicle copyWith({
    dynamic id,
    String? vehicleName,
    String? plate,
    String? brand,
    String? model,
    int? seats,
    String? status,
    String? uploadUrl,
    String? province,
    bool? isDeleted,
    String? type,
    bool? hasFutureBooking,
  }) {
    return Vehicle(
      id: id ?? this.id,
      vehicleName: vehicleName ?? this.vehicleName,
      plate: plate ?? this.plate,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      seats: seats ?? this.seats,
      status: status ?? this.status,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      province: province ?? this.province,
      isDeleted: isDeleted ?? this.isDeleted,
      type: type ?? this.type,
      hasFutureBooking: hasFutureBooking ?? this.hasFutureBooking,
    );
  }
}

final ValueNotifier<List<Vehicle>> globalVehicles = ValueNotifier([]);

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});

  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  bool isLoading = true;
  String selectedFilterStatus = 'ALL'; 
  @override
  void initState() {
    super.initState();
    _fetchVehiclesFromApi();
  }

  Future<void> _fetchVehiclesFromApi() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    final baseUrl = AuthService.baseUrl;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

      debugPrint(
        '🔐 VEHICLE PAGE TOKEN = ${token.isEmpty ? "EMPTY" : "EXISTS"}',
      );
      debugPrint('🔐 VEHICLE PAGE TOKEN LENGTH = ${token.length}');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
      };

      final vehicleFuture = http.get(
        Uri.parse('$baseUrl/api/vehicles'),
        headers: headers,
      );
      final bookingFuture = http.get(
        Uri.parse('$baseUrl/api/vehicle-bookings'),
        headers: headers,
      );

      final responses = await Future.wait([vehicleFuture, bookingFuture]);

      if (responses[0].statusCode == 200) {
        final decodedData = jsonDecode(responses[0].body);
        List<dynamic> vehicleData = [];

        if (decodedData['success'] == true) {
          vehicleData = decodedData['data'];
        } else if (decodedData is List) {
          vehicleData = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          vehicleData = decodedData['data'];
        }

        List<Vehicle> fetchedList = vehicleData.map((json) {
          final vehicle = Vehicle.fromJson(json);

          debugPrint(
            '🚗 VEHICLE ${vehicle.id} | '
            '${vehicle.vehicleName} | '
            'uploadUrl=${vehicle.uploadUrl}',
          );

          return vehicle;
        }).toList();

        if (responses[1].statusCode == 200) {
          final bData = jsonDecode(responses[1].body);
          List<dynamic> bookingsData = bData['data'] ?? bData['bookings'] ?? [];

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          for (int i = 0; i < fetchedList.length; i++) {
            var vehicle = fetchedList[i];

            if (vehicle.status.toUpperCase() == 'MAINTENANCE') {
              continue;
            }

            var vBookings = bookingsData.where((b) {
              int bVid =
                  int.tryParse(
                    b['vehicleId']?.toString() ??
                        b['vehicle']?['id']?.toString() ??
                        '0',
                  ) ??
                  0;
              return bVid == vehicle.id;
            }).toList();

            if (vBookings.isNotEmpty) {
              bool isInUse = vBookings.any((b) {
                String s = (b['status'] ?? '')
                    .toString()
                    .toLowerCase()
                    .replaceAll(' ', '_')
                    .replaceAll('-', '_');
                return s == 'in_use' || s == 'approved' || s == 'กำลังใช้งาน';
              });

              if (isInUse) {
                fetchedList[i] = vehicle.copyWith(status: 'IN_USE');
                continue;
              }

              bool isReservedToday = vBookings.any((b) {
                String s = (b['status'] ?? '')
                    .toString()
                    .toLowerCase()
                    .replaceAll(' ', '_')
                    .replaceAll('-', '_');
                if (s == 'cancelled' ||
                    s == 'completed' ||
                    s == 'ยกเลิกแล้ว' ||
                    s == 'เสร็จสิ้น')
                  return false;

                try {
                  String startStr = b['startDatetime'] ?? b['startDate'] ?? '';
                  String endStr = b['endDatetime'] ?? b['endDate'] ?? '';
                  if (startStr.isEmpty || endStr.isEmpty) return false;

                  DateTime start = DateTime.parse(startStr).toLocal();
                  DateTime end = DateTime.parse(endStr).toLocal();
                  DateTime startDate = DateTime(
                    start.year,
                    start.month,
                    start.day,
                  );
                  DateTime endDate = DateTime(end.year, end.month, end.day);

                  if ((today.isAtSameMomentAs(startDate) ||
                          today.isAfter(startDate)) &&
                      (today.isAtSameMomentAs(endDate) ||
                          today.isBefore(endDate))) {
                    return true;
                  }
                } catch (e) {
                  return false;
                }
                return false;
              });

              if (isReservedToday) {
                fetchedList[i] = vehicle.copyWith(hasFutureBooking: true);
              }
            }
          }
        }

        globalVehicles.value = fetchedList;
      }
    } catch (e) {
      debugPrint('❌ Error fetching vehicles: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateVehicleStatusQuickly(
    BuildContext dialogContext,
    Vehicle vehicle,
    String newStatus,
  ) async {
    final baseUrl = AuthService.baseUrl;
    final url = Uri.parse('$baseUrl/api/vehicles/${vehicle.id}');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final patchUrl = Uri.parse('$baseUrl/api/vehicles/${vehicle.id}/status');
      final response = await http.patch(
        patchUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token.trim()}',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เปลี่ยนสถานะรถเรียบร้อยแล้ว'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchVehiclesFromApi();
        }
      } else {
        if (mounted) {
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดรหัส ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQuickStatusDialog(BuildContext context, Vehicle vehicle) {
    final Map<String, String> statusOptions = {
      'AVAILABLE': 'ว่าง (Available)',
      'IN_USE': 'กำลังใช้งาน (In Use)',
      'MAINTENANCE': 'ส่งซ่อม (Maintenance)',
    };

    String currentRawStatus = vehicle.status.trim().toUpperCase();
    if (currentRawStatus == 'IN USE' || currentRawStatus == 'IN-USE')
      currentRawStatus = 'IN_USE';

    String selectedStatus = statusOptions.containsKey(currentRawStatus)
        ? currentRawStatus
        : 'AVAILABLE';
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: isUpdating
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF009CB4)),
                          SizedBox(height: 20),
                          Text(
                            'กำลังอัปเดตสถานะ...',
                            style: TextStyle(
                              color: Color(0xFF009CB4),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                color: Color(0xFF009CB4),
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'เปลี่ยนสถานะด่วน',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E2841),
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'รถ: ${vehicle.name}\nทะเบียน: ${vehicle.plate}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
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
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: statusOptions.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(fontFamily: 'Kanit'),
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setStateDialog(() {
                                selectedStatus = newValue!;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setStateDialog(() => isUpdating = true);
                                    _updateVehicleStatusQuickly(
                                      dialogContext,
                                      vehicle,
                                      selectedStatus,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF009CB4),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'บันทึก',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'ยกเลิก',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
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
      },
    );
  }

  Future<void> _deleteVehicleFromApi(BuildContext dialogContext, int id) async {
    final baseUrl = AuthService.baseUrl;
    final url = Uri.parse('$baseUrl/api/vehicles/$id');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token.trim()}',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(dialogContext);
          _fetchVehiclesFromApi();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DeleteVehicleSuccessPage(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting vehicle: $e');
      if (mounted) Navigator.pop(dialogContext);
    }
  }

  String _getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final baseUrl = AuthService.baseUrl;
    return '$baseUrl$path';
  }

  void _showCannotDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_busy,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ไม่สามารถลบรถได้',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'รถคันนี้มีรายการจองในอนาคต\nโปรดยกเลิกการจองก่อนทำการลบ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF003E75),
                    fontFamily: 'Kanit',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 140,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009CB4),
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

  void _showDeleteConfirmDialog(BuildContext context, Vehicle vehicle) {
    bool isDeleting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: isDeleting
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFD32F2F)),
                          SizedBox(height: 20),
                          Text(
                            'กำลังลบข้อมูล...',
                            style: TextStyle(
                              color: Color(0xFFD32F2F),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD32F2F),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.priority_high,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'ยืนยันการลบรถ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003E75),
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'คุณต้องการลบรถคันนี้ใช่หรือไม่?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF003E75),
                              fontFamily: 'Kanit',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setStateDialog(() => isDeleting = true);
                                    _deleteVehicleFromApi(
                                      dialogContext,
                                      vehicle.id,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB20000),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'ลบรถ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Kanit',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF009CB4),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'รายชื่อรถ',
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
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddVehiclePage(),
                    ),
                  ).then((value) {
                    _fetchVehiclesFromApi();
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'เพิ่มรถเข้า',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CB8C4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'กรองสถานะ: ',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003E75),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedFilterStatus,
                  underline: Container(
                    height: 2,
                    color: const Color(0xFF003E75),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ALL',
                      child: Text(
                        'ทั้งหมด (All)',
                        style: TextStyle(fontFamily: 'Kanit'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'AVAILABLE',
                      child: Text(
                        'ว่าง (Available)',
                        style: TextStyle(fontFamily: 'Kanit'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'IN_USE',
                      child: Text(
                        'กำลังใช้งาน (In Use)',
                        style: TextStyle(fontFamily: 'Kanit'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'MAINTENANCE',
                      child: Text(
                        'ส่งซ่อม (Maintenance)',
                        style: TextStyle(fontFamily: 'Kanit'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedFilterStatus = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF003E75),
                      ),
                    )
                  : ValueListenableBuilder<List<Vehicle>>(
                      valueListenable: globalVehicles,
                      builder: (context, vehicles, child) {
                        List<Vehicle> activeVehicles = vehicles.where((v) {
                          if (v.isDeleted) return false;
                          if (selectedFilterStatus == 'ALL') return true;

                          String rawStatus = v.status.trim().toUpperCase();
                          if (rawStatus == 'IN USE' ||
                              rawStatus == 'IN-USE' ||
                              rawStatus == 'กำลังใช้งาน')
                            rawStatus = 'IN_USE';

                          return rawStatus == selectedFilterStatus;
                        }).toList();

                        if (activeVehicles.isEmpty) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_car,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'ยังไม่มีข้อมูลรถในระบบ',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                              Text(
                                'กดปุ่ม "เพิ่มรถเข้า" ด้านบนเพื่อเพิ่มรถใหม่',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ],
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: _fetchVehiclesFromApi,
                          color: const Color(0xFF003E75),
                          child: ListView.builder(
                            itemCount: activeVehicles.length,
                            itemBuilder: (context, index) {
                              return _buildVehicleCard(activeVehicles[index]);
                            },
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

  Widget _buildVehicleCard(Vehicle vehicle) {
    String rawStatus = vehicle.status.trim().toUpperCase();
    String displayStatus = 'Available';
    Color statusColor = const Color(0xFF10B981);
    Color statusBgColor = const Color(0xFFD1FAE5);

    if (rawStatus == 'MAINTENANCE') {
      displayStatus = 'Maintenance';
      statusColor = const Color(0xFFE65100);
      statusBgColor = const Color(0xFFFFF3E0);
    } else if (rawStatus == 'IN_USE' ||
        rawStatus == 'IN USE' ||
        rawStatus == 'IN-USE' ||
        rawStatus == 'กำลังใช้งาน') {
      displayStatus = 'In Use';
      statusColor = const Color(0xFFEF4444);
      statusBgColor = const Color(0xFFFEE2E2);
    } else if (vehicle.hasFutureBooking ||
        rawStatus == 'PENDING' ||
        rawStatus == 'จองแล้ว') {
      displayStatus = 'Reserved';
      statusColor = const Color(0xFFF59E0B);
      statusBgColor = const Color(0xFFFEF3C7);
    } else {
      displayStatus = 'Available';
      statusColor = const Color(0xFF10B981);
      statusBgColor = const Color(0xFFD1FAE5);
    }

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          vehicle.imagePath != null && vehicle.imagePath!.isNotEmpty
              ? Image.network(
                  _getFullImageUrl(vehicle.imagePath),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.broken_image,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                )
              : Container(
                  height: 160,
                  width: double.infinity,
                  color: Colors.grey.shade300,
                  child: const Icon(
                    Icons.directions_car,
                    size: 60,
                    color: Colors.white,
                  ),
                ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        vehicle.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003E75),
                          fontFamily: 'Kanit',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: statusColor, size: 8),
                          const SizedBox(width: 6),
                          Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // 🟢 โชว์ ทะเบียนรถ + จังหวัด (ดักจับ Null เรียบร้อย)
                Text(
                  (vehicle.province != null && vehicle.province!.isNotEmpty)
                      ? '${vehicle.plate} ${vehicle.province}'
                      : vehicle.plate,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    _buildTag(vehicle.type == 'CAR' ? 'รถยนต์' : vehicle.type),
                    const SizedBox(width: 8),
                    _buildTag(
                      '${vehicle.capacity} ที่นั่ง',
                      icon: Icons.people_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () => _showQuickStatusDialog(context, vehicle),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF009CB4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        'เปลี่ยนสถานะ',
                        style: TextStyle(
                          color: Color(0xFF009CB4),
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditVehiclePage(vehicle: vehicle, index: 0),
                              ),
                            ).then((value) {
                              _fetchVehiclesFromApi();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF009CB4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text(
                            'แก้ไข',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (vehicle.hasFutureBooking) {
                              _showCannotDeleteDialog(context);
                            } else {
                              _showDeleteConfirmDialog(context, vehicle);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB20000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text(
                            'ลบ',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFF0056A0)),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF0056A0),
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
        ],
      ),
    );
  }
}