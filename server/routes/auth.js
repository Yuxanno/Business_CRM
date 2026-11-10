const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { protect } = require('../middleware/auth');
const { logSuccess, logError, logWarning } = require('../utils/logger');

const router = express.Router();

// Helper for async handlers
const { asyncHandler } = require('../middleware/auth');

// ─── @desc    Register new user ───────────────────────────────────────────────
// ─── @route   POST /api/auth/register ────────────────────────────────────────
// ─── @access  Public ─────────────────────────────────────────────────────────
router.post(
  '/register',
  asyncHandler(async (req, res) => {
    const { name, username, password } = req.body;

    // Validate required fields
    if (!name || !username || !password) {
      res.status(400);
      throw new Error('Укажите имя, логин и пароль');
    }

    const normalizedUsername = String(username).trim().toLowerCase();

    // Check if user exists
    const existingUser = await User.findOne({ username: normalizedUsername });
    if (existingUser) {
      res.status(400);
      throw new Error('Пользователь с таким логином уже существует');
    }

    // Create user with default settings
    const user = await User.create({
      name,
      username: normalizedUsername,
      password,
      currency: 'RUB',  // Default currency
      locale: 'ru',     // Default locale
    });

    if (user) {
      logSuccess('POST', '/api/auth/register', `Пользователь зарегистрирован: ${user.username}`, {
        userId: user._id,
        name: user.name,
      });
      
      res.status(201).json({
        _id: user._id,
        name: user.name,
        username: user.username,
        businessName: user.businessName || '',
        currency: user.currency || 'RUB',
        locale: user.locale || 'ru',
        token: generateToken(user._id),
      });
    } else {
      res.status(400);
      throw new Error('Некорректные данные пользователя');
    }
  })
);

// ─── @desc    Login user ─────────────────────────────────────────────────────
// ─── @route   POST /api/auth/login ──────────────────────────────────────────
// ─── @access  Public ─────────────────────────────────────────────────────────
router.post(
  '/login',
  asyncHandler(async (req, res) => {
    const { username, password } = req.body;

    // Validate required fields
    if (!username || !password) {
      res.status(400);
      throw new Error('Укажите логин и пароль');
    }

    const normalizedUsername = String(username).trim().toLowerCase();

    // Find user in DB (including password)
    const user = await User.findOne({ username: normalizedUsername }).select(
      '+password'
    );

    if (!user) {
      res.status(401);
      throw new Error('Неверный логин или пароль');
    }

    // Check password
    const isPasswordMatch = await user.matchPassword(password);

    if (!isPasswordMatch) {
      res.status(401);
      logWarning('Неверный пароль', { username: normalizedUsername });
      throw new Error('Неверный логин или пароль');
    }

    logSuccess('POST', '/api/auth/login', `Пользователь вошёл: ${user.username}`, {
      userId: user._id,
      name: user.name,
    });

    res.json({
      _id: user._id,
      name: user.name,
      username: user.username,
      businessName: user.businessName || '',
      currency: user.currency || 'RUB',
      locale: user.locale || 'ru',
      token: generateToken(user._id),
    });
  })
);

// ─── @desc    Get logged in user profile ─────────────────────────────────────
// ─── @route   GET /api/auth/me ──────────────────────────────────────────────
// ─── @access  Private ────────────────────────────────────────────────────────
router.get(
  '/me',
  protect,
  asyncHandler(async (req, res) => {
    const user = await User.findById(req.user._id);
    if (user) {
      res.json({
        _id: user._id,
        name: user.name,
        username: user.username,
        businessName: user.businessName || '',
        currency: user.currency || 'RUB',
        locale: user.locale || 'ru',
      });
    } else {
      res.status(404);
      throw new Error('User not found');
    }
  })
);

// ─── @desc    Update name, business, login, password ─────────────────────────
// ─── @route   PUT /api/auth/profile ──────────────────────────────────────────
// ─── @access  Private ────────────────────────────────────────────────────────
router.put(
  '/profile',
  protect,
  asyncHandler(async (req, res) => {
    const user = await User.findById(req.user._id).select('+password');
    if (!user) {
      res.status(404);
      throw new Error('Пользователь не найден');
    }

    const name = req.body.name != null ? String(req.body.name).trim() : user.name;
    const businessName =
      req.body.businessName != null
        ? String(req.body.businessName).trim()
        : user.businessName || '';
    const username =
      req.body.username != null
        ? String(req.body.username).trim().toLowerCase()
        : user.username;
    const password =
      req.body.password != null ? String(req.body.password) : '';
    const currency =
      req.body.currency != null
        ? String(req.body.currency).trim()
        : user.currency || 'RUB';
    const locale =
      req.body.locale != null
        ? String(req.body.locale).trim()
        : user.locale || 'ru';

    if (!name) {
      res.status(400);
      throw new Error('Укажите имя пользователя');
    }
    if (!/^[a-zA-Z0-9._-]{3,32}$/.test(username)) {
      res.status(400);
      throw new Error('Логин: 3–32 символа, латиница, цифры, . _ -');
    }
    if (password && password.length < 6) {
      res.status(400);
      throw new Error('Новый пароль — минимум 6 символов');
    }

    if (username !== user.username) {
      const existing = await User.findOne({ username });
      if (existing) {
        res.status(400);
        throw new Error('Пользователь с таким логином уже существует');
      }
      user.username = username;
    }

    user.name = name;
    user.businessName = businessName;
    user.currency = currency;
    user.locale = locale;
    if (password) user.password = password;

    await user.save();

    logSuccess('PUT', '/api/auth/profile', `Профиль обновлён: ${user.username}`, {
      userId: user._id,
      updatedFields: {
        name: name !== req.user.name,
        businessName: businessName !== req.user.businessName,
        currency: currency !== req.user.currency,
        locale: locale !== req.user.locale,
        password: !!password,
      },
    });

    res.json({
      _id: user._id,
      name: user.name,
      username: user.username,
      businessName: user.businessName || '',
      currency: user.currency || 'RUB',
      locale: user.locale || 'ru',
    });
  })
);

// ─── Generate JWT ─────────────────────────────────────────────────────────────
const generateToken = (userId) => {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET || 'dev-secret', {
    expiresIn: '30d',
  });
};

module.exports = router;
