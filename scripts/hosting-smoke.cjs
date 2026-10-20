const assert=require('node:assert/strict');
(async()=>{
 const base='http://127.0.0.1:5000';
 for(const route of ['/','/settings','/transaction/test-route']) {
  const response=await fetch(base+route);assert.equal(response.status,200);assert((await response.text()).includes('paylog'));
  assert.equal(response.headers.get('x-content-type-options'),'nosniff');
  assert.equal(response.headers.get('x-frame-options'),'DENY');
 }
 const js=await fetch(base+'/main.dart.js');assert.equal(js.status,200);assert.equal(js.headers.get('cache-control'),'public,max-age=0,must-revalidate');
 const manifest=await fetch(base+'/manifest.json');assert.equal(manifest.status,200);assert.equal((await manifest.json()).display,'standalone');
 console.log('PASS: Firebase Hosting emulator SPA routes, security/cache headers, PWA manifest');
})().catch(e=>{console.error(e);process.exit(1)});
