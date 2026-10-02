const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const CoffeeScript = require('coffee-script');
const source = CoffeeScript.compile(fs.readFileSync(
  require.resolve('../src/coffee/log_error.coffee'), 'utf8'));

function load(storage, getStorage) {
  const context = { window: {}, console };
  Object.defineProperty(context, 'localStorage', {
    get: getStorage || (() => storage)
  });
  vm.runInNewContext(source, context);
  return context.window.onerror;
}

test('startup trims a full legacy log and preserves other state', () => {
  const storage = { log: 'x'.repeat(5 * 1024 * 1024),
    'omega.local.availableProfiles': '{"+direct":{}}' };
  load(storage);
  assert.equal(storage.log.length, 64 * 1024);
  assert.equal(storage['omega.local.availableProfiles'], '{"+direct":{}}');
});

test('repeated and oversized errors stay bounded and retain the latest message', () => {
  const storage = {};
  const onerror = load(storage);
  for (let i = 0; i < 2000; i++) {
    onerror('error ' + i, 'extension.js', 1, 2, { stack: 'stack'.repeat(30) });
  }
  assert.ok(storage.log.length <= 64 * 1024);
  assert.ok(storage.log.includes('error 1999'));
  assert.ok(storage.log.includes('extension.js:1:2:'));
  onerror('large error', 'extension.js', 1, 2, { stack: 'x'.repeat(100000) + 'END' });
  assert.equal(storage.log.length, 64 * 1024);
  assert.ok(storage.log.includes('END'));
});

test('quota failure retries with just the latest error', () => {
  let log = 'x'.repeat(900);
  const storage = {};
  Object.defineProperty(storage, 'log', {
    get: () => log,
    set: value => {
      if (value.length > 900) throw new Error('QuotaExceededError');
      log = value;
    }
  });
  const onerror = load(storage);
  assert.doesNotThrow(() => onerror('latest', 'extension.js', 1, 2));
  assert.ok(log.includes('latest'));
  assert.ok(log.length < 900);
});

test('unavailable storage and failed retries do not throw from the handler', () => {
  const blocked = load(null, () => { throw new Error('SecurityError'); });
  assert.doesNotThrow(() => blocked('error', 'extension.js', 1, 2));
  const storage = {};
  Object.defineProperty(storage, 'log', {
    get: () => '',
    set: () => { throw new Error('QuotaExceededError'); }
  });
  const onerror = load(storage);
  assert.doesNotThrow(() => onerror('error', 'extension.js', 1, 2));
  assert.doesNotThrow(() => load(undefined)('error', 'extension.js', 1, 2));
});
