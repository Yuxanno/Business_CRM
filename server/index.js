require('dotenv').config();

const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const app = express();
const PORT = process.env.PORT || 3001;

// ─── Middleware ────────────────────────────────────────────────────────────────
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ─── MongoDB ──────────────────────────────────────────────────────────────────
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log('✅ MongoDB connected'))
  .catch((err) => console.error('❌ MongoDB error:', err.message));

// ─── Health check ─────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    time: new Date().toISOString(),
    db: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
  });
});

// ─── API routes ───────────────────────────────────────────────────────────────
// TODO: mount feature routers here
// app.use('/api/auth', require('./routes/auth'));
// app.use('/api/customers', require('./routes/customers'));
// app.use('/api/orders', require('./routes/orders'));
// app.use('/api/transactions', require('./routes/transactions'));
// app.use('/api/debts', require('./routes/debts'));

app.get('/api', (req, res) => {
  res.json({ message: 'Biznes CRM API', version: '1.0.0' });
});

// ─── 404 fallback ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ─── Error handler ────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

// ─── Start ────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
  console.log(`📊 Health: http://localhost:${PORT}/health`);
});
