const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 กำลังเริ่มฝังข้อมูลตั้งต้น (Database Seeding)...');

  // 0. ล้างข้อมูลเก่าตามลำดับความสัมพันธ์
  await prisma.user.deleteMany();
  await prisma.vehicleLog.deleteMany();
  await prisma.attachment.deleteMany();
  await prisma.vehicleBooking.deleteMany();
  await prisma.vehicle.deleteMany();
  await prisma.roomBooking.deleteMany();
  await prisma.room.deleteMany();
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
    { code: 'SEC001', name: 'สมหมาย รปภ (Guard)', posName: 'จป.เทคนิค', role: 'GUARD' }, // ใช้ตำแหน่งที่ใกล้เคียง รปภ.
    { code: 'ENG001', name: 'สมเกียรติ วิศวกร (User)', posName: 'วิศวกรผลิต', role: 'USER' },
    { code: 'ACC001', name: 'สมศรี บัญชี (User)', posName: 'เจ้าหน้าที่บัญชีและการเงิน', role: 'USER' },
    { code: 'MC-WK0006', name: 'นายจิระพงค์	ธิบดี', posName: 'หัวหน้าช่างประกอบและติดตั้ง', role: 'USER' },
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