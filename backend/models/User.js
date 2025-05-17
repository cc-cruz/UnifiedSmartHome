const mongoose = require('mongoose');
const Schema = mongoose.Schema;
const bcrypt = require('bcryptjs'); // Import bcryptjs

// UserRoleAssociationSchema was here and should be removed.

const UserSchema = new Schema({
  firstName: {
    type: String,
    required: true,
    trim: true
  },
  lastName: {
    type: String,
    required: true,
    trim: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true
  },
  password: { // Renamed from passwordHash for clarity, will be hashed before save
    type: String,
    required: true,
    select: false // Password should not be returned by default in queries
  },
  isSuperAdmin: {
    type: Boolean,
    default: false,
    select: false // Should not be returned by default, but auth middleware will fetch it
  },
  // DEPRECATED: Old role system. Contextual roles are now in UserRoleAssociation collection.
  /* 
  role: {
    type: String,
    enum: ['OWNER', 'PROPERTY_MANAGER', 'TENANT', 'GUEST'],
    default: 'TENANT'
  },
  */
  // DEPRECATED: Old properties array. Contextual access is via UserRoleAssociation collection.
  /*
  properties: [{
    type: Schema.Types.ObjectId,
    ref: 'Property'
  }],
  */

  // NEW: Multi-tenancy default navigation preferences
  defaultPortfolioId: {
    type: Schema.Types.ObjectId,
    ref: 'Portfolio',
    required: false,
    default: null
  },
  defaultPropertyId: {
    type: Schema.Types.ObjectId,
    ref: 'Property',
    required: false,
    default: null
  },
  defaultUnitId: {
    type: Schema.Types.ObjectId,
    ref: 'Unit',
    required: false,
    default: null
  },
  // Guest access fields mirroring the Swift model for consistency (optional here if managed differently)
  /*
  guestAccess: {
    deviceIds: [{ type: String }],
    validFrom: { type: Date },
    validUntil: { type: Date },
    propertyId: { type: String, default: null }, // or ObjectId, ref: 'Property'
    unitId: { type: String, default: null }      // or ObjectId, ref: 'Unit'
  },
  */

  // Removed createdAt and updatedAt fields here, will use Mongoose timestamps
}, { timestamps: true }); // Added Mongoose timestamps option here

// Pre-save middleware to hash password
UserSchema.pre('save', async function(next) {
  if (!this.isModified('password')) {
    return next();
  }
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (err) {
    next(err);
  }
});

// Method to check password (for login)
UserSchema.methods.comparePassword = async function(candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

// Ensure password is not sent by default when converting to JSON
UserSchema.methods.toJSON = function() {
  const user = this.toObject();
  delete user.password; // This should now correctly remove the password field
  // delete user.isSuperAdmin; // Optionally hide this too, but auth middleware needs it.
  return user;
};

module.exports = mongoose.model('User', UserSchema); 