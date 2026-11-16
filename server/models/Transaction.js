const mongoose = require('mongoose');
const { randomUUID } = require('crypto');

const transactionSchema = new mongoose.Schema(
  {
    _id: { type: String, default: () => randomUUID() },
    userId: { type: String, required: true, index: true },
    amountCents: { type: Number, required: true },
    type: { type: String, enum: ['income', 'expense'], required: true },
    category: { type: String, default: null },
    description: { type: String, default: null },
    date: { type: Date, required: true, index: true },
    createdAt: { type: Date, default: Date.now },
    customerId: { type: String, default: null },
    orderId: { type: String, default: null },
    debtId: { type: String, default: null },
    paymentMethod: { type: String, default: null },
    notes: { type: String, default: null },
    linkedEntityType: { type: String, default: null },
    linkedEntityId: { type: String, default: null },
  },
  { _id: false, versionKey: false }
);

transactionSchema.index({ userId: 1, date: -1 });
transactionSchema.index({ userId: 1, type: 1, date: -1 });
transactionSchema.index({ userId: 1, category: 1, date: -1 });

module.exports = mongoose.model('Transaction', transactionSchema);
