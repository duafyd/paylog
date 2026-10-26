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
