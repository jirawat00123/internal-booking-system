import 'dart:io';
import 'dart:convert'; // 🟢 เพิ่มสำหรับการแปลง JSON
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http; // 🟢 เพิ่ม HTTP
import 'package:shared_preferences/shared_preferences.dart'; // 🟢 เพิ่ม SharedPreferences
import 'edit_vehicle_page.dart'; // 🟢 ดึงหน้าแก้ไขรถเข้ามาใช้งาน

import 'add_vehicle_page.dart';
import 'deletevehicle_successpage.dart';

// 💡 1. โครงสร้างเก็บข้อมูลรถ (อัปเดต Mapping ให้รับ JSON จาก API ได้)
class Vehicle {
  final dynamic id;
  final String vehicleName;
  final String plate;
  final String brand;
  final String model;
  final int seats;
  final String status;
  final String? uploadUrl;

  // 🟢 ตัวแปรเพิ่มเติมที่ UI เรียกหา
  final bool isDeleted;
  final String type;
  final bool hasFutureBooking;

  // ==========================================
  // 🌉 GETTER BRIDGE: สะพานเชื่อม UI เก่า เข้ากับ Backend ใหม่
  // ==========================================
  String get name => vehicleName; // ถ้า UI ขอ 'name' ให้ส่ง 'vehicleName'
  String? get imagePath =>
      uploadUrl; // ถ้า UI ขอ 'imagePath' ให้ส่ง 'uploadUrl'
  int get capacity => seats; // ถ้า UI ขอ 'capacity' ให้ส่ง 'seats'

  Vehicle({
    required this.id,
    required this.vehicleName,
    required this.plate,
    required this.brand,
    required this.model,
    required this.seats,
    required this.status,
    this.uploadUrl,
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

      // ดึงค่าเพิ่มเติม (ถ้า backend ไม่ได้ส่งมา ให้ใช้ค่าเริ่มต้น)
      isDeleted: json['isDeleted'] ?? json['is_deleted'] ?? false,
      type: json['type'] ?? 'รถยนต์',
      hasFutureBooking: json['hasFutureBooking'] ?? false,
    );
  }
}

// 🟢 2. เปลี่ยนจากข้อมูลจำลอง เป็น ValueNotifier (ตาม Rule 23)
final ValueNotifier<List<Vehicle>> globalVehicles = ValueNotifier([]);

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});

  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  bool isLoading = true; // 🟢 สถานะกำลังโหลดข้อมูล

  @override
  void initState() {
    super.initState();
    _fetchVehiclesFromApi(); // 🚀 เรียก API ทันทีที่เปิดหน้านี้
  }

  // 🔌 ฟังก์ชันดึงข้อมูลรถจาก API
  Future<void> _fetchVehiclesFromApi() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    final baseUrl = kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001';
    final url = Uri.parse('$baseUrl/api/vehicles');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token.trim()}',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        if (decodedData['success'] == true) {
          final List<dynamic> vehicleData = decodedData['data'];
          globalVehicles.value = vehicleData
              .map((json) => Vehicle.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching vehicles: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // 🔌 ฟังก์ชันลบรถยนต์ (Soft Delete) ผ่าน API
  Future<void> _deleteVehicleFromApi(BuildContext dialogContext, int id) async {
    final baseUrl = kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001';
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
          Navigator.pop(dialogContext); // ปิด Pop-up
          _fetchVehiclesFromApi(); // 🔄 โหลดข้อมูลใหม่ให้รายการหายไป
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

  // 🟢 แปลง URL รูปภาพให้แสดงผลได้ถูกต้อง
  String _getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final baseUrl = kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001';
    return '$baseUrl$path';
  }

  // 🔴 ฟังก์ชันแสดง Popup กรณีลบไม่ได้ (ติด Booking)
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
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'รถคันนี้มีรายการจองในอนาคต\nโปรดยกเลิกการจองก่อนทำการลบ',
                  style: TextStyle(fontSize: 14, color: Color(0xFF003E75)),
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

  // 🔴 ฟังก์ชันแสดง Popup ยืนยันการลบรถ
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
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'คุณต้องการลบรถคันนี้ใช่หรือไม่?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF003E75),
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
                                    ); // 🚀 เรียก API ลบจริง
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
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔘 ปุ่มเพิ่มรถเข้า
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
                    _fetchVehiclesFromApi(); // 🔄 โหลดข้อมูลใหม่เมื่อกลับมาจากหน้าเพิ่มรถ
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'เพิ่มรถเข้า',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

            // 🚙 รายการรถยนต์ (เชื่อม ValueNotifier)
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
                        // กรองเฉพาะรถที่ยังไม่โดน Soft Delete
                        List<Vehicle> activeVehicles = vehicles
                            .where((v) => !v.isDeleted)
                            .toList();

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
                                ),
                              ),
                              Text(
                                'กดปุ่ม "เพิ่มรถเข้า" ด้านบนเพื่อเพิ่มรถใหม่',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        }

                        // 🔄 เพิ่ม RefreshIndicator ให้ดึงจอรีเฟรชได้
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

  // 📝 Widget สร้างการ์ดรถ
  Widget _buildVehicleCard(Vehicle vehicle) {
    // 🎨 1. แปลงสถานะจาก Backend เป็นภาษาไทย และกำหนดสี
    String displayStatus = vehicle.status;
    Color statusBgColor = Colors.grey.withOpacity(0.1);
    Color statusIconColor = Colors.grey;
    Color statusTextColor = Colors.grey;

    if (vehicle.status == 'AVAILABLE') {
      displayStatus = 'ว่างพร้อมใช้งาน';
      statusBgColor = Colors.green.withOpacity(0.1);
      statusIconColor = Colors.green;
      statusTextColor = Colors.green;
    } else if (vehicle.status == 'IN_USE') {
      displayStatus = 'กำลังใช้งาน';
      statusBgColor = const Color.fromARGB(255, 243, 33, 33).withOpacity(0.1);
      statusIconColor = Colors.red;
      statusTextColor = const Color.fromARGB(255, 243, 33, 33);
    } else if (vehicle.status == 'MAINTENANCE') {
      displayStatus = 'ซ่อมบำรุง';
      statusBgColor = Colors.orange.withOpacity(0.1);
      statusIconColor = Colors.orange;
      statusTextColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🖼️ 1. รูปภาพรถ (ใช้ URL จาก API)
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

          // 📋 2. ส่วนของข้อมูล
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ➡️ ใช้ Row เพื่อให้อยู่บรรทัดเดียวกัน
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ชื่อรถ (ใช้ Expanded เพื่อให้กินพื้นที่ที่เหลือ และดันป้ายสถานะไปชิดขวา)
                    Expanded(
                      child: Text(
                        vehicle.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003E75),
                        ),
                        maxLines: 1, // ป้องกันชื่อยาวเกินไปจนตกบรรทัด
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8), // ระยะห่างระหว่างชื่อและป้ายสถานะ
                    // ป้ายสถานะ
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
                          Icon(Icons.circle, color: statusIconColor, size: 10),
                          const SizedBox(width: 6),
                          Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // ป้ายทะเบียน
                Text(
                  vehicle.plate,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),

                // Tags (ประเภทรถ, จำนวนที่นั่ง)
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

                // ปุ่มแก้ไข / ลบ
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // 1. ปิดหน้าต่าง Popup รายละเอียดนี้ไปก่อน

                        // 2. สไลด์เปิดหน้า EditVehiclePage
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditVehiclePage(vehicle: vehicle, index: 0),
                          ),
                        ).then((value) {
                          // 3. พอกดเซฟจากหน้าแก้ไขเสร็จ ให้มันโหลดข้อมูลรถมาแสดงใหม่
                          _fetchVehiclesFromApi();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009CB4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'แก้ไขรถ',
                        style: TextStyle(color: Colors.white),
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
                      ),
                      child: const Text(
                        'ลบรถ',
                        style: TextStyle(color: Colors.white),
                      ),
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

  // ป้าย Tag เล็กๆ
  Widget _buildTag(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
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
            ),
          ),
        ],
      ),
    );
  }
}
