import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {parseHana} from '../src/parser.js';
import {ingest} from '../src/ingest.js';
const detailed = '승인\n금액 13,200원\n카드 하나3*8*\n손님명 염*준\n거래종류 신용\n거래구분 일시불\n사용처 쿠팡이츠\n거래시간 10/10 20:14\n누적금액 1,724,480원';
const general = '[Web발신]\n하나3*8*승인 염*준\n8,800원 일시불 10/12\n18:31 (주)현대마트둔촌\n누적1,824,135원';
const now = Date.parse('2026-10-12T18:32:00+09:00');
const crypto = {hash:s=>createHash('sha256').update(s).digest('hex'),id:s=>'id-'+s};
const token = 'test-only-token-with-at-least-32-characters';
function fixture() {
  const rows=[], receipts=new Map(), reviews=[];
  const card = {id:'card',enabled:true,memberId:'member',maskedIdentifier:'하나3*8*',senderAllowlist:['test-sender']};
  const device = {id:'device',enabled:true,householdId:'home',memberId:'member',platform:'android',tokenHash:crypto.hash(token)};
  const store = {device:()=>device,allowRate:()=>true,cards:()=>[card],message:k=>receipts.get(k),transaction:id=>rows.find(t=>t.id===id),reviewExists:k=>reviews.some(r=>r.key===k),receipt:(k,bodyHash)=>receipts.set(k,{bodyHash}),review:r=>reviews.push(r),category:()=> 'food',append:r=>rows.push(r),originals:()=>rows.filter(t=>t.status==='approved'),cancel:(r,id)=>{r.status='cancelled';rows.push({...r,id,originalTransactionId:r.id});}};
  const input = {action:'sms.ingest',deviceId:'device',ingestToken:token,messageId:'sms-1',sender:'test-sender',receivedAt:'2026-10-12T18:31:30+09:00',body:general};
  return {store,input,rows,reviews,card,device};
}
test('two Hana formats extract transaction amount, never cumulative',()=>{
  assert.equal(parseHana(detailed,'2026-10-10T20:15:00+09:00').amount,13200);
  assert.equal(parseHana(general,'2026-10-12T18:32:00+09:00').amount,8800);
  assert.equal(parseHana(general,'2026-10-12T18:32:00+09:00').merchant,'(주)현대마트둔촌');
});
test('year boundary and impossible/ambiguous dates',()=>{
  const sms = general.replace('10/12','12/31');
  assert.match(parseHana(sms,'2027-01-01T00:05:00+09:00').occurredAt,/^2026-12-31/);
  assert.equal(parseHana(general.replace('10/12','02/30'),'2026-03-01T00:00:00+09:00'),null);
  assert.equal(parseHana(general,'2026-04-01T00:00:00+09:00'),null);
  assert.equal(parseHana('승인 하나3*8* 누적123,456원','2026-10-12T00:00:00+09:00'),null);
});
test('same message id deduplicates; separate same-value payments remain separate',()=>{
  const f=fixture(); assert.equal(ingest(f.input,f.store,crypto,now).code,'CREATED');
  assert.equal(ingest(f.input,f.store,crypto,now).code,'DUPLICATE');
  assert.equal(ingest({...f.input,messageId:'sms-2'},f.store,crypto,now).code,'CREATED');
  assert.equal(f.rows.length,2); assert.equal(JSON.stringify(f.rows).includes(f.input.body),false);
});
test('unknown sender/card ignored; masking collision reviewed',()=>{
  const f=fixture(); assert.equal(ingest({...f.input,sender:'stranger'},f.store,crypto,now).code,'IGNORED_CARD');
  f.card.maskedIdentifier='하나9*9*';assert.equal(ingest(f.input,f.store,crypto,now).code,'IGNORED_CARD');
  f.card.maskedIdentifier='하나3*8*';f.store.cards=()=>[f.card,{...f.card,id:'other'}];
  assert.equal(ingest({...f.input,messageId:'collision'},f.store,crypto,now).code,'REVIEW_REQUIRED'); assert.equal(f.rows.length,0);
});
test('missing/revoked token and rate limit reject before parsing',()=>{
 const f=fixture();assert.equal(ingest({...f.input,ingestToken:''},f.store,crypto,now).code,'UNAUTHORIZED');
 f.device.enabled=false;assert.equal(ingest(f.input,f.store,crypto,now).code,'UNAUTHORIZED');
 f.device.enabled=true;f.store.allowRate=()=>false;assert.equal(ingest(f.input,f.store,crypto,now).code,'RETRYABLE_ERROR');
});
test('cancellation links original, unmatched/ambiguous goes to review',()=>{
 const f=fixture();ingest(f.input,f.store,crypto,now);
 const cancel={...f.input,messageId:'cancel',body:general.replace('승인','취소')};
 assert.equal(ingest(cancel,f.store,crypto,now).code,'CREATED');assert.equal(f.rows.filter(t=>t.status==='approved').length,0);
 assert.equal(ingest(cancel,f.store,crypto,now).code,'DUPLICATE');
 const g=fixture();assert.equal(ingest(cancel,g.store,crypto,now).code,'REVIEW_REQUIRED');
});
test('missing message id and malformed messages are reviewed without raw body storage',()=>{
 const f=fixture();assert.equal(ingest({...f.input,messageId:undefined},f.store,crypto,now).code,'REVIEW_REQUIRED');
 assert.equal(JSON.stringify(f.reviews).includes(general),false);
 assert.equal(ingest({...f.input,body:'x'.repeat(4097)},f.store,crypto,now).code,'INVALID_FORMAT');
});
test('receipt failure after append is recoverable without a second financial write',()=>{
 const f=fixture();const receipt=f.store.receipt;f.store.receipt=()=>{throw Error('lost');};
 assert.throws(()=>ingest(f.input,f.store,crypto,now)); assert.equal(f.rows.length,1);
 f.store.receipt=receipt;assert.equal(ingest(f.input,f.store,crypto,now).code,'DUPLICATE');assert.equal(f.rows.length,1);
});

test('card mapping owns attribution; masking collisions across members require review',()=>{
 const f=fixture();f.card.memberId='another-family-member';
 assert.equal(ingest(f.input,f.store,crypto,now).code,'CREATED');assert.equal(f.rows[0].memberId,'another-family-member');
 const g=fixture();g.store.cards=()=>[g.card,{...g.card,id:'second-card',memberId:'another-family-member'}];
 assert.equal(ingest(g.input,g.store,crypto,now).code,'REVIEW_REQUIRED');assert.equal(g.rows.length,0);
});
