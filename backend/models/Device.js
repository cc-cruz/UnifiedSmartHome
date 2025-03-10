const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const DeviceCapabilitySchema = new Schema({
  type: {
    type: String,
    required: true,
    trim: true
  },
  attributes: {
    type: Schema.Types.Mixed,
    default: {}
  }
});

const DeviceSchema = new Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  manufacturer: {
    type: String,
    enum: ['SAMSUNG', 'LG', 'GE', 'GOOGLE_NEST', 'PHILIPS_HUE', 'AMAZON', 'APPLE', 'OTHER'],
    required: true
  },
  type: {
    type: String,
    enum: ['LIGHT', 'THERMOSTAT', 'LOCK', 'CAMERA', 'DOORBELL', 'SPEAKER', 'TV', 'APPLIANCE', 'SENSOR', 'OTHER'],
    required: true
  },
  room: {
    type: Schema.Types.ObjectId,
    ref: 'Room'
  },
  property: {
    type: Schema.Types.ObjectId,
    ref: 'Property',
    required: true
  },
  status: {
    type: String,
    enum: ['ONLINE', 'OFFLINE', 'ERROR'],
    default: 'OFFLINE'
  },
  capabilities: [DeviceCapabilitySchema],
  // Integration-specific data
  integrationData: {
    type: Schema.Types.Mixed,
    default: {}
  },
  // Device-specific metadata
  metadata: {
    type: Schema.Types.Mixed,
    default: {}
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

module.exports = mongoose.model('Device', DeviceSchema); 