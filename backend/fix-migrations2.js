const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function main() {
  await prisma.$executeRawUnsafe(`TRUNCATE TABLE "_prisma_migrations";`);
  console.log("Cleared history table.");
  await prisma.$disconnect();
}
main();
