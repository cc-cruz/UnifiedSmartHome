const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const UnitSchema = new Schema({
  name: {
    type: String,
    required: true,
    trim: true,
    index: true
  },
  propertyId: {
    type: Schema.Types.ObjectId,
    ref: 'Property',
    required: true,
    index: true
  },
  deviceIds: [{
    type: Schema.Types.ObjectId,
    ref: 'Device',
    index: true
  }],
  tenantUserIds: [{
    type: Schema.Types.ObjectId,
    ref: 'User',
    index: true
  }],
  commonAreaAccessIds: [{
    type: Schema.Types.ObjectId,
    ref: 'Device', // Assuming these are IDs of devices in common areas
    index: true
  }]
}, { timestamps: true });

module.exports = mongoose.model('Unit', UnitSchema); 