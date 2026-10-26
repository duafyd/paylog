// Real FlutterFire web SDK with a simulated Auth backend. No Google account is used.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {spawnSync}=require('node:child_process');
const base=process.env.PAYLOG_BASE_URL || 'http://127.0.0.1:8096';
const sdkCache=path.resolve(__dirname,'../apps/web/build/firebase-auth-smoke-sdk');
fs.mkdirSync(sdkCache,{recursive:true});
function sdkFile(url) {
 const match=/^https:\/\/www\.gstatic\.com\/firebasejs\/(\d+\.\d+\.\d+)\/(firebase-(?:app|auth)\.js)$/.exec(url);
 assert(match,'Only official Firebase app/auth SDK modules may be fetched');
 const target=path.join(sdkCache,match[1]+'-'+match[2]);
 if(!fs.existsSync(target)) {
  const code='import urllib.request,sys\nwith urllib.request.urlopen(sys.argv[1],timeout=30) as r: data=r.read()\nopen(sys.argv[2],"wb").write(data)';
  const result=spawnSync('python3',['-c',code,url,target],{encoding:'utf8'});
  assert.equal(result.status,0,'Official SDK download failed');
 }
 return target;
}
function testJwt() {
 const now=Math.floor(Date.now()/1000);
 return [Buffer.from(JSON.stringify({alg:'RS256',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({sub:'smoke-family',user_id:'smoke-family',aud:'paylog-c5c2d',iss:'https://securetoken.google.com/paylog-c5c2d',iat:now,exp:now+3600,auth_time:now,email:'family@example.com',email_verified:true,firebase:{sign_in_provider:'google.com',identities:{'google.com':['smoke-family']}}})).toString('base64url'),'test-only-signature'].join('.');
}
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});
 try {
  const context=await browser.newContext({viewport:{width:393,height:852}});
  const errors=[];const authRequests=[];let sheetRequests=0;
  // Match Firebase Hosting's existing SPA rewrite when using a plain static server.
  await context.route(base+'/sign-in', route=>route.fulfill({path:path.resolve(__dirname,'../apps/web/build/web/index.html'),contentType:'text/html'}));
  await context.route('https://www.gstatic.com/firebasejs/**',async route=>{
   await route.fulfill({path:sdkFile(route.request().url()),contentType:'text/javascript',headers:{'access-control-allow-origin':'*'}});
  });
  await context.route('https://www.googletagmanager.com/**',route=>route.fulfill({body:'',contentType:'text/javascript'}));
  await context.route('https://sheets.googleapis.com/**',route=>{sheetRequests++;return route.abort();});
  await context.route('https://identitytoolkit.googleapis.com/**',async route=>{
   const pathname=new URL(route.request().url()).pathname;authRequests.push(pathname);
   const provider={providerId:'google.com',rawId:'smoke-family',email:'family@example.com',displayName:'테스트 가족'};
   let body;
   if(pathname.endsWith('/accounts:signInWithIdp')) body={localId:'smoke-family',email:'family@example.com',displayName:'테스트 가족',emailVerified:true,idToken:testJwt(),refreshToken:'test-only-refresh-token',expiresIn:'3600',providerId:'google.com'};
   else if(pathname.endsWith('/accounts:lookup')) body={users:[{localId:'smoke-family',email:'family@example.com',displayName:'테스트 가족',emailVerified:true,providerUserInfo:[provider],createdAt:'1700000000000',lastLoginAt:'1700000000000'}]};
   else throw new Error('Unexpected Auth backend request path: '+pathname);
   await route.fulfill({json:body,headers:{'access-control-allow-origin':'*'}});
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
  await page.goto(base,{waitUntil:'domcontentloaded'});await enableSemantics();
  await page.getByRole('button',{name:'Google 계정으로 시작',exact:true}).click();
  const login=page.getByRole('button',{name:'Google로 로그인',exact:true});
  await login.waitFor();
  for(let i=0;i<150&&!await login.isEnabled();i++)await page.waitForTimeout(100);
  assert(await login.isEnabled(),'Real FlutterFire initialization did not finish');
  assert.equal(await page.locator('body').getByText('로그인 완료',{exact:true}).count(),0);
  // Exercise real SDK state propagation with an explicitly simulated IdP response.
  await page.evaluate(async()=>{
   const auth=window.firebase_auth;const core=window.firebase_core;
   await auth.signInWithCredential(auth.getAuth(core.getApp()),auth.GoogleAuthProvider.credential('test-only-google-id-token'));
  });
  await snapshotContains('family@example.com');
  assert((await page.locator('body').ariaSnapshot()).includes('공동 가계부 저장 기능은 다음 단계'));
  await page.reload({waitUntil:'domcontentloaded'});await enableSemantics();
  await snapshotContains('family@example.com');
  await page.getByRole('button',{name:'로그아웃',exact:true}).click();
  await page.getByRole('button',{name:'Google로 로그인',exact:true}).waitFor();
  await page.reload({waitUntil:'domcontentloaded'});await enableSemantics();
  await page.getByRole('button',{name:'Google로 로그인',exact:true}).waitFor();
  assert(!(await page.locator('body').ariaSnapshot()).includes('family@example.com'));
  assert(authRequests.some(p=>p.endsWith('/accounts:signInWithIdp')));
  assert(authRequests.some(p=>p.endsWith('/accounts:lookup')));
  assert.equal(sheetRequests,0);
  assert.deepEqual(errors,[]);
  console.log('PASS: real FlutterFire SDK initialization, simulated Auth backend state, session refresh, signout, zero Sheets requests, no JS errors');
  console.log('LIMIT: Google account consent, real backend configuration and mobile-device popup login were not tested');
 }finally{await browser.close()}
})().catch(error=>{console.error(error.message);process.exit(1)});
