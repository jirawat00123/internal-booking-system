const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
require('dotenv').config();

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'your_default_secret_key';

const authenticateToken = async (req, res, next) => {
  // 🟢 ปล่อยผ่าน OPTIONS request สำหรับ CORS Preflight (แก้ปัญหา 401 ตอนส่ง PUT/DELETE/POST)
  if (req.method === 'OPTIONS') {
    return next();
  }

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
  
  // รองรับการรับ Token จาก Query Parameter (กรณีดาวน์โหลดไฟล์ผ่าน Browser)
  if (!token && req.query && req.query.token) {
    token = req.query.token;
  }

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

    // 💡 [Requirement Week 13] Guest Mode Validation
    // ดักจับ Guest ก่อนเข้า Database เพราะ Guest จะไม่มี Record ในตาราง User
    if (decoded.role && decoded.role.toUpperCase() === 'GUEST') {
      req.user.role = 'GUEST';
      
      // ดักไม่ให้ Guest ทำการเขียน/แก้ไขข้อมูลใดๆ ผ่าน API (Read Only)
      if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
        console.log(`[EVIDENCE] 403 Failure Cause: [GUEST_WRITE_ATTEMPT] Guest tried to use ${req.method} on ${req.originalUrl}`);
        return res.status(403).json({ success: false, error: "กรุณา Login ก่อนใช้งาน (Guest สามารถอ่านข้อมูลได้อย่างเดียว)" }); 
      }
      
      // ถ้าเป็น GET (อ่านข้อมูล) ให้ผ่านไปได้เลยโดยไม่ต้อง Query Database
      return next();
    }

    const user = await prisma.user.findUnique({
      where: { id: parseInt(decoded.userId, 10) },
      include: { role: true, employee: true } // 💡 สั่งให้ Prisma JOIN ข้อมูลตาราง roles และ employee มาด้วย
    });

    if (!user) {
      console.log(`[EVIDENCE] 7. 401 Failure Cause: [USER_NOT_FOUND] User with ID "${decoded.userId}" was not found in Database.`);
      console.log('[AUTH] User Not Found');
      return res.status(401).json({ success: false, error: "ไม่พบข้อมูลผู้ใช้งาน" });
    }

    // แก้ไขเพิ่มเติม: ตรวจสอบสถานะการเปิดใช้งานบัญชี และการถูกลบ (Soft Delete)
    // อ้างอิงจาก Source of Truth ตาราง user ฟิลด์ "active" และ "isDeleted" รวมถึงสถานะพนักงาน
    if (!user.active || user.isDeleted || (user.employee && (user.employee.isActive === false || user.employee.active === false))) {
      console.log(`[EVIDENCE] 7. 403 Failure Cause: [USER_INACTIVE_OR_DELETED] User ID "${decoded.userId}" account is deactivated or deleted.`);
      return res.status(403).json({ success: false, error: "บัญชีผู้ใช้งานของคุณถูกระงับสิทธิ์หรือถูกลบออกจากระบบ" });
    }

    // 🔴 [Global Account Lockout] ตรวจสอบว่าบัญชีถูก Lock อยู่หรือไม่ (บังคับใช้ทุก Session/Device ทันที)
    if (user.lockedUntil && new Date(user.lockedUntil) > new Date()) {
      console.log(`[EVIDENCE] 403 Failure Cause: [ACCOUNT_LOCKED] User ID "${decoded.userId}" is globally locked until ${user.lockedUntil}. Existing session is blocked.`);
      return res.status(403).json({ 
        success: false, 
        error: "บัญชีของคุณถูกระงับชั่วคราวเนื่องจากใส่รหัสผิดเกินจำนวน กรุณารอจนกว่าระยะเวลาระงับจะสิ้นสุด" 
      });
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
    
    // ✅ แก้ไข: ประกาศตัวแปรคำนวณผลลัพธ์การเปรียบเทียบ Session ID (รองรับกรณีไม่มี sessionId หรือ DB เป็น null)
    const isSessionValid = !decoded.sessionId || !user.currentSessionId || decoded.sessionId === user.currentSessionId;

    console.log(`   -> decoded.sessionId (From Token):        "${decoded.sessionId}"`);
    console.log(`   -> user.currentSessionId (From Database): "${user.currentSessionId}"`);
    console.log(`   -> Comparison Result (decoded.sessionId === user.currentSessionId): "${isSessionValid}"`);

    if (!isSessionValid) {
      // 🚨 [Requirement 7] LOG สาเหตุ 401: Session ไม่ตรงกัน (เกิด Mismatch)
      console.log('[EVIDENCE] 7. 401 Failure Cause: [SESSION_MISMATCH] Session IDs do not match (Current session may be stale or cleared).');
      console.log(`[AUTH] Session Mismatch | Token Session: ${decoded.sessionId} | DB Session: ${user.currentSessionId}`);
      
      // ส่ง 401 พร้อม HTTP code และ error message ชัดเจน เพื่อให้ Client ทำการ Logout และเปลี่ยนหน้าไปหน้า Login ได้อย่างถูกต้อง
      return res.status(401).json({ 
        success: false, 
        error: "SESSION_EXPIRED",
        message: "เซสชันหมดอายุ หรือมีการเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่" 
      });
    }

    // ✅ ปรับการอ่านค่า Role ให้ปลอดภัย และล็อกไม่ให้ SECURITY แอบเนียนเป็น USER
    const dbRole = (user.role?.name || user.roles || '').toUpperCase();
    const tokenRole = (decoded.role || '').toUpperCase();

    if (dbRole === 'SECURITY' || dbRole === 'GUARD' || tokenRole === 'SECURITY' || tokenRole === 'GUARD') {
      req.user.role = 'SECURITY';
    } else {
      req.user.role = dbRole || tokenRole || 'USER';
    }
    req.user.employeeCode = decoded.employeeCode;

    next();

  } catch (error) {
    // 🟢 ตรวจสอบกรณี Token หมดอายุ (TokenExpiredError)
    if (error.name === 'TokenExpiredError') {
      console.log(`[EVIDENCE] 7. 401 Failure Cause: [TOKEN_EXPIRED] Token has expired.`);
      return res.status(401).json({ 
        success: false, 
        error: "TOKEN_EXPIRED", 
        message: "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่" 
      });
    }

    // 🚨 [Requirement 7] LOG สาเหตุ 401: การตรวจสอบด้วย jwt.verify ล้มเหลว
    console.log(`[EVIDENCE] 7. 401 Failure Cause: [JWT_VERIFICATION_FAILED] Error message: "${error.message}"`);
    console.log('[AUTH] JWT Verify Failed');
    console.error('[AUTH] ERROR STACK:', error?.stack);
    return res.status(401).json({ success: false, error: "สิทธิ์การเข้าใช้งานไม่ถูกต้อง" });
  }
};

const verifyToken = authenticateToken;

const requireRole = (allowedRoles) => {
    return (req, res, next) => {
        // อาศัย req.user.role ที่ผ่านการ Validate อย่างเข้มงวดมาแล้ว
        const currentRole = (req.user?.role || '').toUpperCase();
        
        // แปลง allowedRoles ทั้งหมดเป็น Uppercase เพื่อป้องกันบั๊กการพิมพ์ผิด
        const normalizedAllowedRoles = allowedRoles.map(role => role.toUpperCase());

        if (!req.user || !normalizedAllowedRoles.includes(currentRole)) {
            return res.status(403).json({ 
                success: false, 
                error: "ปฏิเสธการเข้าถึง: สิทธิ์ของคุณไม่เพียงพอ" 
            });
        }
        next();
    };
};

const isAdmin = (req, res, next) => {
    const role = (req.user?.role || '').toUpperCase();
    if (role !== 'ADMIN') {
        return res.status(403).json({ 
            success: false, 
            error: "ปฏิเสธการเข้าถึง: สิทธิ์เฉพาะ Admin เท่านั้น" 
        });
    }
    next();
};

const isUser = (req, res, next) => {
    const role = (req.user?.role || '').toUpperCase();
    if (role === 'SECURITY' || role === 'GUARD') {
        return res.status(403).json({ 
            success: false, 
            error: "ปฏิเสธการเข้าถึง: เจ้าหน้าที่ รปภ. ไม่มีสิทธิ์เข้าใช้งานในส่วนผู้ใช้ทั่วไป" 
        });
    }
    next();
};

module.exports = {
    JWT_SECRET,
    authenticateToken,
    verifyToken,
    requireRole,
    isAdmin,
    isUser
};