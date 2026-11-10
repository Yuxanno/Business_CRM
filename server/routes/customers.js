const express = require('express');
const Customer = require('../models/Customer');
const { protect, asyncHandler } = require('../middleware/auth');
const { serialize, serializeMany } = require('../utils/serialize');

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

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const limit = Math.min(Number(req.query.limit) || 200, 500);
    const skip = Number(req.query.skip) || 0;
    const q = (req.query.q || '').trim();
    const filter = { userId: String(req.user._id) };
    if (q) {
      filter.$or = [
        { name: new RegExp(q, 'i') },
        { phone: new RegExp(q, 'i') },
      ];
    }
    const [items, total] = await Promise.all([
      Customer.find(filter)
        .sort({ name: 1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Customer.countDocuments(filter),
    ]);
    res.json({ items: serializeMany(items), total });
  })
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const doc = await Customer.findOne({
      _id: req.params.id,
      userId: String(req.user._id),
    }).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Клиент не найден');
    }
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
    const doc = await Customer.create({
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
    const doc = await Customer.findOneAndUpdate(
      { _id: req.params.id, userId: String(req.user._id) },
      pick(req.body),
      { new: true }
    ).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Клиент не найден');
    }
    res.json(serialize(doc));
  })
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const doc = await Customer.findOneAndDelete({
      _id: req.params.id,
      userId: String(req.user._id),
    });
    if (!doc) {
      res.status(404);
      throw new Error('Клиент не найден');
    }
    res.json({ ok: true });
  })
);

module.exports = router;
