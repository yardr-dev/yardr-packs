// The Worker's tests: node --test, no network. fetch is a stand-in that
// captures the request and answers 200; the signature is checked with
// node:crypto, not with the Worker's own crypto.subtle.
import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import handler from './worker.js';

// Node 18 exposes WebCrypto behind a flag; Cloudflare Workers expose it globally.
globalThis.crypto ??= webcrypto;

const dir = join(dirname(fileURLToPath(import.meta.url)), 'testdata');
const eml = (name) => readFileSync(join(dir, name));

const env = {
  EMAIL_HOOK_SECRET: 'test-secret',
  YARD_HOOK_URL: 'https://hooks.example.test/cloudflare-email',
};

// A ForwardableEmailMessage stand-in: the fields the Worker reads.
function message(raw, { from = 'sender@example.com', to = 'yardmaster@yardr.dev' } = {}) {
  const bytes = typeof raw === 'string' ? new TextEncoder().encode(raw) : raw;
  return {
    from,
    to,
    headers: new Headers(),
    raw: new ReadableStream({
      start(c) {
        c.enqueue(bytes);
        c.close();
      },
    }),
    rawSize: bytes.byteLength,
    rejected: null,
    setReject(reason) {
      this.rejected = reason;
    },
  };
}

let posted;
let status;

beforeEach(() => {
  posted = null;
  status = 200;
  globalThis.fetch = async (url, opts) => {
    posted = { url, headers: opts.headers, body: Buffer.from(opts.body) };
    return { ok: status >= 200 && status < 300, status };
  };
});

afterEach(() => {
  delete globalThis.fetch;
});

function signatureOf(secret, bytes) {
  return createHmac('sha256', secret).update(bytes).digest('hex');
}

describe('email', () => {
  it('posts the plain message, signed with the exact bytes sent', async () => {
    await assert.rejects(
      handler.email(message(eml('plain.eml')), {
        ...env,
        YARD_HOOK_URL: 'http://hooks.example.test/cloudflare-email',
      }, {}),
      /YARD_HOOK_URL must use HTTPS/,
    );
    assert.equal(posted, null);

    const msg = message(eml('plain.eml'));
    await handler.email(msg, env, {});

    assert.equal(msg.rejected, null);
    assert.equal(posted.url, env.YARD_HOOK_URL);
    assert.equal(posted.headers['Content-Type'], 'application/json');
    assert.equal(posted.headers['X-Email-Delivery'], '<plain-1@example.com>');
    assert.equal(posted.headers['X-Email-Signature'], signatureOf(env.EMAIL_HOOK_SECRET, posted.body));
    assert.deepEqual(JSON.parse(posted.body.toString()), {
      message_id: '<plain-1@example.com>',
      from: { address: 'ada@example.com', name: 'Ada' },
      to: ['yardmaster@yardr.dev'],
      subject: 'Can the shed land on Monday?',
      date: '2026-10-25T09:15:00.000Z',
      in_reply_to: '',
      references: [],
      text: 'Hi,\n\nCan the shed land on Monday?\n\n',
      attachments: [{ name: 'shed.txt', size: 5, type: 'text/plain' }],
    });
  });

  it('strips an html-only message to text', async () => {
    const msg = message(eml('html.eml'));
    await handler.email(msg, env, {});

    const body = JSON.parse(posted.body.toString());
    assert.equal(body.from.address, 'reports@example.com');
    assert.equal(body.from.name, '');
    assert.equal(body.text, 'Shed The roof holds & the door swings free.');
    assert.deepEqual(body.attachments, []);
  });

  it('keeps the reply chain', async () => {
    const msg = message(eml('reply.eml'));
    await handler.email(msg, env, {});

    const body = JSON.parse(posted.body.toString());
    assert.equal(body.message_id, '<reply-3@example.com>');
    assert.equal(body.in_reply_to, '<mid-7@example.com>');
    assert.deepEqual(body.references, ['<root-9@example.com>', '<mid-7@example.com>']);
  });

  it('rejects a message over 1 MiB raw, and posts nothing', async () => {
    const msg = message(eml('plain.eml'));
    msg.rawSize = 1024 * 1024 + 1;
    await handler.email(msg, env, {});

    assert.equal(msg.rejected, 'Message over 1 MiB');
    assert.equal(posted, null);
  });

  it('throws on a non-2xx answer, so the MTA retries', async () => {
    status = 503;
    const msg = message(eml('plain.eml'));
    await assert.rejects(handler.email(msg, env, {}), /yard hook answered 503/);
    assert.notEqual(posted, null);
  });

  it('cuts the text at 64 KB', async () => {
    const long = 'x'.repeat(70 * 1024);
    const msg = message(
      'From: a@example.com\nTo: yardmaster@yardr.dev\nSubject: long\nMessage-ID: <long@example.com>\nContent-Type: text/plain\n\n' + long + '\n',
    );
    await handler.email(msg, env, {});

    const body = JSON.parse(posted.body.toString());
    assert.equal(body.text.length, 64 * 1024);
  });

  it('falls back to the envelope where headers are missing', async () => {
    const msg = message('Subject: no addresses\n\nbare\n', {
      from: 'envelope-from@example.com',
      to: 'envelope-to@example.com',
    });
    await handler.email(msg, env, {});

    const body = JSON.parse(posted.body.toString());
    assert.equal(body.from.address, 'envelope-from@example.com');
    assert.deepEqual(body.to, ['envelope-to@example.com']);
  });
});
