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
    { code: 'IT001', name: 'สมชาย ไอที (Admin)', posName: 'หัวหน้าทีมวิศวกรสารสนเทศ IT', role: 'ADMIN' },
    { code: 'HR001', name: 'สมหญิง บุคคล (User)', posName: 'ผจก.ฝ่ายทรัพยากรบุคคลและธุรการ', role: 'USER' },
    { code: 'SEC001', name: 'สมหมาย รปภ (Guard)', posName: 'จป.เทคนิค', role: 'GUARD', pin: '123456' }, // ใช้ตำแหน่งที่ใกล้เคียง รปภ.
    { code: 'ENG001', name: 'สมเกียรติ วิศวกร (User)', posName: 'วิศวกรผลิต', role: 'USER' },
    { code: 'ACC001', name: 'สมศรี บัญชี (User)', posName: 'เจ้าหน้าที่บัญชีและการเงิน', role: 'USER' },
    { code: 'MC-WK0006', name: 'นายจิระพงค์ ธิบดี', posName: 'หัวหน้าช่างประกอบและติดตั้ง', role: 'USER' },
    { code: 'MC-WK0010', name: 'นายสายฝน มณีชัย', posName: 'หัวหน้าช่างเชื่อมประกอบ', role: 'USER' },
    { code: 'MC-WK0012', name: 'นายศรศิริ บุญแก้ว', posName: 'หัวหน้าช่างเชื่อมประกอบ', role: 'USER' },
    { code: 'MC-WK0334', name: 'นายสุริยันต์ พรมสะอาด', posName: 'หัวหน้าช่างเชื่อมประกอบ', role: 'USER' },
    { code: 'MC-WK0358', name: 'นายบุญชู กรสันเทียะ', posName: 'หัวหน้าช่างเชื่อมประกอบ', role: 'USER' },

    { code: 'MC-WK0618', name: 'นายกฤษฎา คชเสนีย์', posName: 'วิศวกรผลิต', role: 'USER' },
    
    { code: 'MC-WK0609', name: 'นางสาวอาทิตยา ราชบัณฑิต', posName: 'วิศวกรควบคุมคุณภาพ', role: 'USER' },
    { code: 'MC-EN0477', name: 'นายวราวุธ ซาผู', posName: 'จป.วิชาชีพ', role: 'USER' },
    { code: 'MC-EN0568', name: 'นายนิติกร หลวงยศ', posName: 'จป.เทคนิค', role: 'USER' },
    { code: 'MC-WK0620', name: 'นางสาวกัญญารัตน์ เทียมแก้ว', posName: 'จป.วิชาชีพ', role: 'USER' },
    
    { code: 'MC-WK0029', name: 'นายชวลิต ยองแสงจันทร์', posName: 'หัวหน้าช่างงานระบบไฟฟ้า', role: 'USER' },
    { code: 'MC-WK0514', name: 'นางสาวปิยวดี จั้นพลแสน', posName: 'ช่างระบบงานไฟฟ้า', role: 'USER' },
    { code: 'MC-WK0565', name: 'นายอนุพงศ์ พิมพา', posName: 'ช่างระบบงานไฟฟ้า', role: 'USER' },
    { code: 'MC-WK0581', name: 'นายเสถียรชัย เชื้อไชยนา', posName: 'ช่างระบบงานไฟฟ้า', role: 'USER' },
    { code: 'MC-WK0614', name: 'นายธีร์ธวัช ภูมิกอง', posName: 'ช่างระบบงานไฟฟ้า', role: 'USER' },

    { code: 'MC-EN0513', name: 'นางสาวณิชาภัทร วาจาดี', posName: 'เจ้าหน้าที่วิศวกรรมซ่อมบำรุง', role: 'USER' },
    { code: 'MC-WK0555', name: 'นายวีรศักดิ์ เหล่าลาพระ', posName: 'ช่างซ่อมบำรุง', role: 'USER' },
    { code: 'MC-WK0639', name: 'นายดนุพร ศุภรมย์', posName: 'ช่างซ่อมบำรุง', role: 'USER' },

    { code: 'MC-PP0291', name: 'นางสาวรุ่งฟ้า มงคลเคหา', posName: 'หัวหน้าแผนกจัดซื้อและสโตร์', role: 'USER' },
    { code: 'MC-PP0553', name: 'นางสาวทินรัตน์ ผลเพิ่ม', posName: 'เจ้าหน้าที่จัดซื้อ', role: 'USER' },
    { code: 'MC-AC0299', name: 'นางสาววัชราภรณ์ ภานุรักษ์', posName: 'หัวหน้าแผนกบัญชีและการเงิน', role: 'USER' },
    { code: 'MC-AC0391', name: 'นางสาวประพิณ เรืองแจ่ม', posName: 'เจ้าหน้าที่บัญชีและการเงิน', role: 'USER' },
    { code: 'MC-WK0633', name: 'นายพีรดนย์ ทองคำ', posName: 'วิศวกรผลิต', role: 'USER' },
    { code: 'MC-HR0527', name: 'นายรชต งามตระหง่าน', posName: 'ผจก.ฝ่ายทรัพยากรบุคคลและธุรการ', role: 'USER' },
    { code: 'MC-HR0608', name: 'นางสาวเบญจวรรณ เอนอ่อน', posName: 'เจ้าหน้าที่ทรัพยากรบุคคลและธุรการ', role: 'USER' },
    { code: 'MC-WK0622', name: 'นางสาววรรณิภา สินไพร', posName: 'เจ้าหน้าที่ฝ่ายทรัพยากรมนุษย์', role: 'USER' },

    { code: 'MC-EN0286', name: 'นายวรวัฒน์ สุวรรณแก้ว', posName: 'ผู้จัดการแผนกวิศวกรรมไฟฟ้า', role: 'USER' },
    { code: 'MC-EN0319', name: 'นายบุรินทร์ แจ่มดารา', posName: 'หัวหน้าทีมวิศวกรไฟฟ้า', role: 'USER' },
    { code: 'MC-WK0325', name: 'นายวุฒมีชัย ตาลหอม', posName: 'วิศวกรไฟฟ้า', role: 'USER' },
    { code: 'MC-EN0466', name: 'นายวัฒนากร บุญตัน', posName: 'วิศวกรไฟฟ้า', role: 'USER' },
    { code: 'MC-EN0474', name: 'นายไวยวุฒิ ทวีโยค', posName: 'วิศวกรไฟฟ้า', role: 'USER' },
    { code: 'MC-EN0538', name: 'นายธรรมรัตน์ รอดจากทุกข์', posName: 'วิศวกรไฟฟ้า', role: 'USER' },
    { code: 'MC-EN0546', name: 'นาย ภาคภูมิ ชัยรัมย์', posName: 'วิศวกรไฟฟ้า', role: 'USER' },
    { code: 'MC-EN0547', name: 'ว่าที่ รต. อุดมศักดิ์ อรัญโสตร', posName: 'วิศวกรไฟฟ้า', role: 'USER' },

    { code: 'MC-EN0240', name: 'นาย ทรงวิทย์ ขุนจบเมือง', posName: 'ผจก.ฝ่ายวิศวกรรม', role: 'USER' },
    { code: 'MC-EN0472', name: 'นาย อัจฉริยะ นวลล่อง', posName: 'วิศวกรการตลาด', role: 'USER' },
    { code: 'MC-SM0610', name: 'นาย บันลือโลก วงทะนี', posName: 'วิศวกรขายและการตลาด', role: 'USER' },

    { code: 'MC-WK0635', name: 'นาย ศิรศักดิ์ เผือกสงค์', posName: 'เจ้าหน้าที่เขียนแบบ', role: 'USER' },

    { code: 'MC-MK0054', name: 'นาย กฤฐิพงษ์ ศรีศิริ', posName: 'ผจก.ฝ่ายวิศวกรรมการขายและการตลาด', role: 'USER' },
    { code: 'MC-WK0535', name: 'นางสาว ศิวรักษ์ อินทรแหยม', posName: 'ผู้ช่วยวิศวกรการขายและการตลาด', role: 'USER' },
    { code: 'MC-SM0597', name: 'นาย วีระชัย ถิ่นฐานทรัพย์', posName: 'Senior Sales and Marketing Manager', role: 'USER' },

    { code: 'MC-EN0320', name: 'นาย วุฒิพงษ์ มาตตี', posName: 'หัวหน้าทีมวิศวกรรมติดตั้งเครื่องจักร', role: 'USER' },
    { code: 'MC-EN0373', name: 'นาย ศักร์สฤษฏิ์ พรหมฉิม', posName: 'วิศวกรติดตั้งเครื่องจักร', role: 'USER' },

    { code: 'MC-PC0241', name: 'นาย สุชาติ สมโพธิ์', posName: 'หัวหน้าแผนกวิศวกรรมซ่อมบำรุง', role: 'USER' },
    { code: 'MC-EN0448', name: 'นาย ชนสิษฎ์ มิ่งขวัญ', posName: 'วิศวกรซ่อมบำรุง', role: 'USER' },
    { code: 'MC-EN0539', name: 'นาย นครินทร์ บุญมาก', posName: 'วิศวกรซ่อมบำรุง', role: 'USER' },
    { code: 'MC-WK0619', name: 'นาย วันชนะ สังข์ลักษณ์', posName: 'วิศวกรซ่อมบำรุง', role: 'USER' },

    { code: 'MC-EN0326', name: 'นาย สมบูรณ์ กมลภูจิตรคุปต์', posName: 'หัวหน้าทีมวิศวกรสารสนเทศ IT', role: 'USER' },
    { code: 'MC-EN0494', name: 'นาย พงศ์พัทธ์ แตงอ่อน', posName: 'วิศวกรสารสนเทศ IT', role: 'USER' },
    { code: 'MC-EN0596', name: 'นาย กิตติ บุญเลิศ', posName: 'วิศวกรสารสนเทศ IT', role: 'USER' },
    { code: 'MC-EN0644', name: 'นาย รณกฤต เหลืองอ่อน', posName: 'วิศวกรสารสนเทศ IT', role: 'USER' },

    { code: 'MC-EN0386', name: 'นาย วรยุทธ เนตรจ๋อย', posName: 'วิศวกรการออกแบบ', role: 'USER' },
    { code: 'MC-EN0439', name: 'นาย ศิวดล นนทะภา', posName: 'ผู้ช่วยวิศวกรการออกแบบ', role: 'USER' },
    { code: 'MC-EN0470', name: 'นาย ทรงศักดิ์ จันทร์คำลา', posName: 'วิศวกรการออกแบบ', role: 'USER' },
    { code: 'MC-EN0481', name: 'นาย สมพล สุขบรรเทิง', posName: 'วิศวกรการออกแบบ', role: 'USER' },

    { code: 'MC-HR0558', name: 'นาย อาคม ชวนละคร', posName: 'เจ้าหน้าที่งานขนส่ง', role: 'USER' },
    { code: 'MC-HR0557', name: 'นาย ทองเจือ คำกลาง', posName: 'เจ้าหน้าที่งานขนส่ง', role: 'USER' },
    { code: 'MC-WK0621', name: 'นาย สามารถ แสนภูมิ', posName: 'เจ้าหน้าที่ขนส่ง', role: 'USER' },
    { code: 'MC-WK0631', name: 'นาย นิพนธ์ โพธิ์สี', posName: 'เจ้าหน้าที่ขนส่ง', role: 'USER' },
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
          pin: emp.pin || null,
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