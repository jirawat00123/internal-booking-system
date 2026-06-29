// room_model.dart

// 💡 1. คลาสโมเดลสำหรับเก็บข้อมูลห้องประชุม
class MeetingRoom {
  final String id;          // ไอดีห้อง (เช่น A, B, C)
  final String floor;       // ชั้น (เช่น 1, 2, 3)
  final String side;        // ฝั่ง (เช่น A, B, นอร์ธ)
  final int capacity;       // จำนวนผู้เข้าร่วมสูงสุด
  final String? imagePath;  // ที่อยู่รูปภาพ (Path ไฟล์ หรือ URL)
  final String status;      // สถานะห้อง (เช่น 'ว่างพร้อมใช้งาน', 'กำลังใช้งาน')

  MeetingRoom({
    required this.id,
    required this.floor,
    required this.side,
    required this.capacity,
    this.imagePath,
    this.status = 'ว่างพร้อมใช้งาน', // ค่าเริ่มต้นกำหนดให้เป็นห้องว่าง
  });

  // ฟังก์ชันสําหรับก๊อปปี้ข้อมูลและเปลี่ยนบางค่า (มีประโยชน์มากเวลาทำระบบแก้ไขข้อมูล)
  MeetingRoom copyWith({
    String? id,
    String? floor,
    String? side,
    int? capacity,
    String? imagePath,
    String? status,
  }) {
    return MeetingRoom(
      id: id ?? this.id,
      floor: floor ?? this.floor,
      side: side ?? this.side,
      capacity: capacity ?? this.capacity,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
    );
  }
}

// 💡 2. ตัวแปรส่วนกลาง (Global Data Source) ที่แชร์ข้อมูลร่วมกันทั้งแอป
// ทุกหน้าที่อ้างอิงรายชื่อนี้ จะเห็นข้อมูลชุดเดียวกันทั้งหมด
List<MeetingRoom> globalMeetingRooms = [
  MeetingRoom(
    id: 'A', 
    floor: '1', 
    side: 'A', 
    capacity: 12, 
    status: 'ว่างพร้อมใช้งาน',
  ),
  MeetingRoom(
    id: 'B', 
    floor: '1', 
    side: 'A', 
    capacity: 12, 
    status: 'กำลังใช้งาน',
  ),
];