import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Room_Completed.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RoomConfirmScreen extends StatefulWidget {
  final MeetingRoom room;
  final String bookingTitle;
  final String formattedDate;
  final String formattedTime;
  final int participantCount;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const RoomConfirmScreen({
    Key? key,
    required this.room,
    required this.bookingTitle,
    required this.formattedDate,
    required this.formattedTime,
    required this.participantCount,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  State<RoomConfirmScreen> createState() => _RoomConfirmScreenState();
}

class _RoomConfirmScreenState extends State<RoomConfirmScreen> {
  // 🟢 1. สร้างตัวแปรดักจับสถานะ Loading เพื่อล็อกปุ่ม
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF004381),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text(
          'จองห้องประชุม',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 30.0,
              ),
              child: Column(
                children: [
                  _buildConfirmTicketCard(),
                  const SizedBox(height: 40),

                  // ปุ่มยืนยันการจองห้อง
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A8CC),
                        disabledBackgroundColor: Colors.grey, // สีปุ่มตอนโหลด
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black26,
                      ),
                      // 🟢 2. ปิดปุ่มถ้าระบบกำลังโหลดอยู่
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              setState(() {
                                isSubmitting = true; // เปิด Loading
                              });

                              try {
                                final String baseUrl = kIsWeb
                                    ? 'https://192.168.88.25:3002'
                                    : 'https://192.168.88.25:3002';

                                const storage = FlutterSecureStorage();
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final String jwtToken =
                                    await storage.read(key: 'token') ??
                                    await storage.read(key: 'jwt') ??
                                    prefs.getString('token') ??
                                    prefs.getString('jwt') ??
                                    '';

                                // 🟢 3. แปลงวันที่และเวลาให้เป็น DateTime เพื่อส่งให้ Prisma แบบ ISO-8601 (สำคัญมาก!)
                                final dateParts = widget.formattedDate.split(
                                  '/',
                                );
                                final int day = int.parse(dateParts[0]);
                                final int month = int.parse(dateParts[1]);
                                final int year = int.parse(dateParts[2]);

                                final DateTime startDateTime = DateTime(
                                  year,
                                  month,
                                  day,
                                  widget.startTime.hour,
                                  widget.startTime.minute,
                                );
                                final DateTime endDateTime = DateTime(
                                  year,
                                  month,
                                  day,
                                  widget.endTime.hour,
                                  widget.endTime.minute,
                                );

                                // ใช้ .toIso8601String() เพื่อให้ Backend (Prisma) ยอมรับข้อมูล
                                final String startDateTimeStr = startDateTime
                                    .toIso8601String();
                                final String endDateTimeStr = endDateTime
                                    .toIso8601String();

                                // ยิง API สร้างรายการจองใหม่
                                // ยิง API สร้างรายการจองใหม่
                                final response = await http
                                    .post(
                                      Uri.parse('$baseUrl/api/bookings'),
                                      headers: {
                                        'Content-Type': 'application/json',
                                        'Authorization': 'Bearer $jwtToken',
                                      },
                                      body: jsonEncode({
                                        "roomId": int.parse(
                                          widget.room.id.toString(),
                                        ),
                                        "title":
                                            widget.bookingTitle.trim().isEmpty
                                            ? 'ประชุมงานทั่วไป'
                                            : widget.bookingTitle.trim(),
                                        "startDatetime": startDateTimeStr,
                                        "endDatetime": endDateTimeStr,
                                        "attendeeCount":
                                            widget.participantCount,
                                      }),
                                    )
                                    .timeout(
                                      const Duration(seconds: 15),
                                    ); // 💡 เพิ่ม Timeout ป้องกันแอปค้างหน้า Loading ถาวร

                                if (response.statusCode == 201) {
                                  if (context.mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RoomCompletedScreen(),
                                      ),
                                      (route) => route.isFirst,
                                    );
                                  }
                                } else if (response.statusCode == 409) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'ช่วงเวลานี้มีการจองแล้ว กรุณาเลือกเวลาใหม่',
                                                style: TextStyle(
                                                  fontFamily: 'Kanit',
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: const Color(
                                          0xFFD32F2F,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(20),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );

                                    // กลับไปหน้า RoomBookingAScreen เพื่อให้ User เลือกเวลาใหม่โดยไม่ล้าง Form
                                    Navigator.pop(context, false);
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'จองไม่สำเร็จ รหัส: ${response.statusCode}',
                                          style: const TextStyle(
                                            fontFamily: 'Kanit',
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'ข้อผิดพลาดการเชื่อมต่อ: $e',
                                        style: const TextStyle(
                                          fontFamily: 'Kanit',
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                // 🟢 4. ปิดสถานะ Loading หากเกิด Error หรือประมวลผลเสร็จ
                                if (mounted) {
                                  setState(() {
                                    isSubmitting = false;
                                  });
                                }
                              }
                            },
                      // 🟢 5. สลับข้อความกับวงกลม Loading
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'ยืนยันการจองห้อง',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Kanit',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepItem(step: '1', title: 'เลือกห้อง', isActive: false),
              _buildStepLine(),
              _buildStepItem(step: '2', title: 'กรอกข้อมูล', isActive: false),
              _buildStepLine(),
              _buildStepItem(step: '3', title: 'ยืนยัน', isActive: true),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: const Color(0xFF003E75),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: const Text(
            'ยืนยันข้อมูลการจอง',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required bool isActive,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00A8CC) : const Color(0xFFE6EDF5),
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
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF004381) : const Color(0xFF004381),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      margin: const EdgeInsets.only(top: 17, left: 4, right: 4),
      width: 80,
      height: 2,
      color: const Color(0xFFAAB6C7),
    );
  }

  Widget _buildConfirmTicketCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey[300],
                  // 💡 ปรับลอจิกให้ตรงกับ Room_list.dart: บังคับใช้ Image.network เนื่องจากภาพอยู่บนเซิร์ฟเวอร์ทั้งหมด
                  child:
                      (widget.room.imagePath != null &&
                          widget.room.imagePath!.isNotEmpty)
                      ? Image.network(
                          widget.room.imagePath!.startsWith('http')
                              ? widget.room.imagePath!
                              : '${kIsWeb ? "https://192.168.88.25:3002" : "https://192.168.88.25:3002"}${widget.room.imagePath}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                size: 50,
                                color: Colors.grey,
                              ),
                        )
                      : const Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ห้องประชุม ${widget.room.location}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.room.roomName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 16.0,
            ),
            child: Row(
              children: List.generate(
                30,
                (index) => Expanded(
                  child: Container(
                    color: index % 2 == 0
                        ? Colors.transparent
                        : Colors.grey.shade400,
                    height: 2,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              bottom: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'หัวข้อการประชุม',
                  style: TextStyle(
                    color: Color(0xFF9BB1BD),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.bookingTitle.trim().isEmpty
                      ? 'ประชุมงานทั่วไป'
                      : widget.bookingTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFF004AAD),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ตำแหน่ง : ${widget.room.location}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Color(0xFFE2E8F0)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'วันที่ใช้งาน',
                            style: TextStyle(
                              color: Color(0xFF9BB1BD),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.formattedDate,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'เวลา',
                            style: TextStyle(
                              color: Color(0xFF9BB1BD),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.formattedTime,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'ผู้เข้าร่วม',
                  style: TextStyle(
                    color: Color(0xFF9BB1BD),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.participantCount} ท่าน',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Kanit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
