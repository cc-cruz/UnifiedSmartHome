const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const SmartThingsToken = require('../models/SmartThingsToken');
const { protect } = require('../middleware/auth.middleware');
const logger = require('../logger');

// Schema App OAuth Configuration (SmartThings connects TO us)
const SCHEMA_CLIENT_ID = process.env.SMARTTHINGS_SCHEMA_CLIENT_ID || 'unified-smart-home-client';
const SCHEMA_CLIENT_SECRET = process.env.SMARTTHINGS_SCHEMA_CLIENT_SECRET || 'your-secret-key-here-make-it-secure-123';

// In-memory storage for auth codes and tokens (use Redis in production)
const authCodes = new Map();
const accessTokens = new Map();
const refreshTokens = new Map();

// Generate secure random tokens
const generateToken = () => crypto.randomBytes(32).toString('hex');
const generateCode = () => crypto.randomBytes(16).toString('hex');

// @route   GET /api/v1/smartthings/oauth/authorize
// @desc    OAuth authorization endpoint that SmartThings calls
// @access  Public (SmartThings calls this)
router.get('/authorize', async (req, res) => {
  try {
    const { 
      response_type, 
      client_id, 
      redirect_uri, 
      scope, 
      state 
    } = req.query;

    logger.info('SmartThings Schema OAuth authorization request', {
      response_type,
      client_id,
      redirect_uri,
      scope,
      state
    });

    // Validate required parameters
    if (!response_type || !client_id || !redirect_uri) {
      return res.status(400).json({
        error: 'invalid_request',
        error_description: 'Missing required parameters'
      });
    }

    // Validate client_id
    if (client_id !== SCHEMA_CLIENT_ID) {
      return res.status(400).json({
        error: 'invalid_client',
        error_description: 'Invalid client_id'
      });
    }

    // Validate response_type
    if (response_type !== 'code') {
      return res.status(400).json({
        error: 'unsupported_response_type',
        error_description: 'Only authorization code flow is supported'
      });
    }

    // Generate authorization code
    const authCode = generateCode();
    const expiresAt = Date.now() + (10 * 60 * 1000); // 10 minutes

    // Store authorization code
    authCodes.set(authCode, {
      client_id,
      redirect_uri,
      scope,
      state,
      expiresAt,
      userId: 'unified-smart-home-user' // In production, this would be the actual user
    });

    // For Schema Apps, we auto-approve (in production, you might show a consent screen)
    const callbackUrl = `${redirect_uri}?code=${authCode}&state=${encodeURIComponent(state || '')}`;

    logger.info('SmartThings Schema OAuth authorization granted', {
      authCode: authCode.substring(0, 8) + '...',
      redirect_uri,
      state
    });

    // Redirect SmartThings back with authorization code
    res.redirect(callbackUrl);

  } catch (error) {
    logger.error('SmartThings Schema OAuth authorization error', {
      error: error.message,
      query: req.query
    });
    
    const redirect_uri = req.query.redirect_uri;
    const state = req.query.state;
    
    if (redirect_uri) {
      const errorUrl = `${redirect_uri}?error=server_error&error_description=${encodeURIComponent('Internal server error')}&state=${encodeURIComponent(state || '')}`;
      res.redirect(errorUrl);
    } else {
      res.status(500).json({
        error: 'server_error',
        error_description: 'Internal server error'
      });
    }
  }
});

// @route   POST /api/v1/smartthings/oauth/token
// @desc    OAuth token endpoint that SmartThings calls
// @access  Public (SmartThings calls this)
router.post('/token', async (req, res) => {
  try {
    const { 
      grant_type, 
      code, 
      redirect_uri, 
      client_id, 
      client_secret,
      refresh_token 
    } = req.body;

    logger.info('SmartThings Schema OAuth token request', {
      grant_type,
      client_id,
      code: code ? code.substring(0, 8) + '...' : undefined,
      refresh_token: refresh_token ? refresh_token.substring(0, 8) + '...' : undefined
    });

    // Validate client credentials
    if (client_id !== SCHEMA_CLIENT_ID || client_secret !== SCHEMA_CLIENT_SECRET) {
      return res.status(401).json({
        error: 'invalid_client',
        error_description: 'Invalid client credentials'
      });
    }

    if (grant_type === 'authorization_code') {
      // Authorization code flow
      if (!code || !redirect_uri) {
        return res.status(400).json({
          error: 'invalid_request',
          error_description: 'Missing required parameters'
        });
      }

      // Validate authorization code
      const authData = authCodes.get(code);
      if (!authData) {
        return res.status(400).json({
          error: 'invalid_grant',
          error_description: 'Invalid or expired authorization code'
        });
      }

      // Check expiration
      if (Date.now() > authData.expiresAt) {
        authCodes.delete(code);
        return res.status(400).json({
          error: 'invalid_grant',
          error_description: 'Authorization code expired'
        });
      }

      // Validate redirect_uri matches
      if (authData.redirect_uri !== redirect_uri) {
        return res.status(400).json({
          error: 'invalid_grant',
          error_description: 'Redirect URI mismatch'
        });
      }

      // Generate tokens
      const accessToken = generateToken();
      const newRefreshToken = generateToken();
      const expiresIn = 3600; // 1 hour
      const tokenExpiresAt = Date.now() + (expiresIn * 1000);

      // Store tokens
      accessTokens.set(accessToken, {
        client_id,
        scope: authData.scope,
        userId: authData.userId,
        expiresAt: tokenExpiresAt
      });

      refreshTokens.set(newRefreshToken, {
        client_id,
        scope: authData.scope,
        userId: authData.userId,
        accessToken
      });

      // Clean up authorization code
      authCodes.delete(code);

      logger.info('SmartThings Schema OAuth token issued', {
        client_id,
        scope: authData.scope,
        expiresIn
      });

      return res.json({
        access_token: accessToken,
        token_type: 'Bearer',
        expires_in: expiresIn,
        refresh_token: newRefreshToken,
        scope: authData.scope
      });

    } else if (grant_type === 'refresh_token') {
      // Refresh token flow
      if (!refresh_token) {
        return res.status(400).json({
          error: 'invalid_request',
          error_description: 'Missing refresh_token'
        });
      }

      // Validate refresh token
      const refreshData = refreshTokens.get(refresh_token);
      if (!refreshData) {
        return res.status(400).json({
          error: 'invalid_grant',
          error_description: 'Invalid refresh token'
        });
      }

      // Invalidate old access token
      if (refreshData.accessToken) {
        accessTokens.delete(refreshData.accessToken);
      }

      // Generate new tokens
      const newAccessToken = generateToken();
      const newRefreshToken = generateToken();
      const expiresIn = 3600; // 1 hour
      const tokenExpiresAt = Date.now() + (expiresIn * 1000);

      // Store new tokens
      accessTokens.set(newAccessToken, {
        client_id,
        scope: refreshData.scope,
        userId: refreshData.userId,
        expiresAt: tokenExpiresAt
      });

      refreshTokens.set(newRefreshToken, {
        client_id,
        scope: refreshData.scope,
        userId: refreshData.userId,
        accessToken: newAccessToken
      });

      // Clean up old refresh token
      refreshTokens.delete(refresh_token);

      logger.info('SmartThings Schema OAuth token refreshed', {
        client_id,
        scope: refreshData.scope
      });

      return res.json({
        access_token: newAccessToken,
        token_type: 'Bearer',
        expires_in: expiresIn,
        refresh_token: newRefreshToken,
        scope: refreshData.scope
      });

    } else {
      return res.status(400).json({
        error: 'unsupported_grant_type',
        error_description: 'Only authorization_code and refresh_token grant types are supported'
      });
    }

  } catch (error) {
    logger.error('SmartThings Schema OAuth token error', {
      error: error.message,
      body: req.body
    });
    
    res.status(500).json({
      error: 'server_error',
      error_description: 'Internal server error'
    });
  }
});

// @route   POST /api/v1/smartthings/oauth/refresh
// @desc    Token refresh endpoint (alternative endpoint for compatibility)
// @access  Public (SmartThings calls this)
router.post('/refresh', async (req, res) => {
  // Forward to the main token endpoint with refresh_token grant
  req.body.grant_type = 'refresh_token';
  
  // Call the token handler directly
  const tokenHandler = router.stack.find(layer => 
    layer.route && layer.route.path === '/token' && layer.route.methods.post
  );
  
  if (tokenHandler) {
    return tokenHandler.route.stack[0].handle(req, res);
  } else {
    return res.status(500).json({
      error: 'server_error',
      error_description: 'Token refresh handler not found'
    });
  }
});

// Middleware to validate access tokens for protected endpoints
const validateAccessToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'invalid_token',
      error_description: 'Missing or invalid authorization header'
    });
  }

  const token = authHeader.substring(7);
  const tokenData = accessTokens.get(token);

  if (!tokenData) {
    return res.status(401).json({
      error: 'invalid_token',
      error_description: 'Invalid access token'
    });
  }

  if (Date.now() > tokenData.expiresAt) {
    accessTokens.delete(token);
    return res.status(401).json({
      error: 'invalid_token',
      error_description: 'Access token expired'
    });
  }

  req.tokenData = tokenData;
  next();
};

// @route   GET /api/v1/smartthings/oauth/userinfo
// @desc    Get user info (optional endpoint for SmartThings)
// @access  Protected (requires access token)
router.get('/userinfo', validateAccessToken, (req, res) => {
  res.json({
    sub: req.tokenData.userId,
    name: 'Unified Smart Home User',
    email: process.env.ALERT_NOTIFICATION_EMAIL || 'user@unifiedsmarthome.com',
    scope: req.tokenData.scope
  });
});

// @route   POST /api/v1/smartthings/oauth/revoke
// @desc    Revoke tokens
// @access  Public (SmartThings calls this)
router.post('/revoke', (req, res) => {
  const { token, token_type_hint } = req.body;
  
  if (!token) {
    return res.status(400).json({
      error: 'invalid_request',
      error_description: 'Missing token parameter'
    });
  }

  // Try to revoke as access token
  if (accessTokens.has(token)) {
    accessTokens.delete(token);
    logger.info('Access token revoked', { token: token.substring(0, 8) + '...' });
  }

  // Try to revoke as refresh token
  if (refreshTokens.has(token)) {
    const refreshData = refreshTokens.get(token);
    if (refreshData.accessToken) {
      accessTokens.delete(refreshData.accessToken);
    }
    refreshTokens.delete(token);
    logger.info('Refresh token revoked', { token: token.substring(0, 8) + '...' });
  }

  res.status(200).json({ success: true });
});

module.exports = router; 