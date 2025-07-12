const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const SmartThingsTokenSchema = new Schema({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  accessToken: {
    type: String,
    required: true,
    select: false // Don't return tokens in queries by default for security
  },
  refreshToken: {
    type: String,
    required: true,
    select: false // Don't return tokens in queries by default for security
  },
  expiresAt: {
    type: Date,
    required: true,
    index: true // Index for efficient cleanup of expired tokens
  },
  scope: {
    type: String,
    required: true
  },
  // Multi-tenant context - tokens are scoped to specific properties/units
  propertyId: {
    type: Schema.Types.ObjectId,
    ref: 'Property',
    required: false, // May be null for portfolio-level tokens
    index: true
  },
  unitId: {
    type: Schema.Types.ObjectId,
    ref: 'Unit',
    required: false, // May be null for property-level tokens
    index: true
  },
  // SmartThings-specific metadata
  smartThingsUserId: {
    type: String,
    required: false // SmartThings user ID from OAuth response
  },
  installedAppId: {
    type: String,
    required: false // SmartThings installed app ID if using SmartApp
  },
  // Token management
  isActive: {
    type: Boolean,
    default: true,
    index: true
  },
  lastRefreshed: {
    type: Date,
    default: Date.now
  },
  // Audit fields
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Compound indexes for efficient multi-tenant queries
SmartThingsTokenSchema.index({ userId: 1, propertyId: 1, unitId: 1 }, { unique: true });
SmartThingsTokenSchema.index({ userId: 1, isActive: 1 });
SmartThingsTokenSchema.index({ expiresAt: 1, isActive: 1 });

// Update the updatedAt field on save
SmartThingsTokenSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// Method to check if token is expired
SmartThingsTokenSchema.methods.isExpired = function() {
  return new Date() >= this.expiresAt;
};

// Method to check if token needs refresh (expires within 5 minutes)
SmartThingsTokenSchema.methods.needsRefresh = function() {
  const fiveMinutesFromNow = new Date(Date.now() + 5 * 60 * 1000);
  return fiveMinutesFromNow >= this.expiresAt;
};

// Static method to find active tokens for a user/property/unit
SmartThingsTokenSchema.statics.findActiveToken = function(userId, propertyId = null, unitId = null) {
  return this.findOne({
    userId,
    propertyId,
    unitId,
    isActive: true,
    expiresAt: { $gt: new Date() }
  });
};

// Static method to cleanup expired tokens
SmartThingsTokenSchema.statics.cleanupExpiredTokens = function() {
  return this.updateMany(
    {
      expiresAt: { $lt: new Date() },
      isActive: true
    },
    {
      $set: { isActive: false }
    }
  );
};

module.exports = mongoose.model('SmartThingsToken', SmartThingsTokenSchema); 