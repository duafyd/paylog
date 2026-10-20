const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');
const fs=require('node:fs');
const screenshotDir=path.resolve(__dirname,'../apps/web/build/browser-smoke');
fs.mkdirSync(screenshotDir,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});
 try {
 const page=await browser.newPage({viewport:{width:402,height:874}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(process.env.PAYLOG_BASE_URL || 'http://127.0.0.1:8080',{waitUntil:'networkidle'});
 await page.locator('#loading').waitFor({state:'detached'});
 await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
 async function snapshotContains(text) {
  for(let i=0;i<50;i++){const snapshot=await page.locator('body').ariaSnapshot();if(snapshot.includes(text)) return snapshot;await page.waitForTimeout(100);}
  throw new Error('Expected accessibility content: '+text);
 }
 async function tab(name){await page.getByRole('tab',{name,exact:true}).or(page.getByRole('button',{name,exact:true})).first().click();}
 await tab('등록');
 await page.getByRole('textbox',{name:'거래 금액',exact:true}).fill('25000');
 await page.getByRole('textbox',{name:'사용처',exact:true}).fill('브라우저 검증 거래');
 await page.getByRole('button',{name:'기록 저장하기',exact:true}).click();

 await snapshotContains('브라우저 검증 거래');
 assert((await page.locator('body').ariaSnapshot()).includes('₩205,600'));
 await page.screenshot({path:path.join(screenshotDir,'saved-expense.png')});
 await tab('통계');
 await snapshotContains('어디에 사용했을까요?');
 assert((await page.locator('body').ariaSnapshot()).includes('₩106,200'));
 await tab('등록');
 await page.getByRole('button',{name:'수입',exact:true}).click();
 await page.getByRole('textbox',{name:'거래 금액',exact:true}).fill('100000');
 await page.getByRole('textbox',{name:'수입 내역',exact:true}).fill('브라우저 검증 수입');
 await page.getByRole('button',{name:'기록 저장하기',exact:true}).click();
 await snapshotContains('브라우저 검증 수입');
 assert((await page.locator('body').ariaSnapshot()).includes('₩4,300,000'));
 await page.reload({waitUntil:'networkidle'});
 await page.locator('#loading').waitFor({state:'detached'});
 await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
 const reset=await snapshotContains('₩180,600');
 assert(!reset.includes('브라우저 검증'));
 assert(reset.includes('₩180,600'));
 const registrations=await page.evaluate(async()=>await navigator.serviceWorker.getRegistrations().then(items=>items.length));
 assert.equal(registrations,0);
 assert.deepEqual(errors,[]);
 console.log('PASS: 브라우저 지출 등록, 통계 반영, 수입 등록, 세션 초기화, 서비스워커 미등록, JS 오류 없음');
 } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exit(1)});
