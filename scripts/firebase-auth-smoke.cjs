// Real FlutterFire web SDK with a simulated password Auth backend. No production account is used.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const base=process.env.PAYLOG_BASE_URL || 'http://127.0.0.1:8096';
const {firebaseSdkRoutes}=require('./firebase-browser-sdk.cjs');
function testJwt() {
 const now=Math.floor(Date.now()/1000);
 return [Buffer.from(JSON.stringify({alg:'RS256',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({sub:'smoke-family',user_id:'smoke-family',aud:'paylog-c5c2d',iss:'https://securetoken.google.com/paylog-c5c2d',iat:now,exp:now+3600,auth_time:now,email:'family_one@accounts.paylog.invalid',email_verified:false,firebase:{sign_in_provider:'password',identities:{email:['family_one@accounts.paylog.invalid']}}})).toString('base64url'),'test-only-signature'].join('.');
}
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});
 try {
  const context=await browser.newContext({viewport:{width:393,height:852}});
  const errors=[];const authRequests=[];let sheetRequests=0;let accountExists=false;
  const loginId='family_one';const address=loginId+'@accounts.paylog.invalid';
  const password='test-only-password  '; // trailing spaces must not be trimmed
  // Match Firebase Hosting's existing SPA rewrite when using a plain static server.
  await context.route(base+'/sign-in', route=>route.fulfill({path:path.resolve(__dirname,'../apps/web/build/web/index.html'),contentType:'text/html'}));
  await firebaseSdkRoutes(context);
  // Household/financial integration is covered separately; never send a fake identity to production Firestore.
  await context.route('https://firestore.googleapis.com/**',route=>route.abort());
  await context.route('https://sheets.googleapis.com/**',route=>{sheetRequests++;return route.abort();});
  await context.route('https://identitytoolkit.googleapis.com/**',async route=>{
   const pathname=new URL(route.request().url()).pathname;authRequests.push(pathname);
   const provider={providerId:'password',rawId:address,email:address};
   const payload=route.request().method()==='POST'?route.request().postDataJSON():{};
   let body;let status=200;
   const credential=()=>({localId:'smoke-family',email:address,emailVerified:false,idToken:testJwt(),refreshToken:'test-only-refresh-token',expiresIn:'3600'});
   if(pathname.endsWith('/accounts:signUp')) {
    assert.equal(payload.email,address);assert.equal(payload.password,password);
    if(accountExists){status=400;body={error:{code:400,message:'EMAIL_EXISTS'}};}
    else {accountExists=true;body=credential();}
   } else if(pathname.endsWith('/accounts:signInWithPassword')) {
    assert.equal(payload.email,address);
    if(!accountExists||payload.password!==password){status=400;body={error:{code:400,message:'INVALID_LOGIN_CREDENTIALS'}};}
    else body=credential();
   } else if(pathname.endsWith('/accounts:lookup')) {
    body={users:[{localId:'smoke-family',email:address,emailVerified:false,providerUserInfo:[provider],createdAt:'1700000000000',lastLoginAt:'1700000000000'}]};
   } else throw new Error('Unexpected Auth backend request path: '+pathname);
   await route.fulfill({status,json:body,headers:{'access-control-allow-origin':'*'}});
  });
  // A refresh must not contact a production token endpoint during this test.
  await context.route('https://securetoken.googleapis.com/**',route=>route.abort());
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
  async function snapshotContains(text){
   for(let i=0;i<100;i++){const snapshot=await page.locator('body').ariaSnapshot();if(snapshot.includes(text))return snapshot;await page.waitForTimeout(100);}
   throw new Error('Expected accessibility text: '+text);
  }
  async function enableSemantics(){
   await page.locator('#loading').waitFor({state:'detached'});
   await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
  }
  async function fill(name,value) {
   const field=page.getByRole('textbox',{name,exact:true});
   await field.click();await page.waitForTimeout(150);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText(value);
   await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  }
  async function waitReady() {
   const login=page.getByRole('button',{name:'로그인',exact:true});await login.waitFor();
   for(let i=0;i<150&&!await login.isEnabled();i++)await page.waitForTimeout(100);
   assert(await login.isEnabled(),'Real FlutterFire initialization did not finish');
  }
  await page.goto(base,{waitUntil:'domcontentloaded'});await enableSemantics();
  await page.getByRole('button',{name:'로그인 / 회원가입',exact:true}).click();
  await waitReady();
  assert.equal(await page.getByRole('button',{name:'Google로 로그인',exact:true}).count(),0);
  await page.getByRole('button',{name:'처음이라면 회원가입',exact:true}).click();
  await fill('아이디','FAMILY_ONE');await fill('비밀번호',password);await fill('비밀번호 확인','mismatch');
  await page.getByRole('button',{name:'가입하고 시작하기',exact:true}).click();
  await snapshotContains('비밀번호가 일치하지 않아요.');
  assert(!authRequests.some(p=>p.endsWith('/accounts:signUp')));
  await fill('비밀번호 확인',password);
  await page.getByRole('button',{name:'가입하고 시작하기',exact:true}).click();
  await snapshotContains(loginId+'님');
  assert(!(await page.locator('body').ariaSnapshot()).includes('@accounts.paylog.invalid'));
  assert((await page.locator('body').ariaSnapshot()).includes('공동 가계부 시작하기'));
  assert(!(await page.evaluate(()=>JSON.stringify(sessionStorage))).includes(password));
  await page.reload({waitUntil:'domcontentloaded'});await enableSemantics();
  await snapshotContains(loginId+'님');
  await page.getByRole('button',{name:'로그아웃',exact:true}).click();await waitReady();
  await fill('아이디',loginId);await fill('비밀번호','wrong-password');
  await page.getByRole('button',{name:'로그인',exact:true}).click();
  await snapshotContains('아이디 또는 비밀번호를 확인해 주세요.');
  await fill('비밀번호',password);
  await page.getByRole('button',{name:'로그인',exact:true}).click();
  await snapshotContains(loginId+'님');
  await page.getByRole('button',{name:'로그아웃',exact:true}).click();await waitReady();
  await page.getByRole('button',{name:'처음이라면 회원가입',exact:true}).click();
  await fill('아이디',loginId);await fill('비밀번호',password);await fill('비밀번호 확인',password);
  await page.getByRole('button',{name:'가입하고 시작하기',exact:true}).click();
  await snapshotContains('이미 사용 중인 아이디예요.');
  assert(!(await page.locator('body').ariaSnapshot()).includes(loginId+'님'));
  await page.reload({waitUntil:'domcontentloaded'});await enableSemantics();await waitReady();
  assert(!(await page.locator('body').ariaSnapshot()).includes(loginId+'님'));
  assert(authRequests.some(p=>p.endsWith('/accounts:signUp')));
  assert(authRequests.some(p=>p.endsWith('/accounts:signInWithPassword')));
  assert(authRequests.some(p=>p.endsWith('/accounts:lookup')));
  assert.equal(sheetRequests,0);
  assert.deepEqual(errors,[]);
  console.log('PASS: real FlutterFire SDK with simulated password backend, signup/confirmation, normalized ID, wrong-password login, duplicate ID, session refresh/signout, no password in session storage, zero Sheets requests');
  console.log('LIMIT: production Email/Password provider and physical iPhone/Android browsers were not tested');
 }finally{await browser.close()}
})().catch(error=>{console.error(error.message);process.exit(1)});
