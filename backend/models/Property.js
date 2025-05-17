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
}, {_id: false});

const PropertySchema = new Schema({
  name: {
    type: String,
    required: true,
    trim: true,
    index: true
  },
  portfolioId: {
    type: Schema.Types.ObjectId,
    ref: 'Portfolio',
    required: true,
    index: true
  },
  address: {
    type: AddressSchema,
    required: true
  },
  unitIds: [{
    type: Schema.Types.ObjectId,
    ref: 'Unit',
    index: true
  }],
  managerUserIds: [{
    type: Schema.Types.ObjectId,
    ref: 'User',
    index: true
  }],
  defaultTimeZone: {
    type: String,
    required: false
  }
}, { timestamps: true });

module.exports = mongoose.model('Property', PropertySchema); 