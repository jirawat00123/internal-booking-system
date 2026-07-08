AI Operating Constitution (Project Memory)
Project Vision

โปรเจกต์นี้เป็น Internal Booking System สำหรับใช้งานภายในองค์กร โดยมีเป้าหมายเพื่อบริหารจัดการการจองทรัพยากร เช่น ห้องประชุมและรถยนต์ ให้มีความถูกต้อง ป้องกันการจองซ้ำซ้อน และสามารถขยายระบบในอนาคตได้

ระบบนี้ถูกพัฒนาในลักษณะ Production-Oriented ไม่ใช่ Prototype ดังนั้นทุกการเปลี่ยนแปลงต้องคำนึงถึงความเสถียร ความสามารถในการบำรุงรักษา และความเข้ากันได้กับโค้ดเดิม

Current Technology Stack
Frontend
Flutter
Material Design
HTTP Package
StatefulWidget (Current Project Style)
Existing State Management Pattern
Backend
Node.js
Express.js
Prisma ORM
PostgreSQL
JWT Authentication
Multer
Swagger
Repository Layout
internal-booking-system/
│
├── backend/
│   ├── prisma/
│   ├── src/
│   ├── uploads/
│   └── package.json
│
├── frontend/
│   └── mobile_app/
│       ├── lib/
│       ├── android/
│       ├── ios/
│       ├── web/
│       └── pubspec.yaml
│
├── .gitignore
├── README.md
└── .vscode/
Architecture Philosophy

AI ต้องเข้าใจว่า

ระบบถูกออกแบบเป็น REST API
Flutter เป็น Client
Express เป็น Backend
Prisma เป็น ORM
PostgreSQL เป็น Database

ห้ามเสนอแนวทางที่เปลี่ยน Architecture ทั้งระบบ เว้นแต่ผู้ใช้ร้องขอโดยตรง

Development Philosophy

AI ต้องถือหลักการดังต่อไปนี้

Maintainability First
Backward Compatibility
Production Ready
Small Incremental Changes
Minimal Risk
Clear Explanation
Non-Goals

AI ห้ามเสนอสิ่งต่อไปนี้เอง

เปลี่ยน Framework
เปลี่ยน Database
เปลี่ยน Architecture
เปลี่ยน State Management
เปลี่ยน UI Design
เปลี่ยน Folder Structure

เว้นแต่ผู้ใช้ร้องขอโดยตรง

AI Coding Constitution (Highest Priority)

AI ต้องปฏิบัติตามกฎต่อไปนี้ทุกครั้ง

Rule 1 — Minimal Change Principle

แก้เฉพาะส่วนที่จำเป็น

ห้าม Rewrite ทั้งไฟล์

ห้าม Refactor ทั้งโปรเจกต์

Rule 2 — Before / After Only

ให้แสดงเฉพาะ

Before

After

ของโค้ดที่เปลี่ยน

ห้าม Generate ไฟล์เต็ม

Rule 3 — Never Use Ellipsis

ห้ามใช้

...

หรือ

...

แทนโค้ดจริง

ต้องแสดงโค้ดเต็มของส่วนที่แก้เสมอ

Rule 4 — Preserve Existing Naming

ห้ามเปลี่ยน

Model
Class
Variable
Field
API Endpoint
Route
Folder Name
File Name

เว้นแต่ผู้ใช้สั่ง

Rule 5 — Preserve Existing UI

ห้ามปรับ

Layout
Color
Font
Widget Structure
Navigation

เว้นแต่ผู้ใช้สั่ง

Rule 6 — Preserve Existing Architecture

ห้ามเสนอ

Riverpod

Bloc

Redux

GetX

Clean Architecture

MVC

MVVM

หากโปรเจกต์ไม่ได้ใช้อยู่

Rule 7 — Preserve Flutter Style

ใช้รูปแบบเดียวกับโปรเจกต์

ไม่เปลี่ยน Coding Style

ไม่เปลี่ยน State Management

ไม่เปลี่ยน Widget Pattern

Rule 8 — Preserve Backend Style

ใช้

Express

Prisma

Middleware

Controller

Route

แบบเดิม

Rule 9 — Never Guess

หากข้อมูลไม่พอ

ให้ถาม

ห้ามเดา

Rule 10 — Explain Every Change

ทุกครั้งที่เสนอการแก้ไข

ต้องอธิบาย

ทำไมต้องแก้
ผลกระทบ
สิ่งที่เปลี่ยน
Rule 11 — Production Safety

ห้ามเสนอ

Quick Fix

Hack

Temporary Code

Magic Number

Hardcode

หากมีทางเลือกที่ถูกต้องกว่า

Rule 12 — Database Safety

ห้าม

ลบ Table
เปลี่ยน Column
เปลี่ยน Relation
เปลี่ยน Prisma Model

โดยไม่มี Migration Plan

Rule 13 — API Compatibility

ห้ามเปลี่ยน

Request

Response

Route

Status Code

Authentication

เว้นแต่ผู้ใช้สั่ง

Rule 14 — Git Safety

ห้ามแนะนำ

git reset --hard

git clean -fd

git push --force

เว้นแต่ผู้ใช้ร้องขอ

Rule 15 — Documentation Consistency

ทุกครั้งที่แก้ระบบ

AI ต้องตรวจว่า

Developer Handover
README
API Documentation

จำเป็นต้องอัปเดตหรือไม่

Rule 16 — Model Requirement

งานที่เกี่ยวกับ

Refactoring
Architecture
Security
Database
Performance
Large Codebase
Production Bug