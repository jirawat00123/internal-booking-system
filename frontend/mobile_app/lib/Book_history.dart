import 'package:flutter/foundation.dart'
    show kIsWeb; // เพิ่ม kIsWeb สำหรับตรวจสอบ Platform
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'Room_model.dart'; // ดึง globalBookingHistory มาใช้งาน

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({Key? key}) : super(key: key);

  @override
  _BookingHistoryScreenState createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  String selectedTab = 'ทั้งหมด'; // แท็บเริ่มต้น
  bool isLoading = true; // State สำหรับเช็กสถานะการโหลดข้อมูล

  @override
  void initState() {
    super.initState();
    fetchHistory(); // สั่งโหลดข้อมูลใหม่ทุกครั้งที่เปิดหน้านี้
  }

  // =========================================================
  // 💡 ฟังก์ชันดึง Token จาก SharedPreferences
  // =========================================================
  Future<String> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // =========================================================
  // 💡 ฟังก์ชันดึงประวัติการจองจาก API
  // =========================================================
  Future<void> fetchHistory() async {
    try {
      setState(() {
        isLoading = true;
      });

      String rawToken = await getSavedToken();
      String cleanToken = rawToken.trim();

      // ปรับ Base URL อัตโนมัติและแก้ Port เป็น 3001 ให้ตรงกับ Backend
      final String baseUrl = kIsWeb
          ? 'http://localhost:3001'
          : 'http://10.0.2.2:3001';

      final response = await http.get(
        Uri.parse('$baseUrl/api/bookings?page=1&limit=50'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> bookings = data['bookings'];

        List<BookingHistory> fetchedList = bookings.map((item) {
          DateTime start = DateTime.parse(item['startDatetime']).toLocal();
          DateTime end = DateTime.parse(item['endDatetime']).toLocal();

          return BookingHistory(
            id: item['id'], // 💡 ดึง ID กลับมา เพื่อใช้ในการยกเลิกการจอง
            status: item['status'], // 💡 ดึง Status จริงจาก Backend
            type: 'ห้องประชุม',
            roomId: item['roomId'].toString(),
            title:
                item['title'] ??
                item['purpose'] ??
                'ไม่มีหัวข้อ', // 💡 เผื่อกรณีใช้ key title หรือ purpose
            date:
                '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}',
            startTime: TimeOfDay(hour: start.hour, minute: start.minute),
            endTime: TimeOfDay(hour: end.hour, minute: end.minute),
            bookedBy: item['user']?['employee']?['firstName'] ?? 'ไม่ระบุชื่อ',
            participantCount: 0,
          );
        }).toList();

        globalBookingHistory.value = fetchedList;
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004AAD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ประวัติและสถานะ',
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
          _buildTabSelection(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF004AAD)),
                  )
                : ValueListenableBuilder<List<BookingHistory>>(
                    valueListenable: globalBookingHistory,
                    builder: (context, historyList, child) {
                      // 🔥 [แก้ไขจุดนี้] หาเวลาเที่ยงคืนของวันนี้ เพื่อเช็กรายการที่เป็นวันเก่า
                      final now = DateTime.now();
                      final todayMidnight = DateTime(
                        now.year,
                        now.month,
                        now.day,
                      ); // 💡 แก้จาก date.day เป็น now.day

                      // 1. กรองรายการที่ 'เสร็จสิ้น' หรือ 'ยกเลิกแล้ว' ของวันเก่าออกไป (หลังผ่านเที่ยงคืน)
                      List<BookingHistory> validTimeList = historyList.where((
                        item,
                      ) {
                        try {
                          // แยกสตริงวันที่ของการ์ด (เช่น "03/07/2026")
                          List<String> dateParts = item.date.split('/');
                          int day = int.parse(dateParts[0]);
                          int month = int.parse(dateParts[1]);
                          int year = int.parse(dateParts[2]);

                          final bookingDate = DateTime(year, month, day);

                          // 💡 เงื่อนไข: ถ้าผ่านเที่ยงคืนไปแล้ว (เป็นวันเก่า) และสถานะคือเสร็จสิ้น/ยกเลิกแล้ว จะไม่นำมาแสดง
                          if ((item.currentStatus == 'เสร็จสิ้น' ||
                                  item.currentStatus == 'ยกเลิกแล้ว') &&
                              bookingDate.isBefore(todayMidnight)) {
                            return false;
                          }
                        } catch (_) {}
                        return true; // แสดงรายการของวันนี้ หรือรายการที่สถานะยังไม่จบตามปกติ
                      }).toList();

                      // 2. นำข้อมูลที่คัดเรื่องเที่ยงคืนออกแล้ว มาแยกตามแท็บคัดกรองต่อ
                      List<BookingHistory> filteredList = [];

                      if (selectedTab == 'ทั้งหมด') {
                        filteredList = validTimeList;
                      } else {
                        filteredList = validTimeList
                            .where((item) => item.type == selectedTab)
                            .toList();
                      }

                      if (filteredList.isEmpty) {
                        return Center(
                          child: Text(
                            'ไม่มีประวัติการจองในหมวด $selectedTab',
                            style: const TextStyle(
                              fontFamily: 'Kanit',
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final booking = filteredList[index];
                          return _buildHistoryCard(booking, index);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTabButton('ทั้งหมด', Icons.all_inclusive),
          _buildTabButton('ห้องประชุม', Icons.meeting_room_outlined),
          _buildTabButton('จองรถ', Icons.directions_car_filled_outlined),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon) {
    bool isSelected = selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.blueGrey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blueGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Kanit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BookingHistory booking, int index) {
    String statusText = booking.currentStatus;

    Color statusColor = const Color(0xFFFFEAD2); // ส้มอ่อน
    Color statusTextColor = const Color(0xFFFF9F43); // จองแล้ว

    if (statusText == 'กำลังใช้งาน') {
      statusColor = const Color(0xFFD6E4FF); // ฟ้าอ่อน
      statusTextColor = const Color(0xFF1890FF);
    } else if (statusText == 'เสร็จสิ้น') {
      statusColor = const Color(0xFFF5F5F5); // เทาอ่อน
      statusTextColor = const Color(0xFF8C8C8C);
    } else if (statusText == 'ยกเลิกแล้ว') {
      statusColor = const Color(0xFFFFD6D6); // แดงอ่อน
      statusTextColor = const Color(0xFFFF4D4F);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: Icon(
                    booking.type == 'ห้องประชุม'
                        ? Icons.meeting_room
                        : Icons.directions_car,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.type == 'ห้องประชุม'
                          ? 'Meeting Room ${booking.roomId}'
                          : booking.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          booking.date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                const Text(
                  'เวลาการจอง',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                    fontFamily: 'Kanit',
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatTime(booking.startTime)} - ${_formatTime(booking.endTime)} น.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004AAD),
                    fontFamily: 'Kanit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showDetailsDialog(context, booking),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'ดูรายละเอียด',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  ),

                  // 💡 ปุ่มยกเลิกคิว (โชว์เฉพาะเมื่อสถานะคำนวณได้เป็น "จองแล้ว" เท่านั้น)
                  if (statusText == 'จองแล้ว') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // 🔥 [แก้ไข] เปลี่ยนสเตตัสบนวัตถุตรง ๆ ในแรมโดยไม่ต้องใช้ ID
                          setState(() {
                            booking.status = 'ยกเลิกแล้ว';
                            globalBookingHistory.value =
                                List<BookingHistory>.from(
                                  globalBookingHistory.value,
                                );
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'ยกเลิกคิว',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Kanit',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // 💡 ปุ่ม "คืนห้องก่อนเวลา" (โชว์เพิ่มเต็มแถวด้านล่างเมื่อสถานะเป็น "กำลังใช้งาน")
              if (statusText == 'กำลังใช้งาน') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      // 🔥 [แก้ไข] กดยกเลิกสัญญาก่อนกำหนดขณะกำลังใช้งาน -> ปรับไปเป็นสถานะเสร็จสิ้นทันที
                      setState(() {
                        booking.status = 'เสร็จสิ้น';
                        globalBookingHistory.value = List<BookingHistory>.from(
                          globalBookingHistory.value,
                        );
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0096C7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'คืนห้องก่อนเวลา',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 💡 ฟังก์ชันสร้างป็อปอัพรายละเอียดการจอง
  // =========================================================
  void _showDetailsDialog(BuildContext context, BookingHistory booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          contentPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          backgroundColor: Colors.white,
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(
                  child: Text(
                    'รายละเอียดประวัติ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontFamily: 'Kanit',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF004AAD).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.groups_outlined,
                        color: Color(0xFF004AAD),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      booking.type == 'ห้องประชุม'
                          ? 'Meeting Room ${booking.roomId}'
                          : booking.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildPopupRow(
                        'สถานะ',
                        booking.currentStatus,
                        isStatus: true,
                      ),
                      const SizedBox(height: 10),
                      _buildPopupRow('วันที่', booking.date),
                      const SizedBox(height: 10),
                      _buildPopupRow(
                        'เวลา',
                        '${_formatTime(booking.startTime)} - ${_formatTime(booking.endTime)}',
                      ),
                      const SizedBox(height: 10),
                      _buildPopupRow('ผู้ทำรายการ', booking.bookedBy),
                      const SizedBox(height: 10),
                      _buildPopupRow(
                        'จำนวนคน',
                        '${booking.participantCount} คน',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ข้อมูลเพิ่มเติม',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildPopupRow(
                        'หัวข้อประชุม',
                        booking.type == 'ห้องประชุม' ? booking.title : '-',
                      ),
                      const SizedBox(height: 10),
                      _buildPopupRow('ลิงก์ออนไลน์', '-'),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A8CC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ปิดหน้าต่าง',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
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

  Widget _buildPopupRow(String label, String value, {bool isStatus = false}) {
    Color bgStatusColor = const Color(0xFFFFEAD2);
    Color textStatusColor = const Color(0xFFFF9F43);

    if (value == 'กำลังใช้งาน') {
      bgStatusColor = const Color(0xFFD6E4FF);
      textStatusColor = const Color(0xFF1890FF);
    } else if (value == 'เสร็จสิ้น') {
      bgStatusColor = const Color(0xFFF5F5F5);
      textStatusColor = const Color(0xFF8C8C8C);
    } else if (value == 'ยกเลิกแล้ว') {
      bgStatusColor = const Color(0xFFFFD6D6);
      textStatusColor = const Color(0xFFFF4D4F);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontFamily: 'Kanit',
          ),
        ),
        isStatus
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bgStatusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: textStatusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
              )
            : Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Kanit',
                ),
              ),
      ],
    );
  }
}
