const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const PortfolioSchema = new Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  administratorUserIds: [{
    type: Schema.Types.ObjectId,
    ref: 'User',
    index: true
  }],
  propertyIds: [{
    type: Schema.Types.ObjectId,
    ref: 'Property',
    index: true
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

module.exports = mongoose.model('Portfolio', PortfolioSchema); 