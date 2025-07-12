const express = require('express');
const router = express.Router();
const SmartThingsToken = require('../models/SmartThingsToken');
const logger = require('../logger');

// Webhook verification signature validation
const verifyWebhookSignature = (req, res, next) => {
  // SmartThings sends webhook verification challenges
  const signature = req.headers['x-st-signature'];
  const timestamp = req.headers['x-st-timestamp'];
  
  // For now, log the webhook attempt
  logger.info('SmartThings webhook received', {
    signature: signature ? 'present' : 'missing',
    timestamp: timestamp ? 'present' : 'missing',
    contentType: req.headers['content-type'],
    userAgent: req.headers['user-agent'],
    bodySize: req.body ? JSON.stringify(req.body).length : 0
  });
  
  // TODO: Implement proper signature verification for production
  // For development, we'll allow all webhooks through
  next();
};

// @route   POST /api/webhooks/smartthings
// @desc    Handle SmartThings device events and notifications
// @access  Public (SmartThings service calls this)
router.post('/', verifyWebhookSignature, async (req, res) => {
  try {
    const { lifecycle, executionId, appId, eventType, eventData } = req.body;
    
    logger.info('SmartThings webhook payload', {
      lifecycle,
      executionId,
      appId,
      eventType,
      eventData: eventData ? Object.keys(eventData) : null
    });
    
    // Handle different webhook lifecycle events
    switch (lifecycle) {
      case 'PING':
        // SmartThings sends PING to verify webhook endpoint
        logger.info('SmartThings webhook PING received');
        return res.json({
          statusCode: 200,
          pingData: req.body.pingData
        });
      
      case 'CONFIGURATION':
        // Handle app configuration lifecycle
        return handleConfigurationLifecycle(req, res);
      
      case 'INSTALL':
        // Handle app installation
        return handleInstallLifecycle(req, res);
      
      case 'UPDATE':
        // Handle app updates
        return handleUpdateLifecycle(req, res);
      
      case 'UNINSTALL':
        // Handle app uninstallation
        return handleUninstallLifecycle(req, res);
      
      case 'EVENT':
        // Handle device events
        return handleDeviceEvent(req, res);
      
      case 'OAUTH_CALLBACK':
        // Handle OAuth callback (if using SmartApp flow)
        return handleOAuthCallback(req, res);
      
      default:
        logger.warn('Unknown SmartThings webhook lifecycle', { lifecycle });
        return res.status(400).json({
          statusCode: 400,
          message: 'Unknown lifecycle event'
        });
    }
    
  } catch (error) {
    logger.error('SmartThings webhook error', {
      error: error.message,
      stack: error.stack,
      body: req.body
    });
    
    res.status(500).json({
      statusCode: 500,
      message: 'Internal server error'
    });
  }
});

// Handle configuration lifecycle
const handleConfigurationLifecycle = async (req, res) => {
  const { configurationData } = req.body;
  
  logger.info('SmartThings configuration request', {
    phase: configurationData?.phase,
    pageId: configurationData?.pageId,
    previousPageId: configurationData?.previousPageId
  });
  
  // Return basic configuration for now
  // In production, this would return dynamic configuration pages
  return res.json({
    statusCode: 200,
    configurationData: {
      initialize: {
        name: 'Unified Smart Home',
        description: 'Unified Smart Home Integration',
        id: 'unified-smart-home',
        permissions: ['r:devices:*', 'x:devices:*'],
        firstPageId: '1'
      },
      page: {
        pageId: '1',
        name: 'Configuration',
        complete: true,
        sections: [
          {
            name: 'Settings',
            settings: [
              {
                id: 'selectedDevices',
                name: 'Select Devices',
                description: 'Choose devices to integrate',
                type: 'DEVICE',
                required: true,
                multiple: true,
                capabilities: ['switch', 'switchLevel', 'colorControl', 'thermostat']
              }
            ]
          }
        ]
      }
    }
  });
};

// Handle install lifecycle
const handleInstallLifecycle = async (req, res) => {
  const { installData } = req.body;
  
  logger.info('SmartThings app installation', {
    installedApp: installData?.installedApp,
    authToken: installData?.authToken ? 'present' : 'missing',
    refreshToken: installData?.refreshToken ? 'present' : 'missing'
  });
  
  // Store installation data if needed
  // This would be where you save the installedAppId and tokens
  
  return res.json({
    statusCode: 200,
    installData: {}
  });
};

// Handle update lifecycle
const handleUpdateLifecycle = async (req, res) => {
  const { updateData } = req.body;
  
  logger.info('SmartThings app update', {
    installedApp: updateData?.installedApp,
    authToken: updateData?.authToken ? 'present' : 'missing'
  });
  
  return res.json({
    statusCode: 200,
    updateData: {}
  });
};

// Handle uninstall lifecycle
const handleUninstallLifecycle = async (req, res) => {
  const { uninstallData } = req.body;
  
  logger.info('SmartThings app uninstallation', {
    installedApp: uninstallData?.installedApp
  });
  
  // Clean up any stored data for this installation
  // This would be where you remove tokens and configuration
  
  return res.json({
    statusCode: 200,
    uninstallData: {}
  });
};

// Handle device events
const handleDeviceEvent = async (req, res) => {
  const { eventData } = req.body;
  
  if (!eventData || !eventData.events) {
    logger.warn('SmartThings device event missing event data');
    return res.json({ statusCode: 200 });
  }
  
  // Process each device event
  for (const event of eventData.events) {
    const { 
      deviceId, 
      locationId, 
      installedAppId, 
      capability, 
      attribute, 
      value, 
      unit, 
      data 
    } = event;
    
    logger.info('SmartThings device event', {
      deviceId,
      locationId,
      installedAppId,
      capability,
      attribute,
      value,
      unit
    });
    
    // Here you would typically:
    // 1. Update device state in your database
    // 2. Send real-time updates to connected clients
    // 3. Trigger automation rules
    // 4. Send notifications to users
    
    try {
      await processDeviceEvent({
        deviceId,
        locationId,
        installedAppId,
        capability,
        attribute,
        value,
        unit,
        data,
        timestamp: new Date()
      });
    } catch (error) {
      logger.error('Error processing device event', {
        error: error.message,
        deviceId,
        capability,
        attribute
      });
    }
  }
  
  return res.json({ statusCode: 200 });
};

// Handle OAuth callback (for SmartApp flow)
const handleOAuthCallback = async (req, res) => {
  const { oauthCallbackData } = req.body;
  
  logger.info('SmartThings OAuth callback', {
    installedAppId: oauthCallbackData?.installedAppId,
    urlPath: oauthCallbackData?.urlPath
  });
  
  return res.json({
    statusCode: 200,
    oauthCallbackData: {}
  });
};

// Process individual device events
const processDeviceEvent = async (eventData) => {
  const { 
    deviceId, 
    locationId, 
    capability, 
    attribute, 
    value, 
    timestamp 
  } = eventData;
  
  // Log the event for debugging
  logger.info('Processing SmartThings device event', {
    deviceId,
    locationId,
    capability,
    attribute,
    value,
    timestamp
  });
  
  // TODO: Implement event processing logic
  // This is where you would:
  // 1. Update device state in your database
  // 2. Send real-time updates to iOS app via WebSocket/Server-Sent Events
  // 3. Trigger automation rules
  // 4. Send push notifications
  
  // For now, just log the event
  // In production, you might store events in a separate collection:
  /*
  const DeviceEvent = require('../models/DeviceEvent');
  const deviceEvent = new DeviceEvent({
    deviceId,
    locationId,
    capability,
    attribute,
    value,
    timestamp
  });
  await deviceEvent.save();
  */
};

// @route   GET /api/webhooks/smartthings/health
// @desc    Health check endpoint for SmartThings webhooks
// @access  Public
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'SmartThings webhook endpoint is healthy',
    timestamp: new Date().toISOString()
  });
});

// @route   POST /api/webhooks/smartthings/test
// @desc    Test webhook endpoint for development
// @access  Public (remove in production)
router.post('/test', (req, res) => {
  logger.info('SmartThings webhook test', {
    headers: req.headers,
    body: req.body
  });
  
  res.json({
    success: true,
    message: 'Test webhook received',
    received: {
      headers: req.headers,
      body: req.body
    }
  });
});

module.exports = router; 