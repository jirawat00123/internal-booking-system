const express = require('express');
const { PrismaClient } = require('@prisma/client');
const { authenticateToken } = require('../middlewares/auth');

const router = express.Router();
const prisma = new PrismaClient();

router.get('/rooms', authenticateToken, async (req, res, next) => {
  try {
    const rooms = await prisma.room.findMany({ orderBy: { id: 'asc' } });
    res.json(rooms);
  } catch (error) { next(error); }
});

router.get('/vehicles', authenticateToken, async (req, res, next) => {
  try {
    const vehicles = await prisma.vehicle.findMany({ orderBy: { id: 'asc' } });
    res.json(vehicles);
  } catch (error) { next(error); }
});

router.post('/vehicles', authenticateToken, async (req, res, next) => {
  try {
    if (req.user.role !== 'ADMIN') return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: ฟังก์ชันนี้สำหรับ ADMIN เท่านั้น" });
    const { brand, model, type, plateNumber, province, color, uploadUrl } = req.body;
    if (!brand || !model || !type || !plateNumber || !province || !color) return res.status(400).json({ error: "กรุณากรอกข้อมูลรถให้ครบถ้วน" });

    const newVehicle = await prisma.vehicle.create({
      data: { brand, model, type, plateNumber, province, color, uploadUrl: uploadUrl || null }
    });
    res.status(201).json({ message: "เพิ่มรถคันใหม่สำเร็จ!", data: newVehicle });
  } catch (error) { next(error); }
});

router.put('/vehicles/:id', authenticateToken, async (req, res, next) => {
  try {
    if (req.user.role !== 'ADMIN') return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: เฉพาะแอดมินเท่านั้น" });
    const vehicleId = parseInt(req.params.id); 
    const { brand, model, type, plateNumber, province, color, uploadUrl } = req.body;

    const updatedVehicle = await prisma.vehicle.update({
      where: { id: vehicleId },
      data: { brand, model, type, plateNumber, province, color, uploadUrl }
    });
    res.json({ message: "อัปเดตข้อมูลรถเรียบร้อยแล้ว!", data: updatedVehicle });
  } catch (error) { next(error); }
});

router.delete('/vehicles/:id', authenticateToken, async (req, res, next) => {
  try {
    if (req.user.role !== 'ADMIN') return res.status(403).json({ error: "ไม่มีสิทธิ์เข้าถึง: เฉพาะแอดมินเท่านั้น" });
    const vehicleId = parseInt(req.params.id);
    await prisma.vehicle.delete({ where: { id: vehicleId } });
    res.json({ message: "ลบรถออกจากระบบสำเร็จ!" });
  } catch (error) { next(error); }
});

module.exports = router;