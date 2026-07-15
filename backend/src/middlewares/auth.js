const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
require('dotenv').config();

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'your_default_secret_key';

const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];

  // 🚨 [Requirement 3] LOG: ตรวจสอบ Authorization Header ที่ได้รับจริงจาก Client ก่อนทำการ verify
  console.log(`[EVIDENCE] 3. Incoming Authorization Header from Client: "${authHeader}"`);

  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    // 🚨 [Requirement 7] LOG สาเหตุ 401: ไม่มี Token
    console.log('[EVIDENCE] 7. 401 Failure Cause: [NO_TOKEN] Token does not exist in request headers.');
    return res.status(401).json({ success: false, error: "กรุณาเข้าสู่ระบบ" });
  }

  try {
    const secretKey = JWT_SECRET || process.env.JWT_SECRET || 'default_secret_key';
    const decoded = jwt.verify(token, secretKey);

    // 🚨 [Requirement 4] LOG: ถอดรหัส JWT payload และดึงข้อมูล userId, sessionId
    console.log('[EVIDENCE] 4. Decoded JWT Payload:', decoded);
    console.log(`[EVIDENCE] 4. decoded.userId: "${decoded.userId}"`);
    console.log(`[EVIDENCE] 4. decoded.sessionId: "${decoded.sessionId}"`);

    req.user = decoded;

    const user = await prisma.user.findUnique({
      where: { id: decoded.userId }
    });

    if (!user) {
      console.log(`[EVIDENCE] 7. 401 Failure Cause: [USER_NOT_FOUND] User with ID "${decoded.userId}" was not found in Database.`);
      return res.status(401).json({ success: false, error: "ไม่พบข้อมูลผู้ใช้งาน" });
    }

    //  แก้ไขเพิ่มเติม: ตรวจสอบสถานะการเปิดใช้งานบัญชี (Account Status Validation)
    // อ้างอิงจาก Source of Truth ตาราง user ฟิลด์เก็บสถานะคือ "active" (Boolean)
    if (!user.active) {
      console.log(`[EVIDENCE] 7. 403 Failure Cause: [USER_INACTIVE] User ID "${decoded.userId}" account is deactivated.`);
      return res.status(403).json({ success: false, error: "บัญชีผู้ใช้งานของคุณถูกระงับสิทธิ์การใช้งานชั่วคราว" });
    }

    // 🚨 [Requirement 5] LOG: ค่า currentSessionId ที่ได้จากฐานข้อมูล ณ ขนาดนี้
    console.log(`[EVIDENCE] 5. Database currentSessionId (user.currentSessionId): "${user.currentSessionId}"`);
    
    // ✅ แก้ไข: ประกาศตัวแปรคำนวณผลลัพธ์การเปรียบเทียบ Session ID ก่อนนำไปใช้งานด้านล่าง
    const isSessionValid = decoded.sessionId === user.currentSessionId;

    console.log(`   -> decoded.sessionId (From Token):        "${decoded.sessionId}"`);
    console.log(`   -> user.currentSessionId (From Database): "${user.currentSessionId}"`);
    console.log(`   -> Comparison Result (decoded.sessionId === user.currentSessionId): "${isSessionValid}"`);

    if (!isSessionValid) {
      // 🚨 [Requirement 7] LOG สาเหตุ 401: Session ไม่ตรงกัน (เกิด Mismatch)
      console.log('[EVIDENCE] 7. 401 Failure Cause: [SESSION_MISMATCH] Session IDs do not match (Current session may be stale or cleared).');
      return res.status(401).json({ success: false, error: "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่" });
    }

    next();
  } catch (error) {
    // 🚨 [Requirement 7] LOG สาเหตุ 401: การตรวจสอบด้วย jwt.verify ล้มเหลว
    console.log(`[EVIDENCE] 7. 401 Failure Cause: [JWT_VERIFICATION_FAILED] Error message: "${error.message}"`);
    return res.status(401).json({ success: false, error: "สิทธิ์การเข้าใช้งานไม่ถูกต้อง" });
  }
};

const verifyToken = authenticateToken;

const requireRole = (allowedRoles) => {
    return (req, res, next) => {
        // อาศัย req.user.role ที่ผ่านการ Validate อย่างเข้มงวดมาแล้ว
        if (!req.user || !allowedRoles.includes(req.user.role)) {
            return res.status(403).json({ 
                success: false, 
                error: "ปฏิเสธการเข้าถึง: สิทธิ์ของคุณไม่เพียงพอ" 
            });
        }
        next();
    };
};

module.exports = {
    JWT_SECRET,
    authenticateToken,
    verifyToken,
    requireRole
};