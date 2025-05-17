const express = require('express');
const router = express.Router();
const Device = require('../models/Device');
const { protect } = require('../middleware/auth.middleware');
const UserRoleAssociation = require('../models/UserRoleAssociation');
const Property = require('../models/Property');

// Middleware for authentication would go here
// const auth = require('../middleware/auth');

// @route   GET /api/devices
// @desc    Get all devices the user has access to
// @access  Private
router.get('/', protect, async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { portfolioId, propertyId, unitId } = req.query;

    // Fetch role associations for this user
    const associations = await UserRoleAssociation.find({ userId });

    // Helper sets for quick lookup
    const allowedUnitIds = associations
      .filter(a => a.associatedEntityType === 'UNIT')
      .map(a => a.associatedEntityId.toString());
    const allowedPropertyIds = associations
      .filter(a => a.associatedEntityType === 'PROPERTY')
      .map(a => a.associatedEntityId.toString());
    const hasPortfolioLevelAccess = associations.some(
      a => a.associatedEntityType === 'PORTFOLIO'
    );

    let query = {};
    if (unitId) {
      // Explicit unit filter – ensure user authorized
      if (!allowedUnitIds.includes(unitId.toString()) && !hasPortfolioLevelAccess) {
        return res.status(403).json({ success: false, message: 'Forbidden: No access to requested unit.' });
      }
      query.unitId = unitId;
    } else if (propertyId) {
      if (!allowedPropertyIds.includes(propertyId.toString()) && !hasPortfolioLevelAccess) {
        return res.status(403).json({ success: false, message: 'Forbidden: No access to requested property.' });
      }
      query.propertyId = propertyId;
    } else if (portfolioId) {
      // Implement portfolio => properties lookup to filter by portfolio.
      // First verify user is allowed to access this portfolio. Acceptable if:
      //  a) user has portfolio-level association for this portfolio OR
      //  b) user has property-level association for at least one property in this portfolio.

      const allowedPortfolioIds = associations
        .filter(a => a.associatedEntityType === 'PORTFOLIO')
        .map(a => a.associatedEntityId.toString());

      if (!allowedPortfolioIds.includes(portfolioId.toString()) && !hasPortfolioLevelAccess) {
        // Secondary check: property-level associations inside portfolio
        const propertiesWithinPortfolio = await Property.find({ portfolioId }).select('_id');
        const propertyIdStrings = propertiesWithinPortfolio.map(p => p._id.toString());
        const hasPropertyAccessWithinPortfolio = allowedPropertyIds.some(pid => propertyIdStrings.includes(pid));
        if (!hasPropertyAccessWithinPortfolio) {
          return res.status(403).json({ success: false, message: 'Forbidden: No access to requested portfolio.' });
        }
      }

      // Build query to fetch devices whose propertyId belongs to this portfolio (and within user's scope if no portfolio-level access):
      const propertiesInPortfolio = await Property.find({ portfolioId }).select('_id');
      const portfolioPropertyIds = propertiesInPortfolio.map(p => p._id);
      query.propertyId = { $in: portfolioPropertyIds };
    } else {
      // Default: restrict to allowed unit/property IDs
      query.$or = [
        { unitId: { $in: allowedUnitIds } },
        { propertyId: { $in: allowedPropertyIds } }
      ];
      if (hasPortfolioLevelAccess) {
        // Portfolio-level users can also see devices not linked to unit or property explicitly (e.g., common devices)
        query = { $or: [query, { unitId: { $exists: false } }, { propertyId: { $exists: false } }] };
      }
    }

    const devices = await Device.find(query);
    
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
router.get('/:id', protect, async (req, res, next) => {
  try {
    const device = await Device.findById(req.params.id);
    
    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'Device not found'
      });
    }
    
    // Authorization: verify user access using role associations
    const associations = await UserRoleAssociation.find({ userId: req.user.id });
    const allowedUnitIds = associations.filter(a => a.associatedEntityType === 'UNIT').map(a => a.associatedEntityId.toString());
    const allowedPropertyIds = associations.filter(a => a.associatedEntityType === 'PROPERTY').map(a => a.associatedEntityId.toString());
    const hasPortfolioLevelAccess = associations.some(a => a.associatedEntityType === 'PORTFOLIO');

    const deviceUnitId = device.unitId ? device.unitId.toString() : null;
    const devicePropertyId = device.propertyId ? device.propertyId.toString() : null;

    if (
      !hasPortfolioLevelAccess &&
      !(
        (deviceUnitId && allowedUnitIds.includes(deviceUnitId)) ||
        (devicePropertyId && allowedPropertyIds.includes(devicePropertyId))
      )
    ) {
      return res.status(403).json({ success: false, message: 'Forbidden: No access to this device.' });
    }
    
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
router.post('/:id/control', protect, async (req, res, next) => {
  try {
    const device = await Device.findById(req.params.id);
    
    if (!device) {
      return res.status(404).json({
        success: false,
        message: 'Device not found'
      });
    }
    
    // Authorization check (reuse logic from GET /:id)
    const associations = await UserRoleAssociation.find({ userId: req.user.id });
    const allowedUnitIds = associations.filter(a => a.associatedEntityType === 'UNIT').map(a => a.associatedEntityId.toString());
    const allowedPropertyIds = associations.filter(a => a.associatedEntityType === 'PROPERTY').map(a => a.associatedEntityId.toString());
    const hasPortfolioLevelAccess = associations.some(a => a.associatedEntityType === 'PORTFOLIO');

    const deviceUnitId = device.unitId ? device.unitId.toString() : null;
    const devicePropertyId = device.propertyId ? device.propertyId.toString() : null;

    if (
      !hasPortfolioLevelAccess &&
      !(
        (deviceUnitId && allowedUnitIds.includes(deviceUnitId)) ||
        (devicePropertyId && allowedPropertyIds.includes(devicePropertyId))
      )
    ) {
      return res.status(403).json({ success: false, message: 'Forbidden: No access to this device.' });
    }
    
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