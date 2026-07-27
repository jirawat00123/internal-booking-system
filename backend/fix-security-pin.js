// backend/fix-security-pin.js
require('dotenv').config(); // โหลดค่า PIN_PEPPER_SECRET จากไฟล์ .env
const { PrismaClient } = require('@prisma/client');
const { hashPin } = require('./src/services/pinService');

const prisma = new PrismaClient();

async function fixAndInspectSecurity() {
    const targetPin = '001122'; 
    
    try {
        // 1. สร้าง Hash โดยผ่าน Pepper HMAC-SHA256 และ Argon2id ตาม Spec ของระบบ
        const hashedPin = await hashPin(targetPin);
        console.log('[1/3] Generated Peppered-Argon2 Hash Successfully!');

        // 2. ค้นหา Security ทั้งหมด
        const securityUsers = await prisma.user.findMany({
            where: {
                role: {
                    name: { equals: 'SECURITY', mode: 'insensitive' }
                }
            },
            include: { employee: true }
        });

        if (securityUsers.length === 0) {
            console.error('❌ No SECURITY user found!');
            return;
        }

        // 3. อัปเดต Hash และ Reset สถานะความปลอดภัยให้ Security ทุกคน
        for (const security of securityUsers) {
            await prisma.user.update({
                where: { id: security.id },
                data: {
                    pin: hashedPin,
                    pinInitialized: true,
                    pinResetRequired: false,
                    failedLoginAttempts: 0,
                    lockedUntil: null,
                    active: true
                }
            });
            console.log(`[2/3] ✅ Updated PIN & Unlocked User ID: ${security.id} (${security.employee?.firstName || 'Security'})`);
        }

        console.log('\n=== [3/3] COMPLETE ===');
        console.log(`🔑 PIN "${targetPin}" is now correctly Peppered & Hashed for SECURITY role!`);

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await prisma.$disconnect();
    }
}

fixAndInspectSecurity();