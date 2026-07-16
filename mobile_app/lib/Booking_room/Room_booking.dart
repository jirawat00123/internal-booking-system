import 'dart:convert'; // 💡 เพิ่มสำหรับจัดการ JSON
import 'package:http/http.dart' as http; // 💡 เพิ่มสำหรับยิง API
import 'package:shared_preferences/shared_preferences.dart'; // 💡 เพิ่มสำหรับดึง Token
import 'package:flutter/foundation.dart'
    show kIsWeb; // 💡 เพิ่มสำหรับเช็ค Platform

import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Room_comfirm.dart';
import '../Book_history.dart'; // ใส่ชื่อไฟล์ที่เป็นตัวจริงของ globalBookingHistory

class RoomBookingAScreen extends StatefulWidget {
  final MeetingRoom room;

  const RoomBookingAScreen({Key? key, required this.room}) : super(key: key);

  @override
  _RoomBookingAScreenState createState() => _RoomBookingAScreenState();
}

class _RoomBookingAScreenState extends State<RoomBookingAScreen> {
  final TextEditingController titleController = TextEditingController();
  bool showWarning = false;
  bool isLoading = false;

  // 💡 [แก้ไข] เปลี่ยนจาก DateTime(2026, 5, 27) ตายตัว ให้เริ่มต้นเป็นวันที่ปัจจุบัน ณ ตอนที่เปิดจองแทน
  late DateTime selectedDate;
  TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 12, minute: 0);
  late int participantCount; // เปลี่ยนมาใช้ late เพื่อกำหนดค่าใน initState

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // ตัดเวลาทิ้ง เหลือเพียง ปี-เดือน-วัน ปัจจุบัน
    selectedDate = DateTime(now.year, now.month, now.day);
    // ป้องกันผู้ใช้เริ่มต้นด้วยจำนวนคนที่เกินความจุห้อง
    participantCount = widget.room.capacity < 4 ? widget.room.capacity : 4;
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  // 💡 [แก้ไข] ปรับเปลี่ยนฟอร์แมตโครงสร้างวันที่ให้เป็น วัน/เดือน/ปี (DD/MM/YYYY) ตามปกติ
  String _formatDate(DateTime date) {
    // ปรับเป็น วัน/เดือน/ปี (DD/MM/YYYY)
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // 💡 ฟังก์ชันแปลง TimeOfDay เป็นนาทีทั้งหมด เพื่อให้ง่ายต่อการคำนวณเปรียบเทียบเลขคณิต
  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  // 💡 ฟังก์ชันตรวจสอบเวลาจองทับซ้อน
  // 💡 ฟังก์ชันตรวจสอบเวลาจองทับซ้อน (เวอร์ชันอัปเดตเพื่อคืนสิทธิ์เวลาที่เสร็จสิ้น/ยกเลิก)
  // 💡 ฟังก์ชันตรวจสอบเวลาจองทับซ้อนแบบ Real-time จาก Backend!
  Future<bool> _checkTimeSlotAvailability() async {
    try {
      final String baseUrl = kIsWeb
          ? 'http://localhost:3001'
          : 'http://10.0.2.2:3001';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // [EVIDENCE_FLUTTER] 1. ตรวจสอบค่า Token ดิบที่อ่านขึ้นมาจาก SharedPreferences ในหน่วยความจำ
      debugPrint(
        '[EVIDENCE_FLUTTER] Token value from SharedPreferences: "$token" (Length: ${token.length})',
      );

      // [EVIDENCE_FLUTTER] 2. ตรวจสอบโครงสร้างข้อความสตริงเต็มที่จะถูกใส่ในช่อง Authorization Header
      debugPrint(
        '[EVIDENCE_FLUTTER] Full Generated Authorization Header: "Bearer $token"',
      );

      // ยิงไปที่ API ใหม่ที่เราเพิ่งสร้าง เพื่อดึงคิวของห้องนี้โดยเฉพาะ
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/rooms/${widget.room.id}/schedule'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> schedules = jsonDecode(response.body);

        final int newStart = _timeToMinutes(startTime);
        final int newEnd = _timeToMinutes(endTime);

        // 💡 [LOG 1] ดูว่ารับข้อมูลมาจาก Backend กี่คิว
        print("==================================================");
        print("🔍 กำลังเช็กคิวห้อง ID: ${widget.room.id}");
        print(
          "📅 คุณต้องการจอง: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} เวลา ${_formatTime(startTime)} - ${_formatTime(endTime)}",
        );
        print("📦 พบข้อมูลคิวจาก Backend ทั้งหมด: ${schedules.length} คิว");

        for (var schedule in schedules) {
          // ✅ ดึงจาก key startDatetime / endDatetime ให้ตรงกับ API
          DateTime existingStartTime = DateTime.parse(
            schedule['startDatetime'],
          ).toLocal();
          DateTime existingEndTime = DateTime.parse(
            schedule['endDatetime'],
          ).toLocal();

          // 💡 [LOG 2] ปริ้นท์ข้อมูลที่ดึงมาเช็กทุกคิว
          print(
            "   -> คิวในระบบ: วันที่ ${existingStartTime.day}/${existingStartTime.month}/${existingStartTime.year} | เวลา ${_formatTime(TimeOfDay.fromDateTime(existingStartTime))} - ${_formatTime(TimeOfDay.fromDateTime(existingEndTime))}",
          );

          // เช็คเฉพาะคิวของ "วันเดียวกัน" ที่ผู้ใช้กำลังจะจอง
          if (existingStartTime.year == selectedDate.year &&
              existingStartTime.month == selectedDate.month &&
              existingStartTime.day == selectedDate.day) {
            final int existingStart = _timeToMinutes(
              TimeOfDay.fromDateTime(existingStartTime),
            );
            final int existingEnd = _timeToMinutes(
              TimeOfDay.fromDateTime(existingEndTime),
            );

            // สูตรคำนวณหาจุดคาบเกี่ยวของเวลา
            if (newStart < existingEnd && newEnd > existingStart) {
              // 💡 [LOG 3] ปริ้นท์บอกถ้าเกิดการชนกัน
              print("❌ [สรุป] จองไม่ได้! เวลาชนกับคิวด้านบนนี้ครับ!");
              print("==================================================");
              return true; // ❌ เวลาทับซ้อนกัน! มีคนจองตัดหน้าไปแล้ว
            }
          }
        }

        // 💡 [LOG 4] ปริ้นท์บอกถ้าผ่านฉลุย
        // 💡 [LOG 4] ปริ้นท์บอกถ้าผ่านฉลุย
        print("✅ [สรุป] ห้องว่าง! สามารถผ่านไปหน้ายืนยันได้");
        print("==================================================");
        return false; // ✅ เวลาว่างพร้อมจองฉลุย
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'บัญชีนี้ถูกเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
        throw Exception('401 Unauthorized');
      } else {
        throw Exception('Failed to fetch schedule');
      }
    } catch (e) {
      print("🚨 เกิด Error ในการดึง API: $e");
      rethrow; // โยน Error ไปให้ปุ่มกดยอมรับ
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    ); // 💡 วันที่ปัจจุบันแบบไม่มีเศษเวลา
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: today, // 💡 ป้องกัน Crash จาก Assertion Error
      lastDate: today.add(
        const Duration(days: 365 * 2),
      ), // จองล่วงหน้าได้สูงสุด 2 ปี
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (!mounted) return; // 💡 เพิ่มบรรทัดนี้
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? startTime : endTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (!mounted) return; // 💡 เพิ่มบรรทัดนี้
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

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
                  _buildBookingFormCard(),
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
                      // 💡 ล็อกปุ่มไว้ถ้า isLoading เป็น true เพื่อไม่ให้กดย้ำ
                      onPressed: isLoading
                          ? null
                          : () async {
                              FocusScope.of(context).unfocus();

                              if (titleController.text.trim().isEmpty) {
                                setState(() => showWarning = true);
                                return;
                              }

                              final now = DateTime.now();
                              final startDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                startTime.hour,
                                startTime.minute,
                              );
                              final endDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                endTime.hour,
                                endTime.minute,
                              );

                              if (startDateTime.isBefore(
                                now.subtract(const Duration(minutes: 10)),
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'ไม่สามารถจองเวลาย้อนหลังได้',
                                      style: TextStyle(fontFamily: 'Kanit'),
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              if (endDateTime.isBefore(startDateTime) ||
                                  endDateTime.isAtSameMomentAs(startDateTime)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'เวลาเริ่มจองต้องอยู่ก่อนเวลาสิ้นสุด',
                                      style: TextStyle(fontFamily: 'Kanit'),
                                    ),
                                    backgroundColor: Color(0xFFB70000),
                                  ),
                                );
                                return;
                              }

                              // 🟢 เริ่มต้นกระบวนการ Re-validation เช็ค API
                              setState(() => isLoading = true);

                              try {
                                bool isOverlapping =
                                    await _checkTimeSlotAvailability();

                                if (!mounted) return;

                                if (isOverlapping) {
                                  setState(() => isLoading = false);
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Row(
                                        children: [
                                          Icon(
                                            Icons.lock_clock,
                                            color: Color(0xFFE11D48),
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            // 💡 นำ Expanded มาครอบไว้เช่นกัน
                                            child: Text(
                                              'เวลานี้ถูกจองแล้ว',
                                              style: TextStyle(
                                                fontFamily: 'Kanit',
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Text(
                                        'ขออภัย ช่วงเวลา ${_formatTime(startTime)} - ${_formatTime(endTime)} ของวันที่ ${_formatDate(selectedDate)} มีผู้ใช้งานอื่นจองตัดหน้าไปเมื่อสักครู่ กรุณาเลือกช่วงเวลาอื่น',
                                        style: const TextStyle(
                                          fontFamily: 'Kanit',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text(
                                            'ตกลง',
                                            style: TextStyle(
                                              fontFamily: 'Kanit',
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF004AAD),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  // ✅ ห้องว่างชัวร์! พาไปหน้า Confirm ได้
                                  setState(() {
                                    showWarning = false;
                                    isLoading = false;
                                  });

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RoomConfirmScreen(
                                        room: widget.room,
                                        bookingTitle: titleController.text
                                            .trim(),
                                        formattedDate: _formatDate(
                                          selectedDate,
                                        ),
                                        formattedTime:
                                            '${_formatTime(startTime)} - ${_formatTime(endTime)}',
                                        participantCount: participantCount,
                                        startTime: startTime,
                                        endTime: endTime,
                                      ),
                                    ),
                                  ).then((value) {
                                    if (!mounted) return;
                                    if (value == true)
                                      Navigator.pop(context, true);
                                  });
                                }
                              } catch (e) {
                                if (!mounted) return;
                                setState(() => isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'เกิดข้อผิดพลาดในการตรวจสอบสถานะห้อง กรุณาลองใหม่',
                                      style: TextStyle(fontFamily: 'Kanit'),
                                    ),
                                  ),
                                );
                              }
                            },
                      // 💡 child มีแค่ตัวเดียวตรงนี้ครับ
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'ต่อไป',
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
              isActive: true,
              isCompleted: false,
            ),
            _buildStepLine(isCompleted: false),
            _buildStepCircle(
              '3',
              'ยืนยัน',
              isActive: false,
              isCompleted: false,
            ),
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

  Widget _buildBookingFormCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
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
          if (showWarning) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDCDD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFA3A6)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE11D48),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    // 💡 นำ Expanded มาครอบ Text ไว้เพื่อป้องกันการล้นขอบ
                    child: Text(
                      'กรุณากรอกข้อมูลให้ครบถ้วน',
                      style: TextStyle(
                        color: Color(0xFFE11D48),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: const Color(0xFF004AAD).withOpacity(0.7),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'ข้อมูลการประชุม',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Kanit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          Row(
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
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFE11D48),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            maxLines: 1,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              hintText: 'เช่น ประชุมสรุปโปรเจกต์',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Kanit',
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: showWarning
                      ? const Color(0xFFFFA3A6)
                      : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: showWarning
                      ? const Color(0xFFE11D48)
                      : const Color(0xFF00A8CC),
                ),
              ),
            ),
            style: const TextStyle(fontSize: 15, fontFamily: 'Kanit'),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(color: Color(0xFFE2E8F0)),
          ),

          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: const Color(0xFF004AAD).withOpacity(0.7),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'ระบุวันและเวลา',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Kanit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          const Text(
            'วันที่',
            style: TextStyle(
              color: Color(0xFF9BB1BD),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 8),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(selectedDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      fontFamily: 'Kanit',
                    ),
                  ),
                  const Icon(
                    Icons.calendar_month,
                    color: Colors.black87,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ตั้งแต่เวลา',
                      style: TextStyle(
                        color: Color(0xFF9BB1BD),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectTime(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _formatTime(startTime),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ถึงเวลา',
                      style: TextStyle(
                        color: Color(0xFF9BB1BD),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectTime(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _formatTime(endTime),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Divider(color: Color(0xFFE2E8F0)),
          ),

          const Center(
            child: Text(
              'จำนวนผู้เข้าร่วม (คน)',
              style: TextStyle(
                color: Color(0xFF9BB1BD),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.remove,
                      color: Colors.blueGrey,
                      size: 16,
                    ),
                    onPressed: () {
                      if (participantCount > 1) {
                        setState(() => participantCount--);
                      }
                    },
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      color: Color(0xFF9BB1BD),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$participantCount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.add,
                      color: Color(0xFF00A8CC),
                      size: 16,
                    ),
                    onPressed: () {
                      if (participantCount < widget.room.capacity) {
                        setState(() => participantCount++);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'ห้องนี้รองรับได้สูงสุด ${widget.room.capacity} ท่าน',
                            ),
                          ),
                        );
                      }
                    },
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
