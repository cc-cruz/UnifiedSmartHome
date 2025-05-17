const express = require('express');
const router = express.Router();
const Property = require('../models/Property');
const Device = require('../models/Device');
const Room = require('../models/Room');

// Middleware for authentication would go here
// const auth = require('../middleware/auth');

// @route   GET /api/properties
// @desc    Get all properties accessible by the authenticated user
// @access  Private
router.get('/', async (req, res, next) => {
  try {
    // const currentUser = req.user; // From auth middleware
    // TODO: Implement proper fetching based on currentUser.roleAssociations
    // For now, to ensure client gets data, fetching all properties (VERY INSECURE - FOR DEV ONLY)
    // This needs to be replaced with logic that filters properties based on req.user.roleAssociations
    // e.g. find all portfolios user is admin of, then all properties in those portfolios
    //      find all properties user is manager of directly
    //      find all properties containing units user is tenant of (more complex)

    console.warn("WARN: GET /api/properties is returning ALL properties. This is for development ONLY and is insecure.");
    const properties = await Property.find({}); // TEMPORARY: Fetch all properties
    
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
      // .populate('rooms') // Consider if these are always needed or can be fetched on demand
      // .populate('devices');
    
    if (!property) {
      return res.status(404).json({
        success: false,
        message: 'Property not found'
      });
    }
    
    // TODO: Add robust permission check based on req.user.roleAssociations and property.portfolioId
    
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
// @access  Private (e.g., Portfolio Admin or Owner)
router.post('/', async (req, res, next) => {
  try {
    const { name, address, portfolioId } = req.body; // Added portfolioId
    // const userId = req.user.id; // From auth middleware, for createdBy or owner fields if kept

    if (!portfolioId) {
      return res.status(400).json({
        success: false,
        message: 'portfolioId is required'
      });
    }
    
    // TODO: Validate that req.user has rights to create a property in this portfolioId

    const property = new Property({
      name,
      address,
      portfolioId,
      // owner: userId // If keeping an owner field, but primary link is portfolioId
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
    // TODO: Add robust permission check to ensure user can access this property's devices
    const devices = await Device.find({ property: req.params.id }); // Ensure Device model has 'property' field
    
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
    // TODO: Add robust permission check to ensure user can access this property's rooms
    const rooms = await Room.find({ property: req.params.id }); // Ensure Room model has 'property' field
    
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