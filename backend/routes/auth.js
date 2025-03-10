const express = require('express');
const router = express.Router();
const User = require('../models/User');

// @route   POST /api/auth/register
// @desc    Register a new user
// @access  Public
router.post('/register', async (req, res, next) => {
  try {
    const { firstName, lastName, email, password } = req.body;
    
    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'User with this email already exists'
      });
    }
    
    // Create new user
    // In a real implementation, you would hash the password before saving
    const user = new User({
      firstName,
      lastName,
      email,
      password, // This should be hashed in production
      role: 'TENANT' // Default role
    });
    
    await user.save();
    
    // Generate JWT token
    // In a real implementation, you would use JWT
    const token = 'dummy_token';
    
    res.status(201).json({
      success: true,
      user,
      token
    });
  } catch (error) {
    next(error);
  }
});

// @route   POST /api/auth/login
// @desc    Login user and return JWT token
// @access  Public
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    
    // Find user by email
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Check password
    // In a real implementation, you would compare hashed passwords
    if (user.password !== password) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
    
    // Generate JWT token
    // In a real implementation, you would use JWT
    const token = 'dummy_token';
    
    res.status(200).json({
      success: true,
      user,
      token
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router; 