const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  try {
    await prisma.$executeRawUnsafe(`UPDATE "rooms" SET "status" = 'AVAILABLE' WHERE "status"::text IN ('IN USE', 'RESERVED');`);
    await prisma.$executeRawUnsafe(`UPDATE "vehicles" SET "status" = 'AVAILABLE' WHERE "status"::text = 'RESERVED';`);
    await prisma.$executeRawUnsafe(`UPDATE "room_bookings" SET "status" = 'PENDING' WHERE "status"::text = 'RESERVED';`);
    await prisma.$executeRawUnsafe(`UPDATE "vehicle_bookings" SET "status" = 'PENDING' WHERE "status"::text = 'RESERVED';`);
    console.log("Successfully cleaned up stale Enum data.");
  } catch (error) {
    console.error("Error cleaning data:", error);
  } finally {
    await prisma.$disconnect();
  }
}
main();
