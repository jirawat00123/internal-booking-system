import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

// =========================================================
// 📦 โมเดลประวัติการจอง
// =========================================================
class BookingHistoryModel {
  final String id;
  final String type;
  final String resourceName;
  final String title;
  final String date;
  final String endDate;
  final DateTime? rawDate;
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
  final String? pororborUrl;

  BookingHistoryModel({
    required this.id,
    required this.type,
    required this.resourceName,
    required this.title,
    required this.date,
    required this.endDate,
    this.rawDate,
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
    this.pororborUrl,
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

  String userRole = '';
  int currentUserId = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo().then((_) => fetchHistory());
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    int loadedUserId = 0;
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

  Future<void> _openPororbor(String? urlPath) async {
    if (urlPath == null || urlPath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบไฟล์เอกสาร')));
      return;
    }

    final baseUrl = 'http://192.168.88.25:3001';
    final fullUrl = '$baseUrl$urlPath';
    final Uri url = Uri.parse(fullUrl);

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่สามารถเปิดเอกสารได้')));
      }
    }
  }

  // =========================================================
  // 📥 ดึงข้อมูลจากฐานข้อมูล (API)
  // =========================================================
  Future<void> fetchHistory() async {
    try {
      setState(() => isLoading = true);
      String token = await getSavedToken();

      // 🟢 ตรวจสอบว่าผู้ใช้มี Token หรือไม่ (ป้องกัน Guest ยิง API)
      if (token.isEmpty) {
        if (mounted) setState(() => isLoading = false);
        return; // ไม่ต้องยิง API หากไม่มี Token
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final roomResponseFuture = http.get(
        Uri.parse('http://192.168.88.25:3001/api/bookings?page=1&limit=50'),
        headers: headers,
      );
      final vehicleResponseFuture = http.get(
        Uri.parse(
          'http://192.168.88.25:3001/api/vehicle-bookings?page=1&limit=50',
        ),
        headers: headers,
      );

      final responses = await Future.wait([
        roomResponseFuture,
        vehicleResponseFuture,
      ]);
      List<BookingHistoryModel> fetchedList = [];

      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        for (var item in (data['bookings'] ?? [])) {
          DateTime start = DateTime.parse(item['startDatetime']).toLocal();
          DateTime end = DateTime.parse(item['endDatetime']).toLocal();

          String rawStatus = item['status'] ?? 'Reserved';
          if (rawStatus.toLowerCase() == 'pending') rawStatus = 'Reserved';
          if (rawStatus.toLowerCase() == 'approved' ||
              rawStatus.toLowerCase() == 'in_use' ||
              rawStatus.toLowerCase() == 'active') {
            rawStatus = 'In Use';
          }
          if (rawStatus.toLowerCase() == 'completed') rawStatus = 'Completed';
          if (rawStatus.toLowerCase() == 'cancelled') rawStatus = 'Cancelled';

          DateTime now = DateTime.now();
          if (rawStatus != 'Cancelled' && rawStatus != 'Completed') {
            if (now.isAfter(start) && now.isBefore(end)) {
              rawStatus = 'In Use';
            } else if (now.isAfter(end)) {
              rawStatus = 'Completed';
            }
          }

          String userName = 'ไม่ระบุชื่อ';
          if (item['user'] != null) {
            userName =
                item['user']['employee']?['fullName'] ??
                item['user']['firstName'] ??
                item['user']['username'] ??
                'ไม่ระบุชื่อ';
          }

          int pCount =
              int.tryParse(item['participants']?.toString() ?? '0') ?? 0;
          if (pCount == 0 && item['room'] != null) {
            pCount =
                int.tryParse(item['room']['capacity']?.toString() ?? '0') ?? 0;
          }

          // 🟢 Filter: ข้ามคิวที่เป็น Cancelled ไปเลย ไม่ต้องเอาใส่ลิสต์
          if (rawStatus == 'Cancelled') continue;

          fetchedList.add(
            BookingHistoryModel(
              id: item['id'].toString(),
              type: 'ห้องประชุม',
              resourceName:
                  item['room']?['roomName'] ??
                  item['room']?['room_name'] ??
                  'ห้องประชุม ${item['roomId']}',
              title:
                  item['purpose'] ??
                  item['title'] ??
                  item['topic'] ??
                  'ไม่ระบุหัวข้อ',
              date: _formatThaiDate(start),
              endDate: _formatThaiDate(end),
              rawDate: start,
              startTime: TimeOfDay(hour: start.hour, minute: start.minute),
              endTime: TimeOfDay(hour: end.hour, minute: end.minute),
              bookedBy: userName,
              bookerName: userName,
              userId:
                  int.tryParse(
                    item['userId']?.toString() ??
                        item['user']?['id']?.toString() ??
                        '0',
                  ) ??
                  0,
              participantCount: pCount,
              currentStatus: rawStatus,
              imageUrl:
                  item['room']?['uploadUrl'] ?? item['room']?['imageUrl'] ?? '',
            ),
          );
        }
      }

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

          String rawStatus = item['status'] ?? 'Reserved';
          if (rawStatus.toLowerCase() == 'pending' ||
              rawStatus == 'ถูกจองไว้อยู่')
            rawStatus = 'Reserved';
          if (rawStatus.toLowerCase() == 'approved' ||
              rawStatus.toLowerCase() == 'in_use' ||
              rawStatus.toLowerCase() == 'active' ||
              rawStatus == 'กำลังใช้งาน') {
            rawStatus = 'In Use';
          }
          if (rawStatus.toLowerCase() == 'completed' ||
              rawStatus == 'เสร็จสิ้น')
            rawStatus = 'Completed';
          if (rawStatus.toLowerCase() == 'cancelled' ||
              rawStatus == 'ยกเลิกแล้ว')
            rawStatus = 'Cancelled';

          String userName = 'ไม่ระบุชื่อ';
          if (item['user'] != null) {
            userName = item['user']['employee']?['fullName'] ?? 'ไม่ระบุชื่อ';
          }

          int pCount = 0;
          if (item['passengers'] != null) {
            pCount = int.tryParse(item['passengers'].toString()) ?? 0;
          } else if (item['passengerCount'] != null) {
            pCount = int.tryParse(item['passengerCount'].toString()) ?? 0;
          }

          // 🟢 Filter: ข้ามคิวที่เป็น Cancelled ไปเลย ไม่ต้องเอาใส่ลิสต์
          if (rawStatus == 'Cancelled') continue;

          fetchedList.add(
            BookingHistoryModel(
              id: item['id'].toString(),
              type: 'จองรถ',
              resourceName: item['vehicle']?['vehicleName'] ?? 'ไม่ระบุรุ่นรถ',
              title: item['destination'] ?? item['purpose'] ?? '-',
              date: _formatThaiDate(start),
              endDate: _formatThaiDate(end),
              rawDate: start,
              startTime: TimeOfDay(hour: start.hour, minute: start.minute),
              endTime: TimeOfDay(hour: end.hour, minute: end.minute),
              bookedBy: userName,
              bookerName: userName,
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
              pororborUrl: item['vehicle']?['uploadPororborUrl'],
            ),
          );
        }
      }

      fetchedList.sort(
        (a, b) => (b.rawDate ?? DateTime.now()).compareTo(
          a.rawDate ?? DateTime.now(),
        ),
      );

      if (mounted) {
        setState(() {
          historyList = fetchedList;
          isLoading = false;
        });
      }
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

      String apiStatus = newStatus;
      if (newStatus == 'Completed') apiStatus = 'COMPLETED';
      if (newStatus == 'Cancelled') apiStatus = 'CANCELLED';

      if (booking.type == 'จองรถ' && newStatus == 'Cancelled') {
        String endpoint =
            'http://192.168.88.25:3001/api/vehicle-bookings/${booking.id}/cancel';
        response = await http.patch(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        newStatus = 'Cancelled';
      } else if (booking.type == 'จองรถ') {
        String baseUrl = 'http://192.168.88.25:3001';
        String endpoint =
            '$baseUrl/api/vehicle-bookings/${booking.id}/complete';

        response = await http.put(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({"status": apiStatus}),
        );
      } else {
        String endpoint =
            'http://192.168.88.25:3001/api/bookings/${booking.id}';
        response = await http.put(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({"status": apiStatus}),
        );
      }

      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          // 🟢 ถ้ายกเลิกสำเร็จ ให้ "ลบ" การ์ดนั้นออกจากลิสต์ไปเลย (ซ่อนจากการมองเห็น)
          if (newStatus == 'Cancelled') {
            historyList.removeWhere((item) => item.id == booking.id);
          } else {
            booking.currentStatus = newStatus;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัปเดตสถานะสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String errorMessage;
        try {
          final responseData = jsonDecode(response.body);
          errorMessage =
              responseData['message'] ??
              'เกิดข้อผิดพลาดรหัส ${response.statusCode}';
        } catch (_) {
          errorMessage = 'เกิดข้อผิดพลาดรหัส ${response.statusCode}';
        }

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
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildList(key: ValueKey<String>(selectedTab)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList({Key? key}) {
    List<BookingHistoryModel> filteredList = historyList.where((item) {
      if (selectedTab != 'ทั้งหมด' && item.type != selectedTab) return false;
      return true;
    }).toList();

    if (filteredList.isEmpty) {
      return Center(
        key: key,
        child: const Text(
          'ไม่มีประวัติการจอง',
          style: TextStyle(fontFamily: 'Kanit', color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        return ShowUp(
          delay: index * 80,
          child: _buildHistoryCard(filteredList[index]),
        );
      },
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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

    if (status == 'In Use') {
      statusBgColor = const Color(0xFFBFDBFE);
      statusTextColor = const Color(0xFF1D4ED8);
    } else if (status == 'Completed' || status == 'Cancelled') {
      statusBgColor = status == 'Cancelled'
          ? const Color(0xFFFF8A8A)
          : const Color(0xFFF1F5F9);
      statusTextColor = status == 'Cancelled'
          ? Colors.white
          : const Color(0xFF94A3B8);
    }

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      elevation: 0,
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
                    child: booking.imageUrl.isNotEmpty
                        ? Image.network(
                            booking.imageUrl.startsWith('/uploads')
                                ? 'http://192.168.88.25:3001${booking.imageUrl}'
                                : booking.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Icon(
                              booking.type == 'ห้องประชุม'
                                  ? Icons.meeting_room
                                  : Icons.directions_car,
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
                        booking.resourceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E2841),
                          fontFamily: 'Kanit',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            booking.type == 'ห้องประชุม'
                                ? Icons.chat_bubble_outline
                                : Icons.place_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              booking.type == 'ห้องประชุม'
                                  ? 'หัวข้อ: ${booking.title}'
                                  : 'ปลายทาง: ${booking.title}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontFamily: 'Kanit',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ผู้จอง: ${booking.bookerName}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontFamily: 'Kanit',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                    booking.type == 'จองรถ'
                        ? '${_formatTime(booking.startTime)} น.'
                        : '${_formatTime(booking.startTime)} - ${_formatTime(booking.endTime)} น.',
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

            Builder(
              builder: (context) {
                bool isOwner = booking.userId == currentUserId;

                if (status == 'Reserved') {
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
                            '* ติดต่อที่ รปภ.',
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
                } else if (status == 'In Use') {
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

                      if (booking.type == 'ห้องประชุม' && isOwner)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () =>
                                _updateStatus(booking, 'Completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009CB4),
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
                      booking.imageUrl.isNotEmpty
                          ? ClipOval(
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Image.network(
                                  booking.imageUrl.startsWith('/uploads')
                                      ? 'http://192.168.88.25:3001${booking.imageUrl}'
                                      : booking.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF003E75,
                                      ).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      booking.type == 'จองรถ'
                                          ? Icons.directions_car
                                          : Icons.meeting_room,
                                      color: const Color(0xFF003E75),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
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
                              booking.resourceName,
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
                          booking.type == 'จองรถ'
                              ? '${_formatTime(booking.startTime)} น.'
                              : '${_formatTime(booking.startTime)} - ${_formatTime(booking.endTime)} น.',
                        ),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow('ผู้ทำรายการ', booking.bookerName),

                        if (booking.participantCount > 0) ...[
                          const SizedBox(height: 12),
                          _buildPopupDetailRow(
                            'จำนวนคน',
                            '${booking.participantCount} คน',
                          ),
                        ],
                      ],
                    ),
                  ),
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

                        if (booking.type == 'ห้องประชุม') ...[
                          _buildPopupDetailRow(
                            'หัวข้อการประชุม',
                            booking.title,
                          ),
                        ],

                        if (booking.type == 'จองรถ') ...[
                          if (booking.destination != '-') ...[
                            _buildPopupDetailRow('ปลายทาง', booking.title),
                            const SizedBox(height: 12),
                          ],
                          _buildPopupDetailRow('วัตถุประสงค์', '-'),
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
                                'เอกสารประจำรถ (พรบ.)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Kanit',
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.file_present_outlined,
                                color: Colors.blue.shade600,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          booking.pororborUrl != null &&
                                  booking.pororborUrl!.isNotEmpty
                              ? SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _openPororbor(booking.pororborUrl),
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'ดูเอกสาร พรบ.',
                                      style: TextStyle(
                                        fontFamily: 'Kanit',
                                        fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF009CB4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Text(
                                      'ไม่มีเอกสารแนบ',
                                      style: TextStyle(
                                        fontFamily: 'Kanit',
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
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

    if (value == 'In Use') {
      bgStatusColor = const Color(0xFFBFDBFE);
      textStatusColor = const Color(0xFF1D4ED8);
    } else if (value == 'Completed' || value == 'Cancelled') {
      bgStatusColor = value == 'Cancelled'
          ? const Color(0xFFFF8A8A)
          : const Color(0xFFE2E8F0);
      textStatusColor = value == 'Cancelled'
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

// ==========================================
// 🚀 WIDGET: ShowUp Animation
// ==========================================
class ShowUp extends StatefulWidget {
  final Widget child;
  final int delay;

  const ShowUp({super.key, required this.child, this.delay = 0});

  @override
  State<ShowUp> createState() => _ShowUpState();
}

class _ShowUpState extends State<ShowUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animOffset = Tween<Offset>(
      begin: const Offset(0.0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.delay == 0) {
      _controller.forward();
    } else {
      Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(position: _animOffset, child: widget.child),
    );
  }
}
