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
const verifyPin = async (plainPin, hashedPin) => {
  if (!hashedPin) return false;
  const pepperedPin = applyPepper(plainPin);
  return await argon2.verify(hashedPin, pepperedPin);
};

module.exports = {
  hashPin,
  verifyPin
};