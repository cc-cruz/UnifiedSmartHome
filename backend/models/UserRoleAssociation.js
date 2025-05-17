const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const UserRoleAssociationSchema = new Schema({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  associatedEntityType: {
    type: String,
    required: true,
    enum: ['PORTFOLIO', 'PROPERTY', 'UNIT'],
    index: true
  },
  associatedEntityId: {
    type: Schema.Types.ObjectId, // Assuming these are ObjectIds. If they can be other string types, adjust accordingly.
    required: true,
    index: true
    // Consider dynamic ref based on associatedEntityType if needed for population:
    // refPath: 'associatedEntityType' 
    // Note: For refPath to work, the referenced model names ('Portfolio', 'Property', 'Unit') 
    // must match the enum values in associatedEntityType. mongoose.model('Portfolio', ...)
  },
  roleWithinEntity: {
    type: String,
    required: true,
    enum: ['OWNER', 'PORTFOLIO_ADMIN', 'PROPERTY_MANAGER', 'TENANT', 'GUEST'], // Added GUEST as it was in the original User model enum
    index: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Compound index for efficient querying as suggested in the plan
UserRoleAssociationSchema.index({ userId: 1, associatedEntityType: 1, associatedEntityId: 1 }, { unique: true });
UserRoleAssociationSchema.index({ associatedEntityType: 1, associatedEntityId: 1, roleWithinEntity: 1 }); // For finding all users with a role for an entity

UserRoleAssociationSchema.pre('save', function(next) {
    this.updatedAt = Date.now();
    next();
});

module.exports = mongoose.model('UserRoleAssociation', UserRoleAssociationSchema); 