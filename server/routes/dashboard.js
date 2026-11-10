const express = require('express');
const Transaction = require('../models/Transaction');
const { Order } = require('../models/Order');
const Customer = require('../models/Customer');
const { Debt } = require('../models/Debt');
const { protect, asyncHandler } = require('../middleware/auth');
const { serializeMany } = require('../utils/serialize');

const router = express.Router();
router.use(protect);

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const now = new Date();
    const year = Number(req.query.year) || now.getFullYear();
    const month = Number(req.query.month) || now.getMonth() + 1;
    const start = new Date(Date.UTC(year, month - 1, 1));
    const end = new Date(Date.UTC(year, month, 1));
    const userId = String(req.user._id);

    const [monthTx, recent, activeOrdersCount, totalCustomersCount, debts] =
      await Promise.all([
        Transaction.find({
          userId,
          date: { $gte: start, $lt: end },
        })
          .select('amountCents type date')
          .lean(),
        Transaction.find({ userId })
          .sort({ date: -1 })
          .limit(15)
          .lean(),
        Order.countDocuments({
          userId,
          status: { $in: ['new', 'inProgress'] },
        }),
        Customer.countDocuments({ userId }),
        Debt.find({
          userId,
          status: { $ne: 'paid' },
        })
          .select('direction originalAmountCents paidAmountCents')
          .lean(),
      ]);

    let incomeCents = 0;
    let expenseCents = 0;
    const buckets = new Map();
    for (const tx of monthTx) {
      if (tx.type === 'income') incomeCents += tx.amountCents;
      else expenseCents += tx.amountCents;
      const day = new Date(tx.date).toISOString().slice(0, 10);
      const key = `${day}|${tx.type}`;
      buckets.set(key, (buckets.get(key) || 0) + tx.amountCents);
    }

    const chartData = [...buckets.entries()]
      .map(([key, total]) => {
        const [day, type] = key.split('|');
        return { day, type, total };
      })
      .sort((a, b) => a.day.localeCompare(b.day));

    let receivableCents = 0;
    let payableCents = 0;
    for (const d of debts) {
      const left = Math.max(0, d.originalAmountCents - d.paidAmountCents);
      if (d.direction === 'receivable') receivableCents += left;
      else payableCents += left;
    }

    res.json({
      year,
      month,
      incomeCents,
      expenseCents,
      activeOrdersCount,
      totalCustomersCount,
      receivableCents,
      payableCents,
      chartData,
      recent: serializeMany(recent),
    });
  })
);

module.exports = router;
