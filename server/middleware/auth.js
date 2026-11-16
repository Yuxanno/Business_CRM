const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { logError } = require('../utils/logger');
const { userCache } = require('../utils/cache');

const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

const protect = asyncHandler(async (req, res, next) => {
  let token;
  const header = req.headers.authorization;
  if (header && header.startsWith('Bearer ')) {
    token = header.slice(7);
  }

  if (!token) {
    res.status(401);
    const error = new Error('Не авторизован — токен отсутствует');
    logError(req.method, req.path, error, {
      reason: 'Отсутствует заголовок Authorization',
    });
    throw error;
  }

  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || 'dev-secret'
    );
    const userId = String(decoded.id);

    // Check fast in-memory user cache first to avoid a MongoDB round-trip per request
    let user = userCache.get(userId);
    if (!user) {
      user = await User.findById(userId)
        .select('_id username name businessName currency locale')
        .lean();
      if (!user) {
        res.status(401);
        const error = new Error('Пользователь не найден');
        logError(req.method, req.path, error, { userId });
        throw error;
      }
      userCache.set(userId, user);
    }

    req.user = user;
    next();
  } catch (err) {
    if (res.statusCode !== 401) res.status(401);
    const error = new Error(err.message || 'Неверный токен');
    logError(req.method, req.path, error, { tokenError: err.message });
    throw error;
  }
});

module.exports = { protect, asyncHandler };
