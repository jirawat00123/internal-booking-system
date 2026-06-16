const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 กำลังเริ่มฝังข้อมูลตั้งต้น (Database Seeding)...');

  // ==============================================================
  // ... โค้ดเดิมที่ใช้ Seed สิทธิ์ (Role) และ พนักงาน (User) 56 คน ...
  // นำมาวางไว้ตรงกลางระหว่างนี้ได้เลยครับ
  // ==============================================================

  console.log('✅ ฝังข้อมูลตั้งต้นสำเร็จเรียบร้อย!');
}

// ส่วนคำสั่งรันการทำงาน (ห้ามอยู่ข้างในปีกกา main)
main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

  // 1. สร้างกลุ่มตำแหน่ง (Roles)
  const roleUser = await prisma.role.upsert({ where: { name: 'USER' }, update: {}, create: { name: 'USER' } });
  const roleAdmin = await prisma.role.upsert({ where: { name: 'ADMIN' }, update: {}, create: { name: 'ADMIN' } });
  const roleGuard = await prisma.role.upsert({ where: { name: 'GUARD' }, update: {}, create: { name: 'GUARD' } });

  // 2. สร้างรายชื่อพนักงานจำลองตั้งต้น
  await prisma.user.upsert({
    where: { email: 'user@company.com' },
    update: {},
    create: {
      email: 'user@company.com',
      employeeId: 'EMP001',
      firstName: 'พนักงาน',
      lastName: 'A',
      position: 'เจ้าหน้าที่ทั่วไป',
      department: 'พัฒนาซอฟต์แวร์',
      division: 'ไอที',
      roleId: roleUser.id
    }
  });

  await prisma.user.upsert({
    where: { email: 'admin@company.com' },
    update: {},
    create: {
      email: 'admin@company.com',
      password: 'password123',
      employeeId: 'EMP002',
      firstName: 'หัวหน้า',
      lastName: 'B',
      position: 'ผู้จัดการฝ่าย',
      department: 'บริหารองค์กร',
      division: 'ส่วนกลาง',
      roleId: roleAdmin.id
    }
  });

  await prisma.user.upsert({
    where: { email: 'guard@company.com' },
    update: {},
    create: {
      email: 'guard@company.com',
      password: 'password123',
      employeeId: 'EMP003',
      firstName: 'สมหมาย',
      lastName: 'รปภ.',
      position: 'เจ้าหน้าที่รักษาความปลอดภัย',
      department: 'ดูแลความปลอดภัย',
      division: 'ส่วนกลาง',
      roleId: roleGuard.id
    }
  });

  // ---------------------------------------------------------
  // 3. เพิ่มข้อมูลพนักงานจำนวนมาก (ยิงรวดเดียวเข้า Database)
  // ---------------------------------------------------------
  const bulkUsers = await prisma.user.createMany({
    data: [
      {
        employeeId: 'MC-WK0006',
        firstName: 'นายจิระพงศ์',
        lastName: 'ธิบดี',
        position: 'หัวหน้าช่างประกอบและติดตั้ง',
        department: 'แผนกเชื่อมประกอบ',
        division: 'ฝ่ายการผลิตและโรงงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0010',
        firstName: 'นายสายฝน',
        lastName: 'มณีชัย',
        position: 'หัวหน้าช่างเชื่อมประกอบ',
        department: 'แผนกเชื่อมประกอบ',
        division: 'ฝ่ายการผลิตและโรงงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0012',
        firstName: 'นายศรศิริ',
        lastName: 'บุญแก้ว',
        position: 'หัวหน้าช่างเชื่อมประกอบ',
        department: 'แผนกเชื่อมประกอบ',
        division: 'ฝ่ายการผลิตและโรงงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0334',
        firstName: 'นายสุริยันต์',
        lastName: 'พรมสะอาด',
        position: 'หัวหน้าช่างเชื่อมประกอบ',
        department: 'แผนกเชื่อมประกอบ',
        division: 'ฝ่ายการผลิตและโรงงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0358',
        firstName: 'นายบุญชู',
        lastName: 'กรสันเทียะ',
        position: 'หัวหน้าช่างเชื่อมประกอบ',
        department: 'แผนกเชื่อมประกอบ',
        division: 'ฝ่ายการผลิตและโรงงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0618',
        firstName: 'นายกฤษฎา',
        lastName: 'คชเสนีย์',
        position: 'วิศวกรผลิต',
        department: 'แผนกการผลิตและโรงงาน',
        division: 'ฝ่ายการผลิตและโรงงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0609',
        firstName: 'นางสาวอาทิตยา',
        lastName: 'ราชบัณฑิต',
        position: 'วิศวกรควบคุมคุณภาพ',
        department: 'แผนกการผลิตและโรงงาน',
        division: 'ฝ่ายการผลิตและโรงงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0477',
        firstName: 'นายวราวุธ',
        lastName: 'ซาผู',
        position: 'จป.วิชาชีพ',
        department: 'แผนกความปลอดภัยและสภาพแวดล้อมฯ',
        division: 'ฝ่ายความปลอดภัยและสภาพแวดล้อมฯ',
        roleId: roleGuard.id
      },
      {
        employeeId: 'MC-EN0568',
        firstName: 'นายนิติกร',
        lastName: 'หลวงยศ',
        position: 'จป.เทคนิค',
        department: 'แผนกความปลอดภัยและสภาพแวดล้อมฯ',
        division: 'ฝ่ายความปลอดภัยและสภาพแวดล้อมฯ',
        roleId: roleGuard.id
      },
      {
        employeeId: 'MC-WK0620',
        firstName: 'นางสาวกัญญารัตน์',
        lastName: 'เทียมแก้ว',
        position: 'จป.วิชาชีพ',
        department: 'แผนกความปลอดภัยและสภาพแวดล้อมฯ',
        division: 'ฝ่ายความปลอดภัยและสภาพแวดล้อมฯ',
        roleId: roleGuard.id
      },
      {
        employeeId: 'MC-WK0029',
        firstName: 'นายชวลิต',
        lastName: 'ยองแสงจันทร์',
        position: 'หัวหน้าช่างงานระบบไฟฟ้า',
        department: 'แผนกงานระบบไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0514',
        firstName: 'นางสาวปิยวดี',
        lastName: 'จั้นพลแสน',
        position: 'ช่างงานระบบไฟฟ้า',
        department: 'แผนกงานระบบไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0565',
        firstName: 'นายอนุพงศ์',
        lastName: 'พิมพา',
        position: 'ช่างงานระบบไฟฟ้า',
        department: 'แผนกงานระบบไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0581',
        firstName: 'นายเสถียรชัย',
        lastName: 'เชื้อไชยนา',
        position: 'ช่างงานระบบไฟฟ้า',
        department: 'แผนกงานระบบไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0614',
        firstName: 'นายธีร์ธวัช',
        lastName: 'ภูมิกอง',
        position: 'ช่างงานระบบไฟฟ้า',
        department: 'แผนกงานระบบไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0513',
        firstName: 'นางสาวณิชาภัทร',
        lastName: 'วาจาดี',
        position: 'เจ้าหน้าที่วิศวกรรมซ่อมบำรุง',
        department: 'แผนกงานระบบซ่อมบำรุง',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0555',
        firstName: 'นายวีรศักดิ์',
        lastName: 'เหล่าลาพระ',
        position: 'ช่างซ่อมบำรุง',
        department: 'แผนกงานระบบซ่อมบำรุง',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-PP0291',
        firstName: 'นางสาวรุ่งฟ้า',
        lastName: 'มงคลเคหา',
        position: 'หัวหน้าแผนกจัดซื้อและสโตร์',
        department: 'แผนกจัดซื้อ',
        division: 'ฝ่ายสำนักงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-PP0553',
        firstName: 'นางสาวทินรัตน์',
        lastName: 'ผลเพิ่ม',
        position: 'เจ้าหน้าที่จัดซื้อ',
        department: 'แผนกจัดซื้อ',
        division: 'ฝ่ายสำนักงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-AC0299',
        firstName: 'นางสาววัชราภรณ์',
        lastName: 'ภานุรักษ์',
        position: 'หัวหน้าแผนกบัญชีและการเงิน',
        department: 'แผนกบัญชีและการเงิน',
        division: 'ฝ่ายสำนักงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-AC0391',
        firstName: 'นางสาววประพิณ',
        lastName: 'เรืองแจ่ม',
        position: 'เจ้าหน้าที่บัญชีและการเงิน',
        department: 'แผนกบัญชีและการเงิน',
        division: 'ฝ่ายสำนักงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0633',
        firstName: 'นายพีรดนย์',
        lastName: 'ทองคำ',
        position: 'วิศวกรผลิต',
        department: 'แผนกผลิตและโรงงาน',
        division: 'ฝ่ายการผลิตและโรงงาน',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-HR0527',
        firstName: 'นายรชต',
        lastName: 'งามตระหง่าน',
        position: 'ผจก.ฝ่ายทรัพยากรบุคคลและธุรการ',
        department: 'แผนกฝ่ายทรัพยากรบุคคล',
        division: 'ฝ่ายทรัพยากรบุคคลและธุรการ',
        roleId: roleAdmin.id
      },
      {
        employeeId: 'MC-HR0608',
        firstName: 'นางสาวเบญจวรรณ',
        lastName: 'เอนอ่อน',
        position: 'เจ้าหน้าที่ทรัพยากรบุคคลและธุรการ',
        department: 'แผนกฝ่ายทรัพยากรบุคคล',
        division: 'ฝ่ายทรัพยากรบุคคลและธุรการ',
        roleId: roleAdmin.id
      },
      {
        employeeId: 'MC-WK0622',
        firstName: 'นางสาววรรณิภา',
        lastName: 'สินไพร',
        position: 'เจ้าหน้าที่ฝ่ายทรัพยากรมนุษย์',
        department: 'แผนกฝ่ายทรัพยากรบุคคล',
        division: 'ฝ่ายทรัพยากรบุคคลและธุรการ',
        roleId: roleAdmin.id
      },
      {
        employeeId: 'MC-EN0286',
        firstName: 'นายวรวัฒน์',
        lastName: 'สุวรรณแก้ว',
        position: 'ผู้จัดการแผนกวิศวกรรมไฟฟ้า',
        department: 'แผนกวิศวกรรมไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0319',
        firstName: 'นายบุรินทร์',
        lastName: 'แจ่มดารา',
        position: 'หัวหน้าทีมวิศวกรไฟฟ้า',
        department: 'แผนกวิศวกรรมไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0325',
        firstName: 'นายวุฒมีชัย',
        lastName: 'ตาลหอม',
        position: 'วิศวกรไฟฟ้า',
        department: 'แผนกวิศวกรรมไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0466',
        firstName: 'นายวัฒนากร',
        lastName: 'บุญตัน',
        position: 'วิศวกรไฟฟ้า',
        department: 'แผนกวิศวกรรมไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0474',
        firstName: 'นายไวยวุฒิ',
        lastName: 'ทวีโยค',
        position: 'วิศวกรไฟฟ้า',
        department: 'แผนกวิศวกรรมไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0538',
        firstName: 'นายธรรมรัตน์',
        lastName: 'รอดจากทุกข์',
        position: 'วิศวกรไฟฟ้า',
        department: 'แผนกวิศวกรรมไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0546',
        firstName: 'นายภาคภูมิ',
        lastName: 'ชัยรัมย์',
        position: 'วิศวกรไฟฟ้า',
        department: 'แผนกวิศวกรรมไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0547',
        firstName: 'ว่าที่ รต.อุดมศักดิ์',
        lastName: 'อรัญโสตร',
        position: 'วิศวกรไฟฟ้า',
        department: 'แผนกวิศวกรรมไฟฟ้า',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0240',
        firstName: 'นายทรงวิทย์',
        lastName: 'ขุนจบเมือง',
        position: 'ผจก.ฝ่ายวิศวกรรม',
        department: 'แผนกวิศวกรรมการ',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0472',
        firstName: 'นายอัจฉริยะ',
        lastName: 'นวลล่อง',
        position: 'วิศวกรการตลาด',
        department: 'แผนกวิศวกรรมการขาย',
        division: 'ฝ่ายวิศวกรรมการขายและการตลาด',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-SM0610',
        firstName: 'นายบันลือโลก',
        lastName: 'วงทะนี',
        position: 'วิศวกรขายและการตลาด',
        department: 'แผนกวิศวกรรมการขาย',
        division: 'ฝ่ายวิศวกรรมการขายและการตลาด',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0635',
        firstName: 'นายศิรศักดิ์',
        lastName: 'เผือกสงค์',
        position: 'เจ้าหน้าที่เขียนแบบ',
        department: 'แผนกวิศวกรรมการขาย',
        division: 'ฝ่ายวิศวกรรมการขายและการตลาด',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-MK0054',
        firstName: 'นายกฤฐิพงษ์',
        lastName: 'ศรีศิริ',
        position: 'ผจก.ฝ่ายวิศวกรรมการขายและการตลาด',
        department: 'แผนกวิศวกรรมการขาย',
        division: 'ฝ่ายวิศวกรรมการขายและการตลาด',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0535',
        firstName: 'นางสาวศิวรักษ์',
        lastName: 'อินทรแหยม',
        position: 'ผู้ช่วยวิศวกรการขายและการตลาด',
        department: 'แผนกวิศวกรรมการขาย',
        division: 'ฝ่ายวิศวกรรมการขายและการตลาด',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-SM0597',
        firstName: 'นายวีระชัย',
        lastName: 'ถิ่นฐานทรัพย์',
        position: 'Senior Sales and Marketing Manager',
        department: 'แผนกวิศวกรรมการขาย',
        division: 'ฝ่ายวิศวกรรมการขายและการตลาด',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0320',
        firstName: 'นายวุฒิพงษ์',
        lastName: 'มาตตี',
        position: 'หัวหน้าทีมวิศวกรรมติดตั้งเครื่องจักร',
        department: 'แผนกวิศวกรรมการติดตั้งเครื่องจักร',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0373',
        firstName: 'นายศักร์สฤษฏิ์',
        lastName: 'พรหมฉิม',
        position: 'วิศวกรติดตั้งเครื่องจักร',
        department: 'แผนกวิศวกรรมการติดตั้งเครื่องจักร',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-PC0241',
        firstName: 'นายสุชาติ',
        lastName: 'สมโพธิ์',
        position: 'หัวหน้าแผนกวิศวกรรมซ่อมบำรุง',
        department: 'แผนกวิศวกรรมซ่อมบำรุง',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0448',
        firstName: 'นายชนสิษฎ์',
        lastName: 'มิ่งขวัญ',
        position: 'วิศวกรซ่อมบำรุง',
        department: 'แผนกวิศวกรรมซ่อมบำรุง',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0539',
        firstName: 'นายนครินทร์',
        lastName: 'บุญมาก',
        position: 'วิศวกรซ่อมบำรุง',
        department: 'แผนกวิศวกรรมซ่อมบำรุง',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0619',
        firstName: 'นายวันชนะ',
        lastName: 'สังข์ลักษณ์',
        position: 'วิศวกรซ่อมบำรุง',
        department: 'แผนกวิศวกรรมซ่อมบำรุง',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0326',
        firstName: 'นายสมบูรณ์',
        lastName: 'กมลภูจิตรคุปต์',
        position: 'หัวหน้าทีมวิศวกรสารสนเทศ IT',
        department: 'แผนกวิศวกรรมสารสนเทศและเทคโนโลยี (IT)',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0494',
        firstName: 'นายพงศ์พัทธ์',
        lastName: 'แตงอ่อน',
        position: 'วิศวกรสารสนเทศ IT',
        department: 'แผนกวิศวกรรมสารสนเทศและเทคโนโลยี (IT)',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0596',
        firstName: 'นายกิตติ',
        lastName: 'บุญเลิศ',
        position: 'วิศวกรสารสนเทศ IT',
        department: 'แผนกวิศวกรรมสารสนเทศและเทคโนโลยี (IT)',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0644',
        firstName: 'นายรณกฤต',
        lastName: 'เหลืองอ่อน',
        position: 'วิศวกรสารสนเทศ IT',
        department: 'แผนกวิศวกรรมสารสนเทศและเทคโนโลยี (IT)',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0386',
        firstName: 'นายวรยุทธ',
        lastName: 'เนตรจ๋อย',
        position: 'วิศวกรการออกแบบ',
        department: 'แผนกวิศวกรรมออกแบบ',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0439',
        firstName: 'นายศิวดล',
        lastName: 'นนทะภา',
        position: 'ผู้ช่วยวิศวกรการออกแบบ',
        department: 'แผนกวิศวกรรมออกแบบ',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0470',
        firstName: 'นายทรงศักดิ์',
        lastName: 'จันทร์คำลา',
        position: 'วิศวกรการออกแบบ',
        department: 'แผนกวิศวกรรมออกแบบ',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-EN0481',
        firstName: 'นายสมพล',
        lastName: 'สุขบรรเทิง',
        position: 'วิศวกรการออกแบบ',
        department: 'แผนกวิศวกรรมออกแบบ',
        division: 'ฝ่ายวิศวกรรม',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-HR0558',
        firstName: 'นายอาคม',
        lastName: 'ชวนละคร',
        position: 'เจ้าหน้าที่งานขนส่ง',
        department: 'หน่วยงานงานขนส่ง',
        division: 'ฝ่ายความปลอดภัยและสภาพแวดล้อมฯ',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-HR0557',
        firstName: 'นายทองเจือ',
        lastName: 'คำกลาง',
        position: 'เจ้าหน้าที่งานขนส่ง',
        department: 'หน่วยงานงานขนส่ง',
        division: 'ฝ่ายความปลอดภัยและสภาพแวดล้อมฯ',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0621',
        firstName: 'นายสามารถ',
        lastName: 'แสนภูมิ',
        position: 'เจ้าหน้าทีขนส่ง',
        department: 'หน่วยงานงานขนส่ง',
        division: 'ฝ่ายความปลอดภัยและสภาพแวดล้อมฯ',
        roleId: roleUser.id
      },
      {
        employeeId: 'MC-WK0631',
        firstName: 'นายนิพนธ์',
        lastName: 'โพธิ์สี',
        position: 'เจ้าหน้าทีขนส่ง',
        department: 'หน่วยงานงานขนส่ง',
        division: 'ฝ่ายความปลอดภัยและสภาพแวดล้อมฯ',
        roleId: roleUser.id
      },



      // ใส่เครื่องหมายลูกน้ำ (,) แล้วก๊อปปี้ปีกกาแบบด้านบน เพื่อเพิ่มพนักงานคนต่อไปได้เลยครับ!
    ],
    skipDuplicates: true, // ป้องกันการ Error ถ้ารันซ้ำ
  });

  console.log(`✅ เพิ่มพนักงานใหม่จำนวน ${bulkUsers.count} คน!`);
  console.log('✅ ฝังข้อมูลตั้งต้นเวอร์ชันใหม่สำเร็จเรียบร้อยแล้ว!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });