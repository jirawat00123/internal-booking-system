// src/services/auditLogService.js
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

/**
 * บันทึก Audit Log ลงฐานข้อมูล
 * @param {Object} params
 * @param {number} params.userId - ID ผู้ทำรายการ (req.user.id)
 * @param {string} params.action - เช่น 'ASSIGN_DRIVER', 'UPDATE_COMPANY_DRIVER'
 * @param {string} [params.module='VEHICLE'] - ชื่อโมดูล เช่น 'VEHICLE'
 * @param {number} params.entityId - ID ของข้อมูลเป้าหมาย (เช่น vehicleBookingId)
 * @param {string} params.entityType - ประเภทข้อมูลเป้าหมาย (เช่น 'VEHICLE_BOOKING')
 * @param {Object|string} params.details - รายละเอียด Diff ก่อน-หลัง เปลี่ยนแปลง
 */
async function recordAuditLog({
  userId,
  action,
  module = 'VEHICLE',
  entityId,
  entityType = 'VEHICLE_BOOKING',
  details,
}) {
  try {
    const detailString = typeof details === 'object' ? JSON.stringify(details) : details;

    await prisma.audit_logs.create({
      data: {
        user_id: Number(userId),
        action: action,
        module: module,
        entity_id: Number(entityId),
        entity_type: entityType,
        details: detailString,
        created_at: new Date(),
      },
    });
  } catch (error) {
    console.error('Error recording audit log:', error);
  }
}

module.exports = { recordAuditLog };