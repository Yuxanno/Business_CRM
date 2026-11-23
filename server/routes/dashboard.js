const express = require('express');
const Transaction = require('../models/Transaction');
const { Order } = require('../models/Order');
const Customer = require('../models/Customer');
const { Debt } = require('../models/Debt');
const { protect, asyncHandler } = require('../middleware/auth');
const { serializeMany } = require('../utils/serialize');
const { dataCache } = require('../utils/cache');

const router = express.Router();
router.use(protect);

router.get(
  '/summary',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const cacheKey = `u:${userId}:dashboard:summary`;
    const cached = dataCache.get(cacheKey);
    if (cached) {
      res.set('Cache-Control', 'private, max-age=15');
      return res.json(cached);
    }

    const [activeOrdersCount, totalCustomersCount, debtAgg] = await Promise.all([
      Order.countDocuments({
        userId,
        status: { $in: ['new', 'inProgress'] },
      }),
      Customer.countDocuments({ userId }),
      Debt.aggregate([
        { $match: { userId, status: { $ne: 'paid' } } },
        {
          $project: {
            direction: 1,
            remaining: {
              $max: [0, { $subtract: ['$originalAmountCents', '$paidAmountCents'] }],
            },
          },
        },
        {
          $group: {
            _id: '$direction',
            total: { $sum: '$remaining' },
          },
        },
      ]),
    ]);

    let receivableCents = 0;
    let payableCents = 0;
    for (const row of debtAgg) {
      if (row._id === 'receivable') receivableCents = row.total || 0;
      else if (row._id === 'payable') payableCents = row.total || 0;
    }

    const payload = {
      activeOrdersCount,
      totalCustomersCount,
      receivableCents,
      payableCents,
    };
    dataCache.set(cacheKey, payload, 30000);
    res.set('Cache-Control', 'private, max-age=15');
    res.json(payload);
  })
);

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const now = new Date();
    const year = Number(req.query.year) || now.getFullYear();
    const month = Number(req.query.month) || now.getMonth() + 1;
    const userId = String(req.user._id);

    // Client time zone offset in minutes (east of UTC) so month/day boundaries
    // match the user's local time (same as the transactions list).
    const tz = Math.max(-840, Math.min(840, Number(req.query.tz) || 0));
    const absTz = Math.abs(tz);
    const tzName = `${tz < 0 ? '-' : '+'}${String(Math.floor(absTz / 60)).padStart(2, '0')}:${String(absTz % 60).padStart(2, '0')}`;

    const cacheKey = `u:${userId}:dashboard:${year}:${month}:${tz}`;
    const cached = dataCache.get(cacheKey);
    if (cached) {
      res.set('Cache-Control', 'private, max-age=15');
      return res.json(cached);
    }

    const start = new Date(Date.UTC(year, month - 1, 1) - tz * 60000);
    const end = new Date(Date.UTC(year, month, 1) - tz * 60000);

    const [txAgg, recent, activeOrdersCount, totalCustomersCount, debtAgg] =
      await Promise.all([
        Transaction.aggregate([
          { $match: { userId, date: { $gte: start, $lt: end } } },
          {
            $facet: {
              totals: [
                { $group: { _id: '$type', total: { $sum: '$amountCents' } } },
              ],
              chart: [
                {
                  $group: {
                    _id: {
                      day: { $dateToString: { format: '%Y-%m-%d', date: '$date', timezone: tzName } },
                      type: '$type',
                    },
                    total: { $sum: '$amountCents' },
                  },
                },
                { $sort: { '_id.day': 1 } },
              ],
            },
          },
        ]),
        Transaction.find({ userId })
          .select('amountCents type category description date createdAt customerId orderId debtId linkedEntityType linkedEntityId')
          .sort({ date: -1 })
          .limit(10)
          .lean(),
        Order.countDocuments({
          userId,
          status: { $in: ['new', 'inProgress'] },
        }),
        Customer.countDocuments({ userId }),
        Debt.aggregate([
          { $match: { userId, status: { $ne: 'paid' } } },
          {
            $project: {
              direction: 1,
              remaining: {
                $max: [0, { $subtract: ['$originalAmountCents', '$paidAmountCents'] }],
              },
            },
          },
          {
            $group: {
              _id: '$direction',
              total: { $sum: '$remaining' },
            },
          },
        ]),
      ]);

    const facetResult = txAgg[0] || {};
    let incomeCents = 0;
    let expenseCents = 0;
    for (const row of facetResult.totals || []) {
      if (row._id === 'income') incomeCents = row.total || 0;
      else if (row._id === 'expense') expenseCents = row.total || 0;
    }

    const chartData = (facetResult.chart || []).map((row) => ({
      day: row._id.day,
      type: row._id.type,
      total: row.total,
    }));

    let receivableCents = 0;
    let payableCents = 0;
    for (const row of debtAgg) {
      if (row._id === 'receivable') receivableCents = row.total || 0;
      else if (row._id === 'payable') payableCents = row.total || 0;
    }

    const payload = {
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
    };

    dataCache.set(cacheKey, payload, 30000);
    res.set('Cache-Control', 'private, max-age=15');
    res.json(payload);
  })
);

module.exports = router;
