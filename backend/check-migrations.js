const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  try {
    const result = await prisma.$queryRawUnsafe(`SELECT migration_name, started_at, finished_at, rolled_back_at FROM "_prisma_migrations" ORDER BY started_at ASC;`);
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error("Error querying database:", error);
  } finally {
    await prisma.$disconnect();
  }
}
main();
