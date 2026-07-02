import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'Admin_addsuccess.dart'; 
import 'Admin_roompage.dart'; 
import 'Room_model.dart'; 

class MobileFrameAddRoomContainer extends StatelessWidget {
  const MobileFrameAddRoomContainer({super.key});

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
          child: const AddMeetingRoomScreen(), 
        ),
      ),
    );
  }
}

class AddMeetingRoomScreen extends StatefulWidget {
  const AddMeetingRoomScreen({Key? key}) : super(key: key);

  @override
  _AddMeetingRoomScreenState createState() => _AddMeetingRoomScreenState();
}

class _AddMeetingRoomScreenState extends State<AddMeetingRoomScreen> {
  int floorNumber = 1;
  String selectedSide = 'A';
  int capacity = 4;

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  void _showAddRoomConfirmDialog() {
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
                          onPressed: () {
                            // 💡 แก้ไขจุดบันทึกข้อมูลเรียลไทม์: แปลงดึงข้อมูลอาเรย์ชุดเดิมออกมาและสร้างอันใหม่เพื่อยิงสัญญาณอัปเดตไปทุกหน้าจอค้าง
                            final updatedList = List<MeetingRoom>.from(globalMeetingRooms.value);
                            
                            // จำลองสุ่มหรือใช้ ID อิงตามสัดส่วนความยาว
                            String generatedId = '${floorNumber}0${updatedList.length + 1}';
                            
                            updatedList.add(
                              MeetingRoom(
                                id: generatedId, 
                                floor: floorNumber.toString(),
                                side: selectedSide,
                                capacity: capacity,
                                imagePath: _imageFile?.path, 
                                status: 'ว่างพร้อมใช้งาน',
                              ),
                            );
                            
                            globalMeetingRooms.value = updatedList; // ข้อมูลเปลี่ยนเรียลไทม์ทันทีในพริบตา!

                            Navigator.pop(dialogContext); 
                            
                            debugPrint('บันทึกข้อมูลเข้าสู่ globalMeetingRooms (ValueNotifier) เรียบร้อยแล้ว');

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MobileFrameSuccessContainer(), 
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0096C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ตกลง',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit'),
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
                            backgroundColor: const Color(0xFFB70000),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit'),
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
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Kanit'),
          ),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 110,
              height: 65,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(14),
                image: _imageFile != null
                    ? DecorationImage(
                        image: FileImage(File(_imageFile!.path)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageFile == null
                  ? const Center(
                      child: Icon(Icons.camera_alt_outlined, color: Colors.black38, size: 24),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.camera_alt, color: Colors.white70, size: 18),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ชั้นที่', style: TextStyle(color: Color(0xFF9BB1BD), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                    const SizedBox(height: 10),
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
                  children: [
                    const Text('ฝั่ง', style: TextStyle(color: Color(0xFF9BB1BD), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit')),
                    const SizedBox(height: 10),
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

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Divider(color: Color(0xFFE8EFF2), thickness: 1.2),
          ),

          const Center(
            child: Text(
              'รองรับได้ทั้งหมด (คน)',
              style: TextStyle(color: Color(0xFF9BB1BD), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Kanit'),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
            icon: const Icon(Icons.remove, color: Color(0xFF00529B), size: 18),
            onPressed: () {
              if (capacity > 1) setState(() => capacity--);
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_alt_outlined, color: Color(0xFF9BB1BD), size: 24),
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
            icon: const Icon(Icons.add, color: Color(0xFF00529B), size: 18),
            onPressed: () => setState(() => capacity++),
          ),
        ],
      ),
    );
  }
}