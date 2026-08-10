const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// 🟢 1. ดึงรายการ Notification พร้อมจำนวน Unread (Badge Counter)
exports.getNotifications = async (req, res) => {
  try {
    const userId = parseInt(req.user.userId, 10);
    const { page = 1, limit = 20, filter } = req.query;

    const pageNum = parseInt(page, 10);
    const limitNum = parseInt(limit, 10);
    const skip = (pageNum - 1) * limitNum;

    // สร้างเงื่อนไขค้นหา
    const whereCondition = { userId };
    
    if (filter === 'UNREAD') {
      whereCondition.isRead = false;
    } else if (filter && filter !== 'ALL') {
      whereCondition.type = filter; // BOOKING, APPROVAL, REMINDER, SYSTEM, DOCUMENT
    }

    // ดึงข้อมูล Notification, จำนวนทั้งหมด และจำนวนที่ยังไม่อ่าน (Badge Counter)
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
      unreadCount, // 🔴 นำไปใช้ทำ Badge Counter
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
    const userId = parseInt(req.user.userId, 10);

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
    const userId = parseInt(req.user.userId, 10);

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
    const userId = parseInt(req.user.userId, 10);

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