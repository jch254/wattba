import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { webcrypto } from 'node:crypto';
import { test } from 'node:test';
import { setTimeout } from 'node:timers';
import { URL } from 'node:url';
import { TextEncoder } from 'node:util';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';

const source = await readFile(
  new URL('../src/components/AccessGate.astro', import.meta.url),
  'utf8',
);
const duration = 24 * 60 * 60 * 1000;
const now = 1_800_000_000_000;
const fixtureCode = 'test-only-access-code';
const fixtureHash = Array.from(
  new Uint8Array(
    await webcrypto.subtle.digest(
      'SHA-256',
      new TextEncoder().encode(fixtureCode),
    ),
  ),
  (byte) => byte.toString(16).padStart(2, '0'),
).join('');
// Exercise the real gate with a test-only code, without needing the real code.
const script = ts.transpileModule(
  source
    .match(/<script>([\s\S]*?)<\/script>/)[1]
    .replace(
      /const PASSWORD_HASH =\s*'[^']+';/,
      `const PASSWORD_HASH = '${fixtureHash}';`,
    ),
  { compilerOptions: { target: ts.ScriptTarget.ES2022 } },
).outputText;
const key = `guide-unlocked-until:${fixtureHash}`;

function loadGate({ storage = new Map(), time = now, blocked = false } = {}) {
  const elements = new Map();
  for (const selector of [
    '.gate',
    '.g#guide',
    'pre',
    '.line',
    '.mask',
    'input',
    '.deny',
    '.grant',
  ]) {
    elements.set(selector, {
      style: {},
      value: '',
      textContent: '',
      classList: { add() {} },
      focus() {},
      blur() {},
      listeners: {},
      addEventListener(event, callback) {
        this.listeners[event] = callback;
      },
      querySelector(selector) {
        return elements.get(selector);
      },
    });
  }
  const localStorage = {
    getItem(key) {
      if (blocked) throw new Error('Storage blocked');
      return storage.get(key) ?? null;
    },
    setItem(key, value) {
      if (blocked) throw new Error('Storage blocked');
      storage.set(key, value);
    },
    removeItem(key) {
      if (blocked) throw new Error('Storage blocked');
      storage.delete(key);
    },
  };
  runInNewContext(script, {
    localStorage,
    document: { querySelector: (selector) => elements.get(selector) },
    window: {
      matchMedia: () => ({ matches: true }),
      setTimeout: (callback) => callback(),
    },
    Date: { now: () => time },
    TextEncoder,
    Uint8Array,
    crypto: webcrypto,
  });
  return {
    unlocked: () => elements.get('.g#guide').style.display === 'flex',
    async enter(code) {
      const input = elements.get('input');
      input.value = code;
      input.listeners.keydown({ key: 'Enter', preventDefault() {} });
      // Hashing completes asynchronously before the gate updates the DOM.
      for (let attempt = 0; attempt < 100; attempt += 1) {
        if (
          elements.get('.grant').style.display === 'block' ||
          elements.get('.deny').style.display === 'block'
        )
          return;
        await new Promise((resolve) => setTimeout(resolve, 5));
      }
      throw new Error('Gate did not finish checking the code');
    },
  };
}

test('valid entry is remembered across page loads for exactly 24 hours', async () => {
  const storage = new Map();
  const gate = loadGate({ storage });
  assert.equal(gate.unlocked(), false);
  await gate.enter(`  ${fixtureCode.toUpperCase()}  `);
  assert.equal(gate.unlocked(), true);
  assert.deepEqual([...storage], [[key, String(now + duration)]]);
  assert.equal(
    loadGate({ storage, time: now + duration - 1 }).unlocked(),
    true,
  );
  assert.equal(
    storage.get(key),
    String(now + duration),
    'visits must not extend expiry',
  );
  assert.equal(loadGate({ storage, time: now + duration }).unlocked(), false);
  assert.equal(storage.has(key), false);
});

test('invalid codes never create a remembered unlock', async () => {
  const storage = new Map();
  const gate = loadGate({ storage });
  await gate.enter('wrong-test-code');
  assert.equal(gate.unlocked(), false);
  assert.equal(storage.size, 0);
});

test('missing, expired, malformed and implausible expiries do not unlock', () => {
  for (const value of [
    '',
    'true',
    'NaN',
    'Infinity',
    '1.5',
    String(now - 1),
    String(now + duration + 1),
  ]) {
    const storage = new Map([[key, value]]);
    assert.equal(loadGate({ storage }).unlocked(), false, value);
    assert.equal(storage.has(key), false);
  }
  assert.equal(loadGate().unlocked(), false);
});

test('an unlock for a previous access code is ignored', () => {
  const storage = new Map([
    ['guide-unlocked-until:old-hash', String(now + duration)],
  ]);
  assert.equal(loadGate({ storage }).unlocked(), false);
});

test('blocked storage still allows a valid code on the current page only', async () => {
  const gate = loadGate({ blocked: true });
  assert.equal(gate.unlocked(), false);
  await gate.enter(fixtureCode);
  assert.equal(gate.unlocked(), true);
  assert.equal(loadGate({ blocked: true }).unlocked(), false);
});
