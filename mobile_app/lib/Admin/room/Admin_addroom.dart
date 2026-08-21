import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'Admin_addsuccess.dart';
import 'Admin_roompage.dart';
import '../../Booking_room/Room_model.dart';
import 'package:flutter/foundation.dart';

class MobileFrameAddRoomContainer extends StatelessWidget {
  const MobileFrameAddRoomContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AddMeetingRoomScreen();
  }
}

class AddMeetingRoomScreen extends StatefulWidget {
  const AddMeetingRoomScreen({Key? key}) : super(key: key);

  @override
  _AddMeetingRoomScreenState createState() => _AddMeetingRoomScreenState();
}

class _AddMeetingRoomScreenState extends State<AddMeetingRoomScreen> {
  // 🟢 เพิ่ม Controller สำหรับรับชื่อห้อง
  final TextEditingController roomNameController = TextEditingController();
  
  int floorNumber = 1;
  String selectedSide = 'A';
  int capacity = 4;
  
  // 🟢 เพิ่มตัวแปรสำหรับเก็บสถานะ
  String selectedStatus = 'AVAILABLE';

  XFile? _imageFile;
  Uint8List? _imageBytes; 
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    roomNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  void _showAddRoomConfirmDialog() {
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.note_add_outlined,
                      size: 64,
                      color: Color(0xFF0D47A1),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ยืนยันการเพิ่มห้อง',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'คุณต้องการเพิ่มห้องใช่หรือไม่?',
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
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      setStateDialog(() {
                                        isSubmitting = true; 
                                      });

                                      try {
                                        final String baseUrl = kIsWeb
                                            ? 'http://localhost:3001'
                                            : 'http://localhost:3001';
                                        var uri = Uri.parse('$baseUrl/api/rooms');
                                        var request = http.MultipartRequest('POST', uri);

                                        final prefs = await SharedPreferences.getInstance();
                                        final token = prefs.getString('token') ?? '';

                                        request.headers.addAll({
                                          'Accept': 'application/json',
                                          'Authorization': 'Bearer $token',
                                        });

                                        // 🟢 แก้ไขการส่งข้อมูลชื่อห้องและสถานะให้ดึงจาก Form
                                        request.fields['roomName'] = roomNameController.text.isNotEmpty 
                                            ? roomNameController.text 
                                            : 'Floor $floorNumber - Side $selectedSide';
                                        request.fields['location'] = 'Floor $floorNumber - Side $selectedSide';
                                        request.fields['capacity'] = capacity.toString();
                                        request.fields['status'] = selectedStatus;

                                        if (_imageBytes != null && _imageFile != null) {
                                          String finalFileName = _imageFile!.name;
                                          String lowerName = finalFileName.toLowerCase();
                                          if (!lowerName.endsWith('.png') &&
                                              !lowerName.endsWith('.jpg') &&
                                              !lowerName.endsWith('.jpeg')) {
                                            finalFileName = 'room_image.png';
                                          }

                                          var multipartFile = http.MultipartFile.fromBytes(
                                            'image',
                                            _imageBytes!,
                                            filename: finalFileName,
                                          );
                                          request.files.add(multipartFile);
                                        }

                                        var response = await request.send();

                                        if (response.statusCode == 201 || response.statusCode == 200) {
                                          final respStr = await response.stream.bytesToString();
                                          try {
                                            final jsonResp = json.decode(respStr);
                                            final roomData = jsonResp['data'] ?? jsonResp; 

                                            if (roomData != null) {
                                              final newRoom = MeetingRoom(
                                              // 🟢 ใส่คู่วงเล็บครอบแล้วเติม .toString()
                                              id: (roomData['id'] ?? DateTime.now().millisecondsSinceEpoch).toString(), 
                                              roomName: roomData['roomName'] ?? request.fields['roomName'],
                                              location: roomData['location'] ?? request.fields['location'],
                                              capacity: roomData['capacity'] is int
                                                  ? roomData['capacity']
                                                  : (int.tryParse(roomData['capacity'].toString()) ?? capacity),
                                              imagePath: roomData['uploadUrl'] ?? roomData['imagePath'] ?? '',
                                              status: roomData['status'] ?? selectedStatus,
                                            );

                                              final updatedList = List<MeetingRoom>.from(globalMeetingRooms.value);
                                              updatedList.add(newRoom);
                                              globalMeetingRooms.value = updatedList; 
                                            }
                                          } catch (e) {
                                            debugPrint('⚠️ [Flutter] Parse Room Error: $e');
                                          }

                                          if (mounted) {
                                            Navigator.pop(dialogContext); 
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const MobileFrameSuccessContainer(),
                                              ),
                                            );
                                          }
                                        } else {
                                          String errorMessage = 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์ (Code: ${response.statusCode})';
                                          try {
                                            final responseBody = await response.stream.bytesToString();
                                            final errorData = jsonDecode(responseBody);
                                            errorMessage = errorData['message'] ?? errorMessage;
                                          } catch (parseError) {}

                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  errorMessage,
                                                  style: const TextStyle(fontFamily: 'Kanit'),
                                                ),
                                                backgroundColor: const Color(0xFFB70000),
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ โปรดตรวจสอบอินเทอร์เน็ต',
                                                style: TextStyle(fontFamily: 'Kanit'),
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setStateDialog(() {
                                            isSubmitting = false;
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0096C7),
                                disabledBackgroundColor: Colors.grey, 
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'ตกลง',
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
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB70000),
                                disabledBackgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                elevation: 0,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'เพิ่มห้องประชุม',
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildImagePickerCard(),
                  const SizedBox(height: 40),
                  _buildFormCard(),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              bottom: 24.0,
            ),
            child: SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0096C7),
                  shadowColor: Colors.black38,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                ),
                onPressed: () {
                  _showAddRoomConfirmDialog();
                },
                child: const Text(
                  'ต่อไป',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kanit',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'เลือกรูปห้องประชุม',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'Kanit',
            ),
          ),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 110,
              height: 65,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(14),
                image: _imageBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_imageBytes!), 
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageBytes == null
                  ? const Center(
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.black38,
                        size: 24,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🟢 เพิ่ม TextField สำหรับชื่อห้องประชุม
          const Text(
            'ชื่อห้องประชุม',
            style: TextStyle(
              color: Color(0xFF9BB1BD),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: roomNameController,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0D47A1)),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ชั้นที่',
                      style: TextStyle(
                        color: Color(0xFF9BB1BD),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCustomStepper(
                      value: floorNumber,
                      onMinus: () {
                        if (floorNumber > 1) setState(() => floorNumber--);
                      },
                      onPlus: () {
                        setState(() => floorNumber++);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ฝั่ง',
                      style: TextStyle(
                        color: Color(0xFF9BB1BD),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kanit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSideToggleButton('A'),
                        const SizedBox(width: 10),
                        _buildSideToggleButton('B'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 🟢 เพิ่มส่วนเลือกสถานะห้องประชุม
          const SizedBox(height: 25),
          const Text(
            'สถานะห้องประชุม',
            style: TextStyle(
              color: Color(0xFF9BB1BD),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 10),
          _buildStatusToggle(),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 25),
            child: Divider(color: Color(0xFFE8EFF2), thickness: 1.2),
          ),

          const Text(
            'รองรับได้ทั้งหมด (คน)',
            style: TextStyle(
              color: Color(0xFF9BB1BD),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Kanit',
            ),
          ),
          const SizedBox(height: 14),

          _buildCapacityStepper(),
        ],
      ),
    );
  }

  Widget _buildSideToggleButton(String side) {
    bool isSelected = selectedSide == side;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedSide = side),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF3F9) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00529B).withOpacity(0.5)
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              side,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF00529B) : Colors.black54,
                fontFamily: 'Kanit',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomStepper({
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove, size: 16, color: Color(0xFF00529B)),
            onPressed: onMinus,
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add, size: 16, color: Color(0xFF00529B)),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityStepper() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: Color(0xFF0D47A1), size: 18),
            onPressed: () {
              if (capacity > 1) setState(() => capacity--);
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: Color(0xFF9BB1BD),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                '$capacity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Kanit',
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF0D47A1), size: 18),
            onPressed: () => setState(() => capacity++),
          ),
        ],
      ),
    );
  }

  // 🟢 Widget สำหรับเลือกสถานะ
  Widget _buildStatusToggle() {
    final statuses = [
      {'label': 'ว่าง', 'value': 'AVAILABLE', 'color': const Color(0xFF2EC4B6)},
      {'label': 'จองแล้ว', 'value': 'RESERVED', 'color': Colors.orange},
      {'label': 'กำลังใช้งาน', 'value': 'IN_USE', 'color': const Color(0xFFE11D48)},
    ];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: statuses.map((item) {
          final String statusValue = item['value'] as String;
          final String statusLabel = item['label'] as String;
          final Color statusColor = item['color'] as Color;
          bool isSelected = selectedStatus == statusValue;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedStatus = statusValue),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? statusColor.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: isSelected ? statusColor : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Kanit',
                        fontWeight: FontWeight.bold,
                        color: isSelected ? statusColor : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}