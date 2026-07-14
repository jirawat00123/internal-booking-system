Frontend Integration Policy (UI Merge Constitution) Objective
โปรเจกต์นี้มีการพัฒนา Frontend และ Backend แยกกันโดยคนละผู้พัฒนา
Backend และ Business Logic เป็นผู้พัฒนาหลัก (API, Database, Authentication, Validation, Booking Logic) Frontend UI/UX อาจได้รับการปรับปรุงจากผู้พัฒนาอีกคนในภายหลัง
ดังนั้นการพัฒนาต่อจากนี้ต้องสามารถ Merge UI ใหม่เข้ากับ Logic เดิมได้โดยไม่ทำให้ระบบเสีย
Rule 12 — Backend is the Source of Truth
Business Logic ทั้งหมดถือเป็นมาตรฐานของระบบ
ได้แก่
API Contract Route Controller Prisma Database Schema Authentication Authorization Validation Booking Logic Conflict Detection Transaction
ห้ามแก้ไขพฤติกรรมของ Backend เพื่อให้ Frontend ใหม่ทำงาน เว้นแต่ได้รับคำสั่งโดยตรง
Frontend ต้องเป็นฝ่ายปรับให้สอดคล้องกับ Backend
Rule 13 — UI Can Change, Logic Must Stay
อนุญาตให้เปลี่ยน
Layout Theme Color Animation Widget Responsive UI Spacing Typography
แต่ห้ามเปลี่ยน
API Endpoint JSON Format Request Body Response Structure Variable ที่ใช้เชื่อม Backend Business Logic Rule 14 — Preserve API Contract
ห้ามเปลี่ยน
HTTP Method Route Header JWT Format Multipart Format Parameter Response Model
เว้นแต่ได้รับคำสั่งโดยตรง
หาก UI ใหม่ต้องการข้อมูลเพิ่ม ให้แก้ Backend แบบ Backward Compatible
Rule 15 — UI Merge Strategy
เมื่อได้รับไฟล์ Frontend เวอร์ชันใหม่
ให้ดำเนินการตามลำดับ
เปรียบเทียบ UI ใหม่กับ UI เดิม คง Logic เดิมทั้งหมด ย้าย Widget ใหม่เข้ามา เชื่อม Widget ใหม่กับ API เดิม ตรวจสอบว่าไม่มี Feature เดิมหาย ตรวจสอบว่า API ทุกตัวทำงานเหมือนเดิม Rule 16 — Never Break Existing Features
ห้ามทำให้ Feature ที่เคยใช้งานได้เสีย
ตัวอย่าง
Login Booking History Upload Image Vehicle Booking Room Booking Admin Security
หาก UI ใหม่ไม่มี Widget เดิม ต้องรวมกลับเข้าไป ไม่ใช่ลบทิ้ง
Rule 17 — Logic Before UI
เมื่อเกิดความขัดแย้งระหว่าง
Logic เดิม UI ใหม่
ให้เลือก
✅ Logic เดิม
แล้วค่อยปรับ UI ให้รองรับ Logic
ห้ามแก้ Logic เพื่อให้ UI ใช้งานได้
Rule 18 — Explain Every Merge
ทุกครั้งที่ Merge Frontend
ต้องอธิบาย
UI ที่เปลี่ยน Logic ที่คงไว้ ส่วนที่ Merge API ที่ยังใช้เหมือนเดิม ผลกระทบ
พร้อมแสดง
ก่อนแก้ หลังแก้
ทุกครั้ง
Rule 19 — Production Compatibility
ทุกการแก้ไขต้องผ่านแนวคิดดังนี้
ไม่ Hardcode ไม่ Duplicate Logic ไม่ Copy/Paste Business Logic ไม่ทำให้ API เปลี่ยนพฤติกรรม รองรับการขยายระบบในอนาคต คงมาตรฐาน Production
Frontend Merge Policy
ระบุให้ชัดว่า
Frontend ของเพื่อนคือ Presentation Layer Frontend ของคุณคือ Business Logic Layer + API Integration
เวลารวมโค้ด
ใช้ UI ของเพื่อน แต่ใช้ Logic ของคุณ
ห้ามทำกลับกัน
Backend Priority
Backend ถือเป็นมาตรฐานของระบบ
ห้ามเปลี่ยน
Database API JWT Validation Prisma Controller Route
เพื่อให้ Frontend ใหม่ทำงาน
ให้ Frontend ปรับตาม Backend
UI Priority
อนุญาตให้เปลี่ยน
Layout Theme Animation Responsive Widget Typography
แต่ห้ามเปลี่ยน
API JSON HTTP Method Token Business Logic Merge Workflow
ทุกครั้งที่ได้รับไฟล์ใหม่
วิเคราะห์ไฟล์ เปรียบเทียบกับไฟล์เดิม ระบุส่วนที่ UI เปลี่ยน ระบุส่วนที่ Logic เปลี่ยน Merge โดยคง Backend เดิม ตรวจสอบ Feature เดิม ตรวจสอบ API สรุปผล Code Review Workflow
ทุกครั้งก่อนส่งโค้ด
ตรวจ Duplicate Logic ตรวจ API Contract ตรวจ Naming ตรวจ Production Safety ตรวจ Security ตรวจ Null Safety ตรวจ Error Handling ตรวจ Responsive ตรวจ Flutter Analysis ตรวจ Backend Impact Before / After Requirement
ทุกครั้งที่แก้โค้ด
ต้องแสดง
ก่อนแก้ หลังแก้ เหตุผล ผลกระทบ ความเข้ากันได้กับ Backend