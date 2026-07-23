const crypto = require('crypto');
const argon2 = require('argon2');

const PEPPER = process.env.PIN_PEPPER_SECRET;

if (!PEPPER) {
  console.error("FATAL ERROR: PIN_PEPPER_SECRET is missing in .env");
  process.exit(1); // หยุดการทำงานถ้าลืมใส่ .env
}

// ผสม Pepper ผ่าน HMAC-SHA256
const applyPepper = (pin) => {
  return crypto
    .createHmac('sha256', PEPPER)
    .update(pin)
    .digest('hex');
};

// ฟังก์ชัน Hash PIN
const hashPin = async (pin) => {
  const pepperedPin = applyPepper(pin);
  
  return await argon2.hash(pepperedPin, {
    type: argon2.argon2id,
    memoryCost: 2 ** 16, // 64 MB
    timeCost: 3,         // 3 Iterations
    parallelism: 1,
  });
};

// ฟังก์ชันตรวจสอบ PIN
// 🟢 แก้ไข 1: สลับลำดับ Parameter เป็น (hashedPin, plainPin) ให้ตรงกับที่ Controller เรียกใช้
const verifyPin = async (hashedPin, plainPin) => { 
  // 🟢 แก้ไข 2: เพิ่มการดักจับค่าว่างทั้งสองตัว
  if (!hashedPin || !plainPin) return false; 
  
  try {
    const pepperedPin = applyPepper(plainPin);
    // 🟢 แก้ไข 3: ครอบ try-catch ป้องกันกรณี Argon2 โยน Error เนื่องจากรูปแบบ Hash ผิด
    return await argon2.verify(hashedPin, pepperedPin);
  } catch (error) {
    console.error('Argon2 Verify Error:', error.message);
    return false; // บล็อกการเข้าสู่ระบบทันทีหากเกิดข้อผิดพลาด
  }
};

module.exports = {
  hashPin,
  verifyPin
};