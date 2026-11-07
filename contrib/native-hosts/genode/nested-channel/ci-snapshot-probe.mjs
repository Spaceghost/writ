// Native I/O-only synthetic probe for the public-evidence snapshot helper.
// Creates and removes only its own private /tmp tree; no Genode or host scan.
import fs from 'node:fs';
import crypto from 'node:crypto';
import { spawn, spawnSync, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const script = fileURLToPath(new URL('./ci-snapshot.mjs', import.meta.url));
const names = ['identity.txt','input-sha256.txt','tool-identity.txt','clang-resource-sha256.txt',
  'genode-git-status.txt','genode-archive-comparison.txt','genode-archive-git-status.txt','genode-commit.txt',
  'environment.txt','source-sha256.txt','overlay-sha256.txt','generated-sha256.txt','original.run','actual.run',
  'config-sha256.txt','negative.diff','build.conf','tools.conf','build-config-sha256.txt','run.log.gz',
  'run-meta.json','run-audit.json','run-status.txt','boot-inputs-sha256.txt','installed-config.txt','observed.txt',
  'fixture-post-status.txt','fixture-post-manifest.txt','setup.log','driver-status.txt'];
const root = fs.mkdtempSync('/tmp/writ-snapshot-probe-');
try {
  for (const kind of ['positive','negative','missing','partial','symlink','fifo','hardlink','oversize','wrong-directory','changed-after-audit']) {
    const dir = path.join(root, kind); const raw = path.join(dir, 'raw'); const out = path.join(dir, 'out');
    fs.mkdirSync(dir); fs.mkdirSync(raw); fs.mkdirSync(out);
    for (const name of names) {
      if (!(name === 'negative.diff' && kind === 'positive')) fs.writeFileSync(path.join(raw, name), 'synthetic\n');
    }
    const log = path.join(raw, 'run.log.gz');
    const synthetic=fs.readFileSync(log);
    const compressed={bytes:synthetic.length,sha256:crypto.createHash('sha256').update(synthetic).digest('hex')};
    const rawIdentity={bytes:1,sha256:'0'.repeat(64)};
    fs.writeFileSync(path.join(raw, 'run-meta.json'), JSON.stringify({capture:'complete',compressed,raw:rawIdentity}));
    fs.writeFileSync(path.join(raw, 'run-audit.json'), JSON.stringify({audit:'complete',compressed,raw:rawIdentity}));
    if (kind === 'missing') fs.unlinkSync(log);
    if (kind === 'partial') { fs.unlinkSync(log); fs.writeFileSync(path.join(raw, 'run.log.gz.partial'), 'partial synthetic'); }
    if (kind === 'symlink') { fs.unlinkSync(log); fs.writeFileSync(path.join(dir, 'sentinel'), 'private synthetic\n'); fs.symlinkSync(path.join(dir, 'sentinel'), log); }
    if (kind === 'fifo') { fs.unlinkSync(log); execFileSync('mkfifo', [log]); }
    if (kind === 'hardlink') { fs.unlinkSync(log); fs.writeFileSync(path.join(dir, 'sentinel'), 'synthetic\n'); fs.linkSync(path.join(dir, 'sentinel'), log); }
    if (kind === 'oversize') fs.truncateSync(log, 545259521);
    if (kind === 'changed-after-audit') fs.writeFileSync(log, 'different synthetic bytes');
    const stat = fs.statSync(raw, { bigint: true });
    const id = kind === 'wrong-directory' ? `${stat.dev}:${stat.ino + 1n}:${stat.uid}` : `${stat.dev}:${stat.ino}:${stat.uid}`;
    const result = spawnSync(process.execPath, [script, raw, out, id, kind === 'positive' ? 'positive' : 'negative'],
      { timeout: 5000, encoding: 'utf8' });
    const expected = kind === 'positive' || kind === 'negative' ? 0 : 1;
    if (result.status !== expected) throw new Error(`${kind}: expected ${expected}, observed ${result.status}: ${result.stderr}`);
    if (kind === 'symlink' && fs.existsSync(path.join(out, 'run.log.gz'))) throw new Error('symlink target was copied');
    if (kind === 'partial' && (!fs.existsSync(path.join(out, 'run.log.gz.partial')) || fs.existsSync(path.join(out, 'run.log.gz')))) throw new Error('partial log was not retained as partial');
    if (kind === 'changed-after-audit' && (!fs.existsSync(path.join(out, 'run.log.gz.unverified')) || fs.existsSync(path.join(out, 'run.log.gz')))) throw new Error('changed log was not retained as unverified');
    console.log(`${kind}: ${expected === 0 ? 'accepted' : 'refused'}`);
  }
  // Mutate our own source on the same inode during its snapshot.
  {
    const dir = path.join(root, 'in-place'); const raw = path.join(dir, 'raw'); const out = path.join(dir, 'out');
    fs.mkdirSync(dir); fs.mkdirSync(raw); fs.mkdirSync(out);
    for (const name of names) fs.writeFileSync(path.join(raw, name), 'synthetic\n');
    const log = path.join(raw, 'run.log.gz'); const inode = fs.statSync(log, {bigint:true}).ino;
    const hook = path.join(dir, 'hook.cjs');
    fs.writeFileSync(hook, `const fs=require('fs'); const original=fs.writeSync; let done=false; fs.writeSync=function(fd,...args){ let target=''; try{ target=fs.readlinkSync('/proc/self/fd/'+fd); }catch{} if(!done && target.endsWith('/.run.log.gz.snapshot.tmp')){ done=true; const f=fs.openSync(${JSON.stringify(log)},'r+'); try{ original.call(fs,f,Buffer.from('X'),0,1,0); } finally{ fs.closeSync(f); } fs.utimesSync(${JSON.stringify(log)},1,1); } return original.call(fs,fd,...args); };`);
    const st=fs.statSync(raw,{bigint:true}); const id=`${st.dev}:${st.ino}:${st.uid}`;
    const result=spawnSync(process.execPath,[script,raw,out,id,'negative'],
      {env:{PATH:'/usr/bin:/bin',NODE_OPTIONS:`--require=${hook}`},timeout:5000,encoding:'utf8'});
    if (result.status !== 1 || fs.existsSync(path.join(out, 'run.log.gz')) || fs.statSync(log, {bigint:true}).ino !== inode) {
      throw new Error('same-inode mutation was not refused');
    }
    console.log('same-inode snapshot mutation: refused');
  }
  // Freeze our own synthetic snapshot while it is writing an unallowlisted
  // temporary file, then terminate only that direct test child.
  const dir = path.join(root, 'mid-copy'); const raw = path.join(dir, 'raw'); const out = path.join(dir, 'out');
  fs.mkdirSync(dir); fs.mkdirSync(raw); fs.mkdirSync(out);
  for (const name of names) fs.writeFileSync(path.join(raw, name), 'synthetic\n');
  const marker = path.join(dir, 'blocked'); const hook = path.join(dir, 'hook.cjs');
  fs.writeFileSync(hook, `const fs=require('fs'); const original=fs.writeSync; fs.writeSync=function(fd,...args){ let target=''; try{ target=fs.readlinkSync('/proc/self/fd/'+fd); }catch{} if(target.endsWith('/.run.log.gz.snapshot.tmp')){ fs.writeFileSync(${JSON.stringify(marker)},'blocked'); Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,30000); } return original.call(fs,fd,...args); };`);
  const st=fs.statSync(raw,{bigint:true}); const id=`${st.dev}:${st.ino}:${st.uid}`;
  const child=spawn(process.execPath,[script,raw,out,id,'negative'],{env:{PATH:'/usr/bin:/bin',NODE_OPTIONS:`--require=${hook}`},stdio:'ignore'});
  const exited=new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',(code,signal)=>resolve({code,signal}));});
  let waiting=0; while(!fs.existsSync(marker) && waiting<5000){ await new Promise(r=>setTimeout(r,20)); waiting+=20; }
  if (!fs.existsSync(marker)) { child.kill('SIGKILL'); await exited; throw new Error('mid-copy hook was not reached'); }
  child.kill('SIGKILL'); const stop=await exited;
  if (stop.signal !== 'SIGKILL' || fs.existsSync(path.join(out, 'run.log.gz')) ||
      !fs.existsSync(path.join(out, '.run.log.gz.snapshot.tmp'))) throw new Error('mid-copy timeout published an unfinished log');
  console.log('mid-copy timeout: unfinished staged file was not promoted');
  {
    const dir2=path.join(root,'before-binding'), raw2=path.join(dir2,'raw'), out2=path.join(dir2,'out');
    fs.mkdirSync(dir2); fs.mkdirSync(raw2); fs.mkdirSync(out2);
    for (const name of names) fs.writeFileSync(path.join(raw2,name),'synthetic\n');
    const marker2=path.join(dir2,'blocked'), hook2=path.join(dir2,'hook.cjs');
    const metaTarget=path.join(out2,'run-meta.json');
    fs.writeFileSync(hook2, `const fs=require('fs'); const original=fs.openSync; fs.openSync=function(p,...args){ let target=''; try{ target=fs.realpathSync(p); }catch{} if(target===${JSON.stringify(metaTarget)}){ fs.writeFileSync(${JSON.stringify(marker2)},'blocked'); Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,30000); } return original.call(fs,p,...args); };`);
    const st2=fs.statSync(raw2,{bigint:true}), id2=`${st2.dev}:${st2.ino}:${st2.uid}`;
    const child2=spawn(process.execPath,[script,raw2,out2,id2,'negative'],{env:{PATH:'/usr/bin:/bin',NODE_OPTIONS:`--require=${hook2}`},stdio:'ignore'});
    const exited2=new Promise((resolve,reject)=>{child2.once('error',reject);child2.once('exit',(code,signal)=>resolve({code,signal}));});
    let waiting2=0; while(!fs.existsSync(marker2) && waiting2<5000){ await new Promise(r=>setTimeout(r,20)); waiting2+=20; }
    if (!fs.existsSync(marker2)) { child2.kill('SIGKILL'); await exited2; throw new Error('pre-binding hook was not reached'); }
    child2.kill('SIGKILL'); const stop2=await exited2;
    if (stop2.signal !== 'SIGKILL' || fs.existsSync(path.join(out2,'run.log.gz')) ||
        fs.existsSync(path.join(out2,'run.log.gz.unverified')) ||
        !fs.existsSync(path.join(out2,'.run.log.gz.snapshot.tmp'))) throw new Error('pre-binding timeout published an unaudited log');
    console.log('pre-binding timeout: copied gzip was not promoted');
  }
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}
