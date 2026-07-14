import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Room_Completed.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
        backgroundColor: const Color(0xFF004AAD),
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
                                    ? 'http://localhost:3001'
                                    : 'http://10.0.2.2:3001';

                                final prefs =
                                    await SharedPreferences.getInstance();
                                final String jwtToken =
                                    prefs.getString('token') ?? '';

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
                                        "participantCount":
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
                                    String errorMessage =
                                        'ไม่สามารถจองได้ เนื่องจากมีการจองในช่วงเวลานี้แล้ว';
                                    try {
                                      final errorData = jsonDecode(
                                        response.body,
                                      );
                                      if (errorData['message'] != null) {
                                        errorMessage = errorData['message'];
                                      }
                                    } catch (_) {}

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                errorMessage,
                                                style: const TextStyle(
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
    return Container(
      color: const Color(0xFF004AAD),
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepCircle(
              '1',
              'เลือกห้อง',
              isActive: false,
              isCompleted: true,
            ),
            _buildStepLine(isCompleted: true),
            _buildStepCircle(
              '2',
              'กรอกข้อมูล',
              isActive: false,
              isCompleted: true,
            ),
            _buildStepLine(isCompleted: true),
            _buildStepCircle('3', 'ยืนยัน', isActive: true, isCompleted: false),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(
    String step,
    String label, {
    required bool isActive,
    required bool isCompleted,
  }) {
    Color circleColor = const Color(0xFFE2E8F0);
    Color textColor = Colors.grey;
    if (isActive) {
      circleColor = const Color(0xFF00A8CC);
      textColor = Colors.white;
    } else if (isCompleted) {
      circleColor = const Color(0xFF004AAD).withOpacity(0.1);
      textColor = const Color(0xFF004AAD);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: isCompleted
                ? Border.all(color: const Color(0xFF004AAD), width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive || isCompleted
                ? const Color(0xFF004AAD)
                : Colors.grey,
            fontFamily: 'Kanit',
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isCompleted}) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? const Color(0xFF004AAD) : const Color(0xFFE2E8F0),
        margin: const EdgeInsets.symmetric(horizontal: 8),
      ),
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
                              : '${kIsWeb ? "http://localhost:3001" : "http://10.0.2.2:3001"}${widget.room.imagePath}',
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
