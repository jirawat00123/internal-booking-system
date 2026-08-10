const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * 🟢 1. สร้าง Notification สำหรับผู้ใช้ 1 คน
 */
exports.createNotification = async ({ userId, title, message, type = 'BOOKING', entityType = null, entityId = null }) => {
  try {
    return await prisma.notification.create({
      data: {
        userId: parseInt(userId, 10),
        title,
        message,
        type,
        entityType,
        entityId: entityId ? parseInt(entityId, 10) : null
      }
    });
  } catch (error) {
    console.error("Create Notification Error:", error);
    throw error;
  }
};

/**
 * 🟢 2. สร้าง Notification ส่งหา Admin ทั้งหมดในระบบ (ใช้ตอนมีคำขอจองใหม่เข้ามา)
 */
exports.notifyAdmins = async ({ title, message, type = 'APPROVAL', entityType = null, entityId = null }) => {
  try {
    // ค้นหา User ทั้งหมดที่มี Role เป็น ADMIN
    const admins = await prisma.user.findMany({
      where: {
        role: { name: 'ADMIN' },
        active: true
      },
      select: { id: true }
    });

    if (admins.length === 0) return [];

    const notificationsData = admins.map(admin => ({
      userId: admin.id,
      title,
      message,
      type,
      entityType,
      entityId: entityId ? parseInt(entityId, 10) : null
    }));

    return await prisma.notification.createMany({
      data: notificationsData
    });
  } catch (error) {
    console.error("Notify Admins Error:", error);
    throw error;
  }
};