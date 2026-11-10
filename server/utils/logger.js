// ─── Утилита для красивого логирования ────────────────────────────────────────

/**
 * Форматирует и выводит информацию об успешном запросе
 */
function logSuccess(method, path, message, data = null) {
  const timestamp = new Date().toLocaleTimeString('ru-RU');
  console.log(`\n✅ [${timestamp}] ${method} ${path}`);
  if (message) console.log(`   💬 ${message}`);
  if (data) {
    console.log(`   📦 Данные:`, JSON.stringify(data, null, 2));
  }
}

/**
 * Форматирует и выводит информацию об ошибке
 */
function logError(method, path, error, details = null) {
  const timestamp = new Date().toLocaleTimeString('ru-RU');
  console.log('\n' + '━'.repeat(70));
  console.log(`❌ ОШИБКА [${timestamp}]`);
  console.log('━'.repeat(70));
  console.log(`📍 Метод:    ${method}`);
  console.log(`📍 Путь:     ${path}`);
  console.log(`💬 Сообщение: ${error.message || error}`);
  
  if (details) {
    console.log(`📦 Детали:`, JSON.stringify(details, null, 2));
  }
  
  if (error.stack) {
    console.log(`\n🔍 Стек:`);
    console.log(error.stack);
  }
  console.log('━'.repeat(70) + '\n');
}

/**
 * Форматирует и выводит информацию о базе данных
 */
function logDB(action, collection, details = null) {
  const timestamp = new Date().toLocaleTimeString('ru-RU');
  console.log(`\n💾 [${timestamp}] MongoDB: ${action} → ${collection}`);
  if (details) {
    console.log(`   📊 ${JSON.stringify(details)}`);
  }
}

/**
 * Форматирует и выводит предупреждение
 */
function logWarning(message, details = null) {
  const timestamp = new Date().toLocaleTimeString('ru-RU');
  console.log(`\n⚠️  [${timestamp}] ${message}`);
  if (details) {
    console.log(`   📦`, JSON.stringify(details, null, 2));
  }
}

/**
 * Выводит информацию в табличном виде
 */
function logTable(title, data) {
  console.log(`\n📊 ${title}:`);
  console.table(data);
}

module.exports = {
  logSuccess,
  logError,
  logDB,
  logWarning,
  logTable,
};
