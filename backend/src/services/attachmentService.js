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

  if (!attachment || attachment.isDeleted) {
    throw new Error('ATTACHMENT_NOT_FOUND');
  }

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

/**
 * Get Attachments By Entity Type and ID
 * (คืนค่าเฉพาะ Metadata ไม่ได้โหลดไฟล์จริงเพื่อประหยัด Memory)
 */
const getAttachmentsByEntity = async (entityType, entityId) => {
  const parsedEntityId = parseInt(entityId, 10);
  
  const attachments = await prisma.attachment.findMany({
    where: {
      entityType: entityType,
      entityId: parsedEntityId,
      isDeleted: false // ➕ เพิ่มเงื่อนไขนี้
    },
    select: {
      id: true,
      entityType: true,
      entityId: true,
      fileName: true,
      fileType: true,
      uploadedById: true,
      createdAt: true
    }
  });

  return attachments;
};

/**
 * Delete Attachment (Database + Physical File)
 * พร้อม IDOR Protection
 */
const deleteAttachmentById = async (attachmentId, userId, roleId) => {
  const id = parseInt(attachmentId, 10);

  // 1. ค้นหาไฟล์เพื่อตรวจสอบสิทธิ์และเอา filePath
  const attachment = await prisma.attachment.findUnique({
    where: { id: id }
  });

  if (!attachment) {
    throw new Error('ATTACHMENT_NOT_FOUND');
  }

  // 2. IDOR Protection (Admin หรือ เจ้าของไฟล์เท่านั้นถึงลบได้)
  if (attachment.uploadedById !== parseInt(userId, 10) && parseInt(roleId, 10) !== 1) {
    throw new Error('FORBIDDEN_ACCESS');
  }

  // 3. ลบข้อมูลออกจาก Database
  await prisma.attachment.update({
    where: { id: id },
    data: { isDeleted: true }
  });
    // ไม่ throw error ให้ระบบพัง เพราะ DB ลบสำเร็จแล้ว

  return true;
};

module.exports = {
  createAttachmentRecord,
  getAttachmentById,
  getAttachmentsByEntity, // ➕ ส่งออกฟังก์ชันใหม่
  deleteAttachmentById    // ➕ ส่งออกฟังก์ชันใหม่
};