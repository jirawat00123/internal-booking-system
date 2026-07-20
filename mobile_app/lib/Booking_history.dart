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
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String bookedBy;
  final String bookerName; 
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
    required this.startTime,
    required this.endTime,
    required this.bookedBy,
    required this.bookerName,
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

  @override
  void initState() {
    super.initState();
    fetchHistory(); 
  }

  Future<String> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? ''; 
  }

  String _formatThaiDate(DateTime date) {
    const thaiMonths = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
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
      print('🔑 Token ที่กำลังส่งไปหลังบ้าน: $token');
      
      // 💡 สมมติว่าดึง currentUserId มาจาก SharedPreferences แล้ว (ตามโค้ดก่อนหน้าที่แก้ไป)
      final prefs = await SharedPreferences.getInstance();
      int currentUserId = prefs.getInt('userId') ?? 1;

      final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};

      final roomResponseFuture = http.get(Uri.parse('http://localhost:3001/api/bookings?page=1&limit=50&userId=$currentUserId'), headers: headers);
      final vehicleResponseFuture = http.get(Uri.parse('http://localhost:3001/api/vehicle-bookings?page=1&limit=50&userId=$currentUserId'), headers: headers);

      final responses = await Future.wait([roomResponseFuture, vehicleResponseFuture]);
      List<BookingHistoryModel> fetchedList = [];
      
      // 💡 สร้างตัวแปรเก็บ "วันนี้" แบบตัดเวลาทิ้ง (เอาไว้วัดว่าผ่านเที่ยงคืนหรือยัง)
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day); 

      // 💡 1. ดึงข้อมูลประวัติ ห้องประชุม
      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        List<dynamic> rBookings = data['bookings'] ?? data['data'] ?? [];
        for (var item in rBookings) {
          DateTime start = DateTime.parse(item['startDatetime']).toLocal();
          DateTime end = DateTime.parse(item['endDatetime']).toLocal();
          
          // แปลงสถานะให้ตรงกับ UI
          String rawStatus = item['status'] ?? 'ถูกจองไว้อยู่';
          if (rawStatus.toLowerCase() == 'pending') rawStatus = 'ถูกจองไว้อยู่';
          if (rawStatus.toLowerCase() == 'approved' || rawStatus.toLowerCase() == 'in_use') rawStatus = 'กำลังใช้งาน';
          if (rawStatus.toLowerCase() == 'completed') rawStatus = 'เสร็จสิ้น';
          if (rawStatus.toLowerCase() == 'cancelled') rawStatus = 'ยกเลิกแล้ว';

          // 🎯 [ไฮไลท์สำคัญ] เช็คว่าถ้ายกเลิกแล้ว และผ่านวันนั้นมาแล้ว (ข้ามเที่ยงคืน) ให้ข้ามไปเลย ไม่ต้องโชว์
          DateTime bookingDateOnly = DateTime(start.year, start.month, start.day);
          if (rawStatus == 'ยกเลิกแล้ว' && bookingDateOnly.isBefore(today)) {
            continue; // ข้ามการทำงานรอบนี้ไป (ไม่ทำโค้ดด้านล่าง)
          }

          // ค้นหาชื่อ User ของห้องประชุม
          String userName = 'ไม่ระบุชื่อ';
          if (item['user'] != null && item['user']['employee'] != null) {
            userName = item['user']['employee']['fullName'] ?? 'ไม่ระบุชื่อ';
          }

          String roomTitle = item['purpose'] != null && item['purpose'].toString().isNotEmpty 
              ? item['purpose'] 
              : (item['room']?['roomName'] ?? 'Meeting Room ${item['roomId']}');

          String imgUrl = item['room']?['uploadUrl'] ?? '';
          String roomLocation = item['room']?['location'] != null ? 'ชั้น ${item['room']['location']}' : '-';

          fetchedList.add(BookingHistoryModel(
            id: item['id'].toString(),
            type: 'ห้องประชุม',
            title: roomTitle,
            date: _formatThaiDate(start),
            endDate: _formatThaiDate(end),
            startTime: TimeOfDay(hour: start.hour, minute: start.minute),
            endTime: TimeOfDay(hour: end.hour, minute: end.minute),
            bookedBy: userName,
            bookerName: userName, 
            participantCount: 0, 
            currentStatus: rawStatus,
            imageUrl: imgUrl,
            destination: roomLocation, 
          ));
        }
      }

      // 💡 2. ดึงข้อมูลประวัติ จองรถ
      if (responses[1].statusCode == 200) {
        final data = jsonDecode(responses[1].body);
        List<dynamic> vBookings = data['data'] ?? data['bookings'] ?? [];
        for (var item in vBookings) {
          DateTime start = DateTime.parse(item['startDatetime'] ?? item['startDate'] ?? DateTime.now().toString()).toLocal();
          DateTime end = DateTime.parse(item['endDatetime'] ?? item['endDate'] ?? DateTime.now().toString()).toLocal();
          
          String rawStatus = item['status'] ?? 'ถูกจองไว้อยู่';
          if (rawStatus.toLowerCase() == 'pending') rawStatus = 'ถูกจองไว้อยู่';
          if (rawStatus.toLowerCase() == 'approved' || rawStatus.toLowerCase() == 'in_use') rawStatus = 'กำลังใช้งาน';
          if (rawStatus.toLowerCase() == 'completed') rawStatus = 'เสร็จสิ้น';
          if (rawStatus.toLowerCase() == 'cancelled') rawStatus = 'ยกเลิกแล้ว';

          // 🎯 [ไฮไลท์สำคัญ] เช็คซ่อนประวัติจองรถที่ยกเลิกไปแล้วเช่นกัน
          DateTime bookingDateOnly = DateTime(start.year, start.month, start.day);
          if (rawStatus == 'ยกเลิกแล้ว' && bookingDateOnly.isBefore(today)) {
            continue; 
          }

          String userName = 'ไม่ระบุชื่อ';
          if (item['user'] != null && item['user']['employee'] != null) {
            userName = item['user']['employee']['fullName'] ?? 'ไม่ระบุชื่อ';
          }

          int pCount = 0;
          if (item['passengers'] != null) {
             pCount = int.tryParse(item['passengers'].toString()) ?? 0;
          }

          fetchedList.add(BookingHistoryModel(
            id: item['id'].toString(),
            type: 'จองรถ',
            title: item['vehicle']?['vehicleName'] ?? 'ไม่ระบุรุ่นรถ',
            date: _formatThaiDate(start),
            endDate: _formatThaiDate(end),
            startTime: TimeOfDay(hour: start.hour, minute: start.minute),
            endTime: TimeOfDay(hour: end.hour, minute: end.minute),
            bookedBy: userName, 
            bookerName: userName,
            participantCount: pCount, 
            currentStatus: rawStatus,
            imageUrl: item['vehicle']?['uploadUrl'] ?? '',
            plateNumber: item['vehicle']?['plateNumber'] ?? '-',
            destination: item['destination'] ?? '-',
            driverType: item['driverType'] ?? 'ขับขี่เอง',
          ));
        }
      }

      // เรียงลำดับจากวันที่ล่าสุดขึ้นก่อน
      fetchedList.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) setState(() { historyList = fetchedList; isLoading = false; });
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }
  // =========================================================
  // 🚀 อัปเดตสถานะไปยังฐานข้อมูล (API)
  // =========================================================
  Future<void> _updateStatus(BookingHistoryModel booking, String newStatus) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      String token = await getSavedToken();
      http.Response response;

      // 💡 เงื่อนไขที่ 1: ยกเลิก "จองรถ"
      if (booking.type == 'จองรถ' && (newStatus == 'Cancelled' || newStatus == 'ยกเลิกแล้ว')) {
        String endpoint = 'http://localhost:3001/api/vehicle-bookings/${booking.id}/cancel';
        response = await http.patch(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        );
        newStatus = 'ยกเลิกแล้ว'; 
      } 
      // 💡 เงื่อนไขที่ 2: ยกเลิก "จองห้องประชุม"
      else if (booking.type == 'ห้องประชุม' && (newStatus == 'Cancelled' || newStatus == 'ยกเลิกแล้ว')) {
        String endpoint = 'http://localhost:3001/api/bookings/${booking.id}/cancel';
        response = await http.patch(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        );
        newStatus = 'ยกเลิกแล้ว'; 
      }
      // 💡 เงื่อนไขที่ 3: อัปเดตสถานะอื่นๆ ของรถ
      else if (booking.type == 'จองรถ') {
        String endpoint = 'http://localhost:3001/api/vehicle-bookings/${booking.id}';
        response = await http.put(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({"status": newStatus}), 
        );
      } 
      // 💡 เงื่อนไขที่ 4: อัปเดตสถานะอื่นๆ ของห้องประชุม
      else {
        String endpoint = 'http://localhost:3001/api/bookings/${booking.id}';
        response = await http.put(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({"status": newStatus}), 
        );
      }

      Navigator.pop(context); 

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => booking.currentStatus = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตสถานะสำเร็จ', style: TextStyle(fontFamily: 'Kanit')), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตไม่สำเร็จ กรุณาลองใหม่', style: TextStyle(fontFamily: 'Kanit')), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ผิดพลาด', style: TextStyle(fontFamily: 'Kanit')), backgroundColor: Colors.redAccent));
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
        title: const Text('ประวัติและสถานะ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Kanit')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTabSelection(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF003E75))) 
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    List<BookingHistoryModel> filteredList = selectedTab == 'ทั้งหมด' 
        ? historyList 
        : historyList.where((item) => item.type == selectedTab).toList();

    if (filteredList.isEmpty) {
      return Center(child: Text('ไม่มีประวัติการจองในหมวด $selectedTab', style: const TextStyle(fontFamily: 'Kanit', color: Colors.grey)));
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
          _buildTabButton('ทั้งหมด', Icons.all_inclusive),
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
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.blueGrey),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
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
      statusBgColor = status == 'ยกเลิกแล้ว' ? const Color(0xFFFF8A8A) : const Color(0xFFF1F5F9);
      statusTextColor = status == 'ยกเลิกแล้ว' ? Colors.white : const Color(0xFF94A3B8);
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
                    width: 70, height: 70, color: Colors.grey[200],
                    child: booking.imageUrl.isNotEmpty
                        ? Image.network(
                            booking.imageUrl.startsWith('/uploads') ? 'http://localhost:3001${booking.imageUrl}' : booking.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c,e,s) => Icon(booking.type == 'จองรถ' ? Icons.directions_car : Icons.meeting_room, color: Colors.grey, size: 30),
                          )
                        : Icon(booking.type == 'ห้องประชุม' ? Icons.meeting_room : Icons.directions_car, color: Colors.grey, size: 30),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E2841), fontFamily: 'Kanit')),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(booking.date, style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Kanit')), 
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(status, style: TextStyle(color: statusTextColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // เวลาการจอง
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  const Text('เวลาการจอง', style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontFamily: 'Kanit')),
                  const Spacer(),
                  Text(
                    '${_formatTime(booking.startTime)} น.', 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF009CB4), fontFamily: 'Kanit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // ปุ่มต่างๆ 
            if (status == 'ถูกจองไว้อยู่') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showDetailsPopup(context, booking),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('ดูรายละเอียด', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Kanit')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(booking, 'Cancelled'), 
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('ยกเลิกคิว', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Kanit')),
                    ),
                  ),
                ],
              ),
              if (booking.type == 'จองรถ') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                  child: const Text('* ติดต่อรับกุญแจที่ รปภ.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Kanit')),
                ),
              ],
            ] else if (status == 'กำลังใช้งาน' && booking.type == 'จองรถ') ...[
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton(
                  onPressed: () => _showDetailsPopup(context, booking),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('ดูรายละเอียด', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Kanit')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 44,
                child: ElevatedButton(
                  onPressed: () => _updateStatus(booking, 'เสร็จสิ้น'), 
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009CB4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  child: const Text('บันทึกคืนรถ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Kanit')),
                ),
              ),
            ] else ...[ 
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton(
                  onPressed: () => _showDetailsPopup(context, booking),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('ดูรายละเอียด', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Kanit')),
                ),
              ),
            ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('รายละเอียดประวัติ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Kanit'))),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF003E75).withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(booking.type == 'จองรถ' ? Icons.directions_car : Icons.meeting_room, color: const Color(0xFF003E75)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(booking.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Kanit')),
                            if (booking.type == 'จองรถ') Text('ทะเบียน ${booking.plateNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Kanit')),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 💡 บล็อก 1: ข้อมูลพื้นฐาน 
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _buildPopupDetailRow('สถานะ', booking.currentStatus, isStatus: true),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow('วันที่', booking.date == booking.endDate ? booking.date : '${booking.date} - ${booking.endDate}'),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow('เวลา', '${_formatTime(booking.startTime)} - ${_formatTime(booking.endTime)} น.'),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow('ผู้ทำรายการ', booking.bookerName),
                        if (booking.type == 'จองรถ') ...[
                           const SizedBox(height: 12),
                           _buildPopupDetailRow('จำนวนคน', '${booking.participantCount} คน'),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // บล็อก 2: ข้อมูลเพิ่มเติม
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ข้อมูลเพิ่มเติม', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                        const SizedBox(height: 12),
                        _buildPopupDetailRow(booking.type == 'ห้องประชุม' ? 'สถานที่' : 'ปลายทาง', booking.destination),
                        if (booking.type == 'จองรถ') ...[
                           const SizedBox(height: 12),
                           _buildPopupDetailRow('รูปแบบคนขับ', booking.driverType),
                        ]
                      ],
                    ),
                  ),
                  
                  // บล็อก 3: เอกสารประจำรถ
                  if (booking.type == 'จองรถ') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, color: Color(0xFF8B5CF6), size: 16),
                              const SizedBox(width: 8),
                              const Text('เอกสารประจำรถ', style: TextStyle(fontSize: 13, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                              const Spacer(),
                              Icon(Icons.image_outlined, color: Colors.blue.shade600, size: 18),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildPopupDetailRow('ประกันภัย :', 'ประกันภัย ชั้น 1', valueColor: const Color(0xFF8B5CF6)),
                          const SizedBox(height: 8),
                          _buildPopupDetailRow('วันต่อภาษี :', '31 ส.ค. 2026', valueColor: const Color(0xFF8B5CF6)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009CB4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: const Text('ปิดหน้าต่าง', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
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

  Widget _buildPopupDetailRow(String label, String value, {bool isStatus = false, Color? valueColor}) {
    Color bgStatusColor = const Color(0xFFF59E0B);
    Color textStatusColor = Colors.white;

    if (value == 'กำลังใช้งาน') {
      bgStatusColor = const Color(0xFFBFDBFE);
      textStatusColor = const Color(0xFF1D4ED8);
    } else if (value == 'เสร็จสิ้น' || value == 'ยกเลิกแล้ว') {
      bgStatusColor = value == 'ยกเลิกแล้ว' ? const Color(0xFFFF8A8A) : const Color(0xFFE2E8F0);
      textStatusColor = value == 'ยกเลิกแล้ว' ? Colors.white : const Color(0xFF64748B);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Kanit')),
        isStatus
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: bgStatusColor, borderRadius: BorderRadius.circular(20)),
                child: Text(value, style: TextStyle(color: textStatusColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
              )
            : Expanded(
                child: Text(
                  value, 
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87, fontFamily: 'Kanit')
                ),
              ),
      ],
    );
  }
}