/* Apps Script runtime adapter. Never log request bodies, tokens, or SMS. */
const TABLE_HEADERS = {
  Cards:['id','householdId','issuer','senderAllowlist','maskedIdentifier','memberId','enabled','createdAt'],
  Categories:['id','householdId','name','icon','type','sortOrder','enabled'],
  Devices:['id','householdId','memberId','platform','tokenHash','enabled','lastSeenAt','createdAt'],
  Messages:['id','bodyHash','deviceId','code','receivedAt'],
  Review:['id','key','householdId','deviceId','reason','candidate','createdAt','resolvedAt','resolution'],
};
function sheetApi(path, method, body) {
  const id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!/^[A-Za-z0-9_-]{20,200}$/.test(id || '')) throw new Error('Configuration required');
  const result = UrlFetchApp.fetch('https://sheets.googleapis.com/v4/spreadsheets/' + id + path, {
    method:method || 'get', contentType:'application/json',
    headers:{Authorization:'Bearer ' + ScriptApp.getOAuthToken()},
    ...(body ? {payload:JSON.stringify(body)} : {}), muteHttpExceptions:true,
  });
  if (result.getResponseCode() < 200 || result.getResponseCode() >= 300) throw new Error('Sheet operation failed');
  return JSON.parse(result.getContentText());
}
function hashValue(value) {
  return Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, value, Utilities.Charset.UTF_8).map(b => ((b + 256) % 256).toString(16).padStart(2,'0')).join('');
}
function stableId(value) {
  const s = hashValue(value);
  return s.slice(0,8)+'-'+s.slice(8,12)+'-5'+s.slice(13,16)+'-a'+s.slice(17,20)+'-'+s.slice(20,32);
}
function table(name) {
  const rows = sheetApi('/values/' + name + '!A1:Z?valueRenderOption=UNFORMATTED_VALUE').values || [];
  const header = rows[0] || [];
  if (!header.length || (TABLE_HEADERS[name] && JSON.stringify(header) !== JSON.stringify(TABLE_HEADERS[name]))) throw new Error('Schema mismatch');
  return {header, rows: rows.slice(1).map((row,index) => ({...Object.fromEntries(header.map((h,i) => [h, row[i] ?? ''])), _row:index+2}))};
}
function appendRecord(name, header, record) {
  sheetApi('/values/' + name + '!A1:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS', 'post', {values:[header.map(h => record[h] ?? '')]});
}
function updateRecord(name, header, record) {
  sheetApi('/values:batchUpdate', 'post', {valueInputOption:'RAW', data:[{range:name+'!A'+record._row, values:[header.map(h => record[h] ?? '')]}]});
}
function enabled(value) { return String(value).toLowerCase() === 'true'; }
function makeStore() {
  const cached = {};
  const get = name => cached[name] || (cached[name] = table(name));
  return {
    device(id) {
      const matches = get('Devices').rows.filter(d => d.id === id);
      if (matches.length !== 1) return null;
      const d = matches[0];
      const members = get('Members').rows.filter(m => m.id === d.memberId && m.householdId === d.householdId && enabled(m.active));
      return {...d, enabled:enabled(d.enabled) && members.length === 1};
    },
    allowRate(id, now) {
      const cache = CacheService.getScriptCache(), key = 'rate:'+id+':'+Math.floor(now/60000);
      const count = Number(cache.get(key) || 0);
      if (count >= 30) return false;
      cache.put(key, String(count + 1), 120); return true;
    },
    cards(household) { return get('Cards').rows.filter(c => c.householdId === household && get('Members').rows.some(m => m.id === c.memberId && m.householdId === household && enabled(m.active))).map(c => ({...c, enabled:enabled(c.enabled), senderAllowlist:String(c.senderAllowlist).split(',').map(s => s.trim()).filter(Boolean)})); },
    message(key) { return get('Messages').rows.find(m => m.id === key); },
    transaction(id) { return get('Transactions').rows.find(t => t.id === id); },
    reviewExists(key) { return get('Review').rows.some(r => r.key === key); },
    receipt(key, bodyHash, deviceId, code, now) {
      appendRecord('Messages', TABLE_HEADERS.Messages, {id:key,bodyHash,deviceId,code,receivedAt:new Date(now).toISOString()});
      const d = get('Devices').rows.find(v => v.id === deviceId);
      updateRecord('Devices', TABLE_HEADERS.Devices, {...d,lastSeenAt:new Date(now).toISOString()});
    },
    review(record) { appendRecord('Review', TABLE_HEADERS.Review, {...record,candidate:JSON.stringify(record.candidate)}); },
    category(household, merchant) {
      const wanted = merchant.includes('쿠팡이츠') ? '식비' : merchant.includes('현대마트') ? '생활' : '기타';
      const matches = get('Categories').rows.filter(c => c.householdId === household && c.type === 'expense' && enabled(c.enabled) && c.name === wanted);
      return matches.length === 1 ? matches[0].id : null;
    },
    originals(household, cardId, parsed) {
      return get('Transactions').rows.filter(t => t.householdId === household && t.cardId === cardId && t.type === 'expense' && t.status === 'approved' && !t.deletedAt && Number(t.amount) === parsed.amount && t.merchant === parsed.merchant && Date.parse(t.occurredAt) <= Date.parse(parsed.occurredAt) && Date.parse(parsed.occurredAt) - Date.parse(t.occurredAt) <= 30*86400000);
    },
    recoverCancellation(marker) {
      if (!marker.originalTransactionId) return;
      const original = get('Transactions').rows.find(t => t.id === marker.originalTransactionId);
      if (!original) throw new Error('Original missing');
      updateRecord('Transactions', get('Transactions').header, {...original,status:'cancelled',updatedAt:marker.updatedAt,updatedBy:marker.updatedBy});
    },
    cancel(original, id, now, actor, source) {
      const header = get('Transactions').header;
      // Marker is durable first. A retry finds it by UUID and finishes the
      // original update, including when a response disappeared mid-operation.
      appendRecord('Transactions', header, {...original,id,status:'cancelled',originalTransactionId:original.id,createdAt:now,updatedAt:now,updatedBy:actor,source});
      updateRecord('Transactions', header, {...original,status:'cancelled',updatedAt:now,updatedBy:actor});
    },
    append(record) { appendRecord('Transactions', get('Transactions').header, record); },
  };
}
function doPost(event) {
  let result;
  const lock = LockService.getScriptLock();
  try {
    if (!event || !event.postData || event.postData.contents.length > 16384) result = {ok:false,code:'INVALID_FORMAT'};
    else if (!lock.tryLock(5000)) result = {ok:false,code:'RETRYABLE_ERROR'};
    else result = ingest(JSON.parse(event.postData.contents), makeStore(), {hash:hashValue,id:stableId});
  } catch (_) { result = {ok:false,code:'RETRYABLE_ERROR'}; }
  finally { if (lock.hasLock()) lock.releaseLock(); }
  return ContentService.createTextOutput(JSON.stringify(result)).setMimeType(ContentService.MimeType.JSON);
}
// Run once as sheet owner. Adds only missing auxiliary tabs; existing tabs are
// never overwritten. Tokens are registered as SHA-256 hashes in Devices manually.
function setupSmsTables() {
  const metadata = sheetApi('?fields=sheets(properties(title))');
  const names = metadata.sheets.map(s => s.properties.title);
  const missing = Object.keys(TABLE_HEADERS).filter(name => !names.includes(name));
  if (!missing.length) return;
  sheetApi(':batchUpdate', 'post', {requests:missing.map(name => ({addSheet:{properties:{title:name}}}))});
  sheetApi('/values:batchUpdate', 'post', {valueInputOption:'RAW',data:missing.map(name => ({range:name+'!A1',values:[TABLE_HEADERS[name]]}))});
}
