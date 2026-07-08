const express = require('express');
const cors = require('cors');
const { PrismaClient } = require('@prisma/client');

const app = express();
const prisma = new PrismaClient();
const PORT = 3001;

// ✅ เปิดใช้งาน CORS และ JSON Parser
app.use(cors());
app.use(express.json());

// ==========================================
// 🌐 ส่วนของ Express API Routes (ดึงข้อมูล)
// ==========================================

/**
 * 1. GET /api/positions
 * สำหรับดึงรายชื่อตำแหน่งทั้งหมดไปแสดงใน Dropdown
 */
app.get('/api/positions', async (req, res) => {
  try {
    const positions = await prisma.position.findMany({
      orderBy: {
        positionName: 'asc',
      },
    });
    return res.status(200).json(positions);
  } catch (error) {
    console.error('Error fetching positions:', error);
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการดึงข้อมูลตำแหน่ง' });
  }
});

/**
 * 2. GET /api/departments
 * สำหรับดึงรายชื่อแผนกทั้งหมดไปแสดงใน Dropdown อันแรก
 */
app.get('/api/departments', async (req, res) => {
  try {
    const departments = await prisma.department.findMany({
      orderBy: { departmentName: 'asc' },
    });
    return res.status(200).json(departments);
  } catch (error) {
    console.error('Error fetching departments:', error);
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการดึงข้อมูลแผนก' });
  }
});

/**
 * 3. GET /api/employees
 * สำหรับดึงรายชื่อพนักงาน โดยกรองด้วย departmentId ผ่านความสัมพันธ์ของตาราง Position
 */
app.get('/api/employees', async (req, res) => {
  const { departmentId } = req.query;

  try {
    const whereCondition = {};
    
    if (departmentId && departmentId !== 'null' && departmentId !== 'undefined') {
      const parsedId = parseInt(departmentId.toString(), 10);
      if (!isNaN(parsedId)) {
        whereCondition.position = {
          departmentId: parsedId
        };
      }
    }

    const employees = await prisma.employee.findMany({
      where: whereCondition,
      include: {
        position: true,
      },
      orderBy: {
        fullName: 'asc',
      },
    });

    return res.status(200).json(employees);
  } catch (error) {
    console.error('Error fetching employees:', error);
    return res.status(500).json({ message: 'เกิดข้อผิดพลาดในการดึงข้อมูลพนักงาน' });
  }
});

// ==========================================
// 🌱 ส่วนของฟังก์ชัน Seed ข้อมูลตั้งต้น (Database Seeding)
// ==========================================
async function seedDatabase() {
  console.log('🌱 กำลังเริ่มฝังข้อมูลตั้งต้น (Database Seeding)...');

  try {
    await prisma.roomBookingHistory.deleteMany().catch(() => {});
    await prisma.vehicleBookingHistory.deleteMany().catch(() => {});
    // 0. ล้างข้อมูลเก่าตามลำดับความสัมพันธ์ (ป้องกัน FK Constraint)
    await prisma.vehicleLog.deleteMany().catch(() => {});
    await prisma.attachment.deleteMany().catch(() => {});
    await prisma.auditLog.deleteMany().catch(() => {}); 
    await prisma.vehicleBooking.deleteMany().catch(() => {});
    await prisma.roomBooking.deleteMany().catch(() => {});
    await prisma.vehicle.deleteMany().catch(() => {});
    await prisma.room.deleteMany().catch(() => {});
    await prisma.user.deleteMany().catch(() => {});        
    await prisma.role.deleteMany().catch(() => {}); 
    await prisma.employee.deleteMany().catch(() => {});
    await prisma.position.deleteMany().catch(() => {});
    await prisma.department.deleteMany().catch(() => {});

    // 1. สร้างแผนก (Departments) ทั้ง 16 แผนก
    const deptNames = [
    'เชื่อมประกอบ', 'การผลิตและโรงงาน', 'ความปลอดภัยและสภาพแวดล้อมฯ',
    'งานระบบไฟฟ้า', 'งานระบบซ่อมบำรุง', 'จัดซื้อ',
    'บัญชีและการเงิน', 'ฝ่ายทรัพยากรบุคคล', 'วิศวกรรมไฟฟ้า',
    'วิศวกรรมการขาย', 'วิศวกรรมการติดตั้งเครื่องจักร',
    'วิศวกรรมซ่อมบำรุง', 'วิศวกรรมสารสนเทศและเทคโนโลยี',
    'วิศวกรรมออกแบบ','วิศวกรรมการ'
  ];

    const createdDepts = [];
    for (const name of deptNames) {
      const dept = await prisma.department.create({ data: { departmentName: name } });
      createdDepts.push(dept);
    }
    console.log(`✅ สร้างแผนกสำเร็จ ${createdDepts.length} แผนก`);

    // 1.5 สร้างสิทธิ์การใช้งาน (Roles)
    const roleNames = ['ADMIN', 'USER', 'GUARD'];
    const roleMap = {};
    for (const name of roleNames) {
      const role = await prisma.role.create({ data: { name } });
      roleMap[name] = role.id; 
    }
    console.log(`✅ สร้างสิทธิ์การใช้งานสำเร็จ ${roleNames.length} สิทธิ์`);

    // 2. สร้างตำแหน่ง (Positions) ผูกกับแผนก
    const positionsToCreate = [
    { name: 'หัวหน้าช่างประกอบและติดตั้ง', deptIndex: 0 }, { name: 'หัวหน้าช่างเชื่อมประกอบ', deptIndex: 0 },
    { name: 'วิศวกรผลิต', deptIndex: 1 }, { name: 'วิศวกรควบคุมคุณภาพ', deptIndex: 1 },
    { name: 'จป.วิชาชีพ', deptIndex: 2 }, { name: 'จป.เทคนิค', deptIndex: 2 },
    { name: 'หัวหน้าช่างงานระบบไฟฟ้า', deptIndex: 3 }, { name: 'ช่างระบบงานไฟฟ้า', deptIndex: 3 },
    { name: 'เจ้าหน้าที่วิศวกรรมซ่อมบำรุง', deptIndex: 4 }, { name: 'ช่างซ่อมบำรุง', deptIndex: 4 },
    { name: 'หัวหน้าแผนกจัดซื้อและสโตร์', deptIndex: 5 }, { name: 'เจ้าหน้าที่จัดซื้อ', deptIndex: 5 },
    { name: 'หัวหน้าแผนกบัญชีและการเงิน', deptIndex: 6 }, { name: 'เจ้าหน้าที่บัญชีและการเงิน', deptIndex: 6 },
    { name: 'ผจก.ฝ่ายทรัพยากรบุคคลและธุรการ', deptIndex: 7 }, { name: 'เจ้าหน้าที่ทรัพยากรบุคคลและธุรการ', deptIndex: 7 }, { name: 'เจ้าหน้าที่ฝ่ายทรัพยากรมนุษย์', deptIndex: 7 },
    { name: 'ผู้จัดการแผนกวิศวกรรมไฟฟ้า', deptIndex: 8 }, { name: 'หัวหน้าทีมวิศวกรไฟฟ้า', deptIndex: 8 }, { name: 'วิศวกรไฟฟ้า', deptIndex: 8 },
    { name: 'ผจก.ฝ่ายวิศวกรรม', deptIndex: 9 },
    { name: 'วิศวกรการตลาด', deptIndex: 10 }, { name: 'วิศวกรขายและการตลาด', deptIndex: 10 }, { name: 'เจ้าหน้าที่เขียนแบบ', deptIndex: 10 }, { name: 'ผจก.ฝ่ายวิศวกรรมการขายและการตลาด', deptIndex: 10 }, { name: 'ผู้ช่วยวิศวกรการขายและการตลาด', deptIndex: 10 }, { name: 'Senior Sales and Marketing Manager', deptIndex: 10 },
    { name: 'หัวหน้าทีมวิศวกรรมติดตั้งเครื่องจักร', deptIndex: 11 }, { name: 'วิศวกรติดตั้งเครื่องจักร', deptIndex: 11 },
    { name: 'หัวหน้าแผนกวิศวกรรมซ่อมบำรุง', deptIndex: 12 }, { name: 'วิศวกรซ่อมบำรุง', deptIndex: 12 },
    { name: 'หัวหน้าทีมวิศวกรสารสนเทศ IT', deptIndex: 13 }, { name: 'วิศวกรสารสนเทศ IT', deptIndex: 13 },
    { name: 'วิศวกรการออกแบบ', deptIndex: 14 }, { name: 'ผู้ช่วยวิศวกรการออกแบบ', deptIndex: 14 },
  ];

    const createdPositions = [];
    for (const pos of positionsToCreate) {
      const p = await prisma.position.create({
        data: { positionName: pos.name, departmentId: createdDepts[pos.deptIndex].id }
      });
      createdPositions.push(p);
    }
    console.log(`✅ สร้างตำแหน่งสำเร็จ ${createdPositions.length} ตำแหน่ง`);

    // 3. สร้างข้อมูลพนักงาน (Employees) และ บัญชีผู้ใช้ (Users)
    const employeesData = [
    { code: 'MC-WK0006', name: 'นายจิระพงค์ ธิบดี (นีโน่)', posName: 'เชื่อมประกอบ', role: 'USER' },
  { code: 'MC-WK0010', name: 'นายสายฝน มณีชัย (หนู)', posName: 'เชื่อมประกอบ', role: 'USER' },
  { code: 'MC-WK0012', name: 'นายศรศิริ บุญแก้ว (โก้)', posName: 'เชื่อมประกอบ', role: 'USER' },
  { code: 'MC-WK0334', name: 'นายสุริยันต์ พรมสะอาด (ยันต์)', posName: 'เชื่อมประกอบ', role: 'USER' },
  { code: 'MC-WK0358', name: 'นายบุญชู กรสันเทียะ (เล็ก)', posName: 'เชื่อมประกอบ', role: 'USER' },

  { code: 'MC-WK0618', name: 'นายกฤษฎา คชเสนีย์ (ไนกี้)', posName: 'การผลิตและโรงงาน', role: 'USER' },
  { code: 'MC-WK0609', name: 'นางสาวอาทิตยา ราชบัณฑิต (ฟ้า)', posName: 'การผลิตและโรงงาน', role: 'USER' },
  { code: 'MC-WK0633', name: 'นายพีรดนย์ ทองคำ (เซน)', posName: 'การผลิตและโรงงาน', role: 'USER' },

  { code: 'MC-EN0477', name: 'นายวราวุธ ซาผู (หนุ่ม)', posName: 'ความปลอดภัยและสภาพแวดล้อมฯ', role: 'USER' },
  { code: 'MC-EN0568', name: 'นายนิติกร หลวงยศ (กร)', posName: 'ความปลอดภัยและสภาพแวดล้อมฯ', role: 'USER' },
  { code: 'MC-WK0620', name: 'นางสาวกัญญารัตน์ เทียมแก้ว (จุ๊บแจง)', posName: 'ความปลอดภัยและสภาพแวดล้อมฯ', role: 'USER' },

  { code: 'MC-WK0029', name: 'นายชวลิต ยองแสงจันทร์ (หลอ)', posName: 'งานระบบไฟฟ้า', role: 'USER' },
  { code: 'MC-WK0514', name: 'นางสาวปิยวดี จั้นพลแสน (แนน)', posName: 'งานระบบไฟฟ้า', role: 'USER' },
  { code: 'MC-WK0565', name: 'นายอนุพงศ์ พิมพา (ตั้น)', posName: 'งานระบบไฟฟ้า', role: 'USER' },
  { code: 'MC-WK0581', name: 'นายเสถียรชัย เชื้อไชยนา (แชมป์)', posName: 'งานระบบไฟฟ้า', role: 'USER' },
  { code: 'MC-WK0614', name: 'นายธีร์ธวัช ภูมิกอง (ฟลุ๊ค)', posName: 'งานระบบไฟฟ้า', role: 'USER' },

  { code: 'MC-EN0513', name: 'นางสาวณิชาภัทร วาจาดี (เอิร์น)', posName: 'งานระบบซ่อมบำรุง', role: 'USER' },
  { code: 'MC-WK0555', name: 'นายวีรศักดิ์ เหล่าลาพระ (เพียว)', posName: 'งานระบบซ่อมบำรุง', role: 'USER' },
  { code: 'MC-WK0639', name: 'นายดนุพร ศุภรมย์ (แม็กซ์)', posName: 'งานระบบซ่อมบำรุง', role: 'USER' },

  { code: 'MC-PP0291', name: 'นางสาวรุ่งฟ้า มงคลเคหา (วิว)', posName: 'จัดซื้อ', role: 'USER' },
  { code: 'MC-PP0553', name: 'นางสาวทินรัตน์ ผลเพิ่ม (เจี๊ยบ)', posName: 'จัดซื้อ', role: 'USER' },

  { code: 'MC-AC0299', name: 'นางสาววัชราภรณ์ ภานุรักษ์ (ยุ)', posName: 'บัญชีและการเงิน', role: 'USER' },
  { code: 'MC-AC0391', name: 'นางสาวประพิณ เรืองแจ่ม (นุช)', posName: 'บัญชีและการเงิน', role: 'USER' },

  { code: 'MC-HR0527', name: 'นายรชต งามตระหง่าน (ป็อป)', posName: 'ฝ่ายทรัพยากรบุคคล', role: 'USER' },
  { code: 'MC-HR0608', name: 'นางสาวเบญจวรรณ เอนอ่อน (โบว์)', posName: 'ฝ่ายทรัพยากรบุคคล', role: 'USER' },
  { code: 'MC-WK0622', name: 'นางสาววรรณิภา สินไพร (กระนุ้งกระนิ้ง)', posName: 'ฝ่ายทรัพยากรบุคคล', role: 'USER' },

  { code: 'MC-EN0286', name: 'นายวรวัฒน์ สุวรรณแก้ว (ชื่น)', posName: 'วิศวกรรมไฟฟ้า', role: 'USER' },
  { code: 'MC-EN0319', name: 'นายบุรินทร์ แจ่มดารา (โน๊ต)', posName: 'วิศวกรรมไฟฟ้า', role: 'USER' },
  { code: 'MC-WK0325', name: 'นายวุฒมีชัย ตาลหอม (วุฒิ)', posName: 'วิศวกรรมไฟฟ้า', role: 'USER' },
  { code: 'MC-EN0466', name: 'นายวัฒนากร บุญตัน (เติ้ล)', posName: 'วิศวกรรมไฟฟ้า', role: 'USER' },
  { code: 'MC-EN0474', name: 'นายไวยวุฒิ ทวีโยค (โด้)', posName: 'วิศวกรรมไฟฟ้า', role: 'USER' },
  { code: 'MC-EN0538', name: 'นายธรรมรัตน์ รอดจากทุกข์ (บอย)', posName: 'วิศวกรรมไฟฟ้า', role: 'USER' },
  { code: 'MC-EN0546', name: 'นายภาคภูมิ ชัยรัมย์ (ภาค)', posName: 'วิศวกรรมไฟฟ้า', role: 'USER' },
  { code: 'MC-EN0547', name: 'ว่าที่ รต.อุดมศักดิ์ อรัญโสตร (เอก)', posName: 'วิศวกรรมไฟฟ้า', role: 'USER' },

  { code: 'MC-EN0240', name: 'นายทรงวิทย์ ขุนจบเมือง (วิทย์)', posName: 'วิศวกรรมการ', role: 'USER' },

  { code: 'MC-EN0472', name: 'นายอัจฉริยะ นวลล่อง (อัจ)', posName: 'วิศวกรรมการขาย', role: 'USER' },
  { code: 'MC-SM0610', name: 'นายบันลือโลก วงทะนี (อ๋า)', posName: 'วิศวกรรมการขาย', role: 'USER' },
  { code: 'MC-WK0635', name: 'นายศิรศักดิ์ เผือกสงค์ (ไนซ์)', posName: 'วิศวกรรมการขาย', role: 'USER' },
  { code: 'MC-MK0054', name: 'นายกฤฐิพงษ์ ศรีศิริ (ไก่)', posName: 'วิศวกรรมการขาย', role: 'USER' },
  { code: 'MC-WK0535', name: 'นางสาวศิวรักษ์ อินทรแหยม (ป๊อป)', posName: 'วิศวกรรมการขาย', role: 'USER' },
  { code: 'MC-SM0597', name: 'นายวีระชัย ถิ่นฐานทรัพย์ (จืด)', posName: 'วิศวกรรมการขาย', role: 'USER' },

  { code: 'MC-EN0320', name: 'นายวุฒิพงษ์ มาตตี (วุฒิ)', posName: 'วิศวกรรมการติดตั้งเครื่องจักร', role: 'USER' },
  { code: 'MC-EN0373', name: 'นายศักร์สฤษฏิ์ พรหมฉิม (สกาย)', posName: 'วิศวกรรมการติดตั้งเครื่องจักร', role: 'USER' },

  { code: 'MC-PC0241', name: 'นายสุชาติ สมโพธิ์ (เอ็ดดี้)', posName: 'วิศวกรรมซ่อมบำรุง', role: 'USER' },
  { code: 'MC-EN0448', name: 'นายชนสิษฎ์ มิ่งขวัญ (เปรม)', posName: 'วิศวกรรมซ่อมบำรุง', role: 'USER' },
  { code: 'MC-EN0539', name: 'นายนครินทร์ บุญมาก (ไม้)', posName: 'วิศวกรรมซ่อมบำรุง', role: 'USER' },
  { code: 'MC-WK0619', name: 'นายวันชนะ สังข์ลักษณ์ (เบลล์)', posName: 'วิศวกรรมซ่อมบำรุง', role: 'USER' },

  { code: 'MC-EN0326', name: 'นายสมบูรณ์ กมลภูจิตรคุปต์ (แซม)', posName: 'วิศวกรรมสารสนเทศและเทคโนโลยี', role: 'USER' },
  { code: 'MC-EN0494', name: 'นายพงศ์พัทธ์ แตงอ่อน (มด)', posName: 'วิศวกรรมสารสนเทศและเทคโนโลยี', role: 'USER' },
  { code: 'MC-EN0596', name: 'นายกิตติ บุญเลิศ (ไผ่)', posName: 'วิศวกรรมสารสนเทศและเทคโนโลยี', role: 'USER' },
  { code: 'MC-EN0644', name: 'นายรณกฤต เหลืองอ่อน (ซัน)', posName: 'วิศวกรรมสารสนเทศและเทคโนโลยี', role: 'USER' },
  { code: 'MC-EN0646', name: 'นายนิติภูมิ กองฟู (ฮ้อ)', posName: 'วิศวกรรมสารสนเทศและเทคโนโลยี', role: 'USER' },
  
  { code: 'MC-EN0386', name: 'นายวรยุทธ เนตรจ๋อย (เจเล่)', posName: 'วิศวกรรมออกแบบ', role: 'USER' },
  { code: 'MC-EN0439', name: 'นายศิวดล นนทะภา (เบนซ์)', posName: 'วิศวกรรมออกแบบ', role: 'USER' },
  { code: 'MC-EN0470', name: 'นายทรงศักดิ์ จันทร์คำลา (กี้)', posName: 'วิศวกรรมออกแบบ', role: 'USER' },
  { code: 'MC-EN0481', name: 'นายสมพล สุขบรรเทิง (ก้อง)', posName: 'วิศวกรรมออกแบบ', role: 'USER' }

  ];

    // ⚡ Optimization: แปลงข้อมูลเป็น Map เพื่อดึงข้อมูลความเร็ว O(1) ประสิทธิภาพสูง
    const deptToDefaultPosMap = new Map();
    for (const dept of createdDepts) {
      const firstPosInDept = createdPositions.find(p => p.departmentId === dept.id);
      if (firstPosInDept) {
        deptToDefaultPosMap.set(dept.departmentName, firstPosInDept.id);
      }
    }

    let successCount = 0;
    for (const emp of employeesData) {
      // 💡 เปลี่ยนไปดึง ID ตำแหน่ง โดยใช้ชื่อแผนก (emp.posName) แทน
      const positionId = deptToDefaultPosMap.get(emp.posName);

      if (positionId) {
        // สร้างข้อมูลพนักงาน (Employee)
        const newEmployee = await prisma.employee.create({
          data: {
            employeeCode: emp.code,
            fullName: emp.name,
            positionId: positionId
          }
        });
        // สร้างสิทธิ์บัญชีผู้ใช้ (User) ผูกกับพนักงาน
        await prisma.user.create({
          data: {
            employeeId: newEmployee.id,    // 💡 ใช้ employeeId ส่งค่าตรงๆ
            roleId: roleMap[emp.role],     // 💡 ใช้ roleId ส่งค่าตรงๆ
            pin: emp.pin || null,
            active: true
          }
        });
        successCount++;
      } else {
        console.log(`⚠️ ไม่พบตำแหน่ง "${emp.posName}" สำหรับพนักงาน ${emp.name}`);
      }
    }
    console.log(`✅ สร้างพนักงานและสิทธิ์ผู้ใช้สำเร็จ ${successCount} บัญชี`);
    console.log('🎉 ฝังข้อมูลตั้งต้นครบถ้วนและเชื่อมโยงความสัมพันธ์เรียบร้อยแล้ว!');

  } catch (error) {
    console.error('🔴 เกิดข้อผิดพลาดในการฝังข้อมูล (Seeding Error):', error);
  }
}

// ==========================================
// 🚀 ฟังก์ชันเริ่มทำงานหลัก (Bootstrapping)
// ==========================================
async function startApp() {
  try {
    // รันการฝังข้อมูล (Seed) ก่อนเปิด Server
    await seedDatabase();

    // เมื่อ Seed เสร็จเรียบร้อย ค่อยเปิด Express Server
    app.listen(PORT, () => {
      console.log(`🚀 Server is running on http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start application:', error);
    process.exit(1);
  }
}

// 🎯 สั่งรันโปรแกรม
startApp();