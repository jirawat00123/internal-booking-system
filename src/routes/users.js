// GET /api/Department
router.get('/Department', async (req, res, next) => {
    try {
        const departments = await prisma.user.findMany({
            where: { 
                Department: { not: null } // ไม่เอาช่องว่าง
            },
            distinct: ['Department'], // ดึงมาแค่ชื่อที่ไม่ซ้ำกัน
            select: {
                Department: true
            },
            orderBy: {
                Department: 'asc' // เรียงตัวอักษร ก-ฮ, A-Z
            }
        });

        // แปลงข้อมูลให้เป็น Array ธรรมดา เช่น ['HR', 'IT', 'Sales']
        const deptList = departments.map(d => d.Department);   

        return res.status(200).json({ success: true, data: deptList });
    } catch (error) {
        next(error);
    }
});