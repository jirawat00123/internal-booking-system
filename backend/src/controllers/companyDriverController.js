const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const fs = require('fs');
const path = require('path');

// GET /api/company-drivers
const getAllDrivers = async (req, res) => {
  try {
    const drivers = await prisma.employee.findMany({
      where: {
        isDriver: true,
        isActive: true
      },
      orderBy: { fullName: 'asc' }
    });

    const formattedDrivers = drivers.map(driver => ({
      ...driver,
      name: driver.fullName
    }));

    res.status(200).json({ success: true, data: formattedDrivers });
  } catch (error) {
    console.error('Error fetching company drivers:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// GET /api/company-drivers/:id
const getDriverById = async (req, res) => {
  try {
    const { id } = req.params;
    const driverId = parseInt(id, 10);
    
    if (isNaN(driverId)) {
      return res.status(400).json({ success: false, message: 'Invalid driver ID format' });
    }

    const driver = await prisma.employee.findFirst({
      where: {
        id: driverId,
        isDriver: true
      }
    });

    if (!driver) return res.status(404).json({ success: false, message: 'Driver not found' });

    res.status(200).json({
      success: true,
      data: {
        ...driver,
        name: driver.fullName
      }
    });
  } catch (error) {
    console.error('Error fetching driver:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// POST /api/company-drivers
const createDriver = async (req, res) => {
  try {
    const { employeeId, name, fullName, isActive } = req.body;
    const targetName = fullName || name;

    let driverEmployee;

    if (employeeId) {
      driverEmployee = await prisma.employee.update({
        where: { id: parseInt(employeeId, 10) },
        data: {
          isDriver: true,
          ...(isActive !== undefined && { isActive })
        }
      });
    } else if (targetName) {
      const existingEmployee = await prisma.employee.findFirst({
        where: { fullName: { equals: targetName, mode: 'insensitive' } }
      });

      if (!existingEmployee) {
        return res.status(404).json({ success: false, message: 'Employee not found' });
      }

      driverEmployee = await prisma.employee.update({
        where: { id: existingEmployee.id },
        data: {
          isDriver: true,
          ...(isActive !== undefined && { isActive })
        }
      });
    } else {
      return res.status(400).json({ success: false, message: 'Employee identifier required' });
    }

    if (req.user) {
      const currentUserId = req.user.userId || req.user.id;
      if (currentUserId) {
        await prisma.auditLog.create({
          data: {
            action: 'CREATE',
            module: 'COMPANY_DRIVER',
            userId: parseInt(currentUserId, 10),
            details: `Set employee as company driver: ${driverEmployee.fullName}`,
            entityId: driverEmployee.id,
            entityType: 'EMPLOYEE'
          }
        }).catch(err => console.error('AuditLog Error:', err.message));
      }
    }

    res.status(201).json({
      success: true,
      data: {
        ...driverEmployee,
        name: driverEmployee.fullName
      }
    });
  } catch (error) {
    console.error('Error creating driver:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

// PUT /api/company-drivers/:id
const updateDriver = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, fullName, isActive, isDriver } = req.body;
    const driverId = parseInt(id, 10);

    if (isNaN(driverId)) {
      return res.status(400).json({ success: false, message: 'Invalid driver ID format' });
    }

    const targetName = fullName || name;

    const updatedEmployee = await prisma.employee.update({
      where: { id: driverId },
      data: {
        ...(targetName !== undefined && { fullName: targetName }),
        ...(isActive !== undefined && { isActive }),
        ...(isDriver !== undefined && { isDriver })
      }
    });

    if (req.user) {
      const currentUserId = req.user.userId || req.user.id;
      if (currentUserId) {
        await prisma.auditLog.create({
          data: {
            action: 'UPDATE',
            module: 'COMPANY_DRIVER',
            userId: parseInt(currentUserId, 10),
            details: `Updated company driver: ${updatedEmployee.fullName}`,
            entityId: updatedEmployee.id,
            entityType: 'EMPLOYEE'
          }
        }).catch(err => console.error('AuditLog Error:', err.message));
      }
    }

    res.status(200).json({
      success: true,
      data: {
        ...updatedEmployee,
        name: updatedEmployee.fullName
      }
    });
  } catch (error) {
    console.error('Error updating driver:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = {
  getAllDrivers,
  getDriverById,
  createDriver,
  updateDriver
};