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
  async function openRecord(page){await page.bringToFront();await page.mouse.move(200,600);await page.mouse.wheel(0,4000);await page.waitForTimeout(300);await page.getByRole('button',{name:/함께 보는 거래/}).click();}
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
  assert.deepEqual(errors,[]);
  console.log('PASS: real local Firebase signup, household creation, 3 members via one code, cross-user transaction create/edit/delete and live sync; no production requests');
 }finally{await Promise.all(contexts.map(c=>c.close()));await browser.close()}
})().catch(e=>{console.error(e.message);process.exit(1)});
