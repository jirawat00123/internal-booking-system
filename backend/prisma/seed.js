const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 กำลังเริ่มฝังข้อมูลตั้งต้น (Database Seeding)...');

  // 0. ล้างข้อมูลเก่าตามลำดับความสัมพันธ์ (ลบตัวลูกก่อนตัวแม่)
  await prisma.vehicleLog.deleteMany();
  await prisma.attachment.deleteMany();
  await prisma.vehicleBooking.deleteMany();
  await prisma.roomBooking.deleteMany();
  await prisma.vehicle.deleteMany();
  await prisma.room.deleteMany();
  await prisma.user.deleteMany();       // <--- ย้ายการลบ User มาไว้ตรงนี้ (หลังจากลบประวัติการจองหมดแล้ว)
  await prisma.employee.deleteMany();
  await prisma.position.deleteMany();
  await prisma.department.deleteMany();

  // 1. สร้างแผนก (Departments) ทั้ง 16 แผนก
  const deptNames = [
    'แผนกเชื่อมประกอบ', 'แผนกการผลิตและโรงงาน', 'แผนกความปลอดภัยและสภาพแวดล้อมฯ',
    'แผนกงานระบบไฟฟ้า', 'แผนกงานระบบซ่อมบำรุง', 'แผนกจัดซื้อ',
    'แผนกบัญชีและการเงิน', 'แผนกฝ่ายทรัพยากรบุคคล', 'แผนกวิศวกรรมไฟฟ้า',
    'แผนกวิศวกรรมการ', 'แผนกวิศวกรรมการขาย', 'แผนกวิศวกรรมการติดตั้งเครื่องจักร',
    'แผนกวิศวกรรมซ่อมบำรุง', 'แผนกวิศวกรรมสารสนเทศและเทคโนโลยี (IT)',
    'แผนกวิศวกรรมออกแบบ', 'หน่วยงานงานขนส่ง'
  ];

  const createdDepts = [];
  for (const name of deptNames) {
    const dept = await prisma.department.create({ data: { departmentName: name } });
    createdDepts.push(dept);
  }
  console.log(`✅ สร้างแผนกสำเร็จ ${createdDepts.length} แผนก`);

  // 2. สร้างตำแหน่ง (Positions) แบบครบถ้วนตามแผนก
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
    { name: 'เจ้าหน้าที่งานขนส่ง', deptIndex: 15 }, { name: 'เจ้าหน้าที่ขนส่ง', deptIndex: 15 }
  ];

  const createdPositions = [];
  for (const pos of positionsToCreate) {
    const p = await prisma.position.create({
      data: { positionName: pos.name, departmentId: createdDepts[pos.deptIndex].id }
    });
    createdPositions.push(p);
  }
  console.log(`✅ สร้างตำแหน่งสำเร็จ ${createdPositions.length} ตำแหน่ง`);

  // ==========================================
  // 3. สร้างข้อมูลพนักงาน (Employees) และให้สิทธิ์ผู้ใช้ (Users)
  // ==========================================
  // 💡 วิธีเพิ่มพนักงาน: แค่ระบุชื่อตำแหน่ง (posName) ให้ตรงกับที่สร้างไว้ด้านบน
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
  { code: 'MC-EN0481', name: 'นายสมพล สุขบรรเทิง (ก้อง)', posName: 'วิศวกรรมออกแบบ', role: 'USER' },
  ];

  const createdUsers = [];
  for (const emp of employeesData) {
    // ระบบจะวิ่งไปหา id ของตำแหน่งจากชื่อตำแหน่งให้อัตโนมัติ
    const positionFound = createdPositions.find(p => p.positionName === emp.posName);

    if (positionFound) {
      // 3.1 สร้างตัวพนักงาน
      const newEmployee = await prisma.employee.create({
        data: {
          employeeCode: emp.code,
          fullName: emp.name,
          positionId: positionFound.id
        }
      });

      // 3.2 สร้างบัญชีผู้ใช้งาน (User) ผูกกับพนักงานคนนั้นทันที
      const newUser = await prisma.user.create({
        data: {
          employeeId: newEmployee.id,
          roles: emp.role,
          active: true
        }
      });
      createdUsers.push(newUser);
    } else {
      console.log(`⚠️ ไม่พบตำแหน่ง "${emp.posName}" สำหรับพนักงาน ${emp.name}`);
    }
  }
  console.log(`✅ สร้างพนักงานและสิทธิ์ผู้ใช้สำเร็จ ${createdUsers.length} บัญชี`);

  console.log('🎉 ฝังข้อมูลตั้งต้นครบถ้วนและเชื่อมโยงความสัมพันธ์เรียบร้อยแล้ว!');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(async () => { await prisma.$disconnect(); });