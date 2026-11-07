#!/usr/bin/env python3
"""Compile bounded writer mutants only in a test-owned temporary directory."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
SOURCES = ('read-held.c', 'read-held.h', 'read-held-internal.h', 'layout.h',
           'config-reference.h', 'publish.c', 'publish.h', 'observe.h')
with tempfile.TemporaryDirectory(prefix='writ-publish-mutants-', dir='/tmp') as directory:
    scratch = Path(directory)
    for name in SOURCES: shutil.copyfile(HERE / name, scratch / name)
    writer = scratch / 'publish.c'
    original = writer.read_text(encoding='utf-8')
    mutants = (
        ('eintr_retry_removed', 'if (n < 0 && errno == EINTR) continue;',
         'if (n < 0 && errno == EINTR) return false;', 'partial writes and EINTR stage 1'),
        ('short_write_not_retried', 'offset += (size_t)n;',
         'offset = length;', 'partial writes and EINTR stage 1'),
    )
    for label, before, after, expected in mutants:
        assert original.count(before) == 1
        writer.write_text(original.replace(before, after), encoding='utf-8')
        library = scratch / (label + '.so')
        subprocess.run(['cc', '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-fPIC', '-shared',
                        '-DWRIT_BOOT_READ_TESTING', '-DWRIT_BOOT_PUBLISH_TESTING',
                        str(scratch / 'read-held.c'), str(writer), '-lcrypto', '-o', str(library)],
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        run = subprocess.run([sys.executable, str(HERE / 'test-publish.py'), str(library)],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60, check=False)
        assert run.returncode == 1 and expected.encode() in run.stderr, label
        print('PASS ' + label + ' rejected by named short-write/EINTR assertion')
print('PASS 2 synthetic publication mutation controls')
