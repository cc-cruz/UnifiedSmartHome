const express = require('express');
const router = express.Router();
const User = require('../models/User');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
    console.error("FATAL ERROR: JWT_SECRET is not defined in .env file.");
    process.exit(1);
}

// @route   POST /api/auth/register
// @desc    Register a new user
// @access  Public
router.post('/register', async (req, res, next) => {
  try {
    const { firstName, lastName, email, password } = req.body;

    if (!firstName || !lastName || !email || !password) {
        return res.status(400).json({ success: false, message: 'Please provide firstName, lastName, email, and password.'});
    }
    
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'User with this email already exists'
      });
    }
    
    // Password will be hashed by the pre-save hook in User model
    const user = new User({
      firstName,
      lastName,
      email,
      password, 
    });
    
    await user.save();
    
    const payload = {
        user: {
            id: user.id
        }
    };
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });
    
    res.status(201).json({
      success: true,
      user: user.toJSON(), // Use toJSON() to strip password
      token
    });
  } catch (error) {
    console.error('Registration error:', error); // Log the actual error
    next(error);
  }
});

// @route   POST /api/auth/login
// @desc    Login user and return JWT token
// @access  Public
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ success: false, message: 'Please provide email and password.'});
    }
    
    // Need to explicitly select password as it's select: false in schema
    const user = await User.findOne({ email }).select('+password +isSuperAdmin'); 
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    const isMatch = await user.comparePassword(password);
    if (!isMatch) { 
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }
    
    const payload = {
        user: {
            id: user.id
        }
    };
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });
    
    res.status(200).json({
      success: true,
      user: user.toJSON(), // Use toJSON() to strip password
      token
    });
  } catch (error) {
    console.error('Login error:', error); // Log the actual error
    next(error);
  }
});

module.exports = router; 