const express = require('express');
const router = express.Router();
const { getAllDrivers, getDriverById, createDriver, updateDriver } = require('../controllers/companyDriverController');
const { authenticateToken } = require('../middlewares/auth');

router.get('/', authenticateToken, getAllDrivers);
router.get('/:id', authenticateToken, getDriverById);
router.post('/', authenticateToken, createDriver);
router.put('/:id', authenticateToken, updateDriver);

module.exports = router;