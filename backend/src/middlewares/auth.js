const jwt = require('jsonwebtoken');
require('dotenv').config(); // ดึงค่าจากไฟล์ .env

// 1. ตั้งค่า Secret Key (ใช้ร่วมกันทั้งระบบ)
const JWT_SECRET = process.env.JWT_SECRET || 'your_default_secret_key';

// 2. Middleware ตรวจสอบ Token (รองรับทั้งชื่อเก่าและชื่อใหม่)
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ success: false, message: 'กรุณาเข้าสู่ระบบก่อนใช้งาน (No Token)' });
    }
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded; // เก็บข้อมูล user ลงใน req
        next();
    } catch (error) {
        return res.status(403).json({ success: false, message: 'Token ไม่ถูกต้องหรือหมดอายุ' });
    }
};

// นามแฝง เพื่อให้ vehicles.js เรียกใช้ verifyToken ได้
const verifyToken = authenticateToken; 

// 3. 🚨 Middleware ตรวจสอบ Role
const requireRole = (allowedRoles) => {
    return (req, res, next) => {
        if (!req.user || !allowedRoles.includes(req.user.role)) {
            return res.status(403).json({ 
                success: false, 
                message: 'ไม่มีสิทธิ์เข้าถึง: เฉพาะผู้ดูแลระบบ (Admin) เท่านั้น' 
            });
        }
        next(); // สิทธิ์ผ่าน ปล่อยไปทำหน้าต่อไป
    };
};

// 4. Export ออกไปให้ครบทุกตัว!
module.exports = { 
    JWT_SECRET,
    authenticateToken, 
    verifyToken, 
    requireRole 
};