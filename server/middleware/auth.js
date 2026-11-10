const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { logError } = require('../utils/logger');

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
      reason: 'Отсутствует заголовок Authorization' 
    });
    throw error;
  }

  try {
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || 'dev-secret'
    );
    const user = await User.findById(decoded.id).select('-password');
    if (!user) {
      res.status(401);
      const error = new Error('Пользователь не найден');
      logError(req.method, req.path, error, { userId: decoded.id });
      throw error;
    }
    req.user = user;
    next();
  } catch (err) {
    res.status(401);
    const error = new Error('Неверный токен');
    logError(req.method, req.path, error, { tokenError: err.message });
    throw error;
  }
});

module.exports = { protect, asyncHandler };
