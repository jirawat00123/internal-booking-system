const express = require('express');
const router = express.Router();

// โครงสร้างชั่วคราวสำหรับ API การจอง (ป้องกัน Server Crash)
router.get('/', (req, res) => {
    res.json({ message: 'Booking API is ready to use!' });
});

module.exports = router;