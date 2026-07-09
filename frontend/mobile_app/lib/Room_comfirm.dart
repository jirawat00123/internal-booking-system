import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Room_Completed.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RoomConfirmScreen extends StatelessWidget {
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
          // ส่วนแสดงสถานะ Step ด้านบน (ขยับมาไฮไลต์เต็มที่ Step 3 ยืนยัน)
          _buildStepIndicator(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 30.0,
              ),
              child: Column(
                children: [
                  // ตัวตั๋ว/Receipt ยืนยันข้อมูลการจอง
                  _buildConfirmTicketCard(),
                  const SizedBox(height: 40),

                  // ปุ่มยืนยันการจองห้อง
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A8CC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                        ),
                        elevation: 4,
                        shadowColor: Colors.black26,
                      ),
                      onPressed: () async {
                        try {
                          // จัดการ Base URL อัตโนมัติระหว่าง Web กับ Emulator
                          final String baseUrl = kIsWeb
                              ? 'http://localhost:3001'
                              : 'http://10.0.2.2:3001';
                          final String jwtToken =
                              globalToken; // TODO: นำ Token ที่ได้จากการ Login มาใส่ที่นี่

                          // แปลงรูปแบบวันที่จาก DD/MM/YYYY เป็น YYYY-MM-DD สำหรับส่งให้ Database
                          final dateParts = formattedDate.split('/');
                          final formattedForApi = dateParts.length == 3
                              ? '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}'
                              : formattedDate;

                          final String startDateTimeStr =
                              '$formattedForApi ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                          final String endDateTimeStr =
                              '$formattedForApi ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                          final response = await http.post(
                            Uri.parse('$baseUrl/api/bookings'),
                            headers: {
                              // 💡 ต้องบอก Backend ว่าข้อมูลใน body เป็น JSON
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer $jwtToken',
                            },
                            body: jsonEncode({
                              "roomId": int.parse(room.id.toString()),
                              "title": bookingTitle.trim().isEmpty
                                  ? 'ประชุมงานทั่วไป'
                                  : bookingTitle,
                              "startDatetime": startDateTimeStr,
                              "endDatetime": endDateTimeStr,
                            }),
                          );

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
                            // 🔥 [สิ่งที่เปลี่ยนไป]: เพิ่มบล็อกสำหรับจัดการ Error 409 (เวลาทับซ้อน) โดยเฉพาะ
                            if (context.mounted) {
                              String errorMessage =
                                  'ไม่สามารถจองได้ เนื่องจากมีการจองในช่วงเวลานี้แล้ว';
                              try {
                                // พยายามดึงข้อความแจ้งเตือนที่เจาะจงจาก Backend
                                final errorData = jsonDecode(response.body);
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
                                  ), // สีแดงแจ้งเตือน
                                  behavior: SnackBarBehavior
                                      .floating, // ให้แสดงแบบลอย ไม่ติดขอบล่าง
                                  margin: const EdgeInsets.all(20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  duration: const Duration(
                                    seconds: 4,
                                  ), // ค้างไว้ 4 วินาทีให้อ่านทัน
                                ),
                              );
                            }
                          } else {
                            // 💡 Error อื่นๆ ที่ไม่ใช่ 409 (เช่น 400, 500)
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'จองไม่สำเร็จ รหัส: ${response.statusCode}',
                                    style: const TextStyle(fontFamily: 'Kanit'),
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
                                  'เกิดข้อผิดพลาด: $e',
                                  style: const TextStyle(fontFamily: 'Kanit'),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
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
          // ส่วนบน: รูปภาพห้องประชุมพร้อมข้อความ Overlay
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
                  child: room.imagePath != null
                      ? (kIsWeb || room.imagePath!.startsWith('/')
                            ? Image.network(
                                room.imagePath!.startsWith('http')
                                    ? room.imagePath!
                                    : '${kIsWeb ? "http://localhost:3001" : "http://10.0.2.2:3001"}${room.imagePath}',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                              )
                            : Image.file(
                                File(room.imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                              ))
                      : const Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
              // แผ่นฟิล์มสีมืดจาง ๆ บังรูปเพื่อให้ตัวหนังสือเด่นชัดขึ้นแบบดีไซน์
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
              // ข้อความระบุชั้น และชื่อห้อง บนรูปภาพ
              Positioned(
                left: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ห้องประชุม ${room.location}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.roomName,
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

          // เส้นประคั่นกลางตั๋วแบบดีไซน์ (Ticket Dash Divider)
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

          // ส่วนล่าง: รายละเอียดข้อมูลที่ User กรอกเข้ามา
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
                  // 💡 ดึงค่าจากหน้าฟอร์มที่กรอกส่งมา: ถ้าค่าว่างให้แสดง 'ประชุมงานทั่วไป' แต่ถ้ากรอกมาจะแสดงตามที่พิมพ์เป๊ะๆ
                  bookingTitle.trim().isEmpty
                      ? 'ประชุมงานทั่วไป'
                      : bookingTitle,
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
                      'ตำแหน่ง : ${room.location}',
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
                            formattedDate,
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
                            formattedTime,
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
                  '$participantCount ท่าน',
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
