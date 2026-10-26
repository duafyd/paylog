const {firebaseSdkRoutes}=require('./firebase-browser-sdk.cjs');
// Synthetic GIS/API contract smoke test. This does NOT prove real Google login.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', args: ['--no-sandbox','--disable-dev-shm-usage']});
  try {
    const page = await browser.newPage({viewport:{width:402,height:874}});
    await firebaseSdkRoutes(page);
 const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    const sheetId = 'browserTestSpreadsheetId0123456789';
    let rows; const methods=[];
    await page.route('https://accounts.google.com/gsi/client', route => route.fulfill({contentType:'text/javascript', body:`
      globalThis.__oauthScopes = [];
      globalThis.google = { accounts: { oauth2: {
        initTokenClient: config => ({requestAccessToken: () => {
          globalThis.__oauthScopes.push(config.scope);
          setTimeout(() => config.callback({access_token:'browser-test-token', expires_in:3600, scope:config.scope}), 0);
        }}),
        revoke: (token, callback) => callback({successful: !globalThis.__revokeFails})
      }}};` }));
    await page.route(/^https:\/\/(openidconnect|sheets)\.googleapis\.com\//, async route => {
      const req=route.request(); const uri=new URL(req.url());
      const headers={'access-control-allow-origin':'*','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'GET,POST,OPTIONS'};
      if(req.method()==='OPTIONS') return route.fulfill({status:204,headers});
      assert.equal(req.headers().authorization, 'Bearer browser-test-token');
      let body;
      if(uri.hostname==='openidconnect.googleapis.com') body={sub:'browser-test-subject',email:'browser@example.com',email_verified:true,name:'브라우저 테스트'};
      else {
        methods.push(req.method());
        if(req.method()==='POST' && uri.pathname==='/v4/spreadsheets') {
          assert.equal(req.postDataJSON().properties.timeZone,'Asia/Seoul');
          body={spreadsheetId:sheetId};
        } else if(req.method()==='POST') {
          assert.equal(uri.searchParams.get('valueInputOption'),'RAW');
          rows=req.postDataJSON().values; body={updates:{updatedRows:2}};
        } else if(uri.pathname.includes('/values/')) body={values:rows};
        else body={properties:{title:'모의 테스트 시트'}};
      }
      await route.fulfill({status:200,headers,contentType:'application/json',body:JSON.stringify(body)});
    });
    async function content(text) {
      for(let i=0;i<60;i++) {const value=await page.locator('body').ariaSnapshot();if(value.includes(text))return value;await page.waitForTimeout(100);}
      throw new Error('Missing accessible content: '+text+'\n'+await page.locator('body').ariaSnapshot());
    }
    async function scroll(delta){await page.mouse.move(200,400);await page.mouse.wheel(0,delta);await page.waitForTimeout(250);}
    async function openConnection() {
      await page.getByRole('tab',{name:'설정',exact:true}).or(page.getByRole('button',{name:'설정',exact:true})).first().click();
      await page.getByRole('button',{name:'Google 연결 검증 열기',exact:true}).click();
    }
    await page.goto(process.env.PAYLOG_BASE_URL || 'http://127.0.0.1:8081',{waitUntil:'networkidle'});
    await page.locator('#loading').waitFor({state:'detached'});
    await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
    await openConnection();
    await page.getByRole('button',{name:'Google 로그인',exact:true}).click();
    await content('browser@example.com');
    assert.deepEqual(await page.evaluate(()=>globalThis.__oauthScopes),['openid email profile']);
    await page.getByRole('button',{name:'Sheets 권한 요청',exact:true}).click();
    await content('Sheets 권한 다시 동의');
    await page.getByRole('button',{name:'전용 테스트 시트 생성·쓰기 확인',exact:true}).click();
    await page.getByRole('button',{name:'새 시트 생성·검증',exact:true}).click();
    await page.mouse.move(200,400);await page.mouse.wheel(0,350);await page.waitForTimeout(250);
    await content('접근 검증 완료');
    assert.deepEqual(methods,['POST','POST','GET']);
    assert.equal(rows[1][3],1000);
    assert.equal(rows[1][16],'browser-test-subject');
    const screenshotDir=path.resolve(__dirname,'../apps/web/build/browser-smoke');
    fs.mkdirSync(screenshotDir,{recursive:true});
    await page.mouse.move(200,650);
    await page.mouse.wheel(0,900);
    await page.waitForTimeout(250);
    await page.screenshot({path:path.join(screenshotDir,'google-probe.png')});
    const sheetInput=page.getByRole('textbox',{name:/시트 ID 또는 Google Sheets URL/});
    await sheetInput.click();
    await page.waitForTimeout(150);
    await sheetInput.fill(sheetId);
    await page.waitForTimeout(200);
    await page.getByRole('button',{name:'기존 시트 읽기 확인',exact:true}).click();
    await page.mouse.move(200,400);await page.mouse.wheel(0,350);await page.waitForTimeout(250);
    await content('모의 테스트 시트');
    assert.deepEqual(methods.slice(-2),['GET','GET']);
    assert.equal(await page.evaluate(()=>JSON.stringify({...localStorage,...sessionStorage}).includes('browser-test-token')),false);
    await scroll(-5000);
    await page.getByRole('button',{name:'Google 연결 해제',exact:true}).click();
    await content('Google 로그인');
    await page.getByRole('button',{name:'Google 로그인',exact:true}).click();
    await content('browser@example.com');
    await page.evaluate(()=>globalThis.__revokeFails=true);
    await scroll(-5000);
    await page.getByRole('button',{name:'Google 연결 해제',exact:true}).click();
    await page.mouse.move(200,400);await page.mouse.wheel(0,600);await page.waitForTimeout(250);
    await content('Google 권한 철회는 확인하지 못했어요.');
    assert.deepEqual(errors,[]);
    console.log('PASS (mock only): GIS JS interop, separate scopes, profile, RAW append/readback, existing sheet GET only, disconnect, no browser token storage');
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
