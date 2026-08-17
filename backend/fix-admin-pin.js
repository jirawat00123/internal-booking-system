// backend/fix-admin-pin.js
require('dotenv').config(); // โหลดค่า PIN_PEPPER_SECRET จากไฟล์ .env
const { PrismaClient } = require('@prisma/client');
const { hashPin } = require('./src/services/pinService'); // [source: 2]

const prisma = new PrismaClient();

async function fixAndInspectUser() {
    const targetPin = '852000';
    
    try {
        // 1. สร้าง Hash โดยผ่าน Pepper HMAC-SHA256 และ Argon2id ตาม Spec ของระบบ [source: 2]
        const hashedPin = await hashPin(targetPin);
        console.log('[1/3] Generated Peppered-Argon2 Hash Successfully!');

        // 2. ค้นหา User ที่ต้องการแก้ PIN โดยตรง
        const targetUser = await prisma.user.findUnique({
            where: {
                id: 56
            },
            include: { employee: true, role: true }
        });

        if (!targetUser) {
            console.error('❌ User ID 56 not found!');
            return;
        }

        // 3. อัปเดต Hash และ Reset สถานะความปลอดภัยให้ User ID 56
        await prisma.user.update({
            where: { id: targetUser.id },
            data: {
                pin: hashedPin,
                pinInitialized: true,
                pinResetRequired: false,
                failedLoginAttempts: 0,
                lockedUntil: null,
                active: true
            }
        });

        console.log(`[2/3] ✅ Updated PIN & Unlocked User ID: ${targetUser.id} (${targetUser.employee?.fullName || 'User'})`);

        console.log('\n=== [3/3] COMPLETE ===');
        console.log(`🔑 PIN "852000" is now correctly Peppered & Hashed for User ID: ${targetUser.id}`);

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await prisma.$disconnect();
    }
}

fixAndInspectUser();