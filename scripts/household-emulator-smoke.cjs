// Real Firebase Auth + Firestore emulators. No live project or billing is used.
const {chromium}=require('playwright');const assert=require('node:assert/strict');
const path=require('node:path');const {firebaseSdkRoutes}=require('./firebase-browser-sdk.cjs');
const base=process.env.PAYLOG_BASE_URL||'http://127.0.0.1:8097';
assert.match(process.env.FIRESTORE_EMULATOR_HOST||'',/^(127\.0\.0\.1|localhost):8085$/,'Local Firestore emulator required');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});
 const contexts=[];const errors=[];
 try {
  async function snapshot(page,text){await page.bringToFront();for(let i=0;i<150;i++){const s=await page.locator('body').ariaSnapshot();if(s.includes(text))return s;await page.waitForTimeout(100);}throw Error('Expected '+text+'\n'+await page.locator('body').ariaSnapshot());}
  async function fill(page,name,value){
   await page.bringToFront();const field=page.getByRole('textbox',{name:new RegExp('(?:^|\\s)'+name+'$')}).first();
   for(let attempt=0;attempt<3;attempt++){
    await field.click();await page.waitForTimeout(250);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText(value);
    await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
    const actual=await field.evaluate(el=>el.value ?? el.querySelector('input,textarea')?.value);
    if(actual===value)return;
   }
   throw Error('Input did not settle: '+name);
  }
  async function openRecord(page,merchant='함께 보는 거래'){await page.bringToFront();await page.mouse.move(200,600);await page.mouse.wheel(0,4000);await page.waitForTimeout(300);await page.getByRole('button',{name:new RegExp(merchant)}).click();}
  async function participant(id){
   const ctx=await browser.newContext({viewport:{width:393,height:1800}});contexts.push(ctx);await ctx.grantPermissions(['clipboard-read','clipboard-write']);await firebaseSdkRoutes(ctx);
   // A demo build must never send account/financial traffic to live endpoints.
   await ctx.route(/^https:\/\/(identitytoolkit|securetoken|firestore)\.googleapis\.com\//,()=>{throw Error('Emulator build contacted production Firebase');});
   const page=await ctx.newPage();page.on('pageerror',e=>errors.push(e.message));
   await page.goto(base,{waitUntil:'domcontentloaded'});await page.addStyleTag({content:'.firebase-emulator-warning { pointer-events: none !important; }'});await page.locator('#loading').waitFor({state:'detached'});await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   await page.getByRole('button',{name:'로그인 / 회원가입',exact:true}).click();
   const login=page.getByRole('button',{name:'로그인',exact:true});await login.waitFor();
   for(let i=0;i<150&&!await login.isEnabled();i++)await page.waitForTimeout(100);assert(await login.isEnabled());
   await page.getByRole('button',{name:'처음이라면 회원가입',exact:true}).click();
   await fill(page,'아이디',id);await fill(page,'비밀번호','local-test-password');await fill(page,'비밀번호 확인','local-test-password');
   await page.getByRole('button',{name:'가입하고 시작하기',exact:true}).click();await snapshot(page,id+'님');
   await page.getByRole('button',{name:'공동 가계부 시작하기',exact:true}).click();await page.getByRole('button',{name:'가계부 만들기',exact:true}).waitFor();
   console.log('Signed in: '+id);
   return page;
  }
  const suffix=Date.now().toString(36);const owner=await participant('owner_'+suffix);
  await fill(owner,'가계부 이름','에뮬레이터 공동 가계부');await owner.getByRole('button',{name:'가계부 만들기',exact:true}).click();
  await owner.getByRole('button',{name:'초대 코드 만들기',exact:true}).waitFor();await owner.getByRole('button',{name:'초대 코드 만들기',exact:true}).click();
  await snapshot(owner,'초대 코드 복사');await owner.getByRole('button',{name:'초대 코드 복사',exact:true}).click();const code=await owner.evaluate(()=>navigator.clipboard.readText());assert.match(code,/^[A-Za-z0-9_-]{32}$/);
  const guests=await Promise.all([participant('guest_'+suffix),participant('third_'+suffix)]);
  await Promise.all(guests.map(async p=>{await fill(p,'초대 코드',code);await p.getByRole('button',{name:'코드로 참여하기',exact:true}).click();await p.getByRole('button',{name:'가계부 열기',exact:true}).waitFor();await p.getByRole('button',{name:'가계부 열기',exact:true}).click();await snapshot(p,'공동 가계부');}));
  await owner.getByRole('button',{name:'가계부 열기',exact:true}).click();await snapshot(owner,'공동 가계부');
  const register=owner.getByRole('tab',{name:'등록',exact:true});await register.click();
  await fill(owner,'거래 금액','25000');await fill(owner,'사용처','함께 보는 거래');
  await owner.getByRole('button',{name:'기록 저장하기',exact:true}).click();await snapshot(owner,'공동 가계부에 거래를 저장했어요.');await snapshot(owner,'함께 보는 거래');
  console.log('Owner saved transaction');for(const p of guests){await snapshot(p,'함께 보는 거래');}console.log('Guests received transaction');
  const guest=guests[0];await openRecord(guest);
  await guest.getByRole('button',{name:'기록 수정',exact:true}).click();await fill(guest,'거래 금액','30000');
  await guest.getByRole('button',{name:'기록 저장하기',exact:true}).click();await snapshot(owner,'₩30,000');await owner.screenshot({path:path.resolve(__dirname,'../apps/web/build/household-shared-ledger.png')});
  await openRecord(guest);await guest.getByRole('button',{name:'기록 삭제',exact:true}).click();
  await guest.getByRole('button',{name:'삭제',exact:true}).click();
  await snapshot(owner,'아직 기록이 없는 날이에요.');
  // Exercise actual capture enrollment without changing the human SDK session.
  await owner.getByRole('button',{name:'문자 수집함 · 기기 연결',exact:true}).click();
  await fill(owner,'기기 이름','테스트 Galaxy');await fill(owner,'카드 문자 발신번호','18001111');await fill(owner,'문자에 표시된 카드 식별자','하나1234');
  async function enrollPhone(){
   await owner.getByRole('button',{name:'휴대폰 연결 파일 만들기',exact:true}).click();
   await snapshot(owner,'연결 파일 다운로드');
   const download=owner.waitForEvent('download');await owner.getByRole('button',{name:'연결 파일 다운로드',exact:true}).click();
   const file=await download;const config=JSON.parse(require('node:fs').readFileSync(await file.path(),'utf8'));await file.delete();
   assert.equal(config.projectId,'demo-paylog');assert.equal(config.version,2);return config;
  }
  const phone=await enrollPhone();await owner.screenshot({path:path.resolve(__dirname,'../apps/web/build/firestore-sms-setup.png')});
  async function authenticate(email,password){const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});assert.equal(r.status,200);return (await r.json()).idToken;}
  const captureToken=await authenticate(phone.email,phone.password);
  const firestore='http://127.0.0.1:8085/v1/projects/demo-paylog/databases/(default)/documents';
  const resource='projects/demo-paylog/databases/(default)/documents';
  const now=new Date(),seoul=new Date(now.getTime()+9*3600000);const pad=n=>String(n).padStart(2,'0');
  const text='하나1234승인\n12,000원\n'+pad(seoul.getUTCMonth()+1)+'/'+pad(seoul.getUTCDate())+' '+pad(seoul.getUTCHours())+':'+pad(seoul.getUTCMinutes())+' 자동 문자 거래';
  const hash=require('node:crypto').createHash('sha256').update(text).digest('hex');const message='a'.repeat(64);
  async function capture(config,token,messageId=message){
   const str=stringValue=>({stringValue});
   const fields={deviceId:str(config.deviceId),messageId:str(messageId),sender:str('18001111'),body:str(text),bodyHash:str(hash),receivedAt:{timestampValue:now.toISOString()},status:str('pending'),transactionId:str(''),handledAt:{nullValue:null}};
   return fetch(firestore+':commit',{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},body:JSON.stringify({writes:[{update:{name:resource+'/households/'+config.householdId+'/smsInbox/'+config.deviceId+'_'+messageId,fields},currentDocument:{exists:false},updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}]}]})});
  }
  assert.equal((await capture(phone,captureToken)).status,200);
  await owner.getByRole('tab',{name:'달력',exact:true}).click();await snapshot(owner,'₩12,000');await snapshot(guests[0],'₩12,000');
  const duplicate=await capture(phone,captureToken);assert([400,409].includes(duplicate.status));
  const privateLedger=await fetch(firestore+'/households/'+phone.householdId,{headers:{authorization:'Bearer '+captureToken}});assert.equal(privateLedger.status,403);
  // A second handset submitting the same source SMS must not double the total.
  await owner.getByRole('button',{name:'문자 수집함 · 기기 연결',exact:true}).click();
  await fill(owner,'기기 이름','두 번째 Galaxy');await fill(owner,'카드 문자 발신번호','18001111');await fill(owner,'문자에 표시된 카드 식별자','하나1234');
  const second=await enrollPhone();const secondToken=await authenticate(second.email,second.password);assert.notEqual(second.deviceId,phone.deviceId);
  assert.equal((await capture(second,secondToken)).status,200);
  await owner.getByRole('tab',{name:'달력',exact:true}).click();await snapshot(owner,'₩12,000');
  const humanToken=await authenticate('owner_'+suffix+'@accounts.paylog.invalid','local-test-password');
  const secondReceipt=firestore+'/households/'+second.householdId+'/smsInbox/'+second.deviceId+'_'+message;
  for(let attempt=0;attempt<100;attempt++){const r=await fetch(secondReceipt,{headers:{authorization:'Bearer '+humanToken}});const d=await r.json();if(d.fields?.status?.stringValue==='imported'){assert.equal(d.fields.body.stringValue,'');break;}if(attempt===99)throw Error('Second capture was not deduplicated');await owner.waitForTimeout(100);}
  const revoke=await fetch(firestore+'/smsDevices/'+phone.deviceId+'?updateMask.fieldPaths=enabled',{method:'PATCH',headers:{'content-type':'application/json',authorization:'Bearer '+humanToken},body:JSON.stringify({fields:{enabled:{booleanValue:false}}})});assert.equal(revoke.status,200);
  assert.equal((await capture(phone,captureToken,'c'.repeat(64))).status,403);
  // Imported transactions use the same editing/deletion UI as manual entries.
  await openRecord(owner,'자동 문자 거래');await owner.getByRole('button',{name:'기록 수정',exact:true}).click();await fill(owner,'거래 금액','14000');
  await owner.getByRole('button',{name:'기록 저장하기',exact:true}).click();await snapshot(owner,'공동 가계부에 거래를 저장했어요.');await snapshot(guests[0],'₩14,000');
  await openRecord(owner,'자동 문자 거래');await owner.getByRole('button',{name:'기록 삭제',exact:true}).click();await owner.getByRole('button',{name:'삭제',exact:true}).click();await snapshot(owner,'아직 기록이 없는 날이에요.');
  assert([400,409].includes((await capture(second,secondToken)).status));
  // The iPhone protocol is the same capture-only REST interface, but requires
  // explicit human confirmation instead of trusting a synthetic SMS UUID.
  const iosEmail='device_'+require('node:crypto').randomBytes(16).toString('hex')+'@devices.paylog.invalid';const iosPassword=require('node:crypto').randomBytes(32).toString('hex');
  const iosSignup=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:iosEmail,password:iosPassword,returnSecureToken:true})});assert.equal(iosSignup.status,200);const iosAuth=await iosSignup.json();
  const ios={...phone,deviceId:iosAuth.localId,email:iosEmail,password:iosPassword,platform:'ios'};const sv=stringValue=>({stringValue});
  const lookup=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:lookup?key=fake-api-key', {
    method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({idToken:humanToken})
  });
  assert.equal(lookup.status,200);const humanUid=(await lookup.json()).users[0].localId;
  const iosBinding={
    update:{name:resource+'/smsDevices/'+ios.deviceId,fields:{
      householdId:sv(ios.householdId),ownerUid:sv(humanUid),name:sv('테스트 iPhone'),
      enabled:{booleanValue:true},platform:sv('ios'),
      senders:{arrayValue:{values:[sv('18001111')]}},cards:{arrayValue:{values:[sv('하나1234')]}}
    }},
    currentDocument:{exists:false},
    updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'}]
  };
  const bindIos=await fetch(firestore+':commit', {
    method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+humanToken},
    body:JSON.stringify({writes:[iosBinding]})
  });assert.equal(bindIos.status,200);
  assert.equal((await capture(ios,iosAuth.idToken,'d'.repeat(64))).status,200);
  await owner.getByRole('button',{name:'문자 수집함 · 기기 연결',exact:true}).click();await snapshot(owner,'확인이 필요한 문자 1건');
  await owner.mouse.move(200,600);await owner.mouse.wheel(0,6000);await owner.waitForTimeout(300);
  await owner.getByRole('button',{name:'승인 기록 추가',exact:true}).click();
  await owner.getByRole('tab',{name:'달력',exact:true}).click();await snapshot(owner,'₩12,000');
  assert.deepEqual(errors,[]);
  console.log('PASS: real local Firebase signup, household creation, 3 members via one code, cross-user transaction create/edit/delete and live sync; capture-only phone enrollment, REST ingestion, automatic SMS import, cross-device dedup and immediate revocation; no production requests');
 }finally{await Promise.all(contexts.map(c=>c.close()));await browser.close()}
})().catch(e=>{console.error(e.message);process.exit(1)});
