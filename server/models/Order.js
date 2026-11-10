const mongoose = require('mongoose');
const { randomUUID } = require('crypto');

const orderSchema = new mongoose.Schema(
  {
    _id: { type: String, default: () => randomUUID() },
    userId: { type: String, required: true, index: true },
    title: { type: String, required: true, trim: true },
    customerId: { type: String, required: true, index: true },
    customerName: { type: String, required: true },
    description: { type: String, default: null },
    notes: { type: String, default: null },
    totalPriceCents: { type: Number, required: true },
    receivedCents: { type: Number, default: 0 },
    status: {
      type: String,
      enum: ['new', 'inProgress', 'completed', 'cancelled'],
      default: 'new',
      index: true,
    },
    createdAt: { type: Date, default: Date.now },
    dueDate: { type: Date, default: null },
    updatedAt: { type: Date, default: null },
  },
  { _id: false, versionKey: false }
);

orderSchema.index({ userId: 1, createdAt: -1 });

const orderPaymentSchema = new mongoose.Schema(
  {
    _id: { type: String, default: () => randomUUID() },
    userId: { type: String, required: true, index: true },
    orderId: { type: String, required: true, index: true },
    customerId: { type: String, required: true },
    amountCents: { type: Number, required: true },
    paidAt: { type: Date, required: true },
    notes: { type: String, default: null },
    transactionId: { type: String, default: null },
  },
  { _id: false, versionKey: false }
);

module.exports = {
  Order: mongoose.model('Order', orderSchema),
  OrderPayment: mongoose.model('OrderPayment', orderPaymentSchema),
};
