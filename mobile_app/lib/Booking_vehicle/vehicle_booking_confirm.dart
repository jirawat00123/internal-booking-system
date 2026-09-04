import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../Booking_vehicle/Vehicle_model.dart';
import 'vehicle_booking_success.dart';
import 'dart:convert';
import '../auth_service.dart';

class VehicleBookingConfirmPage extends StatelessWidget {
  final VehicleModel vehicle;
  final String destination;
  final String startDate;
  final String endDate;
  final String timeRange;
  final int passengerCount;
  final List<String> passengerNames;
  final String driverType;
  final String bookerName;
  final int userId; // 💡 1. เพิ่มตัวแปร userId ตรงนี้ครับ!
  final String? purpose;
  final XFile? licenseImage;

  const VehicleBookingConfirmPage({
    super.key,
    required this.vehicle,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.timeRange,
    required this.passengerCount,
    this.passengerNames = const [],
    required this.driverType,
    required this.bookerName,
    required this.userId, // 💡 2. บังคับรับค่า userId
    this.purpose,
    this.licenseImage,
  });

  @override
  Widget build(BuildContext context) {
    String imagePath = vehicle.uploadUrl ?? '';

    String displayTime = timeRange;
    if (!displayTime.contains('น.')) {
      displayTime += ' น.';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004381),
        title: const Text(
          'จองรถบริษัท',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
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
                  const Text(
                    'ตรวจสอบข้อมูลการจอง',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8F9BB3),
                      fontFamily: 'Kanit',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'รถที่ต้องการ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontFamily: 'Kanit',
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imagePath.isNotEmpty
                                  ? (imagePath.startsWith('assets/')
                                        ? Image.asset(
                                            imagePath,
                                            width: 100,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Container(
                                                  width: 100,
                                                  height: 70,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.directions_car,
                                                  ),
                                                ),
                                          )
                                        : (kIsWeb ||
                                              imagePath.startsWith('http') ||
                                              imagePath.startsWith('/') ||
                                              imagePath.startsWith(
                                                'attachments',
                                              ) ||
                                              imagePath.startsWith('uploads'))
                                        ? Image.network(
                                            AuthService.getImageUrl(imagePath),
                                            width: 100,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Container(
                                                  width: 100,
                                                  height: 70,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.directions_car,
                                                  ),
                                                ),
                                          )
                                        : Image.file(
                                            File(imagePath),
                                            width: 100,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Container(
                                                  width: 100,
                                                  height: 70,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.directions_car,
                                                  ),
                                                ),
                                          ))
                                  : Container(
                                      width: 100,
                                      height: 70,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.directions_car,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.vehicleName,
                                    style: const TextStyle(
                                      fontFamily: 'Kanit',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E2841),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicle.plateNumber,
                                    style: const TextStyle(
                                      fontFamily: 'Kanit',
                                      fontSize: 14,
                                      color: Color(0xFF8F9BB3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(
                            color: Color(0xFFE6EDF5),
                            thickness: 1,
                          ),
                        ),
                        _buildInfoRow(
                          'วันที่เดินทาง :',
                          '$startDate ถึง $endDate',
                        ),
                        _buildInfoRow('เวลา :', displayTime),
                        _buildInfoRow(
                          'ผู้โดยสาร :',
                          passengerNames.isNotEmpty
                              ? '$passengerCount คน\n\n' +
                                    passengerNames
                                        .asMap()
                                        .entries
                                        .map((e) => '${e.key + 1}. ${e.value}')
                                        .join('\n')
                              : '$passengerCount คน',
                        ),
                        FutureBuilder<SharedPreferences>(
                          future: SharedPreferences.getInstance(),
                          builder: (context, snapshot) {
                            String realName = bookerName;
                            if (snapshot.hasData) {
                              final prefs = snapshot.data!;
                              final fullName = prefs.getString('fullName');
                              final name = prefs.getString('name');
                              final employeeName = prefs.getString(
                                'employeeName',
                              );
                              final displayName = prefs.getString(
                                'displayName',
                              );
                              final firstName = prefs.getString('firstName');
                              final lastName = prefs.getString('lastName');
                              final userName = prefs.getString('userName');

                              String? validName;
                              for (final item in [
                                fullName,
                                name,
                                employeeName,
                                displayName,
                              ]) {
                                if (item != null &&
                                    item.trim().isNotEmpty &&
                                    item.trim() != 'MMK') {
                                  validName = item.trim();
                                  break;
                                }
                              }

                              if (validName != null) {
                                realName = validName;
                              } else if (firstName != null &&
                                  firstName.trim().isNotEmpty &&
                                  firstName.trim() != 'MMK') {
                                realName = '$firstName ${lastName ?? ''}'
                                    .trim();
                              } else if (userName != null &&
                                  userName.trim().isNotEmpty &&
                                  userName.trim() != 'MMK') {
                                realName = userName.trim();
                              }
                            }
                            return _buildInfoRow('ผู้ทำรายการ :', realName);
                          },
                        ),
                        _buildInfoRow('ปลายทาง :', destination),
                        _buildInfoRow('วัตถุประสงค์ :', () {
                          if (purpose == null) return '-';
                          final cleaned = purpose!.replaceAll('-', '').trim();
                          final words = cleaned
                              .split(RegExp(r'\s+'))
                              .where((w) => w.isNotEmpty)
                              .toSet()
                              .toList();
                          return words.isNotEmpty ? words.join(' ') : '-';
                        }()),
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
              if (passengerNames.length != passengerCount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'จำนวนผู้โดยสาร ($passengerCount คน) ไม่ตรงกับรายชื่อที่ระบุ (${passengerNames.length} คน)',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final hasEmptyName = passengerNames.any(
                (name) => name.trim().isEmpty,
              );
              if (hasEmptyName) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณากรอกรายชื่อผู้โดยสารให้ครบถ้วน'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final uniqueNames = passengerNames.map((e) => e.trim()).toSet();
              if (uniqueNames.length != passengerNames.length) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ห้ามมีรายชื่อผู้โดยสารซ้ำกัน'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

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

                    return DateTime(
                      yearCE,
                      month,
                      day,
                      hour,
                      minute,
                    ).toIso8601String();
                  } catch (e) {
                    return DateTime.now().toIso8601String();
                  }
                }

                // 💡 1. แยกเวลาใช้งาน และกำหนดเวลาคืนรถอัตโนมัติ (เนื่องจากตัดเวลาคืนออกจากหน้า UI)
                String startTimeStr = timeRange;
                String endTimeStr =
                    '18:00'; // ตั้งเวลาคืนรถเริ่มต้นเป็น 18:00 น.

                if (timeRange.contains('-')) {
                  final parts = timeRange.split('-');
                  startTimeStr = parts[0].trim();
                  endTimeStr = parts[1].trim();
                }

                final isoStart = convertToIso(startDate, startTimeStr);
                String isoEnd = convertToIso(endDate, endTimeStr);

                // 💡 2. ตรวจสอบให้แน่ใจว่าเวลาคืนรถ (End) มากกว่าเวลาเริ่ม (Start) เสมอ
                DateTime dtStart = DateTime.parse(isoStart);
                DateTime dtEnd = DateTime.parse(isoEnd);
                if (!dtEnd.isAfter(dtStart)) {
                  // ถ้าเวลาจบดันน้อยกว่าหรือเท่ากับเวลาเริ่ม ให้ทดเวลาจบไปอีก 4 ชั่วโมงอัตโนมัติ
                  isoEnd = dtStart
                      .add(const Duration(hours: 4))
                      .toIso8601String();
                }

                // 📦 3. เปลี่ยนเป็น MultipartRequest เพื่อรองรับการอัปโหลดไฟล์รูปภาพใบขับขี่
                final uri = Uri.parse(
                  'https://192.168.88.25:3002/api/vehicle-bookings',
                );
                final request = http.MultipartRequest('POST', uri);

                request.headers['Authorization'] = 'Bearer $token';

                request.fields['vehicleId'] = vehicle.id.toString();
                request.fields['userId'] = userId.toString();
                request.fields['destination'] = destination;
                request.fields['startDatetime'] = isoStart;
                request.fields['endDatetime'] = isoEnd;
                request.fields['passengers'] = passengerCount.toString();
                // 🟢 แปลง List<String> เป็น JSON String เพื่อให้ Backend Node.js ใช้ JSON.parse() หรือรับเป็น Array ได้ง่ายขึ้น
                if (passengerNames.isNotEmpty) {
                  request.fields['passengerNames'] = jsonEncode(passengerNames);
                }
                request.fields['driverType'] = driverType;
                if (purpose != null && purpose!.isNotEmpty) {
                  request.fields['purpose'] = purpose!;
                }

                if (licenseImage != null) {
                  if (kIsWeb) {
                    final bytes = await licenseImage!.readAsBytes();
                    request.files.add(
                      http.MultipartFile.fromBytes(
                        'licenseDriver',
                        bytes,
                        filename: licenseImage!.name,
                      ),
                    );
                  } else {
                    request.files.add(
                      await http.MultipartFile.fromPath(
                        'licenseDriver',
                        licenseImage!.path,
                      ),
                    );
                  }
                }

                // 💡 แทรก Print ตรวจสอบข้อมูลที่กำลังจะส่ง
                print('--- DEBUG MULTIPART REQUEST ---');
                print('URL: $uri');
                print('Fields: ${request.fields}');
                print(
                  'Files: ${request.files.map((f) => f.filename).toList()}',
                );

                final streamedResponse = await request.send();
                final response = await http.Response.fromStream(
                  streamedResponse,
                );

                // 💡 แทรก Print ตรวจสอบข้อความที่ Backend ฟ้องกลับมา
                print('--- DEBUG MULTIPART RESPONSE ---');
                print('Status Code: ${response.statusCode}');
                print('Response Body: ${response.body}');

                if (!context.mounted) return;
                Navigator.pop(context);

                if (response.statusCode == 200 || response.statusCode == 201) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VehicleBookingSuccessPage(),
                    ),
                    (route) => false,
                  );
                } else {
                  String errorMsg = "จองไม่สำเร็จ กรุณาลองใหม่";
                  try {
                    final errorData = jsonDecode(response.body);
                    errorMsg =
                        errorData['error'] ?? errorData['message'] ?? errorMsg;
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009CB4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'ยืนยันการจองรถ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
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
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 14,
                color: Color(0xFF1E2841),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 14,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepItem(
            step: '1',
            title: 'เลือกรถ',
            isActive: true,
            isDone: true,
          ),
          _buildStepLine(isActive: true),
          _buildStepItem(
            step: '2',
            title: 'กรอกข้อมูล',
            isActive: true,
            isDone: false,
          ),
          _buildStepLine(isActive: true),
          _buildStepItem(
            step: '3',
            title: 'ยืนยัน',
            isActive: true,
            isDone: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required bool isActive,
    required bool isDone,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF009CB4) : const Color(0xFFE6EDF5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFFAAB6C7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF004381) : const Color(0xFFAAB6C7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isActive}) {
    return Expanded(
      // 💡 ใช้ Expanded เพื่อให้เส้นยืดหดตามขนาดหน้าจอมือถืออัตโนมัติ
      child: Container(
        margin: const EdgeInsets.only(top: 17, left: 4, right: 4),
        height: 2,
        color: isActive ? const Color(0xFF009CB4) : const Color(0xFF009CB4),
      ),
    );
  }
}
