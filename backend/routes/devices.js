const express = require('express');
const router = express.Router();
const Device = require('../models/Device');

// Middleware for authentication would go here
// const auth = require('../middleware/auth');

// @route   GET /api/devices
// @desc    Get all devices the user has access to
// @access  Private
router.get('/', async (req, res, next) => {
  try {
    // In a real implementation, you would get the user's properties from the JWT token
    // and then find all devices for those properties
    
    // For now, just return all devices
    const devices = await Device.find();
    
    res.status(200).json({
      success: true,
      count: devices.length,
      data: devices
    });
  } catch (error) {
    next(error);
  }
});

// @route   GET /api/devices/:id
// @desc    Get a single device by ID
// @access  Private
router.get('/:id', async (req, res, next) => {
  try {
    const device = await Device.findById(req.params.id);
    
    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'Device not found'
      });
    }
    
    // Check if user has access to this device
    // In a real implementation, you would check if the user has access to the property
    
    res.status(200).json({
      success: true,
      data: device
    });
  } catch (error) {
    next(error);
  }
});

// @route   POST /api/devices
// @desc    Create a new device
// @access  Private (Owner or Property Manager only)
router.post('/', async (req, res, next) => {
  try {
    const { name, manufacturer, type, propertyId, roomId } = req.body;
    
    const device = new Device({
      name,
      manufacturer,
      type,
      property: propertyId,
      room: roomId,
      status: 'OFFLINE',
      capabilities: []
    });
    
    await device.save();
    
    res.status(201).json({
      success: true,
      data: device
    });
  } catch (error) {
    next(error);
  }
});

// @route   POST /api/devices/:id/control
// @desc    Control a device
// @access  Private
router.post('/:id/control', async (req, res, next) => {
  try {
    const device = await Device.findById(req.params.id);
    
    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'Device not found'
      });
    }
    
    // Check if user has access to this device
    // In a real implementation, you would check if the user has access to the property
    
    // In a real implementation, you would send the command to the device
    // through the appropriate integration service
    
    // For now, just update the device status
    device.status = 'ONLINE';
    await device.save();
    
    res.status(200).json({
      success: true,
      message: 'Command sent to device',
      data: device
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router; 