require('dotenv').config();

const dns = require('dns');
const net = require('net');
const tls = require('tls');
const express = require('express');
const cors = require('cors');
const compression = require('compression');
const mongoose = require('mongoose');
const { translateError } = require('./utils/i18n');

// Фикс для Node.js v24 (OpenSSL 3.5): отключаем Post-Quantum ML-KEM (увеличивающий TLS ClientHello > MTU)
// и принудительно используем IPv4
tls.DEFAULT_ECDH_CURVE = 'X25519:prime256v1:secp384r1';
tls.DEFAULT_MAX_VERSION = 'TLSv1.2';
dns.setDefaultResultOrder('ipv4first');
if (typeof net.setDefaultAutoSelectFamily === 'function') {
  net.setDefaultAutoSelectFamily(false);
}

const app = express();
const PORT = process.env.PORT || 3001;

// Enable weak ETag so unchanged responses return 304 Not Modified
app.set('etag', 'weak');

// ─── Middleware ────────────────────────────────────────────────────────────────
app.use(compression({ threshold: 512 }));
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Логирование запросов с замером времени отклика (ms)
app.use((req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - start) / 1e6;
    const timestamp = new Date().toLocaleTimeString('ru-RU');
    console.log(
      `[${timestamp}] ${req.method} ${req.path} ${res.statusCode} ${durationMs.toFixed(1)}ms`
    );
  });
  next();
});

// ─── MongoDB ──────────────────────────────────────────────────────────────────
const connectDB = () => {
  mongoose
    .connect(process.env.MONGODB_URI, {
      family: 4,
      tlsAllowInvalidCertificates: true,
      maxPoolSize: 20,
      minPoolSize: 5,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 20000,
      compressors: ['zlib'],
    })
    .then(() => {
      console.log('✅ MongoDB успешно подключена');
      console.log(`📊 База данных: ${mongoose.connection.db.databaseName}`);
    })
    .catch((err) => {
      console.error('\n' + '❌'.repeat(35));
      console.error('❌ ОШИБКА ПОДКЛЮЧЕНИЯ К MONGODB');
      console.error('❌'.repeat(35));
      console.error(`💬 Сообщение: ${err.message}`);
      if (err.reason && err.reason.servers) {
        for (const [addr, desc] of err.reason.servers) {
          if (desc.error) {
            console.error(`🔍 Узел ${addr}: ${desc.error.message}`);
            if (desc.error.cause) {
              console.error(`   ↳ Причина: ${desc.error.cause.message || desc.error.cause}`);
            }
          }
        }
      }
      console.error(`📍 URI: ${process.env.MONGODB_URI ? 'Установлен' : 'НЕ УСТАНОВЛЕН'}`);
      console.error('⚠️  Сервер продолжает работу без БД. Повторная попытка через 10 сек...');
      console.error('❌'.repeat(35) + '\n');
      setTimeout(connectDB, 10000);
    });
};

connectDB();

// ─── Health check ─────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    time: new Date().toISOString(),
    db: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
  });
});

// ─── API routes ───────────────────────────────────────────────────────────────
app.use('/api/auth', require('./routes/auth'));
app.use('/api/customers', require('./routes/customers'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/transactions', require('./routes/transactions'));
app.use('/api/debts', require('./routes/debts'));
app.use('/api/dashboard', require('./routes/dashboard'));

app.get('/api', (req, res) => {
  res.json({ message: 'Biznes CRM API', version: '1.0.0' });
});

// ─── 404 fallback ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ─── Error handler ────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  const status = res.statusCode && res.statusCode !== 200 ? res.statusCode : 500;
  
  // Красивый вывод ошибок в консоль
  const timestamp = new Date().toLocaleTimeString('ru-RU');
  const method = req.method;
  const path = req.path;
  const errorMsg = err.message || 'Internal server error';
  
  console.log('\n' + '━'.repeat(70));
  console.log(`⚠️  ОШИБКА [${timestamp}]`);
  console.log('━'.repeat(70));
  console.log(`📍 Метод:    ${method}`);
  console.log(`📍 Путь:     ${path}`);
  console.log(`📍 Статус:   ${status}`);
  console.log(`💬 Сообщение: ${errorMsg}`);
  
  if (status >= 500) {
    console.log(`\n🔍 Стек ошибки:`);
    console.log(err.stack);
  }
  
  if (req.body && Object.keys(req.body).length > 0) {
    console.log(`\n📦 Тело запроса:`);
    console.log(JSON.stringify(req.body, null, 2));
  }
  
  console.log('━'.repeat(70) + '\n');
  
  res.status(status).json({ error: translateError(req, errorMsg) });
});

// ─── Start ────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log('\n' + '═'.repeat(70));
  console.log('🚀 Biznes CRM Server');
  console.log('═'.repeat(70));
  console.log(`✅ Сервер запущен:     http://localhost:${PORT}`);
  console.log(`✅ API:               http://localhost:${PORT}/api`);
  console.log(`✅ Проверка здоровья: http://localhost:${PORT}/health`);
  console.log(`✅ База данных:       ${mongoose.connection.readyState === 1 ? 'Подключена' : 'Подключение...'}`);
  console.log('═'.repeat(70));
  console.log('📝 Логи запросов:\n');
});
