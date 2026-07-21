import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../digitel.dart';

// =========================================================
// 📦 โมเดลประวัติการจอง (ใช้ร่วมกันทั้งจองรถและห้องประชุม)
// =========================================================
class BookingHistoryModel {
  final String id;
  final String type;
  final String title;
  final String date;
  final String endDate;
  final DateTime?
  rawDate; // 💡 เพิ่มฟิลด์นี้เข้ามาเพื่อใช้สำหรับ Midnight Filter และการ Sort
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String bookedBy;
  final String bookerName;
  final int userId;
  final int participantCount;
  String currentStatus;

  final String imageUrl;
  final String plateNumber;
  final String destination;
  final String driverType;

  BookingHistoryModel({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.endDate,
    this.rawDate, // 💡 ใส่เป็นแบบเลือกใส่ได้ (Optional) เพื่อไม่ให้กระทบโค้ดส่วนอื่น
    required this.startTime,
    required this.endTime,
    required this.bookedBy,
    required this.bookerName,
    required this.userId,
    required this.participantCount,
    required this.currentStatus,
    this.imageUrl = '',
    this.plateNumber = '-',
    this.destination = '-',
    this.driverType = '-',
  });
}

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({Key? key}) : super(key: key);

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  String selectedTab = 'ทั้งหมด';
  bool isLoading = true;
  List<BookingHistoryModel> historyList = [];

  // 💡 เพิ่มตัวแปรเก็บสิทธิ์และ ID ของคนที่ Login อยู่
  String userRole = '';
  int currentUserId = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo().then(
      (_) => fetchHistory(),
    ); // 💡 โหลด User Info ก่อนดึง API
  }

  // 💡 โหลดข้อมูลจาก SharedPreferences
  // 💡 โหลดข้อมูลจาก SharedPreferences (แก้ไขป้องกัน Type Mismatch)
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    int loadedUserId = 0;

    // ตรวจสอบประเภทตัวแปรอย่างปลอดภัยก่อนดึงค่า
    if (prefs.containsKey('userId')) {
      dynamic idVal = prefs.get('userId');
      if (idVal is int) {
        loadedUserId = idVal;
      } else if (idVal is String) {
        loadedUserId = int.tryParse(idVal) ?? 0;
      }
    }

    setState(() {
      userRole = prefs.getString('role') ?? 'USER';
      currentUserId = loadedUserId;

      // ถ้าเป็น GUARD บังคับให้แท็บเริ่มต้นเป็น 'จองรถ'
      if (userRole == 'GUARD') {
        selectedTab = 'จองรถ';
      }
    });
  }

  Future<String> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  String _formatThaiDate(DateTime date) {
    const thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${thaiMonths[date.month - 1]} ${date.year + 543}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // =========================================================
  // 📥 ดึงข้อมูลจากฐานข้อมูล (API)
  // =========================================================
  Future<void> fetchHistory() async {
    try {
      setState(() => isLoading = true);
      String token = await getSavedToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final roomResponseFuture = http.get(
        Uri.parse('http://localhost:3001/api/bookings?page=1&limit=50'),
        headers: headers,
      );
      final vehicleResponseFuture = http.get(
        Uri.parse('http://localhost:3001/api/vehicle-bookings?page=1&limit=50'),
        headers: headers,
      );

      final responses = await Future.wait([
        roomResponseFuture,
        vehicleResponseFuture,
      ]);
      List<BookingHistoryModel> fetchedList = [];

      // 1. ดึงห้องประชุม
      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        for (var item in (data['bookings'] ?? [])) {
          DateTime start = DateTime.parse(item['startDatetime']).toLocal();
          DateTime end = DateTime.parse(item['endDatetime']).toLocal();

          String rawStatus = item['status'] ?? 'ถูกจองไว้อยู่';
          if (rawStatus.toLowerCase() == 'pending') rawStatus = 'ถูกจองไว้อยู่';
          // 💡 เติมสถานะของห้องประชุมให้แปลงเป็นภาษาไทย เพื่อให้เงื่อนไขปุ่ม "กำลังใช้งาน" ทำงานได้ถูกต้อง
          if (rawStatus.toLowerCase() == 'approved' ||
              rawStatus.toLowerCase() == 'in_use' ||
              rawStatus.toLowerCase() == 'active')
            rawStatus = 'กำลังใช้งาน';
          if (rawStatus.toLowerCase() == 'completed') rawStatus = 'เสร็จสิ้น';
          if (rawStatus.toLowerCase() == 'cancelled') rawStatus = 'ยกเลิกแล้ว';

          // ค้นหาชื่อ User ของห้องประชุม

          // ค้นหาชื่อ User ของห้องประชุม
          String userName = 'ไม่ระบุชื่อ';
          if (item['user'] != null) {
            userName =
                item['user']['employee']?['fullName'] ??
                item['user']['firstName'] ??
                item['user']['username'] ??
                'ไม่ระบุชื่อ';
          }

          fetchedList.add(
            BookingHistoryModel(
              id: item['id'].toString(),
              type: 'ห้องประชุม',
              title: 'Meeting Room ${item['roomId']}',
              date: _formatThaiDate(start),
              endDate: _formatThaiDate(end),
              startTime: TimeOfDay(hour: start.hour, minute: start.minute),
              endTime: TimeOfDay(hour: end.hour, minute: end.minute),
              bookedBy: userName,
              bookerName: userName,
              // 💡 เพิ่มการแปลง Type เป็น int อย่างปลอดภัย และเผื่อกรณี Backend ส่งมาใน item['user']['id']
              userId:
                  int.tryParse(
                    item['userId']?.toString() ??
                        item['user']?['id']?.toString() ??
                        '0',
                  ) ??
                  0,
              participantCount: 0,
              currentStatus: rawStatus,
            ),
          );
        }
      }

      // 2. ดึงจองรถ
      if (responses[1].statusCode == 200) {
        final data = jsonDecode(responses[1].body);
        List<dynamic> vBookings = data['data'] ?? data['bookings'] ?? [];
        for (var item in vBookings) {
          DateTime start = DateTime.parse(
            item['startDatetime'] ??
                item['startDate'] ??
                DateTime.now().toString(),
          ).toLocal();
          DateTime end = DateTime.parse(
            item['endDatetime'] ?? item['endDate'] ?? DateTime.now().toString(),
          ).toLocal();

          String rawStatus = item['status'] ?? 'ถูกจองไว้อยู่';
          if (rawStatus.toLowerCase() == 'pending') rawStatus = 'ถูกจองไว้อยู่';
          // 💡 เผื่อ Backend ส่งคำว่า active มา
          if (rawStatus.toLowerCase() == 'approved' ||
              rawStatus.toLowerCase() == 'in_use' ||
              rawStatus.toLowerCase() == 'active')
            rawStatus = 'กำลังใช้งาน';
          if (rawStatus.toLowerCase() == 'completed') rawStatus = 'เสร็จสิ้น';
          if (rawStatus.toLowerCase() == 'cancelled') rawStatus = 'ยกเลิกแล้ว';

          // 💡 1. ดึงชื่อผู้ทำรายการจากการจองรถ (ใช้ fullName ตาม Database Schema)
          String userName = 'ไม่ระบุชื่อ';
          if (item['user'] != null) {
            userName = item['user']['employee']?['fullName'] ?? 'ไม่ระบุชื่อ';
          }

          // 💡 2. ดึงจำนวนคน (ใช้ passengers หรือ passengerCount)
          int pCount = 0;
          if (item['passengers'] != null) {
            pCount = int.tryParse(item['passengers'].toString()) ?? 0;
          } else if (item['passengerCount'] != null) {
            pCount = int.tryParse(item['passengerCount'].toString()) ?? 0;
          }

          fetchedList.add(
            BookingHistoryModel(
              id: item['id'].toString(),
              type: 'จองรถ',
              title: item['vehicle']?['vehicleName'] ?? 'ไม่ระบุรุ่นรถ',
              date: _formatThaiDate(start),
              endDate: _formatThaiDate(end),
              startTime: TimeOfDay(hour: start.hour, minute: start.minute),
              endTime: TimeOfDay(hour: end.hour, minute: end.minute),
              bookedBy: userName,
              bookerName: userName,
              // 💡 เพิ่มการแปลง Type เป็น int อย่างปลอดภัย และเผื่อกรณี Backend ส่งมาใน item['user']['id']
              userId:
                  int.tryParse(
                    item['userId']?.toString() ??
                        item['user']?['id']?.toString() ??
                        '0',
                  ) ??
                  0,
              participantCount: pCount,
              currentStatus: rawStatus,
              imageUrl: item['vehicle']?['uploadUrl'] ?? '',
              plateNumber: item['vehicle']?['plateNumber'] ?? '-',
              destination: item['destination'] ?? '-',
              driverType: item['driverType'] ?? 'ขับขี่เอง',
            ),
          );
        }
      }

      // 💡 เรียงลำดับด้วย DateTime จริง จะแม่นยำกว่าการเทียบ String วันที่แบบภาษาไทย
      fetchedList.sort(
        (a, b) => (b.rawDate ?? DateTime.now()).compareTo(
          a.rawDate ?? DateTime.now(),
        ),
      );
      if (mounted)
        setState(() {
          historyList = fetchedList;
          isLoading = false;
        });
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =========================================================
  // 🚀 อัปเดตสถานะไปยังฐานข้อมูล (API)
  // =========================================================
  Future<void> _updateStatus(
    BookingHistoryModel booking,
    String newStatus,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String token = await getSavedToken();
      http.Response response;

      // 💡 เงื่อนไขที่ 1: ถ้าเป็นการ "ยกเลิกรถ"
      if (booking.type == 'จองรถ' &&
          (newStatus == 'Cancelled' || newStatus == 'ยกเลิกแล้ว')) {
        // 🚀 ต้องใช้ API เส้น PATCH และห้อยท้ายด้วย /cancel (ตามโค้ด Node.js ของคุณ)
        String endpoint =
            'http://localhost:3001/api/vehicle-bookings/${booking.id}/cancel';
        response = await http.patch(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          // ไม่ต้องส่ง body แล้ว เพราะ Node.js จัดการเปลี่ยนสถานะให้เองเลย
        );
        newStatus =
            'ยกเลิกแล้ว'; // บังคับเซ็ตค่ากลับเป็นภาษาไทยเพื่อโชว์บนหน้าจอ
      }
      // 💡 เงื่อนไขที่ 2: ถ้าเป็นการอัปเดตสถานะอื่นๆ ของรถ (เช่น คืนรถ)
      else if (booking.type == 'จองรถ') {
        String endpoint =
            'http://localhost:3001/api/vehicle-bookings/${booking.id}';
        response = await http.put(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({"status": newStatus}),
        );
      }
      // 💡 เงื่อนไขที่ 3: สำหรับระบบจองห้องประชุม
      else {
        String endpoint = 'http://localhost:3001/api/bookings/${booking.id}';
        response = await http.put(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({"status": newStatus}),
        );
      }

      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => booking.currentStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัปเดตสถานะสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 1. ดึงข้อความแจ้งเตือนจาก Backend เป็นค่าเริ่มต้น
        String errorMessage;
        try {
          final responseData = jsonDecode(response.body);
          errorMessage =
              responseData['message'] ??
              'เกิดข้อผิดพลาดรหัส ${response.statusCode}';
        } catch (_) {
          errorMessage = 'เกิดข้อผิดพลาดรหัส ${response.statusCode}';
        }

        // 2. แปลงข้อความตาม HTTP Status Code ที่กำหนด
        switch (response.statusCode) {
          case 401:
            errorMessage = 'กรุณาเข้าสู่ระบบใหม่';
            break;
          case 403:
            errorMessage =
                'คุณไม่มีสิทธิ์ยกเลิกการจองนี้ สามารถยกเลิกได้เฉพาะรายการที่คุณเป็นผู้จอง';
            break;
          case 404:
            errorMessage = 'ไม่พบรายการจอง';
            break;
          case 409:
            errorMessage = 'รายการนี้ถูกเปลี่ยนแปลงหรือยกเลิกไปแล้ว';
            break;
          case 500:
            errorMessage = 'เกิดข้อผิดพลาดของระบบ กรุณาลองใหม่';
            break;
        }

        // 3. แสดงผลผ่าน SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เชื่อมต่อเซิร์ฟเวอร์ผิดพลาด'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003E75),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
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
                    child: CircularProgressIndicator(color: Color(0xFF003E75)),
                  )
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // 💡 คำนวณเวลาเที่ยงคืนของวันนี้
    DateTime todayMidnight = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    List<BookingHistoryModel> filteredList = historyList.where((item) {
      // 1. กรองตาม Tab
      if (selectedTab != 'ทั้งหมด' && item.type != selectedTab) return false;

      // 2. Midnight Filter: ถ้าสถานะจบไปแล้ว และเป็นอดีต (ก่อนเที่ยงคืนของวันนี้) ให้ซ่อน
      if ((item.currentStatus == 'เสร็จสิ้น' ||
              item.currentStatus == 'ยกเลิกแล้ว') &&
          item.rawDate != null) {
        if (item.rawDate!.isBefore(todayMidnight)) {
          return false;
        }
      }
      return true; // รายการอื่นแสดงตามปกติ
    }).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Text(
          'ไม่มีประวัติการจองในหมวด $selectedTab',
          style: const TextStyle(fontFamily: 'Kanit', color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filteredList.length,
      itemBuilder: (context, index) => _buildHistoryCard(filteredList[index]),
    );
  }

  Widget _buildTabSelection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (userRole != 'GUARD')
            _buildTabButton('ทั้งหมด', Icons.all_inclusive),
          if (userRole != 'GUARD')
            _buildTabButton('ห้องประชุม', Icons.meeting_room_outlined),
          _buildTabButton('จองรถ', Icons.directions_car_filled_outlined),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon) {
    bool isSelected = selectedTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = label),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.blueGrey,
              ),
              const SizedBox(width: 4),
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
      ),
    );
  }

  // =========================================================
  // 🎨 การ์ดประวัติ (UI)
  // =========================================================
  Widget _buildHistoryCard(BookingHistoryModel booking) {
    String status = booking.currentStatus;
    Color statusBgColor = const Color(0xFFF59E0B);
    Color statusTextColor = Colors.white;

    if (status == 'กำลังใช้งาน') {
      statusBgColor = const Color(0xFFBFDBFE);
      statusTextColor = const Color(0xFF1D4ED8);
    } else if (status == 'เสร็จสิ้น' || status == 'ยกเลิกแล้ว') {
      statusBgColor = status == 'ยกเลิกแล้ว'
          ? const Color(0xFFFF8A8A)
          : const Color(0xFFF1F5F9);
      statusTextColor = status == 'ยกเลิกแล้ว'
          ? Colors.white
          : const Color(0xFF94A3B8);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[200],
                    child:
                        booking.type == 'จองรถ' && booking.imageUrl.isNotEmpty
                        ? Image.network(
                            booking.imageUrl.startsWith('/uploads')
                                ? 'http://localhost:3001${booking.imageUrl}'
                                : booking.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.directions_car,
                              color: Colors.grey,
                              size: 30,
                            ),
                          )
                        : Icon(
                            booking.type == 'ห้องประชุม'
                                ? Icons.meeting_room
                                : Icons.directions_car,
                            color: Colors.grey,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2841),
                          fontFamily: 'Kanit',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            booking.date,
                            style: const TextStyle(
                              fontSize: 13,
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
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
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

            // เวลาการจอง
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'เวลาการจอง',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey,
                      fontFamily: 'Kanit',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_formatTime(booking.startTime)} - ${_formatTime(booking.endTime)} น.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF009CB4),
                      fontFamily: 'Kanit',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 💡 สร้างตัวแปรเช็คความเป็นเจ้าของ และเพิ่ม Debug Log
            Builder(
              builder: (context) {
                bool isOwner = booking.userId == currentUserId;

                print('--- Debug Log: Permission Check ---');
                print('currentUserId = $currentUserId');
                print('booking.userId = ${booking.userId}');
                print('booking.id = ${booking.id}');
                print('booking.status = $status');
                print('isOwner = $isOwner');
                print('-----------------------------------');

                // ปุ่มต่างๆ
                if (status == 'ถูกจองไว้อยู่') {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _showDetailsPopup(context, booking),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                'ดูรายละเอียด',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                            ),
                          ),

                          // 💡 แสดงปุ่ม "ยกเลิกคิว" เฉพาะเจ้าของรายการ
                          if (isOwner) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _updateStatus(booking, 'Cancelled'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
                      if (booking.type == 'จองรถ') ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '* ติดต่อรับกุญแจที่ รปภ.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                } else if (status == 'กำลังใช้งาน') {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => _showDetailsPopup(context, booking),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'ดูรายละเอียด',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 💡 ปุ่มบันทึกคืนรถ ทำงานเหมือนเดิมตาม Logic เก่า
                      if (booking.type == 'จองรถ')
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () =>
                                _updateStatus(booking, 'เสร็จสิ้น'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009CB4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'บันทึกคืนรถ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Kanit',
                              ),
                            ),
                          ),
                        ),

                      // 💡 ปุ่มคืนห้องก่อนเวลา ตรวจสอบให้แสดงเฉพาะเจ้าของรายการเท่านั้น
                      if (booking.type == 'ห้องประชุม' && isOwner)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () =>
                                _updateStatus(booking, 'เสร็จสิ้น'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
                  );
                } else {
                  return SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => _showDetailsPopup(context, booking),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'ดูรายละเอียด',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 🔍 หน้าต่าง Popup รายละเอียด
  // =========================================================
  void _showDetailsPopup(BuildContext context, BookingHistoryModel booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'รายละเอียดประวัติ',
                      style: TextStyle(
                        fontSize: 18,
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003E75).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          booking.type == 'จองรถ'
                              ? Icons.directions_car
                              : Icons.meeting_room,
                          color: const Color(0xFF003E75),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: 'Kanit',
                              ),
                            ),
                            if (booking.type == 'จองรถ')
                              Text(
                                'ทะเบียน ${booking.plateNumber}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 💡 บล็อก 1: ข้อมูลพื้นฐาน (ใช้ร่วมกันได้)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildPopupDetailRow(
                          'สถานะ',
                          booking.currentStatus,
                          isStatus: true,
                        ),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow(
                          'วันที่',
                          booking.date == booking.endDate
                              ? booking.date
                              : '${booking.date} - ${booking.endDate}',
                        ),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow(
                          'เวลา',
                          '${_formatTime(booking.startTime)} - ${_formatTime(booking.endTime)} น.',
                        ),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow('ผู้ทำรายการ', booking.bookerName),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow(
                          'จำนวนคน',
                          '${booking.participantCount} คน',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 💡 บล็อก 2: ข้อมูลเพิ่มเติม (แยกประเภทชัดเจน ซ่อนบรรทัดที่ไม่เกี่ยวกับ Type นั้นๆ)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
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
                        const SizedBox(height: 12),

                        // --- แสดงเฉพาะ "ห้องประชุม" ---
                        if (booking.type == 'ห้องประชุม') ...[
                          _buildPopupDetailRow(
                            'หัวข้อการประชุม',
                            booking.title,
                          ),
                        ],

                        // --- แสดงเฉพาะ "จองรถ" ---
                        if (booking.type == 'จองรถ') ...[
                          if (booking.destination != '-') ...[
                            _buildPopupDetailRow(
                              'ปลายทาง',
                              booking.destination,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildPopupDetailRow(
                            'วัตถุประสงค์',
                            '-',
                          ), // คงไว้ตามโครงสร้างเดิมของรถ
                          if (booking.driverType != '-') ...[
                            const SizedBox(height: 12),
                            _buildPopupDetailRow(
                              'รูปแบบคนขับ',
                              booking.driverType,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  // บล็อก 3: เอกสารประจำรถ
                  if (booking.type == 'จองรถ') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                color: Color(0xFF8B5CF6),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'เอกสารประจำรถ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.image_outlined,
                                color: Colors.blue.shade600,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildPopupDetailRow(
                            'ประกันภัย :',
                            'ประกันภัย ชั้น 1',
                            valueColor: const Color(0xFF8B5CF6),
                          ),
                          const SizedBox(height: 8),
                          _buildPopupDetailRow(
                            'วันต่อภาษี :',
                            '31 ส.ค. 2026',
                            valueColor: const Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009CB4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
          ),
        );
      },
    );
  }

  Widget _buildPopupDetailRow(
    String label,
    String value, {
    bool isStatus = false,
    Color? valueColor,
  }) {
    Color bgStatusColor = const Color(0xFFF59E0B);
    Color textStatusColor = Colors.white;

    if (value == 'กำลังใช้งาน') {
      bgStatusColor = const Color(0xFFBFDBFE);
      textStatusColor = const Color(0xFF1D4ED8);
    } else if (value == 'เสร็จสิ้น' || value == 'ยกเลิกแล้ว') {
      bgStatusColor = value == 'ยกเลิกแล้ว'
          ? const Color(0xFFFF8A8A)
          : const Color(0xFFE2E8F0);
      textStatusColor = value == 'ยกเลิกแล้ว'
          ? Colors.white
          : const Color(0xFF64748B);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontFamily: 'Kanit',
          ),
        ),
        isStatus
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bgStatusColor,
                  borderRadius: BorderRadius.circular(20),
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
            : Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? Colors.black87,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
      ],
    );
  }
}
