import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'add_vehicle_page.dart';
import 'edit_vehicle_page.dart';
import 'deletevehicle_successpage.dart';
import '../../Booking_vehicle/Vehicle_model.dart'; 

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});

  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('http://localhost:3001/api/vehicles'), 
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        List<dynamic> vehiclesData = [];
        if (decodedData is List) {
          vehiclesData = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('data')) {
          vehiclesData = decodedData['data'];
        }
        List<VehicleModel> fetchedList = vehiclesData.map((json) => VehicleModel.fromJson(json)).toList();
        globalVehicles.value = fetchedList;
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงข้อมูล: $e');
    } finally {
      if (mounted) setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), 
      appBar: AppBar(
        title: const Text('รายชื่อรถ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Kanit')),
        backgroundColor: const Color(0xFF003E75), 
        elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const AddVehiclePage())); },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('เพิ่มรถเข้า', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CB8C4), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF003E75))) 
                : ValueListenableBuilder<List<VehicleModel>>(
                    valueListenable: globalVehicles,
                    builder: (context, vehicles, child) {
                      List<VehicleModel> activeVehicles = vehicles.where((v) => !v.isDeleted).toList();
                      if (activeVehicles.isEmpty) return const Center(child: Text('ไม่มีข้อมูลรถยนต์ในระบบ', style: TextStyle(fontFamily: 'Kanit', color: Colors.grey)));
                      return ListView.builder(
                        itemCount: activeVehicles.length,
                        itemBuilder: (context, index) => _buildVehicleCard(activeVehicles[index]),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // 💡 พระเอกของเราอยู่ตรงนี้ครับ! ฟังก์ชันจัดการแสดงรูปภาพที่หายไป
  Widget _buildVehicleImage(String path) {
    Widget fallbackIcon = Container(height: 160, width: double.infinity, color: Colors.grey.shade200, child: const Icon(Icons.directions_car, size: 60, color: Colors.grey));
    if (path.isEmpty) return fallbackIcon;

    if (path.startsWith('/uploads')) {
      // ต่อ URL อัตโนมัติ เพื่อให้ Web ดึงรูปจาก Node.js ได้
      return Image.network('http://localhost:3001$path', height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallbackIcon);
    } else if (path.startsWith('assets/')) {
      return Image.asset(path, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallbackIcon);
    } else if (kIsWeb) {
      return Image.network(path, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallbackIcon);
    } else {
      return Image.file(File(path), height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => fallbackIcon);
    }
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    String rawStatus = vehicle.status.toUpperCase();
    String displayStatus;
    Color dotColor;
    bool isInUseOrReserved = false;

    if (rawStatus == 'AVAILABLE' || rawStatus == 'ว่างพร้อมใช้งาน') {
      displayStatus = 'ว่างพร้อมใช้งาน'; dotColor = const Color(0xFF4CAF50); 
    } else if (rawStatus == 'RESERVED' || rawStatus == 'จองแล้ว') {
      displayStatus = 'จองแล้ว'; dotColor = const Color(0xFFFF9800); isInUseOrReserved = true;
    } else {
      displayStatus = 'กำลังใช้งาน'; dotColor = const Color(0xFFF44336); isInUseOrReserved = true;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // 💡 เรียกใช้ฟังก์ชันรูปภาพตรงนี้
              _buildVehicleImage(vehicle.uploadUrl ?? ''),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.circle, color: dotColor, size: 10), const SizedBox(width: 6), Text(displayStatus, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Kanit'))],
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.vehicleName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003E75), fontFamily: 'Kanit')),
                const SizedBox(height: 4),
                Text(vehicle.plateNumber, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'Kanit')),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: Color(0xFF003E75)), const SizedBox(width: 4),
                      Text('${vehicle.seats} ที่นั่ง', style: const TextStyle(fontSize: 12, color: Color(0xFF003E75), fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        int realIndex = globalVehicles.value.indexWhere((v) => v.id == vehicle.id);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditVehiclePage(vehicle: vehicle, index: realIndex)));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009CB4), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('แก้ไขรถ', style: TextStyle(color: Colors.white, fontFamily: 'Kanit')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (isInUseOrReserved || vehicle.hasFutureBooking) {
                          _showCannotDeleteDialog(context, displayStatus: displayStatus, hasFutureBooking: vehicle.hasFutureBooking);
                        } else {
                          _showDeleteConfirmDialog(context, vehicle);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('ลบรถ', style: TextStyle(color: Colors.white, fontFamily: 'Kanit')),
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

  void _showCannotDeleteDialog(BuildContext context, {required String displayStatus, bool hasFutureBooking = false}) {
    String reason = '';
    if ((displayStatus == 'กำลังใช้งาน' || displayStatus == 'จองแล้ว') && hasFutureBooking) {
      reason = 'รถยนต์คันนี้กำลัง "$displayStatus" และมี "คิวจองล่วงหน้า"';
    } else if (displayStatus == 'กำลังใช้งาน' || displayStatus == 'จองแล้ว') {
      reason = 'รถยนต์คันนี้มีสถานะเป็น "$displayStatus" ในขณะนี้';
    } else if (hasFutureBooking) {
      reason = 'รถยนต์คันนี้มี "รายการจองล่วงหน้า" อยู่ในระบบ';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ไม่สามารถลบรถได้', style: TextStyle(fontFamily: 'Kanit', color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
        content: Text('$reason\n\nไม่อนุญาตให้ลบข้อมูล กรุณาตรวจสอบอีกครั้ง', style: const TextStyle(fontFamily: 'Kanit')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('เข้าใจแล้ว', style: TextStyle(fontFamily: 'Kanit', color: Color(0xFF009CB4), fontWeight: FontWeight.bold)))],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, VehicleModel vehicle) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFFF0000), shape: BoxShape.circle), child: const Icon(Icons.priority_high, size: 50, color: Colors.white)),
                const SizedBox(height: 20), const Text('ยืนยันการลบรถ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF003E75), fontFamily: 'Kanit')), const SizedBox(height: 8), const Text('คุณต้องการลบรถคันนี้ใช่หรือไม่?', style: TextStyle(fontSize: 14, color: Color(0xFF003E75), fontFamily: 'Kanit'), textAlign: TextAlign.center), const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext); 
                          showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final token = prefs.getString('token');

                            final response = await http.delete(
                              Uri.parse('http://localhost:3001/api/vehicles/${vehicle.id}'),
                              headers: {
                                if (token != null) 'Authorization': 'Bearer $token',
                              }
                            );

                            if (!mounted) return;
                            Navigator.pop(context); 

                            if (response.statusCode == 200) {
                              globalVehicles.value = globalVehicles.value.where((v) => v.id != vehicle.id).toList();
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const DeleteVehicleSuccessPage()));
                            } else {
                              final errorMsg = jsonDecode(response.body)['error'] ?? 'ลบไม่สำเร็จ';
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent));
                            }
                          } catch(e) {
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'), backgroundColor: Colors.redAccent));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB20000), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                        child: const Text('ลบรถ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009CB4), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                        child: const Text('ยกเลิก', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
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
}