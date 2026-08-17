const { PrismaClient } = require('@prisma/client');
const { verifyPin } = require('./src/services/pinService');

const prisma = new PrismaClient();

async function test() {
    const targetPin = process.argv[2];

    if (!targetPin) {
        console.error('Usage: node test-pin.js <PIN>');
        process.exit(1);
    }

    try {
        const admins = await prisma.user.findMany({
            where: {
                role: {
                    name: 'ADMIN'
                }
            },
            select: {
                id: true,
                employeeId: true,
                pin: true,
                employee: {
                    select: {
                        employeeCode: true,
                        fullName: true
                    }
                }
            }
        });

        for (const admin of admins) {
            const result = await verifyPin(admin.pin, targetPin);

            console.log(
                `ID=${admin.id} | ${admin.employee?.employeeCode} | ${admin.employee?.fullName} | VERIFY=${result ? 'VALID' : 'INVALID'}`
            );
        }
    } catch (error) {
        console.error('VERIFY_ERROR:', error);
    } finally {
        await prisma.$disconnect();
    }
}

test();