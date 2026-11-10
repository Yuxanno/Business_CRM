const express = require('express');
const { randomUUID } = require('crypto');
const { Debt, DebtPayment } = require('../models/Debt');
const Transaction = require('../models/Transaction');
const { protect, asyncHandler } = require('../middleware/auth');
const { serialize, serializeMany } = require('../utils/serialize');

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
    const limit = Math.min(Number(req.query.limit) || 200, 500);
    const skip = Number(req.query.skip) || 0;
    const filter = { userId: String(req.user._id) };
    if (req.query.direction) filter.direction = req.query.direction;
    const [items, total] = await Promise.all([
      Debt.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      Debt.countDocuments(filter),
    ]);
    res.json({ items: serializeMany(items), total });
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
    const doc = await Debt.create({
      ...pick(req.body),
      _id: req.body.id,
      userId: String(req.user._id),
      paidAmountCents: req.body.paidAmountCents || 0,
      status: req.body.status || 'unpaid',
    });
    res.status(201).json(serialize(doc));
  })
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const doc = await Debt.findOneAndUpdate(
      { _id: req.params.id, userId: String(req.user._id) },
      { ...pick(req.body), updatedAt: new Date() },
      { new: true }
    ).lean();
    if (!doc) {
      res.status(404);
      throw new Error('Долг не найден');
    }
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
    await debt.save();

    await DebtPayment.create({
      _id: paymentId,
      userId,
      debtId: debt._id,
      amountCents: amount,
      paidAt,
      notes: req.body.notes || null,
      transactionId,
    });

    const isReceivable = debt.direction === 'receivable';
    await Transaction.create({
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
    });

    res.status(201).json(serialize(debt));
  })
);

module.exports = router;
