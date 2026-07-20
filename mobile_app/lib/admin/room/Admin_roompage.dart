import 'dart:io';
import 'dart:convert'; // 💡 เพิ่มเพื่อจัดการ JSON
import 'package:http/http.dart' as http; // 💡 เพิ่มสำหรับยิง API
import 'package:shared_preferences/shared_preferences.dart'; // 💡 ดึง Token
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Admin_addroom.dart';
import 'Admin_editroom.dart';
import '../../Booking_room/Room_model.dart';
import '../../AdminGroupPage.dart';

class MobileFrameContainer extends StatelessWidget {
  const MobileFrameContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[900],
      child: Center(
        child: Container(
          width: 400,
          height: 800,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: const MeetingRoomListScreen(),
        ),
      ),
    );
  }
}

class MeetingRoomListScreen extends StatefulWidget {
  const MeetingRoomListScreen({Key? key}) : super(key: key);

  @override
  _MeetingRoomListScreenState createState() => _MeetingRoomListScreenState();
}

class _MeetingRoomListScreenState extends State<MeetingRoomListScreen> {
  List<MeetingRoom> rooms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRooms(); // 💡 โหลดข้อมูลจากฐานข้อมูลทันทีเมื่อเปิดหน้า
  }

  // =======================================================
  // 📥 ฟังก์ชันดึงข้อมูลจาก API (GET)
  // =======================================================
  // =======================================================
  // 📥 ฟังก์ชันดึงข้อมูลจาก API (GET)
  // =======================================================
  Future<void> _fetchRooms() async {
    if (!mounted) return; // 💡 ป้องกันเรียกตอน Widget ถูกทำลาย
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('http://localhost:3001/api/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return; // 💡 ตรวจสอบอีกครั้งหลังได้ข้อมูลจาก await

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        List<dynamic> roomData = decodedData is List
            ? decodedData
            : (decodedData['data'] ?? []);

        setState(() {
          rooms = roomData.map((json) => MeetingRoom.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching rooms: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =======================================================
  // 🗑️ ฟังก์ชันลบห้องออกจากฐานข้อมูล (DELETE)
  // =======================================================
  Future<void> _deleteRoomFromAPI(String roomId) async {
    // ตรวจสอบ context ก่อนใช้ showDialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      final response = await http.delete(
        Uri.parse('http://localhost:3001/api/rooms/$roomId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (mounted) Navigator.pop(context); // ปิด Loading (เช็ค mounted ก่อนปิด)

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ลบห้องประชุมสำเร็จ',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.green,
            ),
          );
          _fetchRooms(); // ดึงข้อมูลใหม่
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'เกิดข้อผิดพลาดในการลบ',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'เชื่อมต่อเซิร์ฟเวอร์ผิดพลาด',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(String roomId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFBC0101),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ยืนยันการลบห้อง',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                    fontFamily: 'Kanit',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'คุณต้องการลบห้องนี้ใช่หรือไม่?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0D47A1),
                    fontFamily: 'Kanit',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext); // ปิด Popup ยืนยัน
                            _deleteRoomFromAPI(roomId); // เรียกฟังก์ชันลบจริง
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB70000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ลบห้อง',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0096C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminGroupPage()),
            );
          },
        ),
        title: const Text(
          'ห้องประชุม',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Kanit',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 1, 148, 188),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MobileFrameAddRoomContainer(),
                    ),
                  ).then((_) => _fetchRooms()); // โหลดใหม่เมื่อกลับมาหน้านี้
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'เพิ่มห้องประชุม',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : (rooms.isEmpty
                      ? const Center(
                          child: Text(
                            'ยังไม่มีห้องประชุมในระบบ',
                            style: TextStyle(
                              fontFamily: 'Kanit',
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            return _buildRoomCard(rooms[index], index);
                          },
                        )),
          ),
        ],
      ),
    );
  }

  // 💡 _buildRoomCard โค้ดเดิมของคุณ นำมาใช้งานต่อได้เลย
  Widget _buildRoomCard(MeetingRoom room, int index) {
    bool isAvailable = room.status == 'ว่างพร้อมใช้งาน';
    Color statusColor = isAvailable
        ? const Color(0xFF2EC4B6)
        : const Color(0xFFE11D48);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 310,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: room.imagePath != null
                      ? (room.imagePath!.startsWith('http')
                            ? Image.network(
                                room.imagePath!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) =>
                                    _buildImagePlaceholder(),
                              )
                            : (kIsWeb
                                  ? Image.network(
                                      room.imagePath!,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(room.imagePath!),
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )))
                      : _buildImagePlaceholder(),
                ),

                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: statusColor, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          room.status,
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

                Positioned(
                  top: 120,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ค้นหาตำแหน่งที่แสดงชื่อห้องใน _buildRoomCard แล้วเปลี่ยนเป็น:
                        Text(
                          'ห้องประชุม ${room.location} ฝั่ง ${room.side}', // ตั้งคำว่า ห้องประชุม ตายตัวที่นี่
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Kanit',
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ส่วนแสดง ชั้น และ ฝั่ง
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildIconDetail(
                              Icons.layers,
                              'ชั้น ${room.location}',
                            ), // แสดงค่าจากฟิลด์ location 
                            const SizedBox(width: 15),
                            _buildIconDetail(
                              Icons.location_on_outlined,
                              'ฝั่ง ${room.side}',
                            ), // แสดงค่าจากฟิลด์ side
                          ],
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildIconDetail(
                              Icons.people_outline,
                              'รองรับสูงสุด ${room.capacity} ท่าน',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTag('โปรเจคเตอร์'),
                            const SizedBox(width: 8),
                            _buildTag('สมาร์ททีวี'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [_buildTag('กระดานไวท์บอร์ด')],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'แก้ไขห้อง',
                    const Color(0xFF0096C7),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MobileFrameEditRoomContainer(
                            room: room,
                            index: index,
                          ),
                        ),
                      ).then((_) => _fetchRooms());
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    'ลบห้อง',
                    const Color(0xFFB70000),
                    () => _showDeleteConfirmDialog(room.id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 50, color: Colors.grey),
    );
  }

  static Widget _buildIconDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blueGrey,
            fontFamily: 'Kanit',
          ),
        ),
      ],
    );
  }

  static Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
          fontFamily: 'Kanit',
        ),
      ),
    );
  }

  static Widget _buildActionButton(
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Kanit',
          ),
        ),
      ),
    );
  }
}
