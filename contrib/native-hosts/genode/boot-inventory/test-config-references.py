#!/usr/bin/env python3
"""Check fixed public references and two isolated compiler mutants offline."""
import ctypes
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from zipfile import ZipFile

if len(sys.argv) != 2:
    raise SystemExit('usage: test-config-references.py TEST_SHARED_LIBRARY')
lib = ctypes.CDLL(sys.argv[1])
lib.writ_read_test_reference.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lib.writ_read_test_reference.restype = ctypes.POINTER(ctypes.c_ubyte)
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PINS = (
    ('positive', 1, 1710, '2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22'),
    ('negative', 2, 1668, 'e2f60b4d32db4ab16259b4e5da762cf4a17ff919aad86cb9e41061c87d27865a'),
)
checks = 0

def check(value, name):
    global checks
    assert value, name
    checks += 1
    print('PASS ' + name)

for scenario, number, expected_size, expected_hash in PINS:
    length = ctypes.c_size_t()
    address = lib.writ_read_test_reference(number, ctypes.byref(length))
    check(bool(address) and length.value == expected_size, scenario + ' compiled size')
    compiled = ctypes.string_at(address, length.value)
    argument = (ROOT / 'contrib/native-hosts/genode/nested-channel' /
                ('writ_guard_' + scenario + '.args')).read_bytes()
    with ZipFile(ROOT / 'verification/genode-route-retry-42361441863/raw' / (scenario + '.zip')) as archive:
        info = archive.getinfo('installed-config.txt')
        check(info.file_size == expected_size and info.file_size <= 16384, scenario + ' archive size')
        archived = archive.read(info)
    check(compiled == argument + b'\n' == archived, scenario + ' exact argument and archive bytes')
    check(hashlib.sha256(compiled).hexdigest() == expected_hash, scenario + ' fixed installed hash')
    check(compiled.isascii() and b'\0' not in compiled and compiled.endswith(b'\n\n'), scenario + ' byte framing')
    # Change only a separately created test-owned source after the compiled
    # reference has been observed; the immutable expected bytes stay fixed.
    with tempfile.TemporaryDirectory(prefix='writ-reference-source-', dir='/tmp') as directory:
        copy = Path(directory) / 'argument'
        copy.write_bytes(argument)
        changed_source = bytearray(copy.read_bytes())
        changed_source[0] ^= 1
        copy.write_bytes(changed_source)
        check(compiled == archived and compiled != copy.read_bytes() + b'\n',
              scenario + ' changed test-owned source copy does not alter compiled constant')

length = ctypes.c_size_t(123)
check(not bool(lib.writ_read_test_reference(3, ctypes.byref(length))) and length.value == 0,
      'unknown reference scenario refused')

sources = ('layout.c', 'layout.h', 'layout-internal.h', 'read-held.c', 'read-held.h',
           'read-held-internal.h', 'observe.c', 'observe.h', 'config-reference.h')
with tempfile.TemporaryDirectory(prefix='writ-config-mutants-', dir='/tmp') as directory:
    scratch = Path(directory)
    for name in sources:
        shutil.copyfile(HERE / name, scratch / name)

    def build_and_expect(label, expected_failure):
        library = scratch / (label + '.so')
        command = ['cc', '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-fPIC', '-shared',
                   '-DWRIT_BOOT_LAYOUT_TESTING', '-DWRIT_BOOT_OBSERVE_TESTING', '-DWRIT_BOOT_READ_TESTING',
                   str(scratch / 'layout.c'), str(scratch / 'read-held.c'), str(scratch / 'observe.c'),
                   '-lcrypto', '-o', str(library)]
        subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        result = subprocess.run([sys.executable, str(HERE / 'test-observe.py'), str(library)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60, check=False)
        check(result.returncode == 1 and expected_failure.encode() in result.stderr,
              label + ' rejected by named observer assertion')

    # Corrupt one embedded positive byte only; the archived input remains unchanged.
    header = scratch / 'config-reference.h'
    text = header.read_text(encoding='ascii')
    pos = text.index('0x', text.index('writ_config_positive[]'))
    old = int(text[pos + 2:pos + 4], 16)
    text = text[:pos + 2] + f'{old ^ 1:02x}' + text[pos + 4:]
    header.write_text(text, encoding='ascii')
    build_and_expect('mutated_reference', 'positive ordered same-FD observation')

    # Restore the header, then remove only the byte-comparison predicate.
    shutil.copyfile(HERE / 'config-reference.h', header)
    reader = scratch / 'read-held.c'
    text = reader.read_text(encoding='utf-8')
    predicate = 'memcmp(buffer, reference + (size_t)got, (size_t)r)'
    assert text.count(predicate) == 1
    reader.write_text(text.replace(predicate, '0 /* test-only comparison bypass */'), encoding='utf-8')
    build_and_expect('comparison_bypass', 'config first byte mutation rejected')

    # Keep comparison intact but hash a shifted, shorter chunk. The normal
    # positive assertion independently checks the stream fingerprints/digest.
    shutil.copyfile(HERE / 'read-held.c', reader)
    text = reader.read_text(encoding='utf-8')
    call = 'digest_chunk(ctx, buffer, (size_t)r'
    assert text.count(call) == 1
    reader.write_text(text.replace(call, 'digest_chunk(ctx, buffer + 1, (size_t)r - 1'), encoding='utf-8')
    build_and_expect('shifted_hash_input', 'positive ordered same-FD observation')
print(f'PASS {checks} public reference and mutation controls')
