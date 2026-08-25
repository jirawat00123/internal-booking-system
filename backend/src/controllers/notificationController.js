const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// 🟢 1. ดึงรายการ Notification พร้อมจำนวน Unread (Badge Counter)
exports.getNotifications = async (req, res) => {
  try {
    const userId = parseInt(req.user?.userId || req.user?.id, 10);
    const { page = 1, limit = 20, filter } = req.query;

    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const skip = (pageNum - 1) * limitNum;

    const whereCondition = { userId };
    
    if (filter === 'UNREAD') {
      whereCondition.isRead = false;
    } else if (filter && filter !== 'ALL') {
      whereCondition.type = filter;
    }

    const [notifications, totalCount, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: whereCondition,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum
      }),
      prisma.notification.count({ where: whereCondition }),
      prisma.notification.count({ where: { userId, isRead: false } })
    ]);

    return res.status(200).json({
      success: true,
      unreadCount,
      data: notifications,
      pagination: {
        page: pageNum,
        limit: limitNum,
        totalCount,
        totalPages: Math.ceil(totalCount / limitNum)
      }
    });

  } catch (error) {
    console.error("Get Notifications Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถดึงข้อมูลการแจ้งเตือนได้" });
  }
};

// 🟢 2. เปลี่ยนสถานะเป็นอ่านแล้ว (รายชิ้น)
exports.markAsRead = async (req, res) => {
  try {
    const notificationId = parseInt(req.params.id, 10);
    const userId = parseInt(req.user?.userId || req.user?.id, 10);

    const existing = await prisma.notification.findUnique({
      where: { id: notificationId }
    });

    if (!existing || existing.userId !== userId) {
      return res.status(404).json({ success: false, error: "ไม่พบรายการแจ้งเตือนนี้ หรือไม่มีสิทธิ์เข้าถึง" });
    }

    const updated = await prisma.notification.update({
      where: { id: notificationId },
      data: { isRead: true }
    });

    return res.status(200).json({ success: true, data: updated, message: "อัปเดตสถานะการอ่านเรียบร้อย" });
  } catch (error) {
    console.error("Mark As Read Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตสถานะได้" });
  }
};

// 🟢 3. อ่านทั้งหมด (Mark All as Read)
exports.markAllAsRead = async (req, res) => {
  try {
    const userId = parseInt(req.user?.userId || req.user?.id, 10);

    await prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true }
    });

    return res.status(200).json({ success: true, message: "ทำรายการอ่านทั้งหมดเรียบร้อยแล้ว" });
  } catch (error) {
    console.error("Mark All As Read Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถอัปเดตสถานะทั้งหมดได้" });
  }
};

// 🟢 4. ลบการแจ้งเตือน (Delete)
exports.deleteNotification = async (req, res) => {
  try {
    const notificationId = parseInt(req.params.id, 10);
    const userId = parseInt(req.user?.userId || req.user?.id, 10);

    const existing = await prisma.notification.findUnique({
      where: { id: notificationId }
    });

    if (!existing || existing.userId !== userId) {
      return res.status(404).json({ success: false, error: "ไม่พบรายการแจ้งเตือนนี้ หรือไม่มีสิทธิ์เข้าถึง" });
    }

    await prisma.notification.delete({
      where: { id: notificationId }
    });

    return res.status(200).json({ success: true, message: "ลบการแจ้งเตือนสำเร็จ" });
  } catch (error) {
    console.error("Delete Notification Error:", error);
    return res.status(500).json({ success: false, error: "ไม่สามารถลบรายการได้" });
  }
};

// 🟢 5. ตอบรับ/ปฏิเสธ คำขอแจ้งเตือน (เช่น คำขอปล่อยรถก่อนเวลา)
exports.respondToNotification = async (req, res) => {
  try {
    const notificationId = parseInt(req.params.id, 10);
    const userId = parseInt(req.user?.userId || req.user?.id, 10);
    const { action, approved } = req.body;

    if (isNaN(notificationId) || isNaN(userId)) {
      return res.status(404).json({ success: false, error: "ไม่พบรายการแจ้งเตือนนี้ หรือไม่มีสิทธิ์เข้าถึง" });
    }

    const existing = await prisma.notification.findUnique({
      where: { id: notificationId }
    });

    if (!existing || existing.userId !== userId) {
      return res.status(404).json({ success: false, error: "ไม่พบรายการแจ้งเตือนนี้ หรือไม่มีสิทธิ์เข้าถึง" });
    }

    const bookingId = existing.entityId ? parseInt(existing.entityId, 10) : null;

    const normalizedAction = action ? String(action).toUpperCase() : '';
    const isApproved = approved === true || ['CONFIRM', 'APPROVE', 'ACCEPT', 'AGREE', 'YES'].includes(normalizedAction);
    const isRejected = approved === false || ['REJECT', 'DENY', 'NO', 'DECLINE'].includes(normalizedAction);

    if (isRejected) {
      if (bookingId) {
        const rejectAction = existing.type === 'EARLY_RETURN_REQUEST' 
          ? 'EARLY_RETURN_CONSENT_DENIED' 
          : 'EARLY_RELEASE_CONSENT_DENIED';
          
        await prisma.auditLog.create({
          data: {
            module: 'VEHICLE_BOOKING',
            entityId: bookingId,
            action: rejectAction,
            userId: userId,
            details: JSON.stringify({ notificationId, action, approved })
          }
        });

        await prisma.notification.updateMany({
          where: {
            entityType: existing.entityType || 'VEHICLE_BOOKING',
            entityId: existing.entityId,
            isRead: false
          },
          data: { isRead: true }
        });
      } else {
        await prisma.notification.update({
          where: { id: notificationId },
          data: { isRead: true }
        });
      }

      return res.status(200).json({ success: true, message: "ปฏิเสธคำขอเรียบร้อยแล้ว" });
    }

    if (isApproved) {
      if (bookingId) {
        const grantAction = existing.type === 'EARLY_RETURN_REQUEST' 
          ? 'EARLY_RETURN_CONSENT_GRANTED' 
          : 'EARLY_RELEASE_CONSENT_GRANTED';

        await prisma.auditLog.create({
          data: {
            module: 'VEHICLE_BOOKING',
            entityId: bookingId,
            action: grantAction,
            userId: userId,
            details: JSON.stringify({ notificationId, action, approved })
          }
        });

        await prisma.notification.updateMany({
          where: {
            entityType: existing.entityType || 'VEHICLE_BOOKING',
            entityId: existing.entityId,
            isRead: false
          },
          data: { isRead: true }
        });
      } else {
        await prisma.notification.update({
          where: { id: notificationId },
          data: { isRead: true }
        });
      }

      return res.status(200).json({ success: true, message: "ตอบรับคำขอเรียบร้อยแล้ว" });
    }

    return res.status(400).json({ success: false, error: "รูปแบบ Action ไม่ถูกต้อง หรือไม่รองรับการทำงานนี้" });
  } catch (error) {
    console.error("Respond To Notification Error:", error);
    return res.status(500).json({ 
      success: false, 
      error: "ไม่สามารถดำเนินการตามคำขอได้",
      developerMessage: error.message 
    });
  }
};