const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const RoomSchema = new Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  type: {
    type: String,
    enum: ['LIVING_ROOM', 'BEDROOM', 'KITCHEN', 'BATHROOM', 'OFFICE', 'GARAGE', 'OTHER'],
    required: true
  },
  property: {
    type: Schema.Types.ObjectId,
    ref: 'Property',
    required: true
  },
  devices: [{
    type: Schema.Types.ObjectId,
    ref: 'Device'
  }],
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Room', RoomSchema); 