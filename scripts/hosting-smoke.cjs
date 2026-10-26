const assert=require('node:assert/strict');
(async()=>{
 const base='http://127.0.0.1:5000';
 for(const route of ['/','/settings','/transaction/test-route']) {
  const response=await fetch(base+route);assert.equal(response.status,200);assert((await response.text()).includes('paylog'));
  assert.equal(response.headers.get('x-content-type-options'),'nosniff');
  assert.equal(response.headers.get('x-frame-options'),'DENY');
 }
 for(const [route,title] of [['/privacy.html','개인정보처리방침'],['/terms.html','서비스 이용약관']]) {
  const response=await fetch(base+route);assert.equal(response.status,200);
  const html=await response.text();assert(html.includes('<h1>'+title+'</h1>'));
  assert(!html.includes('flutter_bootstrap.js'));
  assert(html.includes('https://github.com/duafyd/paylog/issues'));
  assert(html.includes('mailto:duafyd@gmail.com'));
  assert.equal(response.headers.get('cache-control'),'no-store');
 }
 const css=await fetch(base+'/legal.css');assert.equal(css.status,200);assert.match(css.headers.get('content-type'),/text\/css/);
 const js=await fetch(base+'/main.dart.js');assert.equal(js.status,200);assert.equal(js.headers.get('cache-control'),'public,max-age=0,must-revalidate');
 const manifest=await fetch(base+'/manifest.json');assert.equal(manifest.status,200);assert.equal((await manifest.json()).display,'standalone');
 console.log('PASS: Firebase Hosting emulator SPA routes, security/cache headers, PWA manifest');
})().catch(e=>{console.error(e);process.exit(1)});
