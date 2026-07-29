import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Room_model.dart';
import 'Room_booking.dart';

class RoomListScreen extends StatefulWidget {
  final bool isGuest;
  const RoomListScreen({
    super.key,
    this.isGuest = false,
  });

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoomsFromApi();
  }

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
        if (mounted) {
          await prefs.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'เซสชันหมดอายุ หรือมีการเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่',
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
      } else {
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
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // ปรับพื้นหลังให้เข้ากับ UI ใหม่
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
              'เลือกห้องที่ต้องการ',
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
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF004381)),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchRoomsFromApi,
                    color: const Color(0xFF004381),
                    child: ValueListenableBuilder<List<MeetingRoom>>(
                      valueListenable: globalMeetingRooms,
                      builder: (context, rooms, child) {
                        if (rooms.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
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

  // 🟢 ฟังก์ชันสร้าง Step รูปแบบใหม่
  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepItem(step: '1', title: 'เลือกห้อง', isActive: true),
          _buildStepLine(),
          _buildStepItem(step: '2', title: 'กรอกข้อมูล', isActive: false),
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

  Widget _buildRoomCard(MeetingRoom room) {
    bool isAvailable = room.status == 'AVAILABLE';
    Color statusColor;
    
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
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: _buildImage(room.imagePath),
              ),
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
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: widget.isGuest
                        ? null
                        : () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RoomBookingAScreen(room: room),
                              ),
                            );
                            if (result == true) {
                              if (!mounted) return;
                              setState(() {
                                isLoading = true;
                              });
                              _fetchRoomsFromApi();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A8CC),
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
        Icon(icon, size: 18, color: const Color(0xFF004381)),
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