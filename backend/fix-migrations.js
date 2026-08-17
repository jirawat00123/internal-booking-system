const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  try {
    await prisma.$executeRawUnsafe(`TRUNCATE TABLE "_prisma_migrations";`);
    console.log("Successfully cleared old migration history.");
  } catch (error) {
    console.error("Error clearing database:", error);
  } finally {
    await prisma.$disconnect();
  }
}
main();
