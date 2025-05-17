const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { protect } = require('../middleware/auth.middleware');
const UserRoleAssociation = require('../models/UserRoleAssociation');

// Middleware for authentication would go here
// const auth = require('../middleware/auth');

// @route   GET /api/users/me
// @desc    Get current user profile
// @access  Private
router.get('/me', protect, async (req, res, next) => {
  try {
    const userId = req.user.id; // Provided by protect middleware

    const user = await User.findById(userId).select('-password');
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const roleAssociations = await UserRoleAssociation.find({ userId });
    const userResponse = user.toJSON();
    userResponse.roleAssociations = roleAssociations;

    res.status(200).json({ success: true, data: userResponse });
  } catch (error) {
    next(error);
  }
});

// @route   PUT /api/users/me
// @desc    Update current user profile
// @access  Private
router.put('/me', async (req, res, next) => {
  try {
    // In a real implementation, you would get the user ID from the JWT token
    // const userId = req.user.id;
    const userId = '123'; // Dummy user ID for now
    
    const { firstName, lastName, email } = req.body;
    
    // Build user object
    const userFields = {};
    if (firstName) userFields.firstName = firstName;
    if (lastName) userFields.lastName = lastName;
    if (email) userFields.email = email;
    
    // Update user
    const user = await User.findByIdAndUpdate(
      userId,
      { $set: userFields },
      { new: true }
    ).select('-password');
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    res.status(200).json({
      success: true,
      data: user
    });
  } catch (error) {
    next(error);
  }
});

// @route   GET /api/users/:id
// @desc    Get user by ID
// @access  Private (Admin only)
router.get('/:id', async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    res.status(200).json({
      success: true,
      data: user
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router; 