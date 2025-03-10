const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const AddressSchema = new Schema({
  street: {
    type: String,
    required: true,
    trim: true
  },
  city: {
    type: String,
    required: true,
    trim: true
  },
  state: {
    type: String,
    required: true,
    trim: true
  },
  zipCode: {
    type: String,
    required: true,
    trim: true
  },
  country: {
    type: String,
    required: true,
    trim: true,
    default: 'USA'
  }
});

const PropertySchema = new Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  address: {
    type: AddressSchema,
    required: true
  },
  owner: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  managers: [{
    type: Schema.Types.ObjectId,
    ref: 'User'
  }],
  tenants: [{
    type: Schema.Types.ObjectId,
    ref: 'User'
  }],
  rooms: [{
    type: Schema.Types.ObjectId,
    ref: 'Room'
  }],
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

module.exports = mongoose.model('Property', PropertySchema); 