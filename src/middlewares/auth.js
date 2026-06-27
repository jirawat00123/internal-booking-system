const jwt = require('jsonwebtoken');

// 🔑 ตัวแปรเก็บ Secret Key (ใช้ Environment Variable เป็นหลักเพื่อความปลอดภัย)
const JWT_SECRET = process.env.JWT_SECRET || "SuperSecretKey2026_ForCorporateApp!!";

// 🛡️ Middleware ตรวจสอบ Token
const authenticateToken = (req, res, next) => {
  // 1. ดึง Token จาก Header (รูปแบบ: Bearer <token>)
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  // 2. ถ้าไม่มี Token แนบมา ให้ปฏิเสธการเข้าถึง
  if (!token) {
    return res.status(401).json({ error: "ไม่อนุญาตให้เข้าถึง: กรุณาแนบ Token" });
  }

  // 3. ตรวจสอบความถูกต้องและวันหมดอายุของ Token
  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: "Token ไม่ถูกต้องหรือหมดอายุ" });
    }
    
    // 4. แกะข้อมูลผู้ใช้ (decoded) แปะไว้ใน req เพื่อให้ Route อื่นๆ นำไปใช้ต่อได้
    req.user = decoded; 
    next();
  });
};

// ส่งออก Module ไปให้ไฟล์อื่นใช้งาน
module.exports = { 
  authenticateToken, 
  JWT_SECRET 
};