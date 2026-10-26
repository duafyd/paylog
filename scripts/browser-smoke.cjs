const {firebaseSdkRoutes}=require('./firebase-browser-sdk.cjs');
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
 await firebaseSdkRoutes(page);
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(process.env.PAYLOG_BASE_URL || 'http://127.0.0.1:8080',{waitUntil:'networkidle'});
 await page.locator('#loading').waitFor({state:'detached'});
 await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
 async function snapshotContains(text) {
  for(let i=0;i<50;i++){const snapshot=await page.locator('body').ariaSnapshot();if(snapshot.includes(text)) return snapshot;await page.waitForTimeout(100);}
  throw new Error('Expected accessibility content: '+text+'\n'+await page.locator('body').ariaSnapshot());
 }
 async function fill(name,value){
  const input=page.getByRole('textbox',{name,exact:true});await input.click();await page.waitForTimeout(150);
  await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText(value);
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
 }
 async function scroll(delta){await page.mouse.move(200,400);await page.mouse.wheel(0,delta);await page.waitForTimeout(250);}
 async function tab(name){await page.getByRole('tab',{name,exact:true}).or(page.getByRole('button',{name,exact:true})).first().click();}
 await tab('등록');
 await scroll(-5000);
 await fill('거래 금액','25000');
 await fill('사용처','브라우저 검증 거래');
 await page.getByRole('button',{name:'기록 저장하기',exact:true}).click();

 await snapshotContains('거래를 저장했어요.');
 await scroll(-5000);
 await snapshotContains('₩205,600');
 await page.screenshot({path:path.join(screenshotDir,'saved-expense.png')});
 await tab('통계');
 await snapshotContains('어디에 사용했을까요?');
 await scroll(5000);
 await snapshotContains('₩106,200');
 await tab('등록');
 await scroll(-5000);
 await page.getByRole('button',{name:'수입',exact:true}).click();
 await fill('거래 금액','100000');
 await fill('수입 내역','브라우저 검증 수입');
 await page.getByRole('button',{name:'기록 저장하기',exact:true}).click();
 await snapshotContains('거래를 저장했어요.');
 await scroll(-5000);
 await snapshotContains('₩4,300,000');
 // Follow the real detail/edit/delete routes in the compiled web app.
 await scroll(5000);
 await page.getByRole('button',{name:/브라우저 검증 거래/}).click();
 await snapshotContains('기록 상세');
 await page.getByRole('button',{name:'기록 수정',exact:true}).click();
 await scroll(-5000);
 await fill('거래 금액','27000');
 await page.getByRole('button',{name:'기록 저장하기',exact:true}).click();
 await snapshotContains('거래를 저장했어요.');
 await scroll(-5000);await snapshotContains('₩207,600');
 await scroll(5000);await page.getByRole('button',{name:/브라우저 검증 거래/}).click();
 await page.getByRole('button',{name:'기록 삭제',exact:true}).click();
 await page.getByRole('button',{name:'삭제',exact:true}).click();
 await scroll(-5000);await snapshotContains('₩180,600');
 await page.reload({waitUntil:'networkidle'});
 await page.locator('#loading').waitFor({state:'detached'});
 await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
 const reset=await snapshotContains('₩180,600');
 assert(!reset.includes('브라우저 검증'));
 assert(reset.includes('₩180,600'));
 const registrations=await page.evaluate(async()=>await navigator.serviceWorker.getRegistrations().then(items=>items.length));
 assert.equal(registrations,0);
 assert.deepEqual(errors,[]);
 console.log('PASS: 브라우저 수입·지출 등록/수정/삭제, 통계 반영, 세션 초기화, 서비스워커 미등록, JS 오류 없음');
 } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exit(1)});
