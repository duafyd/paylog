// Pure, deterministic parser. Received time must be an explicit ISO instant.
export function normalizeSender(value) { return String(value ?? '').replace(/[\s()-]/g, ''); }
export function parseHana(body, receivedAt) {
  if (typeof body !== 'string' || body.length > 4096 || !/(Z|[+-]\d\d:\d\d)$/.test(receivedAt ?? '')) return null;
  const received = Date.parse(receivedAt);
  if (!Number.isFinite(received)) return null;
  const text = body.replace(/\r/g, '').trim();
  const card = text.match(/하나[\d*]{4,12}/)?.[0];
  const event = text.match(/(?:^|\n)(승인취소|취소|승인)(?:\s|$)/)?.[1] ?? text.match(/하나[\d*]{4,12}(승인취소|취소|승인)/)?.[1];
  const status = event === '승인' ? 'approved' : event ? 'cancelled' : null;
  if (!card || !status) return null;
  const clean = text.replace(/누적[^\n]*/g, '');
  const amountMatch = clean.match(/(?:금액\s*)?([\d,]+)원/);
  const amount = amountMatch ? Number(amountMatch[1].replaceAll(',', '')) : 0;
  const time = clean.match(/(\d{1,2})\/(\d{1,2})\s*(\d\d):(\d\d)/);
  let merchant = clean.match(/사용처\s+([^\n]+)/)?.[1]?.trim();
  if (!merchant && time) merchant = clean.slice(time.index + time[0].length).split('\n')[0].trim();
  if (!Number.isSafeInteger(amount) || amount <= 0 || amount > 999999999999 || !time || !merchant || merchant.length > 120) return null;
  const [, mo, da, hh, mm] = time.map(Number);
  if (mo < 1 || mo > 12 || da < 1 || hh > 23 || mm > 59) return null;
  const year = new Date(received + 9 * 3600000).getUTCFullYear();
  const candidates = [year - 1, year, year + 1].flatMap(y => {
    if (da > new Date(Date.UTC(y, mo, 0)).getUTCDate()) return [];
    const iso = `${y}-${String(mo).padStart(2,'0')}-${String(da).padStart(2,'0')}T${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}:00+09:00`;
    return [{iso, delta: Math.abs(Date.parse(iso) - received)}];
  }).sort((a,b) => a.delta - b.delta);
  // Delayed or ambiguous messages are reviewed instead of inventing a year.
  if (!candidates.length || candidates[0].delta > 7 * 86400000) return null;
  return {issuer:'하나카드', maskedIdentifier:card, status, amount, merchant, occurredAt:candidates[0].iso};
}
