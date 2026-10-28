import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
const path = new URL('../gas/Code.gs',import.meta.url);
test('generated GAS artifact matches reviewed modules',()=>{
 const before=readFileSync(path,'utf8');execFileSync(process.execPath,[new URL('../build.mjs',import.meta.url).pathname]);assert.equal(readFileSync(path,'utf8'),before);
});
function gas() {
 const tables={};const requests=[];let failureAfterAppend=false;
 const context=vm.createContext({
  PropertiesService:{getScriptProperties:()=>({getProperty:()=> 'testSpreadsheetIdentifier1234567890'})},
  ScriptApp:{getOAuthToken:()=> 'gas-test-owner-token'},
  Utilities:{DigestAlgorithm:{SHA_256:'sha256'},Charset:{UTF_8:'utf8'},computeDigest:(_,s)=>Array.from(createHash('sha256').update(s).digest())},
  CacheService:{getScriptCache:()=>({get:()=>null,put:()=>{}})},
  LockService:{getScriptLock:()=>({tryLock:()=>true,hasLock:()=>true,releaseLock:()=>{}})},
  ContentService:{MimeType:{JSON:'json'},createTextOutput:text=>({setMimeType:()=>JSON.parse(text)})},
  UrlFetchApp:{fetch:(url,options)=>{
    assert.equal(options.headers.Authorization,'Bearer gas-test-owner-token');requests.push({url,options});
    const parsed=new URL(url);const suffix=decodeURIComponent(parsed.pathname.split('/v4/spreadsheets/testSpreadsheetIdentifier1234567890')[1]);
    let body={};
    if(suffix.includes('/values/') && options.method==='get') {const name=suffix.split('/values/')[1].split('!')[0];body={values:tables[name]};}
    else if(suffix.endsWith(':append')) {assert.equal(parsed.searchParams.get('valueInputOption'),'RAW');const name=suffix.split('/values/')[1].split('!')[0];tables[name].push(JSON.parse(options.payload).values[0]);if(failureAfterAppend && name==='Transactions'){failureAfterAppend=false;throw Error('after durable write');}}
    else if(suffix==='/values:batchUpdate') {const payload=JSON.parse(options.payload);assert.equal(payload.valueInputOption,'RAW');for(const d of payload.data){const [_,name,index]=d.range.match(/^(\w+)!A(\d+)/);tables[name][Number(index)-1]=d.values[0];}}
    else throw Error('unexpected '+suffix);
    return {getResponseCode:()=>200,getContentText:()=>JSON.stringify(body)};
  }},
 });
 vm.runInContext(readFileSync(path,'utf8'),context);
 const headers=JSON.parse(vm.runInContext('JSON.stringify(TABLE_HEADERS)',context));
 for(const [name,header] of Object.entries(headers)) tables[name]=[header];
 tables.Members=[['id','householdId','active'],['member','home',true]];
 tables.Transactions=[['id','householdId','type','amount','occurredAt','merchant','memo','categoryId','memberId','cardId','source','status','fingerprint','originalTransactionId','createdAt','updatedAt','updatedBy','deletedAt','paymentMethod']];
 const token='local-test-only-token-with-32-characters';
 tables.Devices.push(['device','home','member','android',createHash('sha256').update(token).digest('hex'),true,'','2026-01-01T00:00:00Z']);
 tables.Cards.push(['card','home','하나카드','test-sender','하나3*8*','member',true,'2026-01-01T00:00:00Z']);
 tables.Categories.push(['category','home','생활','groceries','expense',0,true]);
 const receivedAt=new Date().toISOString();const local=new Date(Date.now()+9*3600000);
 const date=`${local.getUTCMonth()+1}/${local.getUTCDate()} ${String(local.getUTCHours()).padStart(2,'0')}:${String(local.getUTCMinutes()).padStart(2,'0')}`;
 const input={action:'sms.ingest',deviceId:'device',ingestToken:token,messageId:'one',sender:'test-sender',receivedAt,body:`[Web발신]\n하나3*8*승인 염*준\n8,800원 일시불 ${date} (주)현대마트둔촌\n누적1,824,135원`};
 return {tables,requests,input,post:payload=>context.doPost({postData:{contents:JSON.stringify(payload)}}),lose:()=>{failureAfterAppend=true;}};
}
test('GAS wrapper authenticates, writes RAW once, deduplicates, revokes',()=>{
 const f=gas();assert.equal(f.post({...f.input,ingestToken:'wrong-token-with-at-least-32-characters'}).code,'UNAUTHORIZED');
 assert.equal(f.post(f.input).code,'CREATED');assert.equal(f.post(f.input).code,'DUPLICATE');assert.equal(f.tables.Transactions.length,2);
 f.tables.Devices[1][5]=false;assert.equal(f.post({...f.input,messageId:'two'}).code,'UNAUTHORIZED');
 assert.equal(JSON.stringify([f.tables.Messages,f.tables.Review]).includes(f.input.body),false);
});
test('GAS recovers response loss during transaction and cancellation append',()=>{
 const f=gas();f.lose();assert.equal(f.post(f.input).code,'RETRYABLE_ERROR');assert.equal(f.post(f.input).code,'DUPLICATE');assert.equal(f.tables.Transactions.length,2);
 const cancel={...f.input,messageId:'cancel',body:f.input.body.replace('승인','취소')};f.lose();assert.equal(f.post(cancel).code,'RETRYABLE_ERROR');
 assert.equal(f.tables.Transactions[1][11],'approved');assert.equal(f.post(cancel).code,'DUPLICATE');
 assert.equal(f.tables.Transactions[1][11],'cancelled');assert.equal(f.tables.Transactions.length,3);
});
test('zero web sessions: Android and iPhone approvals persist directly; cross-device duplicate is reviewed',()=>{
 const f=gas();
 assert.equal(f.post(f.input).code,'CREATED');
 const token='local-test-ios-token-with-at-least-32-characters';
 f.tables.Devices.push(['iphone','home','member','ios',createHash('sha256').update(token).digest('hex'),true,'','']);
 const ios={...f.input,deviceId:'iphone',ingestToken:token,messageId:'ios-execution-one'};
 assert.equal(f.post(ios).code,'REVIEW_REQUIRED');
 assert.equal(f.tables.Transactions.length,2);
 assert.equal(f.tables.Review[1][4],'POSSIBLE_DUPLICATE');
 const second={...ios,messageId:'ios-execution-two',body:ios.body.replace('8,800원','9,900원')};
 assert.equal(f.post(second).code,'CREATED');
 assert.equal(f.tables.Transactions.length,3);
 assert.equal(f.tables.Transactions[2][10],'ios_shortcut');
 assert.equal(f.post(second).code,'DUPLICATE');
 assert.equal(f.tables.Transactions.length,3);
 // Deleting a row must not make an old retry a new expense.
 f.tables.Transactions[2][17]=new Date().toISOString();
 assert.equal(f.post(second).code,'DUPLICATE');
 assert.equal(f.tables.Transactions.length,3);
});
