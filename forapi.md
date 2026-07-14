
```markdown
# 🔌 Frontend API Integration Constitution (คู่มือการเชื่อมต่อ UI สวยงามเข้ากับ API หลังบ้าน)

เอกสารฉบับนี้ใช้สำหรับเป็นแนวทางเมื่อได้รับ "หน้าจอ UI เปล่าๆ ที่จัดเรียงสวยงามแล้ว" จากทีม UI และต้องการนำมาเชื่อมต่อกับ "Backend API" ที่มีอยู่จริง โดยห้ามทำลายความสวยงามของ UI และห้ามเปลี่ยนแปลงโครงสร้างของ Backend

## 🗂️ 1. โครงสร้าง API ปัจจุบัน (Backend API Inventory)
อ้างอิงจากโครงสร้าง Controller และ Route ของระบบ ให้ใช้ Endpoint เหล่านี้ในการดึง/ส่งข้อมูลเท่านั้น:

### 🔐 Auth & Users (การยืนยันตัวตน)
- `POST /api/auth/login-pin` : ล็อกอินด้วย PIN (รับ Token)
- Route ไฟล์: `routes/auth.js` | Controller: `middlewares/auth.js`

### 🏢 Rooms (ระบบห้องประชุม)
- `GET /api/rooms` : ดึงรายการห้องประชุมทั้งหมด (กรอง isDeleted: false)
- `POST /api/rooms` : สร้างห้องประชุมใหม่ (รองรับ Multipart/รูปภาพ)
- `PUT /api/rooms/:id` : แก้ไขข้อมูลห้องประชุม
- `DELETE /api/rooms/:id` : ลบห้องประชุม (Soft Delete)
- Route ไฟล์: `routes/rooms.js` | Controller: `controllers/roomController.js`

### 🚗 Vehicles (ระบบยานพาหนะ)
- `GET /api/vehicles` : ดึงรายการยานพาหนะทั้งหมด
- `POST /api/vehicles` : เพิ่มยานพาหนะใหม่
- `PUT /api/vehicles/:id` : แก้ไขยานพาหนะ
- `DELETE /api/vehicles/:id` : ลบยานพาหนะ (Soft Delete)
- Route ไฟล์: `routes/vehicles.js` | Controller: `controllers/vehicleController.js`

### 📅 Bookings (ระบบการจอง)
- `GET/POST /api/bookings` : จองห้องประชุม (Route: `routes/bookings.js` | Controller: `bookingController.js`)
- `GET/POST /api/vehicle-bookings` : จองรถยนต์ (Route: `routes/vehicleBookings.js` | Controller: `vehicleBookingController.js`)

*(หมายเหตุ: ไฟล์ `roomRouter.js` และ `vehicleBookingRoutes.js` ที่ซ้ำซ้อน แนะนำให้ลบออกหรือเพิกเฉย เพื่อป้องกันความสับสน ใช้แค่ไฟล์ที่มี `s` ต่อท้ายเป็นหลัก)*

---

## 🛠️ 2. กฎการเชื่อม UI เข้ากับ API (The Binding Rules)

เมื่อได้ไฟล์ UI สวยๆ จากเพื่อนมา ให้ทำตามขั้นตอนการ "Inject Logic" ดังนี้:

### Rule 20 — Model Mapping First
ห้ามโยน JSON สดๆ เข้าไปใน UI เด็ดขาด ต้องสร้าง/อัปเดตไฟล์ Model ในโฟลเดอร์ `lib/models/` ก่อน (เช่น `Vehicle_model.dart`) และใช้ `factory fromJson` ในการรับข้อมูลจาก API เท่านั้น

### Rule 21 — Token is Mandatory
การเรียก API (ยกเว้น Login) **ต้องแนบ JWT Token** ใน Header เสมอ:
```dart
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('token') ?? '';
final response = await http.get(
  url,
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${token.trim()}',
  },
);

```

### Rule 22 — Base URL Standard

เพื่อให้เทสต์ได้ทั้ง Web และ Mobile ให้ประกาศ URL ตามมาตรฐานนี้เสมอ ห้าม Hardcode IP ตรงๆ ในฟังก์ชัน:

```dart
final baseUrl = kIsWeb ? 'http://localhost:3001' : '[http://10.0.2.2:3001](http://10.0.2.2:3001)';
final url = Uri.parse('$baseUrl/api/vehicles');

```

### Rule 23 — Use ValueNotifier for State (ตามสถาปัตยกรรมเดิม)

ห้ามใช้ `setState` พร่ำเพรื่อในการอัปเดต UI รายการใหญ่ๆ ให้ใช้ `ValueNotifier` และ `ValueListenableBuilder` ที่ครอบเฉพาะส่วนของ List UI เท่านั้น เพื่อรักษาความลื่นไหลของหน้าจอที่เพื่อนออกแบบมา:

```dart
// 1. ประกาศตัวแปร (Business Logic)
final ValueNotifier<List<Vehicle>> globalVehicles = ValueNotifier([]);

// 2. นำไปครอบ UI ของเพื่อน (Presentation Logic)
ValueListenableBuilder<List<Vehicle>>(
  valueListenable: globalVehicles,
  builder: (context, vehicles, child) {
    // เอา Widget UI Card สวยๆ ของเพื่อนมาใส่ในนี้
  }
)

```

---

## 🔄 3. Workflow: 4 ขั้นตอนชุบชีวิต UI เปล่า (Bring UI to Life)

1. **Keep the Shell:** เปิดไฟล์ UI ของเพื่อนขึ้นมา ปล่อยโครงสร้าง (Scaffold, AppBar, Colors, Padding) ไว้ที่เดิม
2. **Inject the State:** เพิ่มตัวแปร `isLoading`, `ValueNotifier` และฟังก์ชัน `_fetch...FromApi()` ไว้ด้านบนของคลาส `State`
3. **Trigger on Start:** เรียกใช้ฟังก์ชันดึง API ใน `initState()`
4. **Replace Hardcoded Data:** ไปที่โค้ดส่วนที่เพื่อนจำลองข้อมูลไว้ (Mock Data) แล้วแทนที่ด้วยตัวแปรจาก Model ที่ดึงมาจาก API (`room.roomName`, `vehicle.plateNumber`)

## 🚨 4. UI Fallback (การรองรับข้อผิดพลาดบนหน้าจอ)

เมื่อต่อ API จริง UI ของเพื่อนต้องสามารถรองรับ 3 สถานะนี้ได้ (ถ้าเพื่อนไม่ได้ทำมา คุณต้องเติมเข้าไปโดยอิง Theme เดิม):

1. **Loading State:** ระหว่างรอ API (`CircularProgressIndicator` สีตาม Theme)
2. **Empty State:** เมื่อดึงแล้วไม่มีข้อมูล (โชว์ข้อความ "ยังไม่มีข้อมูล..." สีเทา ตรงกลางจอ)
3. **Error State:** เมื่อเชื่อมต่อหลังบ้านไม่ได้ (โชว์ SnackBar หรือ Pop-up สีแดง แต่หน้าจอต้องไม่พัง)

```

---

### 📝 อธิบายการเปลี่ยนแปลง (Rule 10)
1. **ทำไมต้องเพิ่มสิ่งนี้:** เพราะโปรเจกต์มาถึงจุดเปลี่ยนผ่านสำคัญ (Transition Phase) จาก UI เปล่า (Mockup) มาสู่แอปที่ดึงข้อมูลจริง (Data-driven) ถ้าไม่มีคู่มือนี้ คุณอาจเผลอทำลาย Layout ของเพื่อนตอนพยายามยัด API เข้าไป หรือเพื่อนอาจจะเขียน UI โดยไม่เว้นที่ว่างให้สถานะ Loading
2. **ผลกระทบ:** ทำให้การแบ่งงานชัดเจน 100% (เพื่อน = ดีไซเนอร์, คุณ = ช่างไฟที่เดินสายไฟ API เข้าไปในตึกที่สร้างเสร็จแล้ว)
3. **สิ่งที่เปลี่ยนไป:** เพิ่มมาตรฐานการดึง API, ระบุ Endpoint ที่อ้างอิงจากโครงสร้างจริงของโฟลเดอร์ `backend/src/` เพื่อให้ทำงานได้ตรงจุด ไม่มีเดาสุ่มครับ
