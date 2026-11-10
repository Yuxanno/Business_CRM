const express = require('express');
const { randomUUID } = require('crypto');
const { Order, OrderPayment } = require('../models/Order');
const Customer = require('../models/Customer');
const Transaction = require('../models/Transaction');
const { protect, asyncHandler } = require('../middleware/auth');
const { serialize, serializeMany } = require('../utils/serialize');

const router = express.Router();
router.use(protect);

const fields = [
  'title',
  'customerId',
  'customerName',
  'description',
  'notes',
  'totalPriceCents',
  'receivedCents',
  'status',
  'createdAt',
  'dueDate',
  'updatedAt',
];

function pick(body) {
  const out = {};
  for (const f of fields) {
    if (body[f] !== undefined) out[f] = body[f];
  }
  return out;
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const limit = Math.min(Number(req.query.limit) || 200, 500);
    const skip = Number(req.query.skip) || 0;
    const filter = { userId: String(req.user._id) };
    if (req.query.status) filter.status = req.query.status;
    if (req.query.customerId) filter.customerId = req.query.customerId;
    const q = (req.query.q || '').trim();
    if (q) {
      filter.$or = [
        { title: new RegExp(q, 'i') },
        { customerName: new RegExp(q, 'i') },
      ];
    }
    const [items, total] = await Promise.all([
      Order.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      Order.countDocuments(filter),
    ]);
    res.json({ items: serializeMany(items), total });
  })
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const doc = await Order.findOne({
      _id: req.params.id,
      userId: String(req.user._id),
    }).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Заказ не найден');
    }
    res.json(serialize(doc));
  })
);

router.get(
  '/:id/payments',
  asyncHandler(async (req, res) => {
    const items = await OrderPayment.find({
      orderId: req.params.id,
      userId: String(req.user._id),
    })
      .sort({ paidAt: -1 })
      .lean();
    res.json({ items: serializeMany(items) });
  })
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    if (!req.body.title || !req.body.customerId) {
      res.status(400);
      throw new Error('Укажите название и клиента');
    }
    const userId = String(req.user._id);
    const doc = await Order.create({
      ...pick(req.body),
      _id: req.body.id,
      userId,
      receivedCents: req.body.receivedCents || 0,
    });
    await Customer.updateOne(
      { _id: doc.customerId, userId },
      {
        $inc: {
          totalOrdersAmountCents: doc.totalPriceCents,
          totalOrdersCount: 1,
        },
      }
    );
    res.status(201).json(serialize(doc));
  })
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const doc = await Order.findOneAndUpdate(
      { _id: req.params.id, userId: String(req.user._id) },
      { ...pick(req.body), updatedAt: new Date() },
      { new: true }
    ).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Заказ не найден');
    }
    res.json(serialize(doc));
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const doc = await Order.findOneAndDelete({
      _id: req.params.id,
      userId,
    });
    if (!doc) {
      res.status(404);
      throw new Error('Заказ не найден');
    }
    await Customer.updateOne(
      { _id: doc.customerId, userId },
      {
        $inc: {
          totalOrdersAmountCents: -doc.totalPriceCents,
          totalReceivedCents: -doc.receivedCents,
          totalOrdersCount: -1,
        },
      }
    );
    await OrderPayment.deleteMany({ orderId: doc._id, userId });
    res.json({ ok: true });
  })
);

router.post(
  '/:id/payments',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const order = await Order.findOne({ _id: req.params.id, userId });
    if (!order) {
      res.status(404);
      throw new Error('Заказ не найден');
    }
    const remaining = order.totalPriceCents - order.receivedCents;
    const amount = Math.min(Number(req.body.amountCents) || 0, remaining);
    if (amount <= 0) {
      res.status(400);
      throw new Error('Некорректная сумма');
    }
    const paidAt = req.body.paidAt ? new Date(req.body.paidAt) : new Date();
    const paymentId = req.body.paymentId || randomUUID();
    const transactionId = req.body.transactionId || randomUUID();

    order.receivedCents += amount;
    order.updatedAt = new Date();
    await order.save();

    await OrderPayment.create({
      _id: paymentId,
      userId,
      orderId: order._id,
      customerId: order.customerId,
      amountCents: amount,
      paidAt,
      notes: req.body.notes || null,
      transactionId,
    });

    await Transaction.create({
      _id: transactionId,
      userId,
      amountCents: amount,
      type: 'income',
      category: 'order_payment',
      description: `Оплата заказа: ${order.title}`,
      date: paidAt,
      createdAt: new Date(),
      customerId: order.customerId,
      orderId: order._id,
      linkedEntityType: 'order_payment',
      linkedEntityId: paymentId,
    });

    await Customer.updateOne(
      { _id: order.customerId, userId },
      { $inc: { totalReceivedCents: amount } }
    );

    res.status(201).json(serialize(order));
  })
);

module.exports = router;
