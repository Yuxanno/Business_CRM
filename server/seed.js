/**
 * Seed demo data for a user.
 *
 * Usage:
 *   node server/seed.js                 (user: yuxanno / 123456)
 *   node server/seed.js --reset         (remove previous seed data first)
 *   node server/seed.js --user=name --password=secret
 *
 * Creates: 100 transactions, 100 orders (+ payments), 50 receivable + 50 payable
 * debts (+ payments), 30 categories (used by transactions) and 20 customers.
 * All seeded documents have notes = 'seed' so --reset can remove them.
 *
 * NOTE: categories are stored on the client (SharedPreferences), not in MongoDB.
 * Run the Flutter app once with --dart-define=SEED_CATEGORIES=true to add them.
 */
require('dotenv').config();

const dns = require('dns');
const net = require('net');
const tls = require('tls');
const mongoose = require('mongoose');
const { randomUUID } = require('crypto');

tls.DEFAULT_ECDH_CURVE = 'X25519:prime256v1:secp384r1';
tls.DEFAULT_MAX_VERSION = 'TLSv1.2';
dns.setDefaultResultOrder('ipv4first');
if (typeof net.setDefaultAutoSelectFamily === 'function') {
  net.setDefaultAutoSelectFamily(false);
}

const User = require('./models/User');
const Customer = require('./models/Customer');
const Transaction = require('./models/Transaction');
const { Order, OrderPayment } = require('./models/Order');
const { Debt, DebtPayment } = require('./models/Debt');

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v === undefined ? true : v];
  })
);
const USERNAME = String(args.user || 'yuxanno').toLowerCase();
const PASSWORD = String(args.password || '123456');
const TAG = 'seed';

const INCOME_CATEGORIES = [
  'Продажа товаров', 'Услуги', 'Консультации', 'Подписки', 'Аренда (доход)',
  'Комиссии', 'Реклама (доход)', 'Обучение', 'Проекты', 'Поддержка',
  'Лицензии', 'Партнёрка', 'Возвраты', 'Гранты', 'Прочий доход',
];
const EXPENSE_CATEGORIES = [
  'Закупка товаров', 'Аренда офиса', 'Зарплаты', 'Налоги', 'Реклама',
  'Транспорт', 'Связь и интернет', 'Коммунальные', 'Оборудование', 'Софт и сервисы',
  'Обучение персонала', 'Питание', 'Ремонт', 'Банковские комиссии', 'Прочие расходы',
];

const FIRST = ['Алексей', 'Мария', 'Иван', 'Ольга', 'Дмитрий', 'Анна', 'Сергей', 'Елена', 'Николай', 'Татьяна', 'Артём', 'Наталья', 'Павел', 'Юлия', 'Андрей', 'Ирина', 'Максим', 'Светлана', 'Егор', 'Виктория'];
const LAST = ['Иванов', 'Петрова', 'Сидоров', 'Кузнецова', 'Смирнов', 'Попова', 'Волков', 'Соколова', 'Морозов', 'Лебедева'];
const ORDER_TITLES = ['Разработка сайта', 'Дизайн логотипа', 'Настройка CRM', 'Поставка оборудования', 'Ремонт техники', 'Консультация', 'SMM-продвижение', 'Монтаж', 'Обслуживание', 'Печать материалов'];
const ORDER_STATUSES = ['new', 'inProgress', 'completed', 'cancelled'];

const rnd = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const pick = (arr) => arr[rnd(0, arr.length - 1)];
const DAY = 86400000;
const daysAgo = (n) => new Date(Date.now() - n * DAY - rnd(0, DAY - 1));
const cents = (rub) => Math.round(rub * 100);

async function reset(userId) {
  const orders = await Order.find({ userId, notes: TAG }).select('_id').lean();
  const debts = await Debt.find({ userId, notes: TAG }).select('_id').lean();
  await OrderPayment.deleteMany({ userId, orderId: { $in: orders.map((o) => o._id) } });
  await DebtPayment.deleteMany({ userId, debtId: { $in: debts.map((d) => d._id) } });
  await Promise.all([
    Order.deleteMany({ userId, notes: TAG }),
    Debt.deleteMany({ userId, notes: TAG }),
    Transaction.deleteMany({ userId, notes: TAG }),
    Customer.deleteMany({ userId, notes: TAG }),
  ]);
}

async function main() {
  if (!process.env.MONGODB_URI) throw new Error('MONGODB_URI is not set (.env)');
  await mongoose.connect(process.env.MONGODB_URI, {
    family: 4,
    tlsAllowInvalidCertificates: true,
    serverSelectionTimeoutMS: 8000,
  });

  let user = await User.findOne({ username: USERNAME });
  if (!user) {
    user = await User.create({
      username: USERNAME,
      password: PASSWORD,
      name: USERNAME.charAt(0).toUpperCase() + USERNAME.slice(1),
    });
    console.log(`👤 Создан пользователь ${USERNAME}`);
  } else {
    console.log(`👤 Найден пользователь ${USERNAME}`);
  }
  const userId = String(user._id);

  if (args.reset) {
    await reset(userId);
    console.log('🧹 Старые seed-данные удалены');
  }

  // Customers
  const customers = Array.from({ length: 20 }, (_, i) => ({
    _id: randomUUID(),
    userId,
    name: `${FIRST[i]} ${pick(LAST)}`,
    phone: `+7 9${rnd(10, 99)} ${rnd(100, 999)}-${rnd(10, 99)}-${rnd(10, 99)}`,
    email: `client${i + 1}@example.com`,
    notes: TAG,
    createdAt: daysAgo(rnd(60, 120)),
    totalOrdersAmountCents: 0,
    totalReceivedCents: 0,
    totalOrdersCount: 0,
  }));
  const custById = new Map(customers.map((c) => [c._id, c]));

  // Orders + payments
  const orders = [];
  const orderPayments = [];
  for (let i = 0; i < 100; i++) {
    const customer = pick(customers);
    const status = pick(ORDER_STATUSES);
    const total = cents(rnd(20, 500) * 100);
    const createdAt = daysAgo(rnd(0, 90));
    let received = 0;
    if (status === 'completed') received = total;
    else if (status === 'inProgress') received = Math.floor((total * rnd(0, 80)) / 100);
    else if (status === 'new') received = rnd(0, 1) ? Math.floor((total * rnd(0, 30)) / 100) : 0;
    const id = randomUUID();
    orders.push({
      _id: id,
      userId,
      title: `${pick(ORDER_TITLES)} #${i + 1}`,
      customerId: customer._id,
      customerName: customer.name,
      description: null,
      notes: TAG,
      totalPriceCents: total,
      receivedCents: received,
      status,
      createdAt,
      dueDate: new Date(createdAt.getTime() + rnd(3, 30) * DAY),
      updatedAt: null,
    });
    if (received > 0) {
      orderPayments.push({
        _id: randomUUID(),
        userId,
        orderId: id,
        customerId: customer._id,
        amountCents: received,
        paidAt: new Date(createdAt.getTime() + rnd(0, 5) * DAY),
        notes: TAG,
        transactionId: null,
      });
    }
    const c = custById.get(customer._id);
    if (status !== 'cancelled') {
      c.totalOrdersAmountCents += total;
      c.totalReceivedCents += received;
      c.totalOrdersCount += 1;
    }
  }

  // Debts + payments (50 receivable + 50 payable)
  const debts = [];
  const debtPayments = [];
  for (const direction of ['receivable', 'payable']) {
    for (let i = 0; i < 50; i++) {
      const original = cents(rnd(10, 300) * 100);
      const createdAt = daysAgo(rnd(0, 90));
      const dueDate = new Date(createdAt.getTime() + rnd(7, 60) * DAY);
      const mode = rnd(0, 2); // 0 unpaid, 1 partial, 2 paid
      let paid = 0;
      if (mode === 1) paid = Math.floor((original * rnd(10, 90)) / 100);
      if (mode === 2) paid = original;
      let status = mode === 2 ? 'paid' : mode === 1 ? 'partiallyPaid' : 'unpaid';
      if (status !== 'paid' && dueDate < new Date()) status = 'overdue';
      const id = randomUUID();
      const person = pick(customers);
      debts.push({
        _id: id,
        userId,
        personName: person.name,
        customerId: direction === 'receivable' ? person._id : null,
        direction,
        originalAmountCents: original,
        paidAmountCents: paid,
        status,
        description: direction === 'receivable' ? 'Долг клиента' : 'Долг поставщику',
        createdAt,
        dueDate,
        notes: TAG,
        updatedAt: null,
      });
      if (paid > 0) {
        debtPayments.push({
          _id: randomUUID(),
          userId,
          debtId: id,
          amountCents: paid,
          paidAt: new Date(createdAt.getTime() + rnd(0, 10) * DAY),
          notes: TAG,
          transactionId: null,
        });
      }
    }
  }

  // Transactions (50 income + 50 expense, using the 30 categories)
  const transactions = [];
  for (let i = 0; i < 100; i++) {
    const type = i % 2 === 0 ? 'income' : 'expense';
    const category = pick(type === 'income' ? INCOME_CATEGORIES : EXPENSE_CATEGORIES);
    const date = daysAgo(rnd(0, 90));
    transactions.push({
      _id: randomUUID(),
      userId,
      amountCents: cents(rnd(5, 300) * 100),
      type,
      category,
      description: category,
      date,
      createdAt: date,
      notes: TAG,
    });
  }

  await Customer.insertMany(customers);
  await Order.insertMany(orders);
  await OrderPayment.insertMany(orderPayments);
  await Debt.insertMany(debts);
  await DebtPayment.insertMany(debtPayments);
  await Transaction.insertMany(transactions);

  console.log('✅ Seed готов:');
  console.log(`   клиентов:     ${customers.length}`);
  console.log(`   заказов:      ${orders.length}`);
  console.log(`   долгов:       ${debts.length} (50 receivable + 50 payable)`);
  console.log(`   транзакций:   ${transactions.length}`);
  console.log(`   категорий:    ${INCOME_CATEGORIES.length + EXPENSE_CATEGORIES.length} (на клиенте, см. SEED_CATEGORIES)`);
  console.log('ℹ️  Если сервер запущен, его кэш обновится через ≤30 с (или перезапустите сервер).');

  await mongoose.disconnect();
}

main().catch(async (e) => {
  console.error('❌ Seed не выполнен:', e.message);
  try { await mongoose.disconnect(); } catch (_) {}
  process.exit(1);
});

module.exports = { INCOME_CATEGORIES, EXPENSE_CATEGORIES };

