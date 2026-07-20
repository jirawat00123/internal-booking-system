import 'dart:io'; 
import 'package:http/http.dart' as http; // 💡 ดึง API
import 'package:shared_preferences/shared_preferences.dart'; // 💡 จัดการ Token
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'Admin_roompage.dart'; 
import 'Admin_editsuccess.dart'; 
import '../../Booking_room/Room_model.dart'; 

// ... (MobileFrameEditRoomContainer เหมือนเดิมเป๊ะ)
class MobileFrameEditRoomContainer extends StatelessWidget {
  final MeetingRoom room;
  final int index;

  const MobileFrameEditRoomContainer({super.key, required this.room, required this.index});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[900],
      child: Center(
        child: Container(
          width: 400, height: 800, clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)]),
          child: AdminEditRoomScreen(room: room, index: index),
        ),
      ),
    );
  }
}

class AdminEditRoomScreen extends StatefulWidget {
  final MeetingRoom room;
  final int index;
  const AdminEditRoomScreen({Key? key, required this.room, required this.index}) : super(key: key);
  @override
  _AdminEditRoomScreenState createState() => _AdminEditRoomScreenState();
}

class _AdminEditRoomScreenState extends State<AdminEditRoomScreen> {
  late int floorNumber;
  late String selectedSide;
  late int capacity;
  late String selectedStatus; 
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    floorNumber = widget.room.location;
    selectedSide = widget.room.side;
    capacity = widget.room.capacity;
    selectedStatus = widget.room.status; 
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _imageFile = pickedFile);
  }

  // =======================================================
  // 🚀 ฟังก์ชันแก้ไขข้อมูลเข้าฐานข้อมูล (PUT)
  // =======================================================
  Future<void> _updateRoomToAPI(BuildContext dialogContext) async {
    Navigator.pop(dialogContext); 
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator())); 
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      var request = http.MultipartRequest('PUT', Uri.parse('http://localhost:3001/api/rooms/${widget.room.id}'));
      request.headers['Authorization'] = 'Bearer $token';
      
      request.fields['name'] = selectedSide; 
      request.fields['location'] = floorNumber.toString(); 
      request.fields['capacity'] = capacity.toString();
      
      // อัปเดตสถานะ (แปลงกลับเป็น EN เพื่อให้ตรงกับ Prisma Schema Enum ของคุณ)
      request.fields['status'] = selectedStatus == 'ว่างพร้อมใช้งาน' ? 'AVAILABLE' : 'IN_USE';

      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      Navigator.pop(context); 

      if (response.statusCode == 200) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MobileFrameEditSuccessContainer()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาดในการแก้ไข', style: TextStyle(fontFamily: 'Kanit')), backgroundColor: Colors.red));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ผิดพลาด', style: TextStyle(fontFamily: 'Kanit')), backgroundColor: Colors.red));
    }
  }

  void _showEditConfirmDialog() {
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
                const Icon(Icons.edit_note_outlined, size: 64, color: Color(0xFF0D47A1)),
                const SizedBox(height: 16),
                const Text('ยืนยันการแก้ไข', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontFamily: 'Kanit')),
                const SizedBox(height: 6),
                const Text('คุณต้องการบันทึกการแก้ไขใช่หรือไม่?', style: TextStyle(fontSize: 13, color: Color(0xFF0D47A1), fontFamily: 'Kanit')),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => _updateRoomToAPI(dialogContext), // 💡 ใช้ API
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0096C7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('ตกลง', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB70000), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('ยกเลิก', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
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

  // 💡 โค้ด UI ส่วนล่างของไฟล์ _AdminEditRoomScreenState เหมือนเดิมครับ วางต่อได้เลย
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('แก้ไขห้องประชุม', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Kanit')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(children: [const SizedBox(height: 10), _buildImageEditCard(), const SizedBox(height: 40), _buildFormCard()]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
            child: SizedBox(
              width: 220, height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0096C7), elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0))),
                onPressed: _showEditConfirmDialog,
                child: const Text('ต่อไป', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageEditCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF0096C7).withOpacity(0.3)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('เปลี่ยนรูปห้องประชุม', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 110, height: 65,
              decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(14),
                image: _imageFile != null 
                  ? DecorationImage(image: FileImage(File(_imageFile!.path)), fit: BoxFit.cover)
                  : (widget.room.imagePath != null ? DecorationImage(image: NetworkImage(widget.room.imagePath!), fit: BoxFit.cover) : null), // 💡 ใช้ NetworkImage ถ้าดึงมาจากหลังบ้าน
              ),
              child: _imageFile == null && widget.room.imagePath == null ? const Center(child: Icon(Icons.camera_alt, color: Colors.white70, size: 24)) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('ชั้นที่', style: TextStyle(color: Color(0xFF9BB1BD), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                    const SizedBox(height: 8),
                    _buildStepper(floorNumber, (val) => setState(() => floorNumber = val)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    const Text('ฝั่ง', style: TextStyle(color: Color(0xFF9BB1BD), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                    const SizedBox(height: 8),
                    _buildSideToggle(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text('สถานะห้องประชุม', style: TextStyle(color: Color(0xFF9BB1BD), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
          const SizedBox(height: 10),
          _buildStatusToggle(),
          const Padding(padding: EdgeInsets.symmetric(vertical: 25), child: Divider(color: Color(0xFFE8EFF2))),
          const Text('รองรับได้ทั้งหมด (คน)', style: TextStyle(color: Color(0xFF9BB1BD), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
          const SizedBox(height: 14),
          _buildCapacityStepper(),
        ],
      ),
    );
  }

  Widget _buildStepper(int val, Function(int) onChange) {
    return Container(
      height: 38,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.remove, size: 14), onPressed: () => val > 1 ? onChange(val - 1) : null),
          Text('$val', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add, size: 14), onPressed: () => onChange(val + 1)),
        ],
      ),
    );
  }

  Widget _buildSideToggle() {
    return Container(
      height: 38,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: ['สำนักงาน', 'โรงงาน'].map((s) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => selectedSide = s),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(color: selectedSide == s ? const Color(0xFFEBF3F9) : Colors.white, borderRadius: BorderRadius.circular(7)),
              child: Text(s, style: TextStyle(color: selectedSide == s ? const Color(0xFF0D47A1) : Colors.black54, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildStatusToggle() {
    final statuses = ['ว่างพร้อมใช้งาน', 'ไม่ว่างพร้อมใช้งาน'];
    
    return Container(
      height: 40,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: statuses.map((status) {
          bool isSelected = selectedStatus == status;
          Color activeColor = status == 'ว่างพร้อมใช้งาน' ? const Color(0xFF2EC4B6) : const Color(0xFFE11D48);

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedStatus = status),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.12) : Colors.white, borderRadius: BorderRadius.circular(9)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, size: 8, color: isSelected ? activeColor : Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(status, style: TextStyle(fontSize: 12, fontFamily: 'Kanit', fontWeight: FontWeight.bold, color: isSelected ? activeColor : Colors.black54)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCapacityStepper() {
    return Container(
      height: 50,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.remove, color: Color(0xFF0D47A1)), onPressed: () => capacity > 1 ? setState(() => capacity--) : null),
          Row(children: [const Icon(Icons.people_alt_outlined, color: Color(0xFF9BB1BD)), const SizedBox(width: 10), Text('$capacity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          IconButton(icon: const Icon(Icons.add, color: Color(0xFF0D47A1)), onPressed: () => setState(() => capacity++)),
        ],
      ),
    );
  }
}