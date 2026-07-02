// GET /api/rooms
router.get('/', authenticateToken, async (req, res, next) => {
    try {
        // ดึงข้อมูลห้องประชุมทั้งหมด (อาจจะเรียงตามชื่อห้อง หรือกรองเฉพาะห้องที่ยังเปิดใช้งาน)
        const rooms = await prisma.room.findMany({
            /* ถ้ามีฟิลด์สถานะ เช่น isActive สามารถเพิ่ม where ได้
            where: {
                isActive: true 
            },
            */
            orderBy: {
                name: 'asc' // เรียงตามชื่อห้อง ก-ฮ, A-Z
            }
        });

        return res.status(200).json({
            success: true,
            data: rooms
        });
    } catch (error) {
        next(error);
    }
});