const express = require('express');
const Customer = require('../models/Customer');
const { Order } = require('../models/Order');
const { protect, asyncHandler } = require('../middleware/auth');
const { serialize, serializeMany } = require('../utils/serialize');
const { dataCache, invalidateUserDataCache } = require('../utils/cache');

const router = express.Router();
router.use(protect);

const fields = [
  'name',
  'phone',
  'email',
  'notes',
  'createdAt',
  'totalOrdersAmountCents',
  'totalReceivedCents',
  'totalOrdersCount',
];

function pick(body) {
  const out = {};
  for (const f of fields) {
    if (body[f] !== undefined) out[f] = body[f];
  }
  return out;
}

/**
 * Aggregates live order stats per customerId.
 * Cancelled orders do not create unpaid debt (their amount is capped at receivedCents).
 */
async function getLiveOrderStatsMap(userId, customerIds = null) {
  const match = { userId };
  if (Array.isArray(customerIds) && customerIds.length > 0) {
    match.customerId = { $in: customerIds };
  }
  const rows = await Order.aggregate([
    { $match: match },
    {
      $group: {
        _id: '$customerId',
        totalOrdersCount: { $sum: 1 },
        totalReceivedCents: { $sum: { $ifNull: ['$receivedCents', 0] } },
        totalOrdersAmountCents: {
          $sum: {
            $cond: [
              { $eq: ['$status', 'cancelled'] },
              { $ifNull: ['$receivedCents', 0] },
              { $ifNull: ['$totalPriceCents', 0] },
            ],
          },
        },
      },
    },
  ]);
  const map = new Map();
  for (const r of rows) {
    map.set(String(r._id), {
      totalOrdersCount: r.totalOrdersCount || 0,
      totalReceivedCents: r.totalReceivedCents || 0,
      totalOrdersAmountCents: r.totalOrdersAmountCents || 0,
    });
  }
  return map;
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const limit = Math.min(Math.max(Number(req.query.limit) || 25, 1), 500);
    const skip = Math.max(Number(req.query.skip) || 0, 0);
    const compact = req.query.compact === '1' || req.query.compact === 'true';

    const cacheKey = `u:${userId}:customers:${req.originalUrl}`;
    const cached = dataCache.get(cacheKey);
    if (cached) return res.json(cached);

    const filter = { userId };
    const q = (req.query.q || '').trim();
    if (q) {
      filter.$or = [
        { name: new RegExp(q, 'i') },
        { phone: new RegExp(q, 'i') },
      ];
    }

    const query = Customer.find(filter)
      .sort({ name: 1, _id: 1 })
      .skip(skip)
      .limit(limit + 1);

    if (compact) {
      query.select('-notes');
    }

    const rawItems = await query.lean();
    const hasMore = rawItems.length > limit;
    const pageItems = hasMore ? rawItems.slice(0, limit) : rawItems;

    if (pageItems.length > 0) {
      const ids = pageItems.map((c) => String(c._id));
      const statsMap = await getLiveOrderStatsMap(userId, ids);
      for (const c of pageItems) {
        const s = statsMap.get(String(c._id));
        c.totalOrdersCount = s ? s.totalOrdersCount : 0;
        c.totalReceivedCents = s ? s.totalReceivedCents : 0;
        c.totalOrdersAmountCents = s ? s.totalOrdersAmountCents : 0;
      }
    }

    const payload = {
      items: serializeMany(pageItems),
      hasMore,
      nextSkip: skip + pageItems.length,
    };
    dataCache.set(cacheKey, payload, 20000);
    res.json(payload);
  })
);

// Real totals (independent of pagination)
router.get(
  '/counts',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const cacheKey = `u:${userId}:customers:counts`;
    const cached = dataCache.get(cacheKey);
    if (cached) return res.json(cached);

    const { Debt } = require('../models/Debt');
    const [customers, debts, statsMap] = await Promise.all([
      Customer.find({ userId }).select('name').lean(),
      Debt.find({ userId, direction: 'receivable' })
        .select('customerId personName originalAmountCents paidAmountCents')
        .lean(),
      getLiveOrderStatsMap(userId),
    ]);
    const debtIds = new Set();
    const debtNames = new Set();
    for (const d of debts) {
      if ((d.paidAmountCents || 0) >= d.originalAmountCents) continue;
      if (d.customerId) debtIds.add(d.customerId);
      debtNames.add(String(d.personName || '').trim().toLowerCase());
    }
    let withOrders = 0;
    let withDebt = 0;
    for (const c of customers) {
      const s = statsMap.get(String(c._id));
      const ordersCount = s ? s.totalOrdersCount : 0;
      const ordersAmount = s ? s.totalOrdersAmountCents : 0;
      const receivedAmount = s ? s.totalReceivedCents : 0;

      if (ordersCount > 0) withOrders++;
      const owes =
        ordersAmount - receivedAmount > 0 ||
        debtIds.has(c._id) ||
        debtNames.has(String(c.name || '').trim().toLowerCase());
      if (owes) withDebt++;
    }
    const payload = { total: customers.length, withOrders, withDebt };
    dataCache.set(cacheKey, payload, 20000);
    res.json(payload);
  })
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const doc = await Customer.findOne({
      _id: req.params.id,
      userId,
    }).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Клиент не найден');
    }
    const statsMap = await getLiveOrderStatsMap(userId, [String(doc._id)]);
    const s = statsMap.get(String(doc._id));
    doc.totalOrdersCount = s ? s.totalOrdersCount : 0;
    doc.totalReceivedCents = s ? s.totalReceivedCents : 0;
    doc.totalOrdersAmountCents = s ? s.totalOrdersAmountCents : 0;
    res.json(serialize(doc));
  })
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    if (!req.body.name) {
      res.status(400);
      throw new Error('Укажите имя');
    }
    const userId = String(req.user._id);
    const doc = await Customer.create({
      ...pick(req.body),
      _id: req.body.id,
      userId,
    });
    invalidateUserDataCache(userId);
    res.status(201).json(serialize(doc));
  })
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const doc = await Customer.findOneAndUpdate(
      { _id: req.params.id, userId },
      pick(req.body),
      { new: true }
    ).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Клиент не найден');
    }
    invalidateUserDataCache(userId);
    res.json(serialize(doc));
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const doc = await Customer.findOneAndDelete({
      _id: req.params.id,
      userId,
    });
    if (!doc) {
      res.status(404);
      throw new Error('Клиент не найден');
    }
    invalidateUserDataCache(userId);
    res.json({ ok: true });
  })
);

module.exports = router;
