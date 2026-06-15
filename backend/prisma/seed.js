const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('🌱 กำลังเริ่มฝังข้อมูลตั้งต้น (Database Seeding)...');

  // 1. สร้าง Roles (แก้ไขตรง GUARD เป็น upsert แบบปกติเรียบร้อยครับ)
  const roleUser = await prisma.role.upsert({ where: { name: 'USER' }, update: {}, create: { name: 'USER' } });
  const roleAdmin = await prisma.role.upsert({ where: { name: 'ADMIN' }, update: {}, create: { name: 'ADMIN' } });
  const roleGuard = await prisma.role.upsert({ where: { name: 'GUARD' }, update: {}, create: { name: 'GUARD' } });

  // 2. สร้าง Users
  await prisma.user.upsert({ where: { email: 'user@company.com' }, update: {}, create: { email: 'user@company.com', name: 'พนักงาน A', roleId: roleUser.id } });
  await prisma.user.upsert({ where: { email: 'admin@company.com' }, update: {}, create: { email: 'admin@company.com', name: 'หัวหน้า B', roleId: roleAdmin.id } });
  await prisma.user.upsert({ where: { email: 'guard@company.com' }, update: {}, create: { email: 'guard@company.com', name: 'รปภ. สมหมาย', roleId: roleGuard.id } });

  // 3. สร้าง รหัส PIN
  await prisma.pinAccess.createMany({
    data: [
      { roleId: roleAdmin.id, pinCode: '1234', isActive: true },
      { roleId: roleGuard.id, pinCode: '5678', isActive: true }
    ],
    skipDuplicates: true,
  });

  // 4. สร้าง รถยนต์ และ ห้องประชุม
  await prisma.vehicle.upsert({ where: { id: 1 }, update: {}, create: { id: 1, name: 'Toyota Camry (รถส่วนกลาง)', plateNumber: 'กข-1234' } });
  await prisma.room.upsert({ where: { id: 1 }, update: {}, create: { id: 1, name: 'Meeting Room A', capacity: 10 } });

  console.log('✅ ฝังข้อมูลตั้งต้นสำเร็จเรียบร้อย! ระบบพร้อมใช้งาน');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });