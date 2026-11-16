const express = require('express');
const { randomUUID } = require('crypto');
const { Order, OrderPayment } = require('../models/Order');
const Customer = require('../models/Customer');
const Transaction = require('../models/Transaction');
const { protect, asyncHandler } = require('../middleware/auth');
const { serialize, serializeMany } = require('../utils/serialize');
const { dataCache, invalidateUserDataCache } = require('../utils/cache');

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
    const userId = String(req.user._id);
    const limit = Math.min(Math.max(Number(req.query.limit) || 25, 1), 500);
    const skip = Math.max(Number(req.query.skip) || 0, 0);
    const compact = req.query.compact === '1' || req.query.compact === 'true';

    const cacheKey = `u:${userId}:orders:${req.originalUrl}`;
    const cached = dataCache.get(cacheKey);
    if (cached) return res.json(cached);

    const filter = { userId };
    if (req.query.status) filter.status = req.query.status;
    if (req.query.customerId) filter.customerId = req.query.customerId;
    const q = (req.query.q || '').trim();
    if (q) {
      filter.$or = [
        { title: new RegExp(q, 'i') },
        { customerName: new RegExp(q, 'i') },
      ];
    }

    const query = Order.find(filter)
      .sort({ createdAt: -1, _id: -1 })
      .skip(skip)
      .limit(limit + 1);

    if (compact) {
      query.select('-notes -description');
    }

    const rawItems = await query.lean();
    const hasMore = rawItems.length > limit;
    const pageItems = hasMore ? rawItems.slice(0, limit) : rawItems;

    const payload = {
      items: serializeMany(pageItems),
      hasMore,
      nextSkip: skip + pageItems.length,
    };
    dataCache.set(cacheKey, payload, 20000);
    res.json(payload);
  })
);

// Real totals per status (independent of pagination)
router.get(
  '/counts',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const cacheKey = `u:${userId}:orders:counts`;
    const cached = dataCache.get(cacheKey);
    if (cached) return res.json(cached);

    const rows = await Order.aggregate([
      { $match: { userId } },
      { $group: { _id: '$status', n: { $sum: 1 } } },
    ]);
    const byStatus = { new: 0, inProgress: 0, completed: 0, cancelled: 0 };
    let total = 0;
    for (const r of rows) {
      byStatus[r._id] = r.n;
      total += r.n;
    }
    const payload = { total, byStatus };
    dataCache.set(cacheKey, payload, 20000);
    res.json(payload);
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
    invalidateUserDataCache(userId);
    res.status(201).json(serialize(doc));
  })
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const doc = await Order.findOneAndUpdate(
      { _id: req.params.id, userId },
      { ...pick(req.body), updatedAt: new Date() },
      { new: true }
    ).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Заказ не найден');
    }
    invalidateUserDataCache(userId);
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
    await Promise.all([
      Customer.updateOne(
        { _id: doc.customerId, userId },
        {
          $inc: {
            totalOrdersAmountCents: -doc.totalPriceCents,
            totalReceivedCents: -doc.receivedCents,
            totalOrdersCount: -1,
          },
        }
      ),
      OrderPayment.deleteMany({ orderId: doc._id, userId }),
    ]);
    invalidateUserDataCache(userId);
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

    await Promise.all([
      order.save(),
      OrderPayment.create({
        _id: paymentId,
        userId,
        orderId: order._id,
        customerId: order.customerId,
        amountCents: amount,
        paidAt,
        notes: req.body.notes || null,
        transactionId,
      }),
      Transaction.create({
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
      }),
      Customer.updateOne(
        { _id: order.customerId, userId },
        { $inc: { totalReceivedCents: amount } }
      ),
    ]);

    invalidateUserDataCache(userId);
    res.status(201).json(serialize(order));
  })
);

module.exports = router;
