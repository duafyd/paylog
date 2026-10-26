const {readFileSync}=require('node:fs');
const {before,beforeEach,after,test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeTestEnvironment,assertFails,assertSucceeds}=require('@firebase/rules-unit-testing');
const {doc,writeBatch,setDoc,getDoc,getDocs,collection,query,limit,updateDoc,deleteDoc,serverTimestamp,Timestamp}=require('firebase/firestore');
assert.match(process.env.FIRESTORE_EMULATOR_HOST||'',/^(127\.0\.0\.1|localhost):\d+$/,'Tests require a local emulator; production fallback is forbidden');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-paylog',firestore:{rules:readFileSync('firestore.rules','utf8')}})});
beforeEach(async()=>env.clearFirestore());
after(async()=>env?.cleanup());
function db(uid,provider='password'){return env.authenticatedContext(uid,{email:uid+'@accounts.paylog.invalid',firebase:{sign_in_provider:provider}}).firestore()}
async function create(store,uid,hid){const b=writeBatch(store);b.set(doc(store,'households',hid),{name:'함께 쓰는 가계부',ownerId:uid,createdAt:serverTimestamp()});b.set(doc(store,'households',hid,'members',uid),{uid,username:uid,role:'owner',inviteHash:'',createdAt:serverTimestamp()});b.set(doc(store,'profiles',uid),{householdId:hid,username:uid,createdAt:serverTimestamp()});return b.commit()}
async function invite(store,uid,hid,hash='a'.repeat(64),hours=24){return setDoc(doc(store,'invites',hash),{householdId:hid,createdBy:uid,createdAt:serverTimestamp(),expiresAt:Timestamp.fromMillis(Date.now()+hours*3600000)})}
async function join(store,uid,hid,hash='a'.repeat(64),role='member'){const b=writeBatch(store);b.set(doc(store,'households',hid,'members',uid),{uid,username:uid,role,inviteHash:hash,createdAt:serverTimestamp()});b.set(doc(store,'profiles',uid),{householdId:hid,username:uid,createdAt:serverTimestamp()});return b.commit()}
function transaction(uid,version=1){return {type:'expense',amount:12000,occurredAt:Timestamp.now(),merchant:'식료품점',memo:'',categoryId:'groceries',memberId:uid,memberName:uid,paymentMethod:'카드',version,createdBy:uid,updatedBy:uid,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),deletedAt:null}}

test('owner bootstrap is atomic; missing member/profile and wrong identity are denied',async()=>{
 const owner=db('owner');await assertFails(setDoc(doc(owner,'households','orphan'),{name:'가계부',ownerId:'owner',createdAt:serverTimestamp()}));
 await assertSucceeds(create(owner,'owner','family'));
 await assertFails(create(owner,'owner','second'));
 await assertFails(create(db('other'),'owner','stolen'));
 await assertFails(create(db('googleuser','google.com'),'googleuser','google-home'));
});
test('one code admits many members concurrently, with no two-member ceiling',async()=>{
 const owner=db('owner');await create(owner,'owner','family');await invite(owner,'owner','family');
 await Promise.all(Array.from({length:8},(_,i)=>{const uid='member'+i;return assertSucceeds(join(db(uid),uid,'family'))}));
 const people=await getDocs(query(collection(owner,'households','family','members'),limit(50)));
 assert.equal(people.size,9);
 await assertSucceeds(getDoc(doc(db('member7'),'households','family')));
 await assertFails(join(db('member7'),'member7','family'));
});
test('unknown, expired, revoked and cross-household codes cannot add members',async()=>{
 const owner=db('owner');await create(owner,'owner','family');
 await assertFails(join(db('guest'),'guest','family'));
 await assertFails(invite(owner,'owner','family','b'.repeat(64),-1));
 await env.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),'invites','b'.repeat(64)),{householdId:'family',createdBy:'owner',createdAt:Timestamp.now(),expiresAt:Timestamp.fromMillis(Date.now()-10000)}));
 await assertFails(join(db('guest'),'guest','family','b'.repeat(64)));
 await invite(owner,'owner','family');await deleteDoc(doc(owner,'invites','a'.repeat(64)));
 await assertFails(join(db('guest'),'guest','family'));
 await create(db('another'),'another','other-home');await invite(db('another'),'another','other-home','c'.repeat(64));
 await assertFails(join(db('guest'),'guest','family','c'.repeat(64)));
});
test('outsiders cannot read homes, enumerate invites, forge owner roles or change membership',async()=>{
 const owner=db('owner');const guest=db('guest');await create(owner,'owner','family');await invite(owner,'owner','family');
 await assertFails(getDoc(doc(guest,'households','family')));
 await assertFails(getDocs(query(collection(guest,'invites'),limit(10))));
 await assertFails(join(guest,'guest','family','a'.repeat(64),'owner'));
 await assertSucceeds(join(guest,'guest','family'));
 await assertFails(updateDoc(doc(guest,'households','family','members','guest'),{role:'owner'}));
 await assertFails(updateDoc(doc(guest,'profiles','guest'),{householdId:'other'}));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'households','family')));
});
test('members can invite; only issuer or household owner can revoke a code',async()=>{
 const owner=db('owner');const guest=db('guest');await create(owner,'owner','family');await invite(owner,'owner','family');await join(guest,'guest','family');
 await assertSucceeds(invite(guest,'guest','family','b'.repeat(64)));
 await assertFails(deleteDoc(doc(db('other'),'invites','b'.repeat(64))));
 await assertSucceeds(deleteDoc(doc(owner,'invites','b'.repeat(64))));
});
test('member lists require pagination instead of fetching all participants',async()=>{
 const owner=db('owner');await create(owner,'owner','family');
 await assertSucceeds(getDocs(query(collection(owner,'households','family','members'),limit(50))));
 await assertFails(getDocs(collection(owner,'households','family','members')));
 await assertFails(getDocs(query(collection(owner,'households','family','members'),limit(51))));
});
test('financial records require membership, valid fields and monotonic revisions',async()=>{
 const owner=db('owner');await create(owner,'owner','family');const record=doc(owner,'households','family','transactions','purchase');
 await assertSucceeds(setDoc(record,transaction('owner')));
 await assertFails(getDoc(doc(db('other'),'households','family','transactions','purchase')));
 await assertFails(updateDoc(record,{amount:13000,updatedBy:'owner',updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(record,{amount:13000,version:2,updatedBy:'owner',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(record,{amount:-100,version:3,updatedBy:'owner',updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(record,{deletedAt:serverTimestamp(),version:3,updatedBy:'owner',updatedAt:serverTimestamp()}));
 await assertFails(deleteDoc(record));
 await assertFails(updateDoc(record,{deletedAt:null,version:4,updatedAt:serverTimestamp()}));
 await assertFails(getDocs(collection(owner,'households','family','transactions')));
 await assertSucceeds(getDocs(query(collection(owner,'households','family','transactions'),limit(500))));
});

function capture(uid='capture') {return env.authenticatedContext(uid,{email:'device_'+'a'.repeat(32)+'@devices.paylog.invalid',firebase:{sign_in_provider:'password'}}).firestore()}
async function bind(owner,uid='capture',home='family',platform='android') {
 return setDoc(doc(owner,'smsDevices',uid),{householdId:home,ownerUid:'owner',name:'테스트 휴대폰',enabled:true,senders:['18001111'],cards:['하나1234'],platform,createdAt:serverTimestamp()});
}
function sms(uid='capture',id='a'.repeat(64)) {return {deviceId:uid,messageId:id,sender:'18001111',body:'하나1234승인\n12,000원\n10/26 12:00 테스트 가게',bodyHash:'b'.repeat(64),receivedAt:Timestamp.now(),createdAt:serverTimestamp(),status:'pending',transactionId:'',handledAt:null}}
test('capture accounts are scoped to their own inbox, not human ledgers or account profiles',async()=>{
 const owner=db('owner'), phone=capture();await create(owner,'owner','family');await bind(owner);
 const id='capture_'+'a'.repeat(64), target=doc(phone,'households','family','smsInbox',id);
 await assertSucceeds(setDoc(target,sms()));
 await assertSucceeds(getDoc(target));
 await assertFails(getDoc(doc(phone,'profiles','owner')));
 await assertFails(getDoc(doc(phone,'households','family')));
 await assertFails(getDocs(query(collection(phone,'households','family','smsInbox'),limit(50))));
 await assertFails(setDoc(doc(phone,'households','family','transactions','forged'),transaction('owner')));
 await assertFails(updateDoc(target,{status:'dismissed',body:'',handledAt:serverTimestamp()}));
 await assertFails(setDoc(doc(phone,'households','other','smsInbox',id),sms()));
 await assertFails(getDoc(doc(db('other'),'households','family','smsInbox',id)));
 await assertFails(setDoc(doc(capture('unbound'),'households','family','smsInbox','unbound_'+'a'.repeat(64)),sms('unbound')));
});
test('device revocation, sender filters, immutable receipts and credential-message exclusion are enforced',async()=>{
 const owner=db('owner'), phone=capture();await create(owner,'owner','family');await bind(owner);
 const target=doc(phone,'households','family','smsInbox','capture_'+'a'.repeat(64));
 await assertFails(setDoc(target,{...sms(),sender:'unregistered'}));
 await assertFails(setDoc(target,{...sms(),body:'하나1234승인 인증번호 123456'}));
 await assertFails(setDoc(target,{...sms(),body:'하나1234승인 OTP 123456'}));
 await assertFails(setDoc(target,{...sms(),receivedAt:Timestamp.fromMillis(Date.now()-8*86400000)}));
 await assertSucceeds(setDoc(target,sms()));
 await assertFails(setDoc(target,sms()));
 await assertFails(updateDoc(doc(owner,'smsDevices','capture'),{ownerUid:'other'}));
 await assertSucceeds(updateDoc(doc(owner,'smsDevices','capture'),{enabled:false}));
 await assertFails(setDoc(doc(phone,'households','family','smsInbox','capture_'+'c'.repeat(64)),sms('capture','c'.repeat(64))));
});
test('human review erases raw text; imported status requires an existing transaction',async()=>{
 const owner=db('owner'), phone=capture();await create(owner,'owner','family');await bind(owner);
 const id='capture_'+'a'.repeat(64), source=doc(owner,'households','family','smsInbox',id);
 await setDoc(doc(phone,'households','family','smsInbox',id),sms());
 await assertFails(updateDoc(source,{status:'imported',transactionId:'sms_'+'a'.repeat(64),body:'',handledAt:serverTimestamp()}));
 await assertFails(updateDoc(source,{status:'dismissed',handledAt:serverTimestamp()}));
 const batch=writeBatch(owner);batch.set(doc(owner,'households','family','transactions','sms_'+'a'.repeat(64)),transaction('owner'));
 batch.update(source,{status:'imported',transactionId:'sms_'+'a'.repeat(64),body:'',handledAt:serverTimestamp()});
 await assertSucceeds(batch.commit());
 await assertFails(updateDoc(source,{status:'pending'}));
 const value=(await getDoc(source)).data();assert.equal(value.body,'');assert.equal(value.bodyHash,'b'.repeat(64));
});
test('dismissed source receipts suppress later capture without exposing them to phones',async()=>{
 const owner=db('owner');await create(owner,'owner','family');const key='d'.repeat(64);
 const receipt=doc(owner,'households','family','smsReceipts',key);
 await assertSucceeds(setDoc(receipt,{bodyHash:'b'.repeat(64),sender:'18001111',transactionId:'',createdAt:serverTimestamp()}));
 await assertFails(updateDoc(receipt,{transactionId:'sms_'+key}));
 await assertFails(getDoc(doc(capture(),'households','family','smsReceipts',key)));
 await assertFails(deleteDoc(receipt));
});
