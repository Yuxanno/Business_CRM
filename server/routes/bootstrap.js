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

/**
 * Single batched bootstrap endpoint: returns user profile, dashboard KPIs/chart,
 * and page 1 + counts for transactions, orders, customers, and debts in ONE HTTP request.
 */
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const userId = String(req.user._id);
    const now = new Date();
    const year = Number(req.query.year) || now.getFullYear();
    const month = Number(req.query.month) || now.getMonth() + 1;
    const limit = Math.min(Math.max(Number(req.query.limit) || 30, 1), 100);
    const tz = Math.max(-840, Math.min(840, Number(req.query.tz) || 0));

    const cacheKey = `u:${userId}:bootstrap:${year}:${month}:${tz}:${limit}`;
    const cached = dataCache.get(cacheKey);
    if (cached) {
      res.set('Cache-Control', 'private, max-age=10');
      return res.json(cached);
    }

    const absTz = Math.abs(tz);
    const tzName = `${tz < 0 ? '-' : '+'}${String(Math.floor(absTz / 60)).padStart(2, '0')}:${String(absTz % 60).padStart(2, '0')}`;
    const start = new Date(Date.UTC(year, month - 1, 1) - tz * 60000);
    const end = new Date(Date.UTC(year, month, 1) - tz * 60000);

    const [
      txAgg,
      recentTx,
      monthTxRaw,
      ordersRaw,
      orderCountsRows,
      customersRaw,
      customerOrderStats,
      allCustomersNames,
      debtsRaw,
      debtSummaryAgg,
      debtCountsRows,
    ] = await Promise.all([
      // 1. Dashboard & monthly transaction totals + chart
      Transaction.aggregate([
        { $match: { userId, date: { $gte: start, $lt: end } } },
        {
          $facet: {
            totals: [
              {
                $group: {
                  _id: '$type',
                  total: { $sum: '$amountCents' },
                  count: { $sum: 1 },
                },
              },
            ],
            chart: [
              {
                $group: {
                  _id: {
                    day: {
                      $dateToString: {
                        format: '%Y-%m-%d',
                        date: '$date',
                        timezone: tzName,
                      },
                    },
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
      // 2. Recent activity (top 10)
      Transaction.find({ userId })
        .select(
          'amountCents type category description date createdAt customerId orderId debtId linkedEntityType linkedEntityId'
        )
        .sort({ date: -1 })
        .limit(10)
        .lean(),
      // 3. Current month transactions page 1
      Transaction.find({ userId, date: { $gte: start, $lt: end } })
        .select('-notes')
        .sort({ date: -1, _id: -1 })
        .limit(limit + 1)
        .lean(),
      // 4. Orders page 1
      Order.find({ userId })
        .select('-notes -description')
        .sort({ createdAt: -1, _id: -1 })
        .limit(limit + 1)
        .lean(),
      // 5. Order status counts
      Order.aggregate([
        { $match: { userId } },
        { $group: { _id: '$status', n: { $sum: 1 } } },
      ]),
      // 6. Customers page 1
      Customer.find({ userId })
        .select('-notes')
        .sort({ name: 1, _id: 1 })
        .limit(limit + 1)
        .lean(),
      // 7. Live order stats per customer (used for both customer cards & counts)
      Order.aggregate([
        { $match: { userId } },
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
      ]),
      // 8. Customer names for debt matching
      Customer.find({ userId }).select('name').lean(),
      // 9. Debts page 1
      Debt.find({ userId })
        .select('-notes')
        .sort({ createdAt: -1, _id: -1 })
        .limit(limit + 1)
        .lean(),
      // 10. Unpaid receivable/payable debt totals + receivable customer matching
      Debt.find({ userId, status: { $ne: 'paid' } })
        .select(
          'direction customerId personName originalAmountCents paidAmountCents'
        )
        .lean(),
      // 11. Debt counts per direction & status
      Debt.aggregate([
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
      ]),
    ]);

    // ── Assemble Dashboard + Transactions ────────────────────────────────────
    const facetResult = txAgg[0] || {};
    let incomeCents = 0;
    let expenseCents = 0;
    let incomeCount = 0;
    let expenseCount = 0;
    for (const row of facetResult.totals || []) {
      if (row._id === 'income') {
        incomeCents = row.total || 0;
        incomeCount = row.count || 0;
      } else if (row._id === 'expense') {
        expenseCents = row.total || 0;
        expenseCount = row.count || 0;
      }
    }

    const chartData = (facetResult.chart || []).map((row) => ({
      day: row._id.day,
      type: row._id.type,
      total: row.total,
    }));

    const txHasMore = monthTxRaw.length > limit;
    const txItems = txHasMore ? monthTxRaw.slice(0, limit) : monthTxRaw;

    // ── Assemble Orders ──────────────────────────────────────────────────────
    const byStatus = { new: 0, inProgress: 0, completed: 0, cancelled: 0 };
    let totalOrders = 0;
    for (const r of orderCountsRows) {
      byStatus[r._id] = r.n;
      totalOrders += r.n;
    }
    const activeOrdersCount =
      (byStatus.new || 0) + (byStatus.inProgress || 0);
    const ordersHasMore = ordersRaw.length > limit;
    const orderItems = ordersHasMore ? ordersRaw.slice(0, limit) : ordersRaw;

    // ── Assemble Customers ───────────────────────────────────────────────────
    const orderStatsMap = new Map();
    for (const r of customerOrderStats) {
      orderStatsMap.set(String(r._id), {
        totalOrdersCount: r.totalOrdersCount || 0,
        totalReceivedCents: r.totalReceivedCents || 0,
        totalOrdersAmountCents: r.totalOrdersAmountCents || 0,
      });
    }

    const customersHasMore = customersRaw.length > limit;
    const customerItems = customersHasMore
      ? customersRaw.slice(0, limit)
      : customersRaw;
    for (const c of customerItems) {
      const s = orderStatsMap.get(String(c._id));
      c.totalOrdersCount = s ? s.totalOrdersCount : 0;
      c.totalReceivedCents = s ? s.totalReceivedCents : 0;
      c.totalOrdersAmountCents = s ? s.totalOrdersAmountCents : 0;
    }

    let receivableCents = 0;
    let payableCents = 0;
    const debtCustomerIds = new Set();
    const debtPersonNames = new Set();
    for (const d of debtSummaryAgg) {
      const rem = Math.max(
        0,
        (d.originalAmountCents || 0) - (d.paidAmountCents || 0)
      );
      if (d.direction === 'receivable') {
        receivableCents += rem;
        if (rem > 0) {
          if (d.customerId) debtCustomerIds.add(String(d.customerId));
          debtPersonNames.add(String(d.personName || '').trim().toLowerCase());
        }
      } else if (d.direction === 'payable') {
        payableCents += rem;
      }
    }

    let withOrders = 0;
    let withDebt = 0;
    for (const c of allCustomersNames) {
      const s = orderStatsMap.get(String(c._id));
      const ordersCount = s ? s.totalOrdersCount : 0;
      const ordersAmount = s ? s.totalOrdersAmountCents : 0;
      const receivedAmount = s ? s.totalReceivedCents : 0;
      if (ordersCount > 0) withOrders++;
      if (
        ordersAmount - receivedAmount > 0 ||
        debtCustomerIds.has(String(c._id)) ||
        debtPersonNames.has(String(c.name || '').trim().toLowerCase())
      ) {
        withDebt++;
      }
    }

    // ── Assemble Debts ───────────────────────────────────────────────────────
    const debtsHasMore = debtsRaw.length > limit;
    const debtItems = debtsHasMore ? debtsRaw.slice(0, limit) : debtsRaw;

    const emptyDebtCounts = () => ({ all: 0, active: 0, overdue: 0, paid: 0 });
    const debtCounts = {
      receivable: emptyDebtCounts(),
      payable: emptyDebtCounts(),
    };
    for (const r of debtCountsRows) {
      if (!debtCounts[r._id]) continue;
      debtCounts[r._id] = {
        all: r.all,
        active: r.all - r.paid,
        overdue: r.overdue,
        paid: r.paid,
      };
    }

    const user = req.user;
    const payload = {
      user: {
        _id: user._id,
        name: user.name,
        username: user.username,
        businessName: user.businessName || '',
        currency: user.currency || 'RUB',
        locale: user.locale || 'ru',
      },
      dashboard: {
        year,
        month,
        incomeCents,
        expenseCents,
        activeOrdersCount,
        totalCustomersCount: allCustomersNames.length,
        receivableCents,
        payableCents,
        chartData,
        recent: serializeMany(recentTx),
      },
      transactions: {
        items: serializeMany(txItems),
        hasMore: txHasMore,
        nextSkip: txItems.length,
        incomeCents,
        expenseCents,
        counts: {
          total: incomeCount + expenseCount,
          income: incomeCount,
          expense: expenseCount,
        },
      },
      orders: {
        items: serializeMany(orderItems),
        hasMore: ordersHasMore,
        nextSkip: orderItems.length,
        counts: { total: totalOrders, byStatus },
      },
      customers: {
        items: serializeMany(customerItems),
        hasMore: customersHasMore,
        nextSkip: customerItems.length,
        counts: {
          total: allCustomersNames.length,
          withOrders,
          withDebt,
        },
      },
      debts: {
        items: serializeMany(debtItems),
        hasMore: debtsHasMore,
        nextSkip: debtItems.length,
        counts: debtCounts,
      },
    };

    dataCache.set(cacheKey, payload, 20000);
    res.set('Cache-Control', 'private, max-age=10');
    res.json(payload);
  })
);

module.exports = router;

