import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Room_booking.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  bool isLoading =
      true; // 💡 เพิ่ม State เพื่อโชว์ตัวโหลดระหว่างรอข้อมูลจาก Backend

  @override
  void initState() {
    super.initState();
    _fetchRoomsFromApi(); // 💡 ดึงข้อมูลทันทีที่ผู้ใช้เข้ามาหน้านี้
  }

  // 🔥 [สิ่งที่เปลี่ยนไป 1]: เพิ่มฟังก์ชันดึงห้องประชุมจาก Backend สำหรับ User
  Future<void> _fetchRoomsFromApi() async {
    try {
      final String baseUrl = kIsWeb
          ? 'http://localhost:3001'
          : 'http://10.0.2.2:3001';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$baseUrl/api/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token.trim()}',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List roomsData = body is List ? body : (body['data'] ?? []);

        final activeRooms = roomsData.where((e) {
          return e['isDeleted'] == false || e['isDeleted'] == 'false';
        }).toList();

        globalMeetingRooms.value = activeRooms
            .map((e) => MeetingRoom.fromJson(e))
            .toList();
      } else if (response.statusCode == 401) {
        // 🔴 [เพิ่มใหม่] จัดการ Concurrent Login: เมื่อ Session ไม่ตรงหรือหมดอายุ
        if (mounted) {
          // 1. ล้าง Token ทิ้ง
          await prefs.clear();

          // 2. แจ้งเตือนผู้ใช้
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'เซสชันหมดอายุ หรือมีการเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );

          // 3. บังคับเด้งกลับหน้า Login (ตรวจสอบชื่อ Route ให้ตรงกับที่คุณตั้งไว้ใน main.dart)
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
        }
      } else {
        // 🟢 2. แจ้งเตือนเมื่อ HTTP Status อื่นๆ ที่ไม่ใช่ 200 และ 401
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ดึงข้อมูลไม่สำเร็จ (Code: ${response.statusCode})',
                style: const TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      // 🟢 3. แจ้งเตือนเมื่อเน็ตหลุดหรือเซิร์ฟเวอร์มีปัญหา (Rule 19)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false; // ปิดตัวโหลดเมื่อดึงข้อมูลเสร็จ
        });
      }
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

          // 🔥 [สิ่งที่เปลี่ยนไป 2]: เพิ่ม isLoading เช็กก่อนแสดงการ์ดห้อง เพื่อความสมูท
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF004AAD)),
                  )
                : RefreshIndicator(
                    // 💡 1. เพิ่ม Widget นี้เข้ามาครอบ
                    onRefresh:
                        _fetchRoomsFromApi, // 💡 2. สั่งให้ดึง API ใหม่เมื่อใช้นิ้วดึงหน้าจอลง
                    color: const Color(0xFF004AAD),
                    child: ValueListenableBuilder<List<MeetingRoom>>(
                      valueListenable: globalMeetingRooms,
                      builder: (context, rooms, child) {
                        if (rooms.isEmpty) {
                          return ListView(
                            // 💡 (บังคับให้เป็น ListView เพื่อให้สามารถดึงหน้าจอลงได้แม้ไม่มีข้อมูล)
                            physics:
                                const AlwaysScrollableScrollPhysics(), // 💡 การันตีให้สามารถดึงเพื่อ Refresh ได้เสมอ
                            children: const [
                              SizedBox(height: 200),
                              Center(
                                child: Text(
                                  'ไม่มีห้องประชุมที่พร้อมใช้งาน',
                                  style: TextStyle(
                                    fontFamily: 'Kanit',
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            return _buildRoomCard(rooms[index]);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ส่วนสร้าง Step Indicator (1 เลือกห้อง -> 2 กรอกข้อมูล -> 3 ยืนยัน)
  // ... (โค้ดด้านล่างที่เหลือทั้งหมดคงเดิม ไม่ต้องแก้ครับ) ...

  // ส่วนสร้าง Step Indicator (1 เลือกห้อง -> 2 กรอกข้อมูล -> 3 ยืนยัน)
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
            _buildStepCircle('1', 'เลือกห้อง', isActive: true),
            _buildStepLine(),
            _buildStepCircle('2', 'กรอกข้อมูล', isActive: false),
            _buildStepLine(),
            _buildStepCircle('3', 'ยืนยัน', isActive: false),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(String step, String label, {required bool isActive}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00A8CC) : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
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
            color: isActive ? const Color(0xFF004AAD) : Colors.grey,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: const Color(0xFFE2E8F0),
        margin: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildRoomCard(MeetingRoom room) {
    bool isAvailable = room.status == 'AVAILABLE';
    Color statusColor;
    // ฟังก์ชันแยกสำหรับจัดการโหลดรูปภาพ (Optimize พร้อม ErrorBuilder ป้องกันแอปพัง)
    // 🟢 4. บังคับใช้ Image.network เสมอ และตัดลอจิก Image.file ทิ้ง เพราะภาพทุกใบของระบบนี้อยู่บนเซิร์ฟเวอร์
    Widget _buildImage(String? imagePath) {
      if (imagePath == null || imagePath.isEmpty) {
        return Container(
          height: 180,
          color: Colors.grey[300],
          child: const Icon(Icons.image, size: 50, color: Colors.grey),
        );
      }

      final String baseUrl = kIsWeb
          ? 'http://localhost:3001'
          : 'http://10.0.2.2:3001';
      final imageUrl = imagePath.startsWith('http')
          ? imagePath
          : '$baseUrl$imagePath';

      return Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 180,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      );
    }

    // ส่วนสร้าง Card ห้องประชุม
    switch (room.status) {
      case 'AVAILABLE':
        statusColor = const Color(0xFF2EC4B6);
        break;

      case 'RESERVED':
        statusColor = Colors.orange;
        break;

      default:
        statusColor = const Color(0xFFE11D48);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // แสดงรูปภาพห้องประชุม
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: _buildImage(room.imagePath),
              ),

              // Badge สถานะห้อง (มุมขวาบน)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: statusColor, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        room.status == 'AVAILABLE'
                            ? 'ว่างพร้อมใช้งาน'
                            : room.status == 'RESERVED'
                            ? 'จองแล้ว'
                            : 'กำลังใช้งาน',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontFamily: 'Kanit',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  room.roomName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 12),

                // รายละเอียด โลเคชั่น และ ความจุ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildIconDetail(
                        Icons.location_on_outlined,
                        room.location,
                      ),
                      const SizedBox(height: 6),
                      _buildIconDetail(
                        Icons.people_outline,
                        'รองรับสูงสุด ${room.capacity} ท่าน',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tags อุปกรณ์เสริมภายในห้อง (Wrap ป้องกัน UI ทะลุบนจอเล็ก)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildTag('โปรเจคเตอร์'),
                    _buildTag('สมาร์ททีวี'),
                    _buildTag('กระดานไวท์บอร์ด'),
                  ],
                ),

                const SizedBox(height: 20),

                // ปุ่มเลือกห้องนี้
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    // 💡 ปลดล็อก! เอาเงื่อนไข isAvailable ออกไปเลย ให้กดเข้าได้ 100% เสมอ
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoomBookingAScreen(room: room),
                        ),
                      );

                      // เมื่อกลับมาหน้านี้ ถ้า result เป็น true ให้ดึงข้อมูลใหม่
                      if (result == true) {
                        if (!mounted) return;
                        setState(() {
                          isLoading = true;
                        });
                        _fetchRoomsFromApi();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF00A8CC,
                      ), // สีฟ้าพร้อมกดเสมอ
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'เลือกห้องนี้',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Kanit',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconDetail(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF004AAD)),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.blueGrey,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
          fontFamily: 'Kanit',
        ),
      ),
    );
  }
}
