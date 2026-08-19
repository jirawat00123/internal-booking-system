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
    .update(String(pin).trim())
    .digest('hex');
};

// ฟังก์ชัน Hash PIN
const hashPin = async (pin) => {
  if (!pin) throw new Error('กรุณาระบุ PIN ที่ต้องการ Hash');
  const pepperedPin = applyPepper(pin);
  
  return await argon2.hash(pepperedPin, {
    type: argon2.argon2id,
    memoryCost: 2 ** 16, // 64 MB
    timeCost: 3,         // 3 Iterations
    parallelism: 1,
  });
};

// ฟังก์ชันตรวจสอบ PIN
const verifyPin = async (hashedPin, plainPin) => {
  if (!hashedPin || !plainPin) return false;

  try {
    // รองรับกรณีรหัส PIN ใน Database เป็นรหัสเก่าที่ยังไม่ได้ถูก Hash
    if (typeof hashedPin !== 'string' || !hashedPin.startsWith('$argon2')) {
      return String(hashedPin).trim() === String(plainPin).trim();
    }

    const pepperedPin = applyPepper(String(plainPin).trim());
    return await argon2.verify(hashedPin, pepperedPin);
  } catch (error) {
    console.error('Argon2 Verify Error:', error.message);
    return false;
  }
};

module.exports = {
  hashPin,
  verifyPin
};