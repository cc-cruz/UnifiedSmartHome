const express = require('express');
const router = express.Router();
const Property = require('../models/Property');
const Device = require('../models/Device');
const Room = require('../models/Room');

// Middleware for authentication would go here
// const auth = require('../middleware/auth');

// @route   GET /api/properties
// @desc    Get all properties for the authenticated user
// @access  Private
router.get('/', async (req, res, next) => {
  try {
    // In a real implementation, you would get the user ID from the JWT token
    // const userId = req.user.id;
    const userId = '123'; // Dummy user ID for now
    
    // Find properties where the user is the owner, manager, or tenant
    const properties = await Property.find({
      $or: [
        { owner: userId },
        { managers: userId },
        { tenants: userId }
      ]
    });
    
    res.status(200).json({
      success: true,
      count: properties.length,
      data: properties
    });
  } catch (error) {
    next(error);
  }
});

// @route   GET /api/properties/:id
// @desc    Get a single property by ID
// @access  Private
router.get('/:id', async (req, res, next) => {
  try {
    const property = await Property.findById(req.params.id)
      .populate('rooms')
      .populate('devices');
    
    if (!property) {
      return res.status(404).json({
        success: false,
        message: 'Property not found'
      });
    }
    
    // Check if user has access to this property
    // In a real implementation, you would check if the user is the owner, manager, or tenant
    
    res.status(200).json({
      success: true,
      data: property
    });
  } catch (error) {
    next(error);
  }
});

// @route   POST /api/properties
// @desc    Create a new property
// @access  Private (Owner or Property Manager only)
router.post('/', async (req, res, next) => {
  try {
    const { name, address } = req.body;
    
    // In a real implementation, you would get the user ID from the JWT token
    // const userId = req.user.id;
    const userId = '123'; // Dummy user ID for now
    
    const property = new Property({
      name,
      address,
      owner: userId
    });
    
    await property.save();
    
    res.status(201).json({
      success: true,
      data: property
    });
  } catch (error) {
    next(error);
  }
});

// @route   GET /api/properties/:id/devices
// @desc    Get all devices for a property
// @access  Private
router.get('/:id/devices', async (req, res, next) => {
  try {
    const devices = await Device.find({ property: req.params.id });
    
    res.status(200).json({
      success: true,
      count: devices.length,
      data: devices
    });
  } catch (error) {
    next(error);
  }
});

// @route   GET /api/properties/:id/rooms
// @desc    Get all rooms for a property
// @access  Private
router.get('/:id/rooms', async (req, res, next) => {
  try {
    const rooms = await Room.find({ property: req.params.id });
    
    res.status(200).json({
      success: true,
      count: rooms.length,
      data: rooms
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router; 