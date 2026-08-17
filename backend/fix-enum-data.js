const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function main() {
  try {
    await prisma.$executeRawUnsafe(`UPDATE rooms SET status = 'AVAILABLE' WHERE status IN ('IN USE', 'RESERVED');`);
    await prisma.$executeRawUnsafe(`UPDATE vehicles SET status = 'AVAILABLE' WHERE status = 'RESERVED');`);
    await prisma.$executeRawUnsafe(`UPDATE room_bookings SET status = 'PENDING' WHERE status = 'RESERVED');`);
    await prisma.$executeRawUnsafe(`UPDATE vehicle_bookings SET status = 'PENDING' WHERE status = 'RESERVED');`);
    console.log("Successfully cleaned up stale Enum data.");
  } catch (error) {
    console.error("Error:", error);
  } finally {
    await prisma.$disconnect();
  }
}
main();
