import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:http/http.dart' as http;
import '../../Booking_vehicle/Vehicle_model.dart';
import 'vehicle_booking_success.dart';
import 'dart:convert';

class VehicleBookingConfirmPage extends StatelessWidget {
  final VehicleModel vehicle;
  final String destination;
  final String startDate;
  final String endDate;
  final String timeRange;
  final int passengerCount;
  final String driverType;
  final String bookerName;
  final int userId; // 💡 1. เพิ่มตัวแปร userId ตรงนี้ครับ!

  const VehicleBookingConfirmPage({
    super.key,
    required this.vehicle,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.timeRange,
    required this.passengerCount,
    required this.driverType,
    required this.bookerName, 
    required this.userId, // 💡 2. บังคับรับค่า userId
  });

  @override
  Widget build(BuildContext context) {
    String imagePath = vehicle.uploadUrl ?? '';

    String displayTime = timeRange.split(' - ')[0];
    if (!displayTime.contains('น.')) {
      displayTime += ' น.';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004381),
        title: const Text('จองรถบริษัท', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ตรวจสอบข้อมูลการจอง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8F9BB3), fontFamily: 'Kanit')),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('รถที่ต้องการ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'Kanit')),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imagePath.isNotEmpty
                                  ? (imagePath.startsWith('/uploads')
                                        ? Image.network('http://localhost:3001$imagePath', width: 100, height: 70, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car)))
                                        : imagePath.startsWith('assets/')
                                        ? Image.asset(imagePath, width: 100, height: 70, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car)))
                                        : (kIsWeb
                                              ? Image.network(imagePath, width: 100, height: 70, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car)))
                                              : Image.file(File(imagePath), width: 100, height: 70, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car)))))
                                  : Container(width: 100, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.directions_car, color: Colors.grey)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(vehicle.vehicleName, style: const TextStyle(fontFamily: 'Kanit', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2841))),
                                  const SizedBox(height: 4),
                                  Text(vehicle.plateNumber, style: const TextStyle(fontFamily: 'Kanit', fontSize: 14, color: Color(0xFF8F9BB3))),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFE6EDF5), thickness: 1)),
                        _buildInfoRow('วันที่เดินทาง :', '$startDate ถึง $endDate'),
                        _buildInfoRow('เวลา :', displayTime),
                        _buildInfoRow('ผู้โดยสาร :', '$passengerCount คน'),
                        _buildInfoRow('ผู้ทำรายการ :', bookerName),
                        _buildInfoRow('ปลายทาง :', destination),
                        _buildInfoRow('การขับขี่ :', driverType),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Color(0xFFF4F7FA)),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () async {
              showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token') ?? '';

                String convertToIso(String dateStr, String timeStr) {
                  try {
                    final dateParts = dateStr.split('/');
                    final day = int.parse(dateParts[0]);
                    final month = int.parse(dateParts[1]);
                    final yearBE = int.parse(dateParts[2]) + 2500; 
                    final yearCE = yearBE - 543; 

                    final timeClean = timeStr.replaceAll(' น.', '').trim();
                    final timeParts = timeClean.split(':');
                    final hour = int.parse(timeParts[0]);
                    final minute = int.parse(timeParts[1]);

                    return DateTime(yearCE, month, day, hour, minute).toIso8601String();
                  } catch (e) {
                    return DateTime.now().toIso8601String(); 
                  }
                }

                final isoStart = convertToIso(startDate, timeRange);
                final isoEnd = convertToIso(endDate, timeRange); 

                // 📦 3. จุดสำคัญ: ยัด userId ลงไปในก้อนข้อมูลด้วย!
                final Map<String, dynamic> bodyData = {
                  "vehicleId": vehicle.id,
                  "userId": userId, // 💡 คราวนี้ส่ง ID ตัวจริงไปแล้วครับ ไม่พลาดแน่!
                  "destination": destination,
                  "startDatetime": isoStart, 
                  "endDatetime": isoEnd,     
                  "passengerCount": passengerCount, 
                  "passengers": passengerCount, 
                  "driverType": driverType, 
                };

                final response = await http.post(
                  Uri.parse('http://localhost:3001/api/vehicle-bookings'),
                  headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                  body: jsonEncode(bodyData),
                );

                if (!context.mounted) return;
                Navigator.pop(context); 

                if (response.statusCode == 200 || response.statusCode == 201) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const VehicleBookingSuccessPage()), (route) => false);
                } else {
                  String errorMsg = "จองไม่สำเร็จ กรุณาลองใหม่";
                  try {
                    final errorData = jsonDecode(response.body);
                    errorMsg = errorData['error'] ?? errorData['message'] ?? errorMsg;
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent));
                }
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์'), backgroundColor: Colors.redAccent));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009CB4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('ยืนยันการจองรถ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(title, style: const TextStyle(fontFamily: 'Kanit', fontSize: 14, color: Color(0xFF1E2841)))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Kanit', fontSize: 14, color: Color(0xFF4B5563)))),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepItem(step: '1', title: 'เลือกรถ', isActive: true, isDone: true), _buildStepLine(isActive: true),
          _buildStepItem(step: '2', title: 'กรอกข้อมูล', isActive: true, isDone: false), _buildStepLine(isActive: true),
          _buildStepItem(step: '3', title: 'ยืนยัน', isActive: true, isDone: true),
        ],
      ),
    );
  }

  Widget _buildStepItem({required String step, required String title, required bool isActive, required bool isDone}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 70, height: 36, decoration: BoxDecoration(color: isActive ? const Color(0xFF009CB4) : const Color(0xFFE6EDF5), shape: BoxShape.circle), alignment: Alignment.center, child: Text(step, style: TextStyle(color: isActive ? Colors.white : const Color(0xFFAAB6C7), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit'))),
        const SizedBox(height: 8), Text(title, style: TextStyle(color: isActive ? const Color(0xFF004381) : const Color(0xFFAAB6C7), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
      ],
    );
  }

  Widget _buildStepLine({required bool isActive}) {
    return Container(margin: const EdgeInsets.only(top: 17, left: 4, right: 4), width: 80, height: 2, color: isActive ? const Color(0xFF009CB4) : const Color(0xFF009CB4));
  }
}