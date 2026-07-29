import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Room_comfirm.dart';
import '../Book_history.dart';

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

  late DateTime selectedDate;
  TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 12, minute: 0);
  late int participantCount;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    participantCount = widget.room.capacity < 4 ? widget.room.capacity : 4;
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Future<bool> _checkTimeSlotAvailability() async {
    try {
      final String baseUrl = kIsWeb
          ? 'http://localhost:3001'
          : 'http://10.0.2.2:3001';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

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

        for (var schedule in schedules) {
          DateTime existingStartTime = DateTime.parse(
            schedule['startDatetime'],
          ).toLocal();
          DateTime existingEndTime = DateTime.parse(
            schedule['endDatetime'],
          ).toLocal();

          if (existingStartTime.year == selectedDate.year &&
              existingStartTime.month == selectedDate.month &&
              existingStartTime.day == selectedDate.day) {
            final int existingStart = _timeToMinutes(
              TimeOfDay.fromDateTime(existingStartTime),
            );
            final int existingEnd = _timeToMinutes(
              TimeOfDay.fromDateTime(existingEndTime),
            );

            if (newStart < existingEnd && newEnd > existingStart) {
              return true; 
            }
          }
        }
        return false; 
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
      rethrow; 
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); 
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: today, 
      lastDate: today.add(const Duration(days: 365 * 2)), 
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (!mounted) return; 
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
    if (!mounted) return; 
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004381),
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
          
          // 🟢 แถบสีน้ำเงินหัวข้อ
          Container(
            width: double.infinity,
            color: const Color(0xFF004381),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Text(
              'กรอกข้อมูลการจอง',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
          ),

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
                                    if (value == true) {
                                      Navigator.pop(context, true);
                                    }
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

  // 🟢 ฟังก์ชันสร้าง Step รูปแบบใหม่
  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepItem(step: '1', title: 'เลือกห้อง', isActive: false),
          _buildStepLine(),
          _buildStepItem(step: '2', title: 'กรอกข้อมูล', isActive: true),
          _buildStepLine(),
          _buildStepItem(step: '3', title: 'ยืนยัน', isActive: false),
        ],
      ),
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