const express = require('express');
const router = express.Router();

// แก้ไข path ให้ถอยออกมา 1 โฟลเดอร์ (..) แล้วค่อยเข้าไปที่ controllers
const roomController = require('../controllers/roomController');

// กำหนดเส้นทาง (Route) และเรียกใช้ Controller
router.get('/', roomController.getAllRooms);

module.exports = router;