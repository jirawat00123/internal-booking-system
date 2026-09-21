const cron = require('node-cron');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');
const socketService = require('./socketService');

class CronService {
  start() {
    // รันทุกๆ 1 นาที
    cron.schedule('* * * * *', async () => {
      console.log('[Cron Job] Checking and updating booking statuses...');
      try {
        const now = new Date();

        await prisma.$transaction(async (tx) => {
          // ==========================================
          // 1. เปลี่ยน RESERVED -> IN_USE เมื่อถึงเวลา
          // ==========================================
          
          // --- Room ---
          const roomsToStart = await tx.roomBooking.findMany({
            where: { status: 'RESERVED', startDatetime: { lte: now } }
          });
          for (const booking of roomsToStart) {
            await tx.roomBooking.update({ where: { id: booking.id }, data: { status: 'IN_USE' } });
            await tx.room.update({ where: { id: booking.roomId }, data: { status: 'IN_USE' } });
          }

          // --- Vehicle ---
          const vehiclesToStart = await tx.vehicleBooking.findMany({
            where: { status: 'RESERVED', startDatetime: { lte: now } }
          });
          for (const booking of vehiclesToStart) {
            await tx.vehicleBooking.update({ where: { id: booking.id }, data: { status: 'IN_USE' } });
            await tx.vehicle.update({ where: { id: booking.vehicleId }, data: { status: 'IN_USE' } });
          }

          // ==========================================
          // 2. เปลี่ยน IN_USE -> COMPLETED เมื่อหมดเวลา
          // ==========================================

          // --- Room ---
          const roomsToComplete = await tx.roomBooking.findMany({
            where: { status: 'IN_USE', endDatetime: { lte: now } }
          });
          for (const booking of roomsToComplete) {
            await tx.roomBooking.update({ where: { id: booking.id }, data: { status: 'COMPLETED' } });
            await tx.room.update({ where: { id: booking.roomId }, data: { status: 'AVAILABLE' } });
          }

          // --- Vehicle ---
          const vehiclesToComplete = await tx.vehicleBooking.findMany({
            where: { status: 'IN_USE', endDatetime: { lte: now } }
          });
          for (const booking of vehiclesToComplete) {
            await tx.vehicleBooking.update({ where: { id: booking.id }, data: { status: 'COMPLETED' } });
            await tx.vehicle.update({ where: { id: booking.vehicleId }, data: { status: 'AVAILABLE' } });
          }

          // ==========================================
          // 3. เคลียร์ Session ผี (Ghost Session) ที่หมดอายุ (เกิน 15 นาที)
          // ==========================================
          const sessionTimeoutMinutes = 15;
          const expiredTime = new Date(now.getTime() - sessionTimeoutMinutes * 60000);
          
          await tx.user.updateMany({
            where: {
              currentSessionId: { not: null },
              lastLoginAt: { lt: expiredTime }
            },
            data: {
              currentSessionId: null
            }
          });
        });

      } catch (error) {
        console.error('[Cron Job] Error during execution:', error);
      }
    });
  }
}

module.exports = new CronService();