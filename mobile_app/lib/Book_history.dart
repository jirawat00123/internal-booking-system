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
  bool isLoading = true; // 💡 เพิ่ม State สำหรับเช็กสถานะการโหลดข้อมูล

  @override
  void initState() {
    super.initState();
    fetchHistory(); // 💡 สั่งโหลดข้อมูลใหม่ทุกครั้งที่เปิดหน้านี้
  }

  // =========================================================
  // 💡 ฟังก์ชันจำลองดึง Token จาก SharedPreferences (แก้ให้ใช้งานได้จริง)
  // =========================================================
  Future<String> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ??
        ''; // เปลี่ยน 'token' เป็น key จริงของคุณ
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
      String cleanToken = rawToken.trim(); // ล้างช่องว่างป้องกัน API แครช

      final response = await http.get(
        Uri.parse('http://localhost:3000/api/bookings?page=1&limit=50'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> bookings = data['bookings'];

        // 💡 แมปปิ้ง (Mapping) ข้อมูลจาก JSON เป็น Object ของคุณ
        List<BookingHistory> fetchedList = bookings.map((item) {
          DateTime start = DateTime.parse(item['startDatetime']).toLocal();
          DateTime end = DateTime.parse(item['endDatetime']).toLocal();

          return BookingHistory(
            // id: item['id'], // ⚠️ ถ้า Room_model.dart ของคุณมีตัวแปร id ให้ปลดคอมเมนต์ตรงนี้
            type: 'ห้องประชุม',
            roomId: item['roomId'].toString(),
            title: item['purpose'] ?? 'ไม่มีหัวข้อ',
            date:
                '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}',
            startTime: TimeOfDay(hour: start.hour, minute: start.minute),
            endTime: TimeOfDay(hour: end.hour, minute: end.minute),
            bookedBy: item['user']?['employee']?['firstName'] ?? 'ไม่ระบุชื่อ',
            participantCount: 0, // ใส่ค่าเริ่มต้นไปก่อน หรือดึงจาก item ถ้ามี
          );
        }).toList();

        // 💡 อัปเดตข้อมูลที่ดึงมาใหม่ลง global state ของคุณ
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

  // =========================================================
  // 💡 ฟังก์ชันยกเลิกการจองผ่าน API
  // =========================================================
  Future<void> cancelBooking(BookingHistory booking) async {
    try {
      String rawToken = await getSavedToken();
      String cleanToken = rawToken.trim();

      // ⚠️ จำเป็นต้องใช้ ID ของการจอง (สมมติว่าคลาส BookingHistory ของคุณมี .id)
      // หากไม่มี .id ให้ทำการเพิ่มใน Room_model.dart ก่อนใช้งานบรรทัดนี้นะครับ
      // int bookingId = booking.id;
      int bookingId = 2; // ฮาร์ดโค้ดเป็น 2 ชั่วคราวตามแบบทดสอบใน Postman ของคุณ

      final response = await http.patch(
        Uri.parse('http://localhost:3000/api/bookings/$bookingId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $cleanToken',
        },
      );

      if (response.statusCode == 200) {
        // อัปเดต UI ทันทีเมื่อ API คืนค่า 200 Success
        setState(() {
          final currentList = List<BookingHistory>.from(
            globalBookingHistory.value,
          );
          currentList.remove(booking);
          globalBookingHistory.value = currentList;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ยกเลิกการจองสำเร็จ',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถยกเลิกการจองได้',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error cancelling booking: $e");
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
          // กลุ่มแท็บคัดกรองข้อมูลด้านบน
          _buildTabSelection(),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF004AAD),
                    ), // 💡 แสดงตัวโหลดระหว่างรอ API
                  )
                : ValueListenableBuilder<List<BookingHistory>>(
                    valueListenable: globalBookingHistory,
                    builder: (context, historyList, child) {
                      // กรองข้อมูลตามแท็บที่เลือก
                      List<BookingHistory> filteredList = [];

                      if (selectedTab == 'ทั้งหมด') {
                        filteredList = historyList;
                      } else {
                        filteredList = historyList
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
    String statusText = 'จองแล้ว';
    Color statusColor = const Color(0xFFFFEAD2);
    Color statusTextColor = const Color(0xFFFF9F43);

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

          Row(
            children: [
              // ปุ่มดูรายละเอียด
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // 💡 เรียกป็อปอัพโชว์รายละเอียดการจองห้อง
                    _showDetailsDialog(context, booking);
                  },
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
              const SizedBox(width: 12),
              // ปุ่มยกเลิกคิว
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // 💡 เรียกใช้ฟังก์ชันยกเลิกคิวแบบยิง API
                    cancelBooking(booking);
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
                      _buildPopupRow('สถานะ', 'จองแล้ว', isStatus: true),
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

  // 💡 แก้ไขฟังก์ชัน _buildPopupRow ให้รองรับข้อความยาว ๆ ไม่ให้ล้นขอบจอ
  Widget _buildPopupRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontFamily: 'Kanit',
          ),
        ),
        const SizedBox(width: 16),

        isStatus
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAD2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'จองแล้ว',
                  style: TextStyle(
                    color: Color(0xFFFF9F43),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
              )
            : Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
      ],
    );
  }
}
