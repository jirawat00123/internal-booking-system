// generate-pin-hash.js
const argon2 = require('argon2');

async function generateAdminPin() {
    const plainPin = '852000'; // PIN ที่ Admin ต้องการ
    try {
        // ใช้ Default Config ของระบบเพื่อสร้าง Hash
        const hash = await argon2.hash(plainPin);
        console.log('--- Copy the Hash below ---');
        console.log(hash);
        console.log('---------------------------');
    } catch (err) {
        console.error('Hashing failed', err);
    }
}

generateAdminPin();