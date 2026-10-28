import {normalizeSender, parseHana} from './parser.js';
export function constantEqual(a, b) {
  a = String(a); b = String(b);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length,b.length); i++) diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  return diff === 0;
}
const response = (code) => ({ok:['CREATED','DUPLICATE','IGNORED_CARD','REVIEW_REQUIRED'].includes(code), code});
// Store serializes callers, persists dedup keys, and uses RAW sheet writes.
// No raw SMS or bearer token is passed to durable store operations.
export function ingest(input, store, crypto, now = Date.now()) {
  if (!input || input.action !== 'sms.ingest' || typeof input.deviceId !== 'string' || typeof input.ingestToken !== 'string' || input.ingestToken.length < 32 || input.ingestToken.length > 256) return response('UNAUTHORIZED');
  const device = store.device(input.deviceId);
  if (!device || !device.enabled || !constantEqual(crypto.hash(input.ingestToken), device.tokenHash)) return response('UNAUTHORIZED');
  if (!store.allowRate(device.id, now)) return response('RETRYABLE_ERROR');
  if (typeof input.body !== 'string' || input.body.length > 4096 || input.body.length === 0 || typeof input.sender !== 'string' || input.sender.length > 40 || !Number.isFinite(Date.parse(input.receivedAt)) || Math.abs(now - Date.parse(input.receivedAt)) > 7 * 86400000 || (input.messageId != null && (typeof input.messageId !== 'string' || input.messageId.length > 160))) return response('INVALID_FORMAT');
  const sender = normalizeSender(input.sender);
  const bodyHash = crypto.hash(input.body);
  const hasId = !!input.messageId;
  const key = crypto.hash(`${device.id}|${hasId ? input.messageId : bodyHash + '|' + input.receivedAt}`);
  const previous = store.message(key);
  if (previous) return previous.bodyHash === bodyHash ? response('DUPLICATE') : response('INVALID_FORMAT');
  // Stable UUID per ingest key permits recovery after append succeeded but receipt failed.
  const transactionId = crypto.id(key);
  if (store.transaction(transactionId)) { store.recoverCancellation?.(store.transaction(transactionId)); store.receipt(key, bodyHash, device.id, 'CREATED', now); return response('DUPLICATE'); }
  if (store.reviewExists(key)) { store.receipt(key, bodyHash, device.id, 'REVIEW_REQUIRED', now); return response('DUPLICATE'); }
  const parsed = parseHana(input.body, input.receivedAt);
  const permitted = store.cards(device.householdId).filter(c => c.enabled && c.senderAllowlist.map(normalizeSender).includes(sender));
  if (!permitted.length) return response('IGNORED_CARD');
  function finish(code) { store.receipt(key, bodyHash, device.id, code, now); return response(code); }
  function review(reason, candidate = parsed) {
    store.review({id:crypto.id('review|' + key), key, householdId:device.householdId, deviceId:device.id, reason, candidate, createdAt:new Date(now).toISOString()});
    return finish('REVIEW_REQUIRED');
  }
  if (!parsed) return review('UNPARSEABLE', null);
  const cards = permitted.filter(c => c.maskedIdentifier === parsed.maskedIdentifier);
  if (!cards.length) return finish('IGNORED_CARD');
  if (cards.length !== 1) return review('AMBIGUOUS_CARD');
  if (!hasId) return review('MISSING_MESSAGE_ID');
  const card = cards[0];
  if (parsed.status === 'cancelled') {
    const originals = store.originals(device.householdId, card.id, parsed);
    if (originals.length !== 1) return review('CANCELLATION_UNMATCHED');
    store.cancel(originals[0], transactionId, new Date(now).toISOString(), device.id, device.platform === 'android' ? 'android_sms' : 'ios_shortcut');
    return finish('CREATED');
  }
  const fingerprint = crypto.hash([sender,card.id,parsed.amount,parsed.merchant.trim().replace(/\s+/g,' '),parsed.occurredAt,parsed.status].join('|'));
  // A new Shortcut execution has a new UUID. Same card/minute/merchant may
  // also be a real second purchase, so retain it for review rather than drop it.
  if (store.approvalExists(device.householdId, fingerprint)) return review('POSSIBLE_DUPLICATE');
  const categoryId = store.category(device.householdId, parsed.merchant);
  if (!categoryId) return review('MISSING_CATEGORY');
  store.append({id:transactionId, householdId:device.householdId, type:'expense', amount:parsed.amount, occurredAt:parsed.occurredAt, merchant:parsed.merchant, memo:'', categoryId, memberId:card.memberId, cardId:card.id, source:device.platform === 'android' ? 'android_sms' : 'ios_shortcut', status:'approved', fingerprint, originalTransactionId:'', createdAt:new Date(now).toISOString(), updatedAt:new Date(now).toISOString(), updatedBy:device.id, deletedAt:'', paymentMethod:'카드'});
  return finish('CREATED');
}
