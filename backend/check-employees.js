const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  const employees = await prisma.employee.findMany({
    include: {
      department: true,
      position: true
    },
    orderBy: {
      employeeCode: 'asc'
    }
  });

  console.table(
    employees.map(e => ({
      code: e.employeeCode,
      name: e.fullName,
      department: e.department?.departmentName,
      position: e.position?.positionName
    }))
  );

  console.log(`Total Employee: ${employees.length}`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
