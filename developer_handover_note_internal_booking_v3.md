# 🚀 Developer Handover Note: Internal Booking System

เอกสารส่งมอบงานสำหรับระบบจัดการและจองทรัพยากรภายในองค์กร (Meeting Room & Vehicle Booking System) เพื่อใช้เป็นบริบททางเทคนิค (Technical Context) ให้กับผู้พัฒนาหรือ AI ตัวถัดไปในการรับไม้ช่วงต่อและพัฒนาต่อได้ทันทีโดยไม่มีข้อมูลตกหล่น

---

## 1. ภาพรวมโปรเจกต์ (Project Overview)
โปรเจกต์นี้พัฒาระบบสำหรับการจองและบริหารจัดการทรัพยากรส่วนกลางภายในองค์กร โดยแบ่งออกเป็น 2 โมดูลหลักที่มีเงื่อนไขและลักษณะการทำงานเฉพาะตัว:
* **ระบบจองห้องประชุม (Meeting Room Booking):** ใช้สำหรับจองห้องประชุมเพื่อประสานงานภายในทีม ดักจับเวลาการใช้ห้องเพื่อไม่ให้เกิดการชนกัน
* **ระบบจองรถยนต์ส่วนกลาง (Vehicle Booking):** ใช้สำหรับจองยานพาหนะของบริษัทในการเดินทางไปปฏิบัติงาน มีขั้นตอนการเช็กอิน/เอาท์รถเพิ่มเติม
* **เป้าหมายสูงสุด:** บริหารจัดการคิวการใช้งานทรัพยากรอย่างมีประสิทธิภาพ ลดปัญหาการจองเวลาทับซ้อน (Collision Prevention) และจัดเก็บประวัติบันทึกกิจกรรมอย่างละเอียด (Audit Logging)

### ระบบสิทธิ์และการเข้าถึง (Role-based Access Control - RBAC)
ระบบรองรับบัญชีผู้ใช้ที่แบ่งระดับสิทธิ์การเข้าถึงและการทำงานไว้ 3 ระดับหลัก:
1.  **USER (พนักงานทั่วไป):** สามารถตรวจสอบสถานะทรัพยากรที่ว่าง ทำเรื่องจอง ดูประวัติการจองของตนเอง และยกเลิกการจองได้
2.  **ADMIN (ผู้ดูแลระบบ เช่น HR, IT):** ควบคุมสิทธิ์การใช้งาน เพิ่ม/ลด/แก้ไขข้อมูลทรัพยากร (ห้องประชุม, รถยนต์) อนุมัติหรือปฏิเสธคำขอ และเข้าดูรายงานประวัติทั้งหมด
3.  **GUARD (พนักงานรักษาความปลอดภัย):** มีสิทธิ์เฉพาะในโมดูลยานพาหนะ ทำหน้าที่ตรวจสอบและกดอนุมัติการเช็กอิน (Check-in) และเช็กเอาท์ (Check-out) รถยนต์จริงที่จุดบริการ

### ความปลอดภัยและการตรวจสอบ (Security & Observability)
* **Centralized Audit Log:** ระบบบันทึกประวัติกิจกรรมสำคัญที่เกิดขึ้นบนเซิร์ฟเวอร์ทั้งหมด (เช่น ใครทำอะไร, เวลาไหน, สำเร็จหรือไม่) ลงในตารางกลางเพื่อความโปร่งใส
* **Resource History Separation:** ประวัติและสถานะการจองจะถูกแยกตารางเก็บตามประเภททรัพยากรอย่างชัดเจน เพื่อประสิทธิภาพในการ Query และการทำ Data Analytics ในอนาคต

---

## 2. สถาปัตยกรรมและเครื่องมือที่ใช้ (Tech Stack & Tools)

| ส่วนประกอบ (Component) | เทคโนโลยีที่เลือกใช้ (Technology & Tools) |
| :--- | :--- |
| **Frontend Framework** | Flutter (Dart) |
| **State Management** | ระบบ State เบื้องต้น โดยใช้ `ValueNotifier` / `ValueListenableBuilder` |
| **Backend Framework** | Node.js (Express.js) |
| **Database Engine** | PostgreSQL |
| **Object-Relational Mapping** | Prisma Client (`prisma-client-js`) |
| **API Documentation** | Swagger UI (`swagger-ui-express`) |
| **Development IDE & Tools** | VS Code, pgAdmin |

### 2.1 โครงสร้างโฟลเดอร์ฝั่งหน้าบ้าน (Flutter Folder Structure)
โครงสร้างไฟล์หลักในโปรเจกต์แอปพลิเคชันมือถือถูกจัดระเบียบไว้ในโฟลเดอร์ `lib/` ดังนี้:
* `lib/models/` : สำหรับเก็บ Data Models หรือคลาสพิมพ์เขียวข้อมูลทั้งหมด (เช่น `Room_model.dart`)
* `lib/screens/` : สำหรับเก็บไฟล์หน้าจอ UI แต่ละหน้า (เช่น `Room_booking.dart`)
* `lib/widgets/` : สำหรับเก็บ Component หรือชิ้นส่วน UI ที่สามารถเรียกใช้งานซ้ำได้

### 2.2 ตัวแปรส่วนกลาง (Global Variables)
ระบบใช้งาน State Management เบื้องต้นเพื่อแชร์ข้อมูลข้ามหน้าจอ โดยมีตัวแปร Global หลักที่ใช้งานอยู่ ดังนี้:
* `globalMeetingRooms` : จัดเก็บข้อมูลรายการห้องประชุมทั้งหมด
* `globalBookingHistory` : จัดเก็บรายการประวัติการจองทั้งหมด
* `globalCurrentUserName` : จัดเก็บชื่อผู้ใช้งานหรือพนักงานปัจจุบันที่เข้าสู่ระบบอยู่

---

## 3. ฟีเจอร์ที่พัฒนาและเชื่อมต่อสำเร็จแล้ว (Implemented Features)

### 3.1 โครงสร้างฐานข้อมูล (Database Schema - Prisma)
สร้างตารางสัมพันธ์และ Migrate ขึ้นระบบฐานข้อมูล PostgreSQL เสร็จสมบูรณ์แล้วรวมทั้งหมด **14 ตาราง** โดยแบ่งกลุ่มหลักๆ ได้แก่ ตารางข้อมูลพนักงาน, ตารางทรัพยากร (Rooms/Vehicles), ตารางการจอง และตารางเก็บ AuditLog/History

### 3.2 ระบบบริการหลังบ้าน (Backend API - Node.js)
* **Server Core & Middleware:** จัดทำโครงสร้างระบบที่ไฟล์ `src/index.js` พร้อมระบบ Centralized Error Handling 
* **Authentication API:** ระบบ Login ด้วย Employee Code และรหัส PIN 6 หลัก
* **Resource API:** บริการดึงข้อมูล เพิ่ม แก้ไข และลบข้อมูลห้องประชุม (`/api/rooms`) และเช็กรถว่าง (`/api/vehicles/available`)
* **Booking & Collision API:** ระบบจองพร้อมติดตั้ง Logic ตรวจสอบเวลาจองชนกันเรียบร้อยแล้ว
* **Bug Fixed (Backend):** แก้ไขปัญหาการบันทึกข้อมูลประวัติลงตาราง `AuditLog` สำเร็จ ข้อมูลลง DB เรียบร้อย

---

## 4. สิ่งที่กำลังทำค้างอยู่ / ขั้นตอนถัดไป (Current Task & Next Steps)

**สถานะงานปัจจุบัน:** กำลัง Debugging โค้ดฝั่งหน้าบ้าน **Flutter (Frontend)** ในหน้าจอยืนยันการจองห้องประชุม โดยไฟล์ที่กำลังเกิดปัญหาคือ `Room_booking.dart` และ `Room_comfirm.dart`

### ⚠️ ประเด็นปัญหาด่วนที่ต้องแก้ไขทันที (Issues for Next AI/Developer)
1.  **Undefined Variables & Classes:** โค้ดฟ้อง Error หาตัวแปรไม่เจอ ต้องแก้ปัญหาการ Import ไฟล์
    * **📍 พิกัดที่ต้องแก้:** * ไฟล์ `lib/Room_booking.dart` (บรรทัดที่ 47: หา `globalBookingHistory` ไม่เจอ)
        * ไฟล์ `lib/Room_comfirm.dart` (หา `globalCurrentUserName`, คลาส `BookingHistory`, และหน้าจอ `RoomCompletedScreen` ไม่เจอ)
2.  **Type Mismatch Error:** มีการส่ง `ValueNotifier<List<BookingHistory>>` เข้าไปในส่วนที่ต้องการรับ `String` ใน Constructor ของ Model
    * **📍 พิกัดที่ต้องแก้:** ไฟล์ `lib/Room_comfirm.dart` (จุดที่มีการสร้างออบเจกต์ประวัติหลังกดยืนยันจอง)
3.  **Model Property Name Discrepancy:** ต้องหาชื่อฟิลด์เก็บสถานะที่แท้จริงใน `Room_model.dart` เพื่อมาแทนที่ `.currentStatus` หรือ `.action`
    * **📍 พิกัดที่ต้องแก้:** ไฟล์ `lib/Room_booking.dart` (บรรทัดที่ 50-51)
4.  **Navigation Routing Structure:** ต้องแก้โค้ดตอนบันทึกสำเร็จด้วย `Navigator.pushAndRemoveUntil` ให้เรียกชื่อคลาสหน้าจอสำเร็จรูปให้ถูกต้องเพื่อเคลียร์ Stack
    * **📍 พิกัดที่ต้องแก้:** ไฟล์ `lib/Room_comfirm.dart` (โค้ดส่วน `Navigator.push` ในปุ่มกดยืนยันการจอง)

---

## 5. ข้อจำกัดและเงื่อนไขพิเศษ (Constraints & Specific Rules)

### 5.1 กฎการตั้งชื่อ (Naming Convention)
* **ไฟล์ (File Names):** ยึดตามสไตล์ที่โปรเจกต์มีอยู่แล้ว เช่น `Room_model.dart`, `Room_booking.dart`
* **คลาส (Class Names):** ใช้ PascalCase เช่น `MeetingRoom`, `BookingHistory`
* **ตัวแปรข้ามระบบ (Cross-System Variables):** ในแอปใช้ CamelCase (เช่น `userId`, `startDatetime`) แต่ในฐานข้อมูล PostgreSQL ผ่าน Prisma แมปเป็น Snake_case (`@map("user_id")`) ระวังการเรียกใช้ให้ถูกบริบท

### 5.2 เงื่อนไขการดักจับเวลาทับซ้อน (Strict Collision Check Rule)
ในการจองห้องประชุมหรือรถยนต์ ระบบต้องลูปตรวจสอบช่วงเวลาเพื่อไม่ให้จองชนกัน **ข้อยกเว้น:** หากรายการเดิมมีสถานะเป็น `CANCELLED`, `REJECTED`, หรือข้อความฝั่งหน้าบ้านว่า `'เสร็จสิ้น'` หรือ `'ยกเลิกแล้ว'` ให้สั่ง `continue` เพื่อปล่อยข้าม (Ignore) ทันที ให้คนอื่นจองทับได้

### 5.3 ⚠️ กฎข้อบังคับสูงสุดสำหรับ AI (AI Coding Rules)
เมื่อต้องทำการปรับปรุง โค้ด (Refactoring) หรือแก้บั๊ก AI **ต้อง** ปฏิบัติตามกฎเหล่านี้อย่างเคร่งครัด:
1.  **บอกเฉพาะจุดที่ต้องแก้ (Show Before/After snippet only):** ไม่ต้อง Generate โค้ดเต็มไฟล์ ให้แสดงเฉพาะส่วนที่ต้องแก้ไข โดยระบุให้ชัดเจนว่า **ก่อนแก้ (Before)** เป็นอย่างไร และ **หลังแก้ (After)** เปลี่ยนเป็นอย่างไร
2.  **Never use `...`:** ห้ามละทิ้งโค้ดสำคัญภายในบล็อกที่นำเสนอด้วยการใช้เครื่องหมายจุดๆ (`...`)
3.  **Never rename Model:** ห้ามเปลี่ยนชื่อ Model, ชื่อ Class, หรือชื่อฟิลด์ ที่มีอยู่เดิมเด็ดขาด
4.  **Follow existing UI:** ปฏิบัติตามโครงสร้าง UI หรือการดีไซน์ที่มีอยู่เดิม อย่าปรับแก้หน้าตาเองเว้นแต่จะระบุ
5.  **Preserve Flutter Style:** รักษารูปแบบการเขียนและวิธีการใช้ State Management แบบที่โปรเจกต์ทำอยู่
6.  **Use Model Pro Only:** บังคับใช้ AI ในระดับ Model Pro (เช่น Gemini Pro หรือเทียบเท่า) เท่านั้นในการทำงาน ปรับปรุงโค้ด หรือแก้ไขระบบ เพื่อรองรับการคิดวิเคราะห์เชิงตรรกะที่ซับซ้อนและถูกต้องแม่นยำ
