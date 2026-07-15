import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'Admin_addroom.dart';
import 'Admin_editroom.dart'; 
import '../../Booking_room/Room_model.dart'; 
import '../../AdminGroupPage.dart'; // ดึงเข้ามารองรับปุ่มออกจากระบบ เพื่อกลับไปหน้าเลือกสิทธิ์

// 💡 รายการข้อมูลส่วนกลาง ValueNotifier
final ValueNotifier<List<MeetingRoom>> globalMeetingRooms = ValueNotifier<List<MeetingRoom>>([
  
]);

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
          child: ValueListenableBuilder<List<MeetingRoom>>(
            valueListenable: globalMeetingRooms,
            builder: (context, rooms, child) {
              return const MeetingRoomListScreen();
            },
          ),
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
  
  void _showDeleteConfirmDialog(int index) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Color(0xFFBC0101), shape: BoxShape.circle),
                  child: const Icon(Icons.priority_high, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 20),
                const Text('ยืนยันการลบห้อง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontFamily: 'Kanit')),
                const SizedBox(height: 6),
                const Text('คุณต้องการลบห้องนี้ใช่หรือไม่?', style: TextStyle(fontSize: 13, color: Color(0xFF0D47A1), fontFamily: 'Kanit'), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            final updatedList = List<MeetingRoom>.from(globalMeetingRooms.value);
                            updatedList.removeAt(index);
                            globalMeetingRooms.value = updatedList;
                            
                            setState(() {}); 
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB70000), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('ลบห้อง', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0096C7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('ยกเลิก', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
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
    final rooms = globalMeetingRooms.value;

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
        title: const Text('ห้องประชุม', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Kanit')),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MobileFrameAddRoomContainer()),
                  ).then((_) => setState(() {}));
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('เพิ่มห้องประชุม', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: rooms.isEmpty
                ? const Center(child: Text('ยังไม่มีห้องประชุมในระบบ', style: TextStyle(fontFamily: 'Kanit', color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomCard(rooms[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

 Widget _buildRoomCard(MeetingRoom room, int index) {
    bool isAvailable = room.status == 'ว่างพร้อมใช้งาน';
    Color statusColor = isAvailable ? const Color(0xFF2EC4B6) : const Color(0xFFE11D48);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Column(
        children: [
          // 💡 ส่วนของการทำภาพและกล่องข้อมูลลอยซ้อนเกยกัน
          SizedBox(
            height: 310, // ล็อกความสูงรวมของส่วนแสดงผลด้านบนเพื่อไม่ให้เบียดกัน
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. ตัวรูปภาพประชุม (หรือกล่องสีเทา) วางเต็มพื้นที่ด้านบน
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: room.imagePath != null
                      ? (kIsWeb 
                          ? Image.network(room.imagePath!, height: 180, width: double.infinity, fit: BoxFit.cover)
                          : Image.file(File(room.imagePath!), height: 180, width: double.infinity, fit: BoxFit.cover))
                      : Container(
                          height: 180, 
                          width: double.infinity, 
                          color: Colors.grey[300], 
                          child: const Icon(Icons.image, size: 50, color: Colors.grey),
                        ),
                ),
                
                // 2. ป้ายสถานะ เกาะอยู่ที่มุมบนขวาของรูปภาพอย่างถูกต้อง
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: statusColor, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          room.status,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor, fontFamily: 'Kanit'),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. 🔥 กล่องทรงมนสีขาวลอยขึ้นมาเกยทับรูปภาพ (จัดตำแหน่งโดยใช้ Positioned)
                Positioned(
                  top: 120, // ดันลงมาให้อยู่กึ่งกลางรอยต่อขอบภาพพอดี
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32), // มนกลมสวยงามตาม image_cd9329.png
                      border: Border.all(color: Colors.grey.shade100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ห้องประชุม ชั้น ${room.floor}', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Kanit')
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildIconDetail(Icons.location_on_outlined, 'ชั้น ${room.floor} ฝั่ง ${room.side}'),
                            _buildIconDetail(Icons.people_outline, 'รองรับสูงสุด ${room.capacity} ท่าน'),
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
          
          // ส่วนล่างสุด: ปุ่มแก้ไขและลบห้อง
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'แก้ไขห้อง',
                    const Color(0xFF0096C7), // เปลี่ยนโทนสีฟ้าตามดีไซน์ต้นฉบับ
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MobileFrameEditRoomContainer(
                            room: room,
                            index: index,
                          ),
                        ),
                      ).then((_) => setState(() {})); 
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    'ลบห้อง',
                    const Color(0xFFB70000), // เปลี่ยนโทนสีแดงเข้มตามดีไซน์ต้นฉบับ
                    () => _showDeleteConfirmDialog(index),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildIconDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'Kanit')),
      ],
    );
  }

  static Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Kanit')),
    );
  }

  static Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: () {
                        onTap();
        },
        style: ElevatedButton.styleFrom(backgroundColor: color, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
      ),
    );
  }
}