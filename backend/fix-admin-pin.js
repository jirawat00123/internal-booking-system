// backend/fix-admin-pin.js
require('dotenv').config(); // โหลดค่า PIN_PEPPER_SECRET จากไฟล์ .env
const { PrismaClient } = require('@prisma/client');
const { hashPin } = require('./src/services/pinService'); // [source: 2]

const prisma = new PrismaClient();

async function fixAndInspectAdmin() {
    const targetPin = '852000';
    
    try {
        // 1. สร้าง Hash โดยผ่าน Pepper HMAC-SHA256 และ Argon2id ตาม Spec ของระบบ [source: 2]
        const hashedPin = await hashPin(targetPin);
        console.log('[1/3] Generated Peppered-Argon2 Hash Successfully!');

        // 2. ค้นหา Admin ทั้งหมด
        const adminUsers = await prisma.user.findMany({
            where: {
                role: {
                    name: { equals: 'ADMIN', mode: 'insensitive' }
                }
            },
            include: { employee: true }
        });

        if (adminUsers.length === 0) {
            console.error('❌ No Admin user found!');
            return;
        }

        // 3. อัปเดต Hash และ Reset สถานะความปลอดภัยให้ Admin ทุกคน
        for (const admin of adminUsers) {
            await prisma.user.update({
                where: { id: admin.id },
                data: {
                    pin: hashedPin,
                    pinInitialized: true,
                    pinResetRequired: false,
                    failedLoginAttempts: 0,
                    lockedUntil: null,
                    active: true
                }
            });
            console.log(`[2/3] ✅ Updated PIN & Unlocked User ID: ${admin.id} (${admin.employee?.firstName || 'Admin'})`);
        }

        console.log('\n=== [3/3] COMPLETE ===');
        console.log('🔑 PIN "852000" is now correctly Peppered & Hashed!');

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await prisma.$disconnect();
    }
}

fixAndInspectAdmin();