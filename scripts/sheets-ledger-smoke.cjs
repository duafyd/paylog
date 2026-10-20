// Mock-only integration: no real Google account or spreadsheet is accessed.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const path=require('node:path');const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});
 try {
  const page=await browser.newPage({viewport:{width:402,height:874}});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const id='mockLiveSpreadsheetIdentifier1234567890';
  let rows=[],people=[],appendCount=0,firstAppend=true;
  await page.route('https://accounts.google.com/gsi/client',route=>route.fulfill({contentType:'text/javascript',body:`
    globalThis.google={accounts:{oauth2:{initTokenClient:config=>({requestAccessToken:()=>setTimeout(()=>config.callback({access_token:'ledger-browser-token',expires_in:3600,scope:config.scope}),0)}),revoke:(token,callback)=>callback({successful:true})}}};
  `}));
  await page.route(/^https:\/\/(openidconnect|sheets)\.googleapis\.com\//,async route=>{
   const req=route.request(),url=new URL(req.url());
   const headers={'access-control-allow-origin':'*','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'GET,POST,OPTIONS'};
   if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
   assert.equal(req.headers().authorization,'Bearer ledger-browser-token');
   let body,status=200;
   if(url.hostname==='openidconnect.googleapis.com')body={sub:'ledger-browser-subject',email:'ledger@example.com',email_verified:true,name:'테스트 가족'};
   else if(req.method()==='POST'){
    const data=req.postDataJSON();
    if(url.pathname==='/v4/spreadsheets'){
     assert.equal(data.properties.title,'paylog 가계부');assert.equal(data.properties.timeZone,'Asia/Seoul');
     body={spreadsheetId:id};
    }else if(url.pathname.endsWith('/values:batchUpdate')){
     assert.equal(data.valueInputOption,'RAW');
     rows=data.data.find(d=>d.range.startsWith('Transactions')).values;
     people=data.data.find(d=>d.range.startsWith('Members')).values;
     assert.equal(rows.length,1);assert.equal(people[1][2],'ledger-browser-subject');
     body={totalUpdatedRows:3};
    }else if(url.pathname.endsWith(':append')){
     appendCount++;assert.equal(url.searchParams.get('valueInputOption'),'RAW');
     const row=data.values[0];assert.equal(row[8],people[1][0]);assert.equal(row[16],people[1][0]);
     rows.push(row);
     if(firstAppend){firstAppend=false;status=503;body={error:'simulated lost response after commit'};}
     else body={updates:{updatedRows:1}};
    }else throw new Error('Unexpected write '+url.pathname);
   }else if(url.pathname.endsWith('/values:batchGet'))body={valueRanges:[{values:people}]};
   else if(url.pathname.includes('/values/'))body={values:rows};
   else body={properties:{title:'모의 공유 원장'}};
   await route.fulfill({status,headers,contentType:'application/json',body:JSON.stringify(body)});
  });
  async function content(text){for(let i=0;i<60;i++){const s=await page.locator('body').ariaSnapshot();if(s.includes(text))return s;await page.waitForTimeout(100);}throw new Error('Missing content: '+text+'\n'+await page.locator('body').ariaSnapshot());}
  async function scroll(delta){await page.mouse.move(200,400);await page.mouse.wheel(0,delta);await page.waitForTimeout(250);}
  async function tab(name){await page.getByRole('tab',{name,exact:true}).or(page.getByRole('button',{name,exact:true})).first().click();await page.waitForTimeout(150);}
  async function fill(name,value){const el=page.getByRole('textbox',{name:new RegExp(name)});await el.click();await page.waitForTimeout(150);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText(value);await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));}
  async function openConnection(){await tab('설정');await page.getByRole('button',{name:'Google 연결 검증 열기',exact:true}).click();}
  async function signIn(){await page.getByRole('button',{name:'Google 로그인',exact:true}).click();await content('ledger@example.com');await page.getByRole('button',{name:'Sheets 권한 요청',exact:true}).click();await content('Sheets 권한 다시 동의');}
  await page.goto(process.env.PAYLOG_BASE_URL || 'http://127.0.0.1:8081',{waitUntil:'networkidle'});
  await page.locator('#loading').waitFor({state:'detached'});await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await openConnection();await signIn();
  await scroll(5000);
  await page.getByRole('button',{name:'새 가계부 템플릿 만들기',exact:true}).click();
  await page.getByRole('button',{name:'가계부 생성·연결',exact:true}).click();
  await content('연결됨 · 모의 공유 원장');
  await tab('달력');await scroll(-5000);await content('Sheets · 모의 공유 원장');
  assert(!(await page.locator('body').ariaSnapshot()).includes('₩180,600'));
  await tab('등록');await scroll(-5000);
  await fill('거래 금액','25000');await fill('사용처','=SUM(A1:A2)');
  await scroll(5000);await page.getByRole('button',{name:'기록 저장하기',exact:true}).click();
  await content('저장 결과 다시 확인');assert.equal(appendCount,1);assert.equal(rows.length,2);
  assert.equal(rows[1][5],'=SUM(A1:A2)');assert.equal(rows[1][18],'카드');
  await page.getByRole('button',{name:'저장 결과 다시 확인',exact:true}).click();
  await content('Sheets 재조회까지 확인했습니다.');await scroll(-5000);await content('₩25,000');
  assert.equal(appendCount,1);
  await tab('통계');await scroll(5000);await content('₩25,000');
  const out=path.resolve(__dirname,'../apps/web/build/browser-smoke');fs.mkdirSync(out,{recursive:true});
  await tab('달력');await scroll(-5000);await page.screenshot({path:path.join(out,'sheets-calendar-mock.png')});
  await page.reload({waitUntil:'networkidle'});await page.locator('#loading').waitFor({state:'detached'});await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await content('₩180,600');await openConnection();await signIn();await scroll(5000);
  await fill('연결할 가계부 ID 또는 URL',id);
  await page.getByRole('button',{name:'기존 가계부 연결',exact:true}).click();await content('연결됨 · 모의 공유 원장');
  await tab('달력');await scroll(-5000);await content('₩25,000');assert.equal(appendCount,1);
  people[1][5]='viewer';await page.getByRole('button',{name:'원장 새로고침',exact:true}).click();
  await content('조회 전용 · 서울 시간 기준');
  await tab('등록');await scroll(5000);assert.equal(await page.getByRole('button',{name:'기록 저장하기',exact:true}).isEnabled(),false);
  await openConnection();await scroll(-5000);await page.getByRole('button',{name:'Google 연결 해제',exact:true}).click();
  await content('Google 로그인');await tab('달력');await scroll(-5000);await content('₩180,600');
  assert.deepEqual(errors,[]);
  console.log('PASS (mock only): template, Members UUID, sample isolation, unknown write + GET-only confirmation, calendar/statistics, reconnect, read-only UI, logout cache clearing');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
