const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const roomController = require('../controllers/roomController'); 

// 💡 [แก้ไข 1] เปลี่ยนมาใช้ verifyToken ให้ตรงกับไฟล์ auth.js ล่าสุด
const { verifyToken } = require('../middlewares/auth');

const uploadDir = 'uploads/';
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'room-' + uniqueSuffix + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });


// 💡 [แก้ไข 2] อัปเดต Middleware เป็น verifyToken
router.get('/', verifyToken, roomController.getAllRooms);
router.post('/', verifyToken, upload.single('image'), roomController.createRoom);

// 💡 [แก้ไข 3] ปิด 2 บรรทัดนี้ไว้ก่อนชั่วคราว เพราะใน roomController ยังไม่ได้เขียนฟังก์ชัน updateRoom กับ deleteRoom
// ไว้คุณไปเขียนฟังก์ชันใน Controller เสร็จ ค่อยกลับมาเอาเครื่องหมาย // ออกครับ
 router.put('/:id', verifyToken, upload.single('image'), roomController.updateRoom);
 router.delete('/:id', verifyToken, roomController.deleteRoom);

module.exports = router;