// Serve official Firebase modules to browser tests through validated HTTPS
// downloads, so CI/proxy certificate differences do not disable TLS checks.
const fs=require('node:fs');const path=require('node:path');const {spawnSync}=require('node:child_process');
const cache=path.resolve(__dirname,'../apps/web/build/firebase-auth-smoke-sdk');
async function firebaseSdkRoutes(target) {
 fs.mkdirSync(cache,{recursive:true});
 await target.route('https://www.gstatic.com/firebasejs/**',async route=>{
  const url=route.request().url();
  const match=/^https:\/\/www\.gstatic\.com\/firebasejs\/(\d+\.\d+\.\d+)\/(firebase-(?:app|auth|firestore|firestore-pipelines)\.js)$/.exec(url);
  if(!match)throw new Error('Unexpected Firebase SDK module');
  const file=path.join(cache,match[1]+'-'+match[2]);
  if(!fs.existsSync(file)) {
   const code='import urllib.request,sys\nwith urllib.request.urlopen(sys.argv[1],timeout=30) as r: data=r.read()\nopen(sys.argv[2],"wb").write(data)';
   const result=spawnSync('python3',['-c',code,url,file],{encoding:'utf8'});
   if(result.status!==0)throw new Error('Official Firebase SDK download failed');
  }
  await route.fulfill({path:file,contentType:'text/javascript',headers:{'access-control-allow-origin':'*'}});
 });
 await target.route('https://www.googletagmanager.com/**',route=>route.fulfill({body:'',contentType:'text/javascript'}));
}
module.exports={firebaseSdkRoutes};
