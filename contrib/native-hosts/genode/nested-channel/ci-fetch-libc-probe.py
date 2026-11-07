#!/usr/bin/env python3
"""Offline mock-curl checks of pinned-input download and fallback mechanics."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile

here = Path(__file__).resolve().parent
original = (here/'ci-fetch-libc.sh').read_text()
good = b'gooddata'
pinned = '0da393ac2174168a71c1c527d1453e07372295187d05c288250800cb152a889b'
assert original.count(pinned) == 1 and original.count('writ_size=159564768') == 1
# Patch only the expected data identity in an external test copy so tiny
# synthetic files can exercise the real fixed-source transfer logic.
test_script = original.replace(pinned, hashlib.sha256(good).hexdigest()).replace('writ_size=159564768', 'writ_size=8')
MOCK = r'''#!/usr/bin/env python3
import os, pathlib, sys
args=sys.argv[1:]
assert args[0] == "-q"
assert "--proto" in args and args[args.index("--proto")+1] == "=https"
assert "--proto-redir" in args and args[args.index("--proto-redir")+1] == "=https"
assert args[args.index("--retry")+1] == "0" and args[args.index("--max-time")+1] == "600"
assert args[args.index("--max-filesize")+1] == "8"
url=args[-1]; label="primary" if "archive.freebsd.org" in url else "fallback"
with open(os.environ["WRIT_MOCK_CALLS"],"a") as f: f.write(label+"\n")
scenario=os.environ["WRIT_MOCK_CASE"]
data = b"gooddata"
if scenario == "both-fail" or (scenario == "transport-fallback" and label == "primary"):
 pathlib.Path(args[args.index("--output")+1]).write_bytes(b"partial")
 print("synthetic transfer failure",file=sys.stderr); sys.exit(28)
if scenario in ("both-badhash", "badhash-fallback") and (scenario == "both-badhash" or label == "primary"):
 data=b"baddata!"
if scenario == "short-fallback" and label == "primary": data=b"short"
if scenario == "oversize-fallback" and label == "primary": data=b"oversize!"
pathlib.Path(args[args.index("--output")+1]).write_bytes(data)
print("http_code=200\neffective_url="+url)
'''

with tempfile.TemporaryDirectory(prefix='writ-libc-fetch-probe-') as name:
    root=Path(name); bindir=root/'bin'; bindir.mkdir(); mock=bindir/'curl'; mock.write_text(MOCK); mock.chmod(0o755)
    script=root/'fetch.sh'; script.write_text(test_script); script.chmod(0o755)
    for case, expected, calls in [('primary-good', True, ['primary']), ('transport-fallback', True, ['primary','fallback']),
                                  ('badhash-fallback', True, ['primary','fallback']), ('short-fallback', True, ['primary','fallback']),
                                  ('oversize-fallback', True, ['primary','fallback']), ('both-fail', False, ['primary','fallback']),
                                  ('both-badhash', False, ['primary','fallback'])]:
        case_root=root/case; case_root.mkdir(); inputs=case_root/'inputs'; inputs.mkdir(); evidence=case_root/'evidence'; evidence.mkdir()
        calls_file=case_root/'calls'
        env={**os.environ,'PATH':str(bindir)+':/usr/bin:/bin','WRIT_MOCK_CALLS':str(calls_file),'WRIT_MOCK_CASE':case}
        run=subprocess.run([str(script),str(inputs),str(evidence)],env=env,capture_output=True,timeout=10)
        assert (run.returncode == 0) == expected, (case,run.stderr)
        assert calls_file.read_text().splitlines()==calls, case
        target=inputs/'libc.txz'; meta=(evidence/'libc-fetch.txt').read_text()
        assert target.exists() == expected, case
        if expected:
            assert target.read_bytes()==good and 'result=verified' in meta
            assert 'selected='+calls[-1] in meta
        else: assert 'overall=incomplete' in meta
        assert not list(inputs.glob('*.partial'))
        if len(calls)==2: assert 'result=not_verified' in meta
        if case in ('transport-fallback', 'both-fail'): assert 'transfer_exit=28' in meta
        if case in ('badhash-fallback', 'both-badhash'): assert 'received_sha256=' in meta
        print(case, 'verified' if expected else 'incomplete')
    # Existing files are not overwritten or treated as successful inputs.
    inputs=root/'stale-input'; inputs.mkdir(); evidence=root/'stale-evidence'; evidence.mkdir()
    (inputs/'libc.txz').write_bytes(b'sentinel')
    env={**os.environ,'PATH':str(bindir)+':/usr/bin:/bin','WRIT_MOCK_CALLS':str(root/'unused'),'WRIT_MOCK_CASE':'primary-good'}
    run=subprocess.run([str(script),str(inputs),str(evidence)],env=env,capture_output=True,timeout=10)
    assert run.returncode != 0 and (inputs/'libc.txz').read_bytes()==b'sentinel' and not (root/'unused').exists()
    print('existing target: refused')
    inputs=root/'stale-partial-input'; inputs.mkdir(); evidence=root/'stale-partial-evidence'; evidence.mkdir()
    sentinel=root/'sentinel'; sentinel.write_bytes(b'untouched')
    (inputs/'libc.primary.partial').symlink_to(sentinel)
    calls=root/'stale-partial-calls'
    env={**os.environ,'PATH':str(bindir)+':/usr/bin:/bin','WRIT_MOCK_CALLS':str(calls),'WRIT_MOCK_CASE':'primary-good'}
    run=subprocess.run([str(script),str(inputs),str(evidence)],env=env,capture_output=True,timeout=10)
    assert run.returncode == 0 and sentinel.read_bytes()==b'untouched'
    assert calls.read_text().splitlines()==['fallback'] and (inputs/'libc.txz').read_bytes()==good
    assert 'reason=existing_partial' in (evidence/'libc-fetch.txt').read_text()
    print('existing partial symlink: untouched; fallback verified')
print('offline mock transfers only; no network used')
