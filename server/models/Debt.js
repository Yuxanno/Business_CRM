const mongoose = require('mongoose');
const { randomUUID } = require('crypto');

const debtSchema = new mongoose.Schema(
  {
    _id: { type: String, default: () => randomUUID() },
    userId: { type: String, required: true, index: true },
    personName: { type: String, required: true, trim: true },
    customerId: { type: String, default: null },
    direction: {
      type: String,
      enum: ['receivable', 'payable'],
      required: true,
      index: true,
    },
    originalAmountCents: { type: Number, required: true },
    paidAmountCents: { type: Number, default: 0 },
    status: {
      type: String,
      enum: ['unpaid', 'partiallyPaid', 'paid', 'overdue'],
      default: 'unpaid',
    },
    description: { type: String, default: null },
    createdAt: { type: Date, default: Date.now },
    dueDate: { type: Date, default: null },
    notes: { type: String, default: null },
    updatedAt: { type: Date, default: null },
  },
  { _id: false, versionKey: false }
);

debtSchema.index({ userId: 1, createdAt: -1 });
debtSchema.index({ userId: 1, direction: 1, createdAt: -1 });
debtSchema.index({ userId: 1, status: 1 });
debtSchema.index({ userId: 1, customerId: 1 });

const debtPaymentSchema = new mongoose.Schema(
  {
    _id: { type: String, default: () => randomUUID() },
    userId: { type: String, required: true, index: true },
    debtId: { type: String, required: true, index: true },
    amountCents: { type: Number, required: true },
    paidAt: { type: Date, required: true },
    notes: { type: String, default: null },
    transactionId: { type: String, default: null },
  },
  { _id: false, versionKey: false }
);

debtPaymentSchema.index({ userId: 1, debtId: 1, paidAt: -1 });

module.exports = {
  Debt: mongoose.model('Debt', debtSchema),
  DebtPayment: mongoose.model('DebtPayment', debtPaymentSchema),
};
