const express = require('express');
const Transaction = require('../models/Transaction');
const { protect, asyncHandler } = require('../middleware/auth');
const { serialize, serializeMany } = require('../utils/serialize');
const { dataCache, invalidateUserDataCache } = require('../utils/cache');

const router = express.Router();
router.use(protect);

const fields = [
  'amountCents',
  'type',
  'category',
  'description',
  'date',
  'createdAt',
  'customerId',
  'orderId',
  'debtId',
  'paymentMethod',
  'notes',
  'linkedEntityType',
  'linkedEntityId',
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
    const includeSummary =
      req.query.includeSummary === '1' || req.query.includeSummary === 'true';

    const cacheKey = `u:${userId}:tx:${req.originalUrl}`;
    const cached = dataCache.get(cacheKey);
    if (cached) return res.json(cached);

    const filter = { userId };
    if (req.query.type) filter.type = req.query.type;
    if (req.query.category) filter.category = req.query.category;
    if (req.query.from || req.query.to) {
      filter.date = {};
      if (req.query.from) filter.date.$gte = new Date(req.query.from);
      if (req.query.to) filter.date.$lt = new Date(req.query.to);
    }
    const q = (req.query.q || '').trim();
    if (q) {
      filter.$or = [
        { description: new RegExp(q, 'i') },
        { category: new RegExp(q, 'i') },
      ];
    }

    const query = Transaction.find(filter)
      .sort({ date: -1, _id: -1 })
      .skip(skip)
      .limit(limit + 1);

    if (compact) {
      query.select('-notes');
    }

    const summaryPromise =
      includeSummary && skip === 0
        ? Transaction.aggregate([
            {
              $match: {
                userId,
                ...(filter.date ? { date: filter.date } : {}),
                ...(filter.category ? { category: filter.category } : {}),
                ...(filter.$or ? { $or: filter.$or } : {}),
              },
            },
            { $group: { _id: '$type', total: { $sum: '$amountCents' } } },
          ])
        : null;

    const [rawItems, summaryRows] = await Promise.all([
      query.lean(),
      summaryPromise || Promise.resolve(null),
    ]);

    const hasMore = rawItems.length > limit;
    const pageItems = hasMore ? rawItems.slice(0, limit) : rawItems;

    const payload = {
      items: serializeMany(pageItems),
      hasMore,
      nextSkip: skip + pageItems.length,
    };

    if (summaryRows) {
      let incomeCents = 0;
      let expenseCents = 0;
      for (const row of summaryRows) {
        if (row._id === 'income') incomeCents = row.total || 0;
        else if (row._id === 'expense') expenseCents = row.total || 0;
      }
      payload.incomeCents = incomeCents;
      payload.expenseCents = expenseCents;
    }

    dataCache.set(cacheKey, payload, 20000);
    res.json(payload);
  })
);

// Real income/expense counts for a period (independent of pagination)
router.get(
  '/counts',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const cacheKey = `u:${userId}:tx:counts:${req.originalUrl}`;
    const cached = dataCache.get(cacheKey);
    if (cached) return res.json(cached);

    const match = { userId };
    if (req.query.from || req.query.to) {
      match.date = {};
      if (req.query.from) match.date.$gte = new Date(req.query.from);
      if (req.query.to) match.date.$lt = new Date(req.query.to);
    }
    const rows = await Transaction.aggregate([
      { $match: match },
      { $group: { _id: '$type', n: { $sum: 1 } } },
    ]);
    let income = 0;
    let expense = 0;
    for (const r of rows) {
      if (r._id === 'income') income = r.n;
      else if (r._id === 'expense') expense = r.n;
    }
    const payload = { total: income + expense, income, expense };
    dataCache.set(cacheKey, payload, 20000);
    res.json(payload);
  })
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    if (!req.body.amountCents || !req.body.type || !req.body.date) {
      res.status(400);
      throw new Error('Укажите сумму, тип и дату');
    }
    const userId = String(req.user._id);
    const doc = await Transaction.create({
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
    const doc = await Transaction.findOneAndUpdate(
      { _id: req.params.id, userId },
      pick(req.body),
      { new: true }
    ).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Операция не найдена');
    }
    invalidateUserDataCache(userId);
    res.json(serialize(doc));
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const doc = await Transaction.findOneAndDelete({
      _id: req.params.id,
      userId,
    });
    if (!doc) {
      res.status(404);
      throw new Error('Операция не найдена');
    }
    invalidateUserDataCache(userId);
    res.json({ ok: true });
  })
);

module.exports = router;
