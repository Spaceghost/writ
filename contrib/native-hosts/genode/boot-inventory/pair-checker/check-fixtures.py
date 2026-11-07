#!/usr/bin/env python3
"""Independently audit the fixed public Bend fixture literals with hashlib."""
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent

def functions(path):
    text = path.read_text(encoding='utf-8')
    found = {}
    for match in re.finditer(r'^def ([A-Za-z0-9_]+)\(\) -> String:\n((?:  ".*\n)+)', text, re.M):
        parts = []
        for line in match.group(2).splitlines():
            literal = line.strip().removesuffix(' ++').replace('\\0', '\\u0000')
            parts.append(json.loads(literal))
        found[match.group(1)] = ''.join(parts)
    return found

fixtures = functions(HERE / 'Fixtures.bend')
feasibility = functions(HERE / 'Feasibility.bend')
checked = 0
intentional = 0
for name, manifest in fixtures.items():
    if not name.startswith('m_'): continue
    suffix = name[2:]
    status = fixtures['s_' + suffix]
    match = re.search(r'^manifest_sha256=([0-9a-f]{64})$', status, re.M)
    assert match, suffix
    actual = hashlib.sha256(manifest.encode('ascii')).hexdigest()
    expected_mismatch = suffix == 'wrong_status_hash' or suffix.startswith('hash_word_')
    assert (actual != match.group(1)) == expected_mismatch, suffix
    checked += 1
    intentional += expected_mismatch
status_only = 0
base_hash = hashlib.sha256(fixtures['m_positive'].encode('ascii')).hexdigest()
for name, status in fixtures.items():
    if not name.startswith('s_status_'): continue
    match = re.search(r'^manifest_sha256=([0-9a-fA-F]{64})$', status, re.M)
    assert match and match.group(1).lower() == base_hash, name
    status_only += 1
full = feasibility['full_fixture'].encode('ascii')
assert len(full) == 1462
assert hashlib.sha256(full).hexdigest() == '37cb576c943004fd734e21706951cd6470ab3f26ffb76ce0a5817e0e5eefdde3'
assert 'manifest_bytes=1462\n' in fixtures['s_full']
assert hashlib.sha256(full).hexdigest() in fixtures['s_full']
print(f'PASS {checked} fixed pair hashes independently checked ({intentional} intentional mismatches)')
print(f'PASS {status_only} status-only variants retain the intended base hash')
print('PASS 1462-byte maximum-width fixture and status hash independently checked')
