const express = require('express');
const { randomUUID } = require('crypto');
const { Debt, DebtPayment } = require('../models/Debt');
const Transaction = require('../models/Transaction');
const { protect, asyncHandler } = require('../middleware/auth');
const { serialize, serializeMany } = require('../utils/serialize');
const { dataCache, invalidateUserDataCache } = require('../utils/cache');

const router = express.Router();
router.use(protect);

const fields = [
  'personName',
  'customerId',
  'direction',
  'originalAmountCents',
  'paidAmountCents',
  'status',
  'description',
  'createdAt',
  'dueDate',
  'notes',
  'updatedAt',
];

function pick(body) {
  const out = {};
  for (const f of fields) {
    if (body[f] !== undefined) out[f] = body[f];
  }
  return out;
}

function computeStatus(debt, paid) {
  const due = debt.dueDate ? new Date(debt.dueDate) : null;
  const overdue = due && Date.now() > due.getTime();
  if (paid >= debt.originalAmountCents) return 'paid';
  if (paid > 0) return overdue ? 'overdue' : 'partiallyPaid';
  return overdue ? 'overdue' : 'unpaid';
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const limit = Math.min(Math.max(Number(req.query.limit) || 25, 1), 500);
    const skip = Math.max(Number(req.query.skip) || 0, 0);
    const compact = req.query.compact === '1' || req.query.compact === 'true';

    const cacheKey = `u:${userId}:debts:${req.originalUrl}`;
    const cached = dataCache.get(cacheKey);
    if (cached) return res.json(cached);

    const filter = { userId };
    if (req.query.direction) filter.direction = req.query.direction;
    if (req.query.customerId) filter.customerId = req.query.customerId;

    const query = Debt.find(filter)
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

// Real totals per direction/status (independent of pagination)
router.get(
  '/counts',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const cacheKey = `u:${userId}:debts:counts`;
    const cached = dataCache.get(cacheKey);
    if (cached) return res.json(cached);

    const rows = await Debt.aggregate([
      { $match: { userId } },
      {
        $project: {
          direction: 1,
          isPaid: { $gte: ['$paidAmountCents', '$originalAmountCents'] },
          isOverdue: {
            $and: [
              { $lt: ['$paidAmountCents', '$originalAmountCents'] },
              { $ne: ['$dueDate', null] },
              { $lt: ['$dueDate', '$$NOW'] },
            ],
          },
        },
      },
      {
        $group: {
          _id: '$direction',
          all: { $sum: 1 },
          paid: { $sum: { $cond: ['$isPaid', 1, 0] } },
          overdue: { $sum: { $cond: ['$isOverdue', 1, 0] } },
        },
      },
    ]);
    const empty = () => ({ all: 0, active: 0, overdue: 0, paid: 0 });
    const payload = { receivable: empty(), payable: empty() };
    for (const r of rows) {
      if (!payload[r._id]) continue;
      payload[r._id] = {
        all: r.all,
        active: r.all - r.paid,
        overdue: r.overdue,
        paid: r.paid,
      };
    }
    payload.total = payload.receivable.all + payload.payable.all;
    dataCache.set(cacheKey, payload, 20000);
    res.json(payload);
  })
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const doc = await Debt.findOne({
      _id: req.params.id,
      userId: String(req.user._id),
    }).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Долг не найден');
    }
    res.json(serialize(doc));
  })
);

router.get(
  '/:id/payments',
  asyncHandler(async (req, res) => {
    const items = await DebtPayment.find({
      debtId: req.params.id,
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
    if (!req.body.personName || !req.body.direction || !req.body.originalAmountCents) {
      res.status(400);
      throw new Error('Укажите имя, направление и сумму');
    }
    const userId = String(req.user._id);
    const doc = await Debt.create({
      ...pick(req.body),
      _id: req.body.id,
      userId,
      paidAmountCents: req.body.paidAmountCents || 0,
      status: req.body.status || 'unpaid',
    });
    invalidateUserDataCache(userId);
    res.status(201).json(serialize(doc));
  })
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const doc = await Debt.findOneAndUpdate(
      { _id: req.params.id, userId },
      { ...pick(req.body), updatedAt: new Date() },
      { new: true }
    ).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Долг не найден');
    }
    invalidateUserDataCache(userId);
    res.json(serialize(doc));
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const doc = await Debt.findOneAndDelete({ _id: req.params.id, userId });
    if (!doc) {
      res.status(404);
      throw new Error('Долг не найден');
    }
    await DebtPayment.deleteMany({ debtId: doc._id, userId });
    invalidateUserDataCache(userId);
    res.json({ ok: true });
  })
);

router.post(
  '/:id/payments',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const debt = await Debt.findOne({ _id: req.params.id, userId });
    if (!debt) {
      res.status(404);
      throw new Error('Долг не найден');
    }
    const remaining = debt.originalAmountCents - debt.paidAmountCents;
    const amount = Math.min(Number(req.body.amountCents) || 0, remaining);
    if (amount <= 0) {
      res.status(400);
      throw new Error('Некорректная сумма');
    }
    const paidAt = req.body.paidAt ? new Date(req.body.paidAt) : new Date();
    const paymentId = req.body.paymentId || randomUUID();
    const transactionId = req.body.transactionId || randomUUID();
    const newPaid = debt.paidAmountCents + amount;
    debt.paidAmountCents = newPaid;
    debt.status = computeStatus(debt, newPaid);
    debt.updatedAt = new Date();

    const isReceivable = debt.direction === 'receivable';
    await Promise.all([
      debt.save(),
      DebtPayment.create({
        _id: paymentId,
        userId,
        debtId: debt._id,
        amountCents: amount,
        paidAt,
        notes: req.body.notes || null,
        transactionId,
      }),
      Transaction.create({
        _id: transactionId,
        userId,
        amountCents: amount,
        type: isReceivable ? 'income' : 'expense',
        category: isReceivable ? 'debt_received' : 'debt_paid',
        description: `Долг: ${debt.personName}`,
        date: paidAt,
        createdAt: new Date(),
        debtId: debt._id,
        linkedEntityType: 'debt_payment',
        linkedEntityId: paymentId,
      }),
    ]);

    invalidateUserDataCache(userId);
    res.status(201).json(serialize(debt));
  })
);

module.exports = router;
