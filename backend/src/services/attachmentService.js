const { PrismaClient } = require('@prisma/client');
const fs = require('fs/promises');
const path = require('path');

const prisma = new PrismaClient();

/**
 * Upload Attachment Core Logic
 * ทำงานภายใต้ Transaction หาก DB Fail จะลบไฟล์ทิ้งทันที
 */
const createAttachmentRecord = async (file, entityType, entityId, userId) => {
  try {
    // 1. Map Entity IDs for Relations based on schema
    let roomBookingId = null;
    let vehicleBookingId = null;
    const parsedEntityId = parseInt(entityId, 10);

    if (entityType === 'ROOM_BOOKING') {
      roomBookingId = parsedEntityId;
    } else if (entityType === 'VEHICLE_BOOKING') {
      vehicleBookingId = parsedEntityId;
    }

    // 2. Prisma Transaction
    const attachment = await prisma.$transaction(async (tx) => {
      return await tx.attachment.create({
        data: {
          entityType: entityType,
          entityId: parsedEntityId,
          fileName: file.originalname,  // ชื่อไฟล์ต้นฉบับ สำหรับให้ User ดู
          filePath: file.filename,      // ชื่อไฟล์ UUID ที่เก็บจริงบน Disk
          fileType: file.mimetype,
          uploadedById: parseInt(userId, 10),
          roomBookingId: roomBookingId,
          vehicleBookingId: vehicleBookingId,
        }
      });
    });

    return attachment;

  } catch (error) {
    // 3. Cleanup File: Database Fail -> Delete Physical File
    if (file && file.path) {
      try {
        await fs.unlink(file.path);
        console.log(`[AttachmentService] Cleaned up orphaned file: ${file.path}`);
      } catch (unlinkError) {
        console.error(`[AttachmentService] Failed to delete orphaned file: ${unlinkError.message}`);
      }
    }
    throw new Error(`Database transaction failed: ${error.message}`);
  }
};

/**
 * Get Attachment Info (with IDOR Protection readiness)
 */
const getAttachmentById = async (attachmentId, userId, roleId) => {
  const attachment = await prisma.attachment.findUnique({
    where: { id: parseInt(attachmentId, 10) }
  });

  if (!attachment) {
    throw new Error('ATTACHMENT_NOT_FOUND');
  }

  // IDOR Protection: ตรวจสอบความเป็นเจ้าของ 
  // (สมมติ Role: 1 = Admin มีสิทธิ์ดูทั้งหมด หากไม่ใช่ Admin ต้องเป็นเจ้าของไฟล์)
  if (attachment.uploadedById !== parseInt(userId, 10) && parseInt(roleId, 10) !== 1) {
    throw new Error('FORBIDDEN_ACCESS');
  }

  return attachment;
};

module.exports = {
  createAttachmentRecord,
  getAttachmentById
};