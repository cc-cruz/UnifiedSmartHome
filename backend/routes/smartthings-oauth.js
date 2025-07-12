const express = require('express');
const router = express.Router();
const SmartThingsToken = require('../models/SmartThingsToken');
const { protect } = require('../middleware/auth.middleware');
const logger = require('../logger');

// SmartThings OAuth 2.0 Configuration
const SMARTTHINGS_CLIENT_ID = process.env.SMARTTHINGS_CLIENT_ID;
const SMARTTHINGS_CLIENT_SECRET = process.env.SMARTTHINGS_CLIENT_SECRET;
const SMARTTHINGS_REDIRECT_URI = process.env.SMARTTHINGS_REDIRECT_URI || 'https://unifiedsmarthome.onrender.com/api/v1/smartthings/oauth/callback';

// Validate required environment variables
if (!SMARTTHINGS_CLIENT_ID || !SMARTTHINGS_CLIENT_SECRET) {
  logger.error('SmartThings OAuth configuration missing. Please set SMARTTHINGS_CLIENT_ID and SMARTTHINGS_CLIENT_SECRET environment variables.');
}

// @route   GET /api/v1/smartthings/oauth/authorize
// @desc    Initialize SmartThings OAuth flow for authenticated user
// @access  Private (Protected by JWT)
router.get('/authorize', protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const { propertyId, unitId } = req.query;
    
    // Generate state parameter for CSRF protection
    const state = Buffer.from(JSON.stringify({
      userId,
      propertyId: propertyId || null,
      unitId: unitId || null,
      timestamp: Date.now()
    })).toString('base64');
    
    // SmartThings OAuth scope for device control
    const scope = 'r:devices:* x:devices:* r:locations:* r:scenes:* x:scenes:*';
    
    const authUrl = `https://api.smartthings.com/oauth/authorize?` +
      `response_type=code&` +
      `client_id=${SMARTTHINGS_CLIENT_ID}&` +
      `redirect_uri=${encodeURIComponent(SMARTTHINGS_REDIRECT_URI)}&` +
      `scope=${encodeURIComponent(scope)}&` +
      `state=${encodeURIComponent(state)}`;
    
    logger.info('SmartThings OAuth authorization started', { 
      userId, 
      propertyId, 
      unitId,
      state: state.substring(0, 20) + '...' // Log truncated state for debugging
    });
    
    res.json({
      success: true,
      authUrl,
      state
    });
    
  } catch (error) {
    logger.error('SmartThings OAuth authorization error', { 
      error: error.message,
      userId: req.user?.id
    });
    res.status(500).json({
      success: false,
      message: 'Failed to initialize SmartThings authorization'
    });
  }
});

// @route   GET /api/v1/smartthings/oauth/callback
// @desc    Handle SmartThings OAuth callback and store tokens
// @access  Public (but validates state parameter)
router.get('/callback', async (req, res) => {
  try {
    const { code, state, error } = req.query;
    
    if (error) {
      logger.error('SmartThings OAuth callback error', { error, state });
      return res.status(400).json({ 
        success: false,
        message: 'OAuth authorization failed', 
        error 
      });
    }
    
    if (!code || !state) {
      logger.error('SmartThings OAuth callback missing parameters', { code: !!code, state: !!state });
      return res.status(400).json({ 
        success: false,
        message: 'Missing authorization code or state parameter' 
      });
    }
    
    // Decode and validate state parameter
    let stateData;
    try {
      stateData = JSON.parse(Buffer.from(state, 'base64').toString());
    } catch (err) {
      logger.error('SmartThings OAuth invalid state parameter', { state });
      return res.status(400).json({ 
        success: false,
        message: 'Invalid state parameter' 
      });
    }
    
    const { userId, propertyId, unitId, timestamp } = stateData;
    
    // Check state timestamp (reject if older than 10 minutes)
    const tenMinutesAgo = Date.now() - (10 * 60 * 1000);
    if (timestamp < tenMinutesAgo) {
      logger.error('SmartThings OAuth expired state', { userId, timestamp });
      return res.status(400).json({ 
        success: false,
        message: 'Authorization request expired' 
      });
    }
    
    // Exchange authorization code for access token
    const tokenResponse = await fetch('https://api.smartthings.com/oauth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${Buffer.from(`${SMARTTHINGS_CLIENT_ID}:${SMARTTHINGS_CLIENT_SECRET}`).toString('base64')}`
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: SMARTTHINGS_REDIRECT_URI
      })
    });
    
    const tokenData = await tokenResponse.json();
    
    if (!tokenResponse.ok) {
      logger.error('SmartThings token exchange failed', { 
        status: tokenResponse.status, 
        error: tokenData,
        userId
      });
      return res.status(400).json({ 
        success: false,
        message: 'Token exchange failed', 
        details: tokenData 
      });
    }
    
    // Calculate token expiration
    const expiresAt = new Date(Date.now() + (tokenData.expires_in * 1000));
    
    // Store token in database (upsert pattern for user/property/unit combination)
    const tokenRecord = await SmartThingsToken.findOneAndUpdate(
      { userId, propertyId, unitId },
      {
        accessToken: tokenData.access_token,
        refreshToken: tokenData.refresh_token,
        expiresAt,
        scope: tokenData.scope,
        isActive: true,
        lastRefreshed: new Date()
      },
      { 
        upsert: true, 
        new: true,
        setDefaultsOnInsert: true
      }
    );
    
    logger.info('SmartThings OAuth successful', { 
      userId, 
      propertyId, 
      unitId,
      tokenId: tokenRecord._id,
      scope: tokenData.scope,
      expiresAt
    });
    
    // Return success response (don't include actual tokens)
    res.json({ 
      success: true, 
      message: 'SmartThings integration authorized successfully',
      tokenId: tokenRecord._id,
      expiresAt,
      scope: tokenData.scope
    });
    
  } catch (error) {
    logger.error('SmartThings OAuth callback error', { 
      error: error.message,
      stack: error.stack
    });
    res.status(500).json({ 
      success: false,
      message: 'Internal server error during OAuth callback' 
    });
  }
});

// @route   POST /api/v1/smartthings/oauth/refresh
// @desc    Refresh SmartThings access token
// @access  Private (Protected by JWT)
router.post('/refresh', protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const { propertyId, unitId } = req.body;
    
    // Find the token record
    const tokenRecord = await SmartThingsToken.findOne({
      userId,
      propertyId: propertyId || null,
      unitId: unitId || null,
      isActive: true
    }).select('+accessToken +refreshToken');
    
    if (!tokenRecord) {
      return res.status(404).json({
        success: false,
        message: 'SmartThings token not found'
      });
    }
    
    // Refresh the token
    const refreshResponse = await fetch('https://api.smartthings.com/oauth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${Buffer.from(`${SMARTTHINGS_CLIENT_ID}:${SMARTTHINGS_CLIENT_SECRET}`).toString('base64')}`
      },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: tokenRecord.refreshToken
      })
    });
    
    const refreshData = await refreshResponse.json();
    
    if (!refreshResponse.ok) {
      logger.error('SmartThings token refresh failed', { 
        status: refreshResponse.status, 
        error: refreshData,
        userId,
        tokenId: tokenRecord._id
      });
      
      // If refresh fails, mark token as inactive
      await SmartThingsToken.findByIdAndUpdate(tokenRecord._id, { isActive: false });
      
      return res.status(400).json({ 
        success: false,
        message: 'Token refresh failed', 
        details: refreshData 
      });
    }
    
    // Update token record
    const expiresAt = new Date(Date.now() + (refreshData.expires_in * 1000));
    tokenRecord.accessToken = refreshData.access_token;
    if (refreshData.refresh_token) {
      tokenRecord.refreshToken = refreshData.refresh_token;
    }
    tokenRecord.expiresAt = expiresAt;
    tokenRecord.lastRefreshed = new Date();
    
    await tokenRecord.save();
    
    logger.info('SmartThings token refreshed successfully', { 
      userId,
      tokenId: tokenRecord._id,
      expiresAt
    });
    
    res.json({
      success: true,
      message: 'Token refreshed successfully',
      expiresAt
    });
    
  } catch (error) {
    logger.error('SmartThings token refresh error', { 
      error: error.message,
      userId: req.user?.id
    });
    res.status(500).json({
      success: false,
      message: 'Internal server error during token refresh'
    });
  }
});

// @route   DELETE /api/v1/smartthings/oauth/revoke
// @desc    Revoke SmartThings access token
// @access  Private (Protected by JWT)
router.delete('/revoke', protect, async (req, res) => {
  try {
    const userId = req.user.id;
    const { propertyId, unitId } = req.body;
    
    // Find and deactivate the token
    const result = await SmartThingsToken.findOneAndUpdate(
      {
        userId,
        propertyId: propertyId || null,
        unitId: unitId || null,
        isActive: true
      },
      { isActive: false },
      { new: true }
    );
    
    if (!result) {
      return res.status(404).json({
        success: false,
        message: 'SmartThings token not found'
      });
    }
    
    logger.info('SmartThings token revoked', { 
      userId,
      tokenId: result._id
    });
    
    res.json({
      success: true,
      message: 'SmartThings integration revoked successfully'
    });
    
  } catch (error) {
    logger.error('SmartThings token revocation error', { 
      error: error.message,
      userId: req.user?.id
    });
    res.status(500).json({
      success: false,
      message: 'Internal server error during token revocation'
    });
  }
});

module.exports = router; 