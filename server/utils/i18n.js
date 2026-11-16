const ERROR_EN = {
  'Укажите имя, логин и пароль': 'Enter name, username, and password',
  'Пользователь с таким логином уже существует':
    'An account with this username already exists',
  'Некорректные данные пользователя': 'Invalid user data',
  'Укажите логин и пароль': 'Enter username and password',
  'Неверный логин или пароль': 'Invalid username or password',
  'Пользователь не найден': 'User not found',
  'Укажите имя пользователя': 'Enter owner name',
  'Логин: 3–32 символа, латиница, цифры, . _ -':
    'Username: 3–32 chars, letters, digits, . _ -',
  'Новый пароль — минимум 6 символов':
    'New password must be at least 6 characters',
  'Введите пароль для подтверждения': 'Enter your password to confirm',
  'Неверный пароль': 'Incorrect password',
  'Не авторизован — токен отсутствует': 'Unauthorized — token missing',
  'Неверный токен': 'Invalid token',
  'Клиент не найден': 'Customer not found',
  'Укажите имя': 'Enter name',
  'Долг не найден': 'Debt not found',
  'Укажите имя, направление и сумму': 'Enter name, direction, and amount',
  'Некорректная сумма': 'Invalid amount',
  'Заказ не найден': 'Order not found',
  'Укажите название и клиента': 'Enter title and customer',
  'Укажите сумму, тип и дату': 'Enter amount, type, and date',
  'Операция не найдена': 'Transaction not found',
};

function isEnglishRequest(req) {
  const header = String(req?.headers?.['accept-language'] || '').toLowerCase();
  return header.startsWith('en');
}

function translateError(req, message) {
  if (!isEnglishRequest(req)) return message;
  return ERROR_EN[message] || message;
}

module.exports = { translateError };

