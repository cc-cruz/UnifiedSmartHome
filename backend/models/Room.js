const mongoose = require('mongoose');

const roomSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  propertyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Property',
    required: true
  },
  type: {
    type: String,
    enum: ['LIVING_ROOM', 'BEDROOM', 'KITCHEN', 'BATHROOM', 'OFFICE', 'GARAGE', 'OTHER'],
    required: true
  },
  deviceIds: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Device'
  }]
}, {
  timestamps: true
});

// Index for efficient queries
roomSchema.index({ propertyId: 1 });

module.exports = mongoose.model('Room', roomSchema); 