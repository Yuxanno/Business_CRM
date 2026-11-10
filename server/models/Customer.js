const mongoose = require('mongoose');
const { randomUUID } = require('crypto');

const customerSchema = new mongoose.Schema(
  {
    _id: { type: String, default: () => randomUUID() },
    userId: { type: String, required: true, index: true },
    name: { type: String, required: true, trim: true },
    phone: { type: String, default: null },
    email: { type: String, default: null },
    notes: { type: String, default: null },
    createdAt: { type: Date, default: Date.now },
    totalOrdersAmountCents: { type: Number, default: 0 },
    totalReceivedCents: { type: Number, default: 0 },
    totalOrdersCount: { type: Number, default: 0 },
  },
  { _id: false, versionKey: false }
);

customerSchema.index({ userId: 1, name: 1 });

module.exports = mongoose.model('Customer', customerSchema);
