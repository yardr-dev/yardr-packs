// Mail to the yard's hook: each message sent to yardmaster@yardr.dev is
// parsed with postal-mime and posted to the hook as one JSON object,
// signed with the hook's secret. The Worker reads nothing of the yard:
// it knows only the hook's address and secret, as env YARD_HOOK_URL and
// EMAIL_HOOK_SECRET. The yard cannot reach Cloudflare; this Worker is
// the operator's to deploy (SETUP.md).
//
// A message over 1 MiB raw is rejected, never posted: the yard refuses
// bodies over its own bound, and postage is wasted on one. Anything else
// is posted, whatever its authentication results say: the email()
// runtime API (Cloudflare's docs, 15 Oct 2026) exposes no SPF/DKIM/DMARC
// verdict property, and the only documented carrier, the
// ARC-Authentication-Results header Cloudflare adds when it forwards,
// is undocumented on the Worker path and unverifiable without an ARC
// chain check, so the Worker does not reject on it (README.md).
//
// A non-2xx answer throws, so the sending MTA retries later; a reject
// (setReject) answers 5xx, and the message is refused for good.
import PostalMime from 'postal-mime';

// Above this many raw bytes the message is rejected, never posted.
const MAX_RAW_BYTES = 1024 * 1024;
// Above this many characters the text is cut.
const MAX_TEXT_CHARS = 64 * 1024;

export default {
  async email(message, env, ctx) {
    if (message.rawSize > MAX_RAW_BYTES) {
      message.setReject('Message over 1 MiB');
      return;
    }
    const raw = new Uint8Array(await new Response(message.raw).arrayBuffer());
    const mail = await PostalMime.parse(raw);
    const body = toHookBody(mail, message);
    // The signature covers the exact bytes sent, hex with no prefix.
    const bytes = new TextEncoder().encode(JSON.stringify(body));
    const hookURL = new URL(env.YARD_HOOK_URL);
    if (hookURL.protocol !== 'https:') {
      throw new Error('YARD_HOOK_URL must use HTTPS');
    }
    const res = await fetch(env.YARD_HOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Email-Signature': await hmacHex(env.EMAIL_HOOK_SECRET, bytes),
        'X-Email-Delivery': body.message_id,
      },
      body: bytes,
    });
    if (!res.ok) {
      throw new Error(`yard hook answered ${res.status}`);
    }
  },
};

// The hook's body: what email.yaml's normalize reads. Attachments are
// listed, never carried: names, sizes and types cross; the bytes stay
// in the mail.
function toHookBody(mail, message) {
  const from = mailbox(mail.from);
  const to = addresses(mail.to);
  return {
    message_id: mail.messageId ?? '',
    from: {
      address: from.address || message.from || '',
      name: from.name,
    },
    to: to.length > 0 ? to : message.to ? [message.to] : [],
    subject: mail.subject ?? '',
    date: mail.date ?? '',
    in_reply_to: mail.inReplyTo ?? '',
    references: (mail.references ?? '').split(/\s+/).filter((id) => id !== ''),
    text: (mail.text || stripHtml(mail.html || '')).slice(0, MAX_TEXT_CHARS),
    attachments: mail.attachments.map((a) => ({
      name: a.filename ?? '',
      size: contentBytes(a.content),
      type: a.mimeType ?? '',
    })),
  };
}

// One address: a mailbox, or the first member of a group.
function mailbox(addr) {
  if (!addr) {
    return { address: '', name: '' };
  }
  if (addr.group) {
    return mailbox(addr.group[0]);
  }
  return { address: addr.address ?? '', name: addr.name ?? '' };
}

// An address list, flattened: groups contribute their members.
function addresses(list) {
  const out = [];
  for (const addr of list ?? []) {
    if (addr.group) {
      for (const member of addr.group) {
        if (member.address) {
          out.push(member.address);
        }
      }
    } else if (addr.address) {
      out.push(addr.address);
    }
  }
  return out;
}

function contentBytes(content) {
  if (typeof content === 'string') {
    return new TextEncoder().encode(content).byteLength;
  }
  return content?.byteLength ?? 0;
}

// HTML stripped to text: scripts and styles dropped whole, tags cut to
// spaces, entities decoded where they are the common ones, whitespace
// collapsed. The yard collapses again; this is only so the text reads.
function stripHtml(html) {
  return html
    .replace(/<script[\s\S]*?<\/script\s*>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style\s*>/gi, ' ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&(#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]+);/g, decodeEntity)
    .replace(/\s+/g, ' ')
    .trim();
}

const ENTITIES = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: '\u00a0',
};

function decodeEntity(match, ref) {
  if (ref[0] === '#') {
    const code =
      ref[1] === 'x' || ref[1] === 'X'
        ? parseInt(ref.slice(2), 16)
        : parseInt(ref.slice(1), 10);
    if (Number.isSafeInteger(code) && code > 0 && code <= 0x10ffff) {
      return String.fromCodePoint(code);
    }
    return match;
  }
  return ENTITIES[ref] ?? match;
}

async function hmacHex(secret, bytes) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, bytes));
  return [...sig].map((b) => b.toString(16).padStart(2, '0')).join('');
}
