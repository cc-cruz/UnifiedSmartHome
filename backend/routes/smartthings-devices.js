const express = require('express');
const router = express.Router();
const SmartThingsToken = require('../models/SmartThingsToken');
const { protect } = require('../middleware/auth.middleware');
const logger = require('../logger');

// Helper function to get SmartThings API headers with access token
const getSmartThingsHeaders = (accessToken) => ({
  'Authorization': `Bearer ${accessToken}`,
  'Content-Type': 'application/json',
  'Accept': 'application/json'
});

// Helper function to get active token for user/property/unit
const getActiveToken = async (userId, propertyId = null, unitId = null) => {
  return await SmartThingsToken.findActiveToken(userId, propertyId, unitId)
    .select('+accessToken +refreshToken');
};

// Helper function to refresh token if needed
const ensureValidToken = async (tokenRecord) => {
  if (!tokenRecord) {
    throw new Error('Token not found');
  }
  
  if (tokenRecord.isExpired()) {
    throw new Error('Token expired');
  }
  
  // Auto-refresh if token expires soon
  if (tokenRecord.needsRefresh()) {
    logger.info('Auto-refreshing SmartThings token', { tokenId: tokenRecord._id });
    // Note: In production, implement token refresh logic here
    // For now, just log and continue with existing token
  }
  
  return tokenRecord;
};

// @route   GET /api/v1/smartthings/devices
// @desc    Get all SmartThings devices for authenticated user
// @access  Private (Protected by JWT)
router.get('/', protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const { propertyId, unitId } = req.query;
    
    // Get active token
    const tokenRecord = await getActiveToken(userId, propertyId, unitId);
    if (!tokenRecord) {
      return res.status(404).json({
        success: false,
        message: 'SmartThings integration not found. Please authorize first.'
      });
    }
    
    await ensureValidToken(tokenRecord);
    
    // Fetch devices from SmartThings API
    const devicesResponse = await fetch('https://api.smartthings.com/v1/devices', {
      headers: getSmartThingsHeaders(tokenRecord.accessToken)
    });
    
    if (!devicesResponse.ok) {
      const error = await devicesResponse.text();
      logger.error('SmartThings devices fetch failed', { 
        status: devicesResponse.status,
        error,
        userId,
        tokenId: tokenRecord._id
      });
      return res.status(devicesResponse.status).json({
        success: false,
        message: 'Failed to fetch devices from SmartThings'
      });
    }
    
    const devicesData = await devicesResponse.json();
    
    // Transform devices to match iOS app expectations
    const devices = devicesData.items.map(device => ({
      id: device.deviceId,
      name: device.name || device.label,
      type: device.deviceTypeName,
      capabilities: device.components?.[0]?.capabilities || [],
      status: device.status,
      locationId: device.locationId,
      roomId: device.roomId,
      // Additional metadata for iOS app
      metadata: {
        deviceId: device.deviceId,
        deviceTypeId: device.deviceTypeId,
        deviceTypeName: device.deviceTypeName,
        deviceNetworkType: device.deviceNetworkType,
        components: device.components,
        createTime: device.createTime,
        lastActivityTime: device.lastActivityTime
      }
    }));
    
    logger.info('SmartThings devices fetched successfully', { 
      userId,
      propertyId,
      unitId,
      deviceCount: devices.length,
      tokenId: tokenRecord._id
    });
    
    res.json({
      success: true,
      count: devices.length,
      devices
    });
    
  } catch (error) {
    logger.error('SmartThings devices fetch error', { 
      error: error.message,
      userId: req.user?.id
    });
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching devices'
    });
  }
});

// @route   GET /api/v1/smartthings/devices/:deviceId
// @desc    Get specific SmartThings device details
// @access  Private (Protected by JWT)
router.get('/:deviceId', protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const { deviceId } = req.params;
    const { propertyId, unitId } = req.query;
    
    // Get active token
    const tokenRecord = await getActiveToken(userId, propertyId, unitId);
    if (!tokenRecord) {
      return res.status(404).json({
        success: false,
        message: 'SmartThings integration not found'
      });
    }
    
    await ensureValidToken(tokenRecord);
    
    // Fetch device details and status
    const [deviceResponse, statusResponse] = await Promise.all([
      fetch(`https://api.smartthings.com/v1/devices/${deviceId}`, {
        headers: getSmartThingsHeaders(tokenRecord.accessToken)
      }),
      fetch(`https://api.smartthings.com/v1/devices/${deviceId}/status`, {
        headers: getSmartThingsHeaders(tokenRecord.accessToken)
      })
    ]);
    
    if (!deviceResponse.ok || !statusResponse.ok) {
      const deviceError = !deviceResponse.ok ? await deviceResponse.text() : null;
      const statusError = !statusResponse.ok ? await statusResponse.text() : null;
      
      logger.error('SmartThings device fetch failed', { 
        deviceId,
        deviceStatus: deviceResponse.status,
        statusStatus: statusResponse.status,
        deviceError,
        statusError,
        userId
      });
      
      return res.status(deviceResponse.status || statusResponse.status).json({
        success: false,
        message: 'Failed to fetch device from SmartThings'
      });
    }
    
    const deviceData = await deviceResponse.json();
    const statusData = await statusResponse.json();
    
    // Transform device data for iOS app
    const device = {
      id: deviceData.deviceId,
      name: deviceData.name || deviceData.label,
      type: deviceData.deviceTypeName,
      capabilities: deviceData.components?.[0]?.capabilities || [],
      status: statusData.components?.main || {},
      locationId: deviceData.locationId,
      roomId: deviceData.roomId,
      metadata: {
        deviceId: deviceData.deviceId,
        deviceTypeId: deviceData.deviceTypeId,
        deviceTypeName: deviceData.deviceTypeName,
        deviceNetworkType: deviceData.deviceNetworkType,
        components: deviceData.components,
        createTime: deviceData.createTime,
        lastActivityTime: deviceData.lastActivityTime,
        presentationId: deviceData.presentationId,
        manufacturerName: deviceData.manufacturerName,
        model: deviceData.model
      }
    };
    
    logger.info('SmartThings device fetched successfully', { 
      userId,
      deviceId,
      tokenId: tokenRecord._id
    });
    
    res.json({
      success: true,
      device
    });
    
  } catch (error) {
    logger.error('SmartThings device fetch error', { 
      error: error.message,
      deviceId: req.params.deviceId,
      userId: req.user?.id
    });
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching device'
    });
  }
});

// @route   POST /api/v1/smartthings/devices/:deviceId/commands
// @desc    Send command to SmartThings device
// @access  Private (Protected by JWT)
router.post('/:deviceId/commands', protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const { deviceId } = req.params;
    const { propertyId, unitId } = req.query;
    const { commands } = req.body;
    
    if (!commands || !Array.isArray(commands)) {
      return res.status(400).json({
        success: false,
        message: 'Commands array is required'
      });
    }
    
    // Get active token
    const tokenRecord = await getActiveToken(userId, propertyId, unitId);
    if (!tokenRecord) {
      return res.status(404).json({
        success: false,
        message: 'SmartThings integration not found'
      });
    }
    
    await ensureValidToken(tokenRecord);
    
    // Send commands to SmartThings API
    const commandResponse = await fetch(`https://api.smartthings.com/v1/devices/${deviceId}/commands`, {
      method: 'POST',
      headers: getSmartThingsHeaders(tokenRecord.accessToken),
      body: JSON.stringify({ commands })
    });
    
    if (!commandResponse.ok) {
      const error = await commandResponse.text();
      logger.error('SmartThings command failed', { 
        deviceId,
        commands,
        status: commandResponse.status,
        error,
        userId
      });
      return res.status(commandResponse.status).json({
        success: false,
        message: 'Failed to send command to SmartThings device'
      });
    }
    
    const commandData = await commandResponse.json();
    
    logger.info('SmartThings command sent successfully', { 
      userId,
      deviceId,
      commands,
      tokenId: tokenRecord._id
    });
    
    res.json({
      success: true,
      message: 'Command sent successfully',
      result: commandData
    });
    
  } catch (error) {
    logger.error('SmartThings command error', { 
      error: error.message,
      deviceId: req.params.deviceId,
      userId: req.user?.id
    });
    res.status(500).json({
      success: false,
      message: 'Internal server error while sending command'
    });
  }
});

// @route   GET /api/v1/smartthings/locations
// @desc    Get SmartThings locations for authenticated user
// @access  Private (Protected by JWT)
router.get('/locations', protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const { propertyId, unitId } = req.query;
    
    // Get active token
    const tokenRecord = await getActiveToken(userId, propertyId, unitId);
    if (!tokenRecord) {
      return res.status(404).json({
        success: false,
        message: 'SmartThings integration not found'
      });
    }
    
    await ensureValidToken(tokenRecord);
    
    // Fetch locations from SmartThings API
    const locationsResponse = await fetch('https://api.smartthings.com/v1/locations', {
      headers: getSmartThingsHeaders(tokenRecord.accessToken)
    });
    
    if (!locationsResponse.ok) {
      const error = await locationsResponse.text();
      logger.error('SmartThings locations fetch failed', { 
        status: locationsResponse.status,
        error,
        userId
      });
      return res.status(locationsResponse.status).json({
        success: false,
        message: 'Failed to fetch locations from SmartThings'
      });
    }
    
    const locationsData = await locationsResponse.json();
    
    logger.info('SmartThings locations fetched successfully', { 
      userId,
      locationCount: locationsData.items.length,
      tokenId: tokenRecord._id
    });
    
    res.json({
      success: true,
      count: locationsData.items.length,
      locations: locationsData.items
    });
    
  } catch (error) {
    logger.error('SmartThings locations fetch error', { 
      error: error.message,
      userId: req.user?.id
    });
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching locations'
    });
  }
});

// @route   GET /api/v1/smartthings/integration/status
// @desc    Get SmartThings integration status for user
// @access  Private (Protected by JWT)
router.get('/integration/status', protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const { propertyId, unitId } = req.query;
    
    // Get active token
    const tokenRecord = await getActiveToken(userId, propertyId, unitId);
    
    if (!tokenRecord) {
      return res.json({
        success: true,
        integrated: false,
        message: 'SmartThings integration not found'
      });
    }
    
    const status = {
      integrated: true,
      tokenId: tokenRecord._id,
      scope: tokenRecord.scope,
      expiresAt: tokenRecord.expiresAt,
      lastRefreshed: tokenRecord.lastRefreshed,
      isExpired: tokenRecord.isExpired(),
      needsRefresh: tokenRecord.needsRefresh()
    };
    
    logger.info('SmartThings integration status checked', { 
      userId,
      propertyId,
      unitId,
      status
    });
    
    res.json({
      success: true,
      ...status
    });
    
  } catch (error) {
    logger.error('SmartThings integration status error', { 
      error: error.message,
      userId: req.user?.id
    });
    res.status(500).json({
      success: false,
      message: 'Internal server error while checking integration status'
    });
  }
});

module.exports = router; 