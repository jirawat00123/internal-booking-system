import 'dart:io';
import 'dart:convert'; // 💡 เพิ่มสำหรับ JSON
import 'package:http/http.dart' as http; // 💡 เพิ่มสำหรับเรียก API
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Room_completed.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoomConfirmScreen extends StatelessWidget {
  final MeetingRoom room;
  final String bookingTitle;
  final String formattedDate;
  final String formattedTime;
  final int participantCount;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int userId; // 💡 เพิ่มตัวแปร userId


  const RoomConfirmScreen({
    Key? key,
    required this.room,
    required this.bookingTitle,
    required this.formattedDate,
    required this.formattedTime,
    required this.participantCount,
    required this.startTime,
    required this.endTime,
    required this.userId,
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
          onPressed: () => Navigator.pop(context),
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
                        // 💡 1. แปลงรูปแบบวันที่ให้ตรงกับระบบฐานข้อมูล
                        List<String> dateParts = formattedDate.split('/');
                        int day = int.parse(dateParts[0]);
                        int month = int.parse(dateParts[1]);
                        int year = int.parse(dateParts[2]);
                        
                        DateTime startDt = DateTime(year, month, day, startTime.hour, startTime.minute);
                        DateTime endDt = DateTime(year, month, day, endTime.hour, endTime.minute);

                        showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                        try {
                          final prefs = await SharedPreferences.getInstance();
                        String token = prefs.getString('token') ?? '';

                       

                          if (token.isEmpty) {
                            // ดักจับกรณีไม่มี Token
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนใช้งาน (No Token)')),
                            );
                            return;
                          }
                          // 💡 2. ส่งข้อมูลไปที่ API
                          final response = await http.post(
                            Uri.parse('http://localhost:3001/api/bookings'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': 'Bearer $token',
                            },
                          
                            body: jsonEncode({
                              "roomId": int.parse(room.id),
                              "startDatetime": startDt.toIso8601String(),
                              "endDatetime": endDt.toIso8601String(),
                              "title": bookingTitle,
                              "userId": userId,
                              
                            }),
                          );

                          Navigator.pop(context); // ปิดหน้า Loading

                          if (response.statusCode == 201) {
                            // 🚀 บันทึกเสร็จ ไปหน้าสำเร็จ
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const RoomCompletedScreen()),
                              (route) => route.isFirst,
                            );
                          } else {
                            final errorMsg = jsonDecode(response.body)['message'] ?? 'เกิดข้อผิดพลาดในการจอง';
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(errorMsg, style: const TextStyle(fontFamily: 'Kanit')), 
                              backgroundColor: Colors.red
                            ));
                          }
                        } catch (e) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('ไม่สามารถติดต่อเซิร์ฟเวอร์ได้', style: TextStyle(fontFamily: 'Kanit')), 
                            backgroundColor: Colors.red
                          ));
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
            _buildStepCircle('1', 'เลือกห้อง', isActive: false, isCompleted: true),
            _buildStepLine(isCompleted: true),
            _buildStepCircle('2', 'กรอกข้อมูล', isActive: false, isCompleted: true),
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
                  child: room.imagePath != null
                      ? (room.imagePath!.startsWith('http')
                          ? Image.network(room.imagePath!, fit: BoxFit.cover)
                          : (kIsWeb
                              ? Image.network(room.imagePath!, fit: BoxFit.cover)
                              : Image.file(
                                  File(room.imagePath!),
                                  fit: BoxFit.cover,
                                )))
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
                      'ห้องประชุมชั้น ${room.location}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Meeting Room ${room.id}',
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
                      'ชั้น ${room.location} ฝั่ง ${room.side}',
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