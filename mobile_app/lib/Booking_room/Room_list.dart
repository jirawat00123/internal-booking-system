import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'Room_model.dart';
import 'Room_booking.dart';

class RoomListScreen extends StatefulWidget {
  final bool isGuest;
  const RoomListScreen({super.key, this.isGuest = false});

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
          ? 'http://192.168.88.25:3001'
          : 'http://192.168.88.25:3001';
      final prefs = await SharedPreferences.getInstance();
      // 🟢 ดึง Token จากทั้ง 'token' และ 'jwt_token' เพื่อรองรับทุก Key
      final token =
          prefs.getString('token') ?? prefs.getString('jwt_token') ?? '';

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

        debugPrint('🏢 Rooms API response: ${response.body}');

        final activeRooms = roomsData.where((e) {
          return e['isDeleted'] == false || e['isDeleted'] == 'false';
        }).toList();

        debugPrint('🏢 Active rooms count: ${activeRooms.length}');

        for (final room in activeRooms) {
          debugPrint('🏢 Room ID: ${room['id']}');
          debugPrint('🏢 Room Name: ${room['roomName']}');
          debugPrint('🖼️ uploadUrl: ${room['uploadUrl']}');
        }

        globalMeetingRooms.value = activeRooms
            .map((e) => MeetingRoom.fromJson(e))
            .toList();

        for (final room in globalMeetingRooms.value) {
          debugPrint('🖼️ Parsed imagePath [${room.id}]: ${room.imagePath}');
        }
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
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => isLoading = false);
        });
      }
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
                ? ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: 3,
                    itemBuilder: (context, index) => _buildShimmerRoomCard(),
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
                            children: [
                              const SizedBox(height: 150),
                              ShowUp(
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.meeting_room,
                                        size: 80,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'ไม่มีห้องประชุมที่พร้อมใช้งาน',
                                        style: TextStyle(
                                          fontFamily: 'Kanit',
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
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
                            return ShowUp(
                              delay: index * 100,
                              child: _buildRoomCard(rooms[index]),
                            );
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

  Widget _buildShimmerRoomCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(height: 20, width: 150, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(height: 16, width: 120, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 16, width: 120, color: Colors.white),
                  const SizedBox(height: 20),
                  Container(
                    height: 46,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    String rawStatus = (room.status ?? '').toString().toUpperCase().replaceAll(
      ' ',
      '_',
    );

    bool isAvailable = rawStatus == 'AVAILABLE' || rawStatus == 'ว่าง';
    bool isReserved = rawStatus == 'RESERVED' || rawStatus == 'PENDING';
    bool isInUse = rawStatus == 'IN_USE' || rawStatus == 'กำลังใช้งาน';

    String displayStatus;
    Color statusColor;

    if (isAvailable) {
      displayStatus = 'Available';
      statusColor = const Color(0xFF2EC4B6);
    } else if (isReserved) {
      displayStatus = 'Reserved';
      statusColor = Colors.orange;
    } else if (isInUse) {
      displayStatus = 'In Use';
      statusColor = const Color(0xFFE11D48);
    } else {
      displayStatus = 'In Use';
      statusColor = const Color(0xFFE11D48);
    }

    Widget _buildImage(String? imagePath) {
      if (imagePath == null || imagePath.trim().isEmpty) {
        return Container(
          height: 180,
          width: double.infinity,
          color: Colors.grey[300],
          child: const Icon(Icons.image, size: 50, color: Colors.grey),
        );
      }

      final String baseUrl = 'http://192.168.88.25:3001';
      final String imageUrl = imagePath.startsWith('http')
          ? imagePath
          : Uri.parse('$baseUrl$imagePath').toString();

      debugPrint('🖼️ Room image URL: $imageUrl');

      return Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Room image failed: $imageUrl');
          debugPrint('❌ Image error: $error');

          return Container(
            height: 180,
            width: double.infinity,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
          );
        },
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                child: Hero(
                  tag: 'room_img_${room.id}',
                  child: _buildImage(room.imagePath),
                ),
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
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: statusColor, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        displayStatus,
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
                    // 🟢 ปลดล็อกปุ่ม ไม่เช็ก isAvailable แล้ว ให้ทุกคนกดเข้าไปจองล่วงหน้าได้เสมอ
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
                      // 🟢 สีปุ่มเป็นสีฟ้าเสมอ ไม่ต้องเป็นสีเทาแล้ว
                      backgroundColor: const Color(0xFF00A8CC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'เลือกห้องนี้', // 🟢 ข้อความปุ่มเป็น "เลือกห้องนี้" เสมอ
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
