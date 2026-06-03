import test from 'node:test';
import assert from 'node:assert/strict';
import {
  EMAIL_SEND_LIMIT_PER_HOUR,
  VERIFY_EMAIL_LIMIT_PER_WINDOW,
  VERIFY_IP_LIMIT_PER_WINDOW,
  enforceSendLimits,
  enforceVerifyLimits,
  emailKey,
  requireKv,
} from '../src/rate-limit.js';

class MemoryKv {
  constructor() {
    this.values = new Map();
    this.putOptions = new Map();
  }

  async get(key) {
    return this.values.has(key) ? this.values.get(key) : null;
  }

  async put(key, value, options = {}) {
    this.values.set(key, value);
    this.putOptions.set(key, options);
  }
}

test('emailKey is HMAC based and does not expose raw email', async () => {
  const key = await emailKey(
    { EMAIL_KEY_SECRET: 'test-secret' },
    'user@example.com',
  );

  assert.match(key, /^[a-f0-9]{64}$/);
  assert.equal(key.includes('user@example.com'), false);
});

test('requireKv fails clearly when binding is missing', () => {
  assert.throws(() => requireKv({}), /Missing PASSWORD_RESET_KV binding/);
});

test('enforceSendLimits blocks after email send limit', async () => {
  const kv = new MemoryKv();
  const env = {
    PASSWORD_RESET_KV: kv,
    EMAIL_KEY_SECRET: 'test-secret',
  };

  for (let i = 0; i < EMAIL_SEND_LIMIT_PER_HOUR; i++) {
    await enforceSendLimits(env, 'user@example.com', '127.0.0.1');
  }

  await assert.rejects(
    () => enforceSendLimits(env, 'user@example.com', '127.0.0.2'),
    (error) => error.status === 429 && /Email send limit/.test(error.message),
  );
});

test('enforceSendLimits starts a fresh window for legacy stuck counters', async () => {
  const kv = new MemoryKv();
  const env = {
    PASSWORD_RESET_KV: kv,
    EMAIL_KEY_SECRET: 'test-secret',
  };
  const emailHash = await emailKey(env, 'user@example.com');

  kv.values.set(`rl:email:${emailHash}`, String(EMAIL_SEND_LIMIT_PER_HOUR + 20));

  await enforceSendLimits(env, 'user@example.com', '127.0.0.1');

  const stored = JSON.parse(kv.values.get(`rl:email:${emailHash}`));
  assert.equal(stored.count, 1);
  assert.equal(kv.putOptions.get(`rl:email:${emailHash}`).expirationTtl > 0, true);
});

test('enforceVerifyLimits blocks repeated verify attempts per email', async () => {
  const kv = new MemoryKv();
  const env = {
    PASSWORD_RESET_KV: kv,
    EMAIL_KEY_SECRET: 'test-secret',
  };

  for (let i = 0; i < VERIFY_EMAIL_LIMIT_PER_WINDOW; i++) {
    await enforceVerifyLimits(env, 'user@example.com', `127.0.0.${i}`, 'verify');
  }

  await assert.rejects(
    () => enforceVerifyLimits(env, 'user@example.com', '127.0.0.200', 'verify'),
    (error) => error.status === 429 && /Verify limit/.test(error.message),
  );

  for (const key of kv.values.keys()) {
    assert.equal(key.includes('user@example.com'), false);
  }
});

test('enforceVerifyLimits blocks repeated verify attempts per IP', async () => {
  const kv = new MemoryKv();
  const env = {
    PASSWORD_RESET_KV: kv,
    EMAIL_KEY_SECRET: 'test-secret',
  };

  for (let i = 0; i < VERIFY_IP_LIMIT_PER_WINDOW; i++) {
    await enforceVerifyLimits(env, `user-${i}@example.com`, '127.0.0.1', 'confirm');
  }

  await assert.rejects(
    () => enforceVerifyLimits(env, 'overflow@example.com', '127.0.0.1', 'confirm'),
    (error) => error.status === 429 && /Verify IP limit/.test(error.message),
  );
});
