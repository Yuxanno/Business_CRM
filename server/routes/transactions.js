const express = require('express');
const Transaction = require('../models/Transaction');
const { protect, asyncHandler } = require('../middleware/auth');
const { serialize, serializeMany } = require('../utils/serialize');

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
    const limit = Math.min(Number(req.query.limit) || 300, 500);
    const skip = Number(req.query.skip) || 0;
    const filter = { userId: String(req.user._id) };
    if (req.query.type) filter.type = req.query.type;
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
    const [items, total] = await Promise.all([
      Transaction.find(filter)
        .sort({ date: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Transaction.countDocuments(filter),
    ]);
    res.json({ items: serializeMany(items), total });
  })
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    if (!req.body.amountCents || !req.body.type || !req.body.date) {
      res.status(400);
      throw new Error('Укажите сумму, тип и дату');
    }
    const doc = await Transaction.create({
      ...pick(req.body),
      _id: req.body.id,
      userId: String(req.user._id),
    });
    res.status(201).json(serialize(doc));
  })
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const doc = await Transaction.findOneAndUpdate(
      { _id: req.params.id, userId: String(req.user._id) },
      pick(req.body),
      { new: true }
    ).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Операция не найдена');
    }
    res.json(serialize(doc));
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const doc = await Transaction.findOneAndDelete({
      _id: req.params.id,
      userId: String(req.user._id),
    });
    if (!doc) {
      res.status(404);
      throw new Error('Операция не найдена');
    }
    res.json({ ok: true });
  })
);

module.exports = router;
