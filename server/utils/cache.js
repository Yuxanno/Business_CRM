/**
 * Lightweight in-memory TTL cache for single-instance Node backend.
 * Eliminates redundant MongoDB round-trips on auth & repeated dashboard/list reads.
 */
class TtlCache {
  constructor({ defaultTtlMs = 30000, maxEntries = 1000 } = {}) {
    this.defaultTtlMs = defaultTtlMs;
    this.maxEntries = maxEntries;
    this.store = new Map();
  }

  get(key) {
    const entry = this.store.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.store.delete(key);
      return null;
    }
    return entry.value;
  }

  set(key, value, ttlMs = this.defaultTtlMs) {
    if (this.store.size >= this.maxEntries) {
      // Evict oldest entry (Map preserves insertion order)
      const firstKey = this.store.keys().next().value;
      if (firstKey !== undefined) this.store.delete(firstKey);
    }
    this.store.set(key, {
      value,
      expiresAt: Date.now() + ttlMs,
    });
  }

  delete(key) {
    this.store.delete(key);
  }

  deleteByPrefix(prefix) {
    for (const key of this.store.keys()) {
      if (key.startsWith(prefix)) {
        this.store.delete(key);
      }
    }
  }
}

// User profile cache for auth middleware (60s TTL)
const userCache = new TtlCache({ defaultTtlMs: 60000, maxEntries: 500 });

// Per-user data cache for dashboard & summary responses (30s TTL)
const dataCache = new TtlCache({ defaultTtlMs: 30000, maxEntries: 1000 });

function invalidateUserDataCache(userId) {
  if (!userId) return;
  dataCache.deleteByPrefix(`u:${String(userId)}:`);
}

function invalidateUserAuthCache(userId) {
  if (!userId) return;
  userCache.delete(String(userId));
}

module.exports = {
  userCache,
  dataCache,
  invalidateUserDataCache,
  invalidateUserAuthCache,
};

