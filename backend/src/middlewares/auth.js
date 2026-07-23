const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
require('dotenv').config();

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'your_default_secret_key';

const authenticateToken = async (req, res, next) => {
  // ยกเว้นการตรวจ Token และ Session สำหรับ Route ที่ใช้ Login ทุกรูปแบบ
  // เปลี่ยนเป็น /login เพื่อให้ครอบคลุมทั้ง /login และ /login-pin
  if (req.originalUrl.includes('/login')) {
    return next();
  }

  const authHeader = req.headers['authorization'];

  // 🚨 [Requirement 3] LOG: ตรวจสอบ Authorization Header ที่ได้รับจริงจาก Client ก่อนทำการ verify
  console.log(`[EVIDENCE] 3. Incoming Authorization Header from Client: "${authHeader}"`);

  // 🟢 ทำ Clean/Trim Token ป้องกันการติดอัญประกาศ " หรือ whitespace จาก Client
  let token = authHeader && authHeader.split(' ')[1];
  if (token) {
    token = token.replace(/^"(.*)"$/, '$1').trim();
  }

  if (!token) {
    // 🚨 [Requirement 7] LOG สาเหตุ 401: ไม่มี Token
    console.log('[EVIDENCE] 7. 401 Failure Cause: [NO_TOKEN] Token does not exist in request headers.');
    console.log('[AUTH] Missing Token');
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
      where: { id: decoded.userId },
      include: { role: true } // 💡 สั่งให้ Prisma JOIN ข้อมูลตาราง roles มาด้วย
    });

    if (!user) {
      console.log(`[EVIDENCE] 7. 401 Failure Cause: [USER_NOT_FOUND] User with ID "${decoded.userId}" was not found in Database.`);
      console.log('[AUTH] User Not Found');
      return res.status(401).json({ success: false, error: "ไม่พบข้อมูลผู้ใช้งาน" });
    }

    //  แก้ไขเพิ่มเติม: ตรวจสอบสถานะการเปิดใช้งานบัญชี (Account Status Validation)
    // อ้างอิงจาก Source of Truth ตาราง user ฟิลด์เก็บสถานะคือ "active" (Boolean)
    //  แก้ไขเพิ่มเติม: ตรวจสอบสถานะการเปิดใช้งานบัญชี (Account Status Validation)
    // อ้างอิงจาก Source of Truth ตาราง user ฟิลด์เก็บสถานะคือ "active" (Boolean)
    if (!user.active) {
      console.log(`[EVIDENCE] 7. 403 Failure Cause: [USER_INACTIVE] User ID "${decoded.userId}" account is deactivated.`);
      return res.status(403).json({ success: false, error: "บัญชีผู้ใช้งานของคุณถูกระงับสิทธิ์การใช้งานชั่วคราว" });
    }

    // 🔒 [Security Feature]: บังคับตั้งค่า PIN ใหม่ หากถูก Admin สั่งรีเซ็ต หรือเป็นการเข้าใช้งานครั้งแรก
    if (user.pinResetRequired) {
      // 🟢 เพิ่ม '/me' เข้าไป เพื่อให้แอป Flutter ดึงชื่อผู้ใช้ไปแสดงบนหน้าตั้งค่า PIN ได้
      const allowedPaths = ['/setup-pin', '/change-pin', '/logout', '/me'];
      const isAllowed = allowedPaths.some(path => req.originalUrl.includes(path));
      
      if (!isAllowed) {
        console.log(`[EVIDENCE] 403 Failure Cause: [PIN_RESET_REQUIRED] User ID "${decoded.userId}" needs to set up a new PIN.`);
        return res.status(403).json({ 
          success: false, 
          error: "กรุณาตั้งค่าหรือเปลี่ยนรหัส PIN ใหม่ก่อนเข้าใช้งานระบบ",
          requirePinSetup: true // ส่ง flag ไปให้ Frontend รู้ว่าต้องเด้งหน้าตั้งค่ารหัส
        });
      }
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
      console.log(`[AUTH] Session Mismatch | Token Session: ${decoded.sessionId} | DB Session: ${user.currentSessionId}`);
      return res.status(401).json({ success: false, error: "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่" });
    }

    // ✅ ปรับการอ่านค่า Role ให้ปลอดภัย รองรับทั้งจากตาราง Role Relation และฟิลด์ roles Enum 
    req.user.role = user.role?.name || user.roles || decoded.role || 'USER';

    // 💡 [Requirement Week 13] Guest Mode Validation
    // ดักจับ Role GUEST ไม่ให้ทำการเขียน/แก้ไขข้อมูลใดๆ ผ่าน API
    if (req.user.role === 'GUEST' && ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
      console.log(`[EVIDENCE] 403 Failure Cause: [GUEST_WRITE_ATTEMPT] Guest tried to use ${req.method} on ${req.originalUrl}`);
      // ส่งข้อความกลับไป เพื่อให้ Frontend นำไปโชว์เป็น Popup ได้ทันที
      return res.status(403).json({ success: false, error: "กรุณา Login ก่อนใช้งาน" }); 
    }

    next();

  } catch (error) {
    // 🚨 [Requirement 7] LOG สาเหตุ 401: การตรวจสอบด้วย jwt.verify ล้มเหลว
    console.log(`[EVIDENCE] 7. 401 Failure Cause: [JWT_VERIFICATION_FAILED] Error message: "${error.message}"`);
    console.log('[AUTH] JWT Verify Failed');
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