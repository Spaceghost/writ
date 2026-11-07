#!/usr/bin/env python3
"""Fixed public synthetic capture-to-Bend test, not an execution supervisor.

Only test-owned temporary files are captured. The two hex environment values
and re-encoded stdout exist only in the child environment and bounded memory;
they must never carry secrets or be printed or saved as evidence. This test has
no enforced subprocess deadline. It sends no signals, and cleanup/wait can
block if a fixed trusted tool or its child hangs. It is not a production handoff.
"""
import ctypes
import hashlib
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile

if not __debug__:
    raise SystemExit('synthetic test requires Python assertions enabled')
if len(sys.argv) != 4:
    raise SystemExit('usage: test-handoff.py CAPTURE_TEST_LIBRARY BEND NODE')
lib_path, bend, node = map(os.path.abspath, sys.argv[1:])
here = Path(__file__).resolve().parent
entry = here / 'HandoffTest.bend'
fixture_manifest = (here / 'handoff-fixtures/manifest.txt').read_bytes()
fixture_status = (here / 'handoff-fixtures/status.txt').read_bytes()
lib = ctypes.CDLL(lib_path)

class Snapshot(ctypes.Structure):
    _fields_ = [('manifest', ctypes.c_ubyte * 4096), ('status', ctypes.c_ubyte * 512),
                ('manifest_size', ctypes.c_uint32), ('status_size', ctypes.c_uint32)]

lib.writ_handoff_test_layout.argtypes = [ctypes.c_uint]
lib.writ_handoff_test_layout.restype = ctypes.c_size_t
expected_layout = [ctypes.sizeof(Snapshot), Snapshot.manifest.offset, Snapshot.status.offset,
                   Snapshot.manifest_size.offset, Snapshot.status_size.offset,
                   ctypes.sizeof(ctypes.c_ubyte * 4096), ctypes.sizeof(ctypes.c_ubyte * 512),
                   ctypes.sizeof(ctypes.c_uint32), ctypes.sizeof(ctypes.c_uint32)]
assert [lib.writ_handoff_test_layout(i) for i in range(len(expected_layout))] == expected_layout, 'capture ABI mismatch'
lib.writ_pair_capture.argtypes = [ctypes.c_int, ctypes.POINTER(Snapshot)]
lib.writ_pair_capture.restype = ctypes.c_int
lib.writ_capture_test_fault.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.c_uint]

# These are fixed trusted test commands and fixed synthetic inputs, not a
# general command endpoint. Drain both pipes without unbounded accumulation.
# On excess output close the read pipes and wait: without a supervisor that
# wait may block, and no deadline or descendant cleanup is claimed.
def run_bounded(command, env, waited=None, closed=None):
    proc = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, env=env, close_fds=True)
    sel = None
    limits = {'stdout': 16384, 'stderr': 8192}
    buffers = {'stdout': bytearray(), 'stderr': bytearray()}
    overflow = False
    close_failed = False
    try:
        sel = selectors.DefaultSelector()
        for name in ('stdout', 'stderr'):
            pipe = getattr(proc, name)
            os.set_blocking(pipe.fileno(), False)
            sel.register(pipe, selectors.EVENT_READ, name)
        while sel.get_map():
            for key, _ in sel.select():
                name = key.data
                try:
                    chunk = os.read(key.fileobj.fileno(), min(4096, limits[name] + 1 - len(buffers[name])))
                except (BlockingIOError, InterruptedError):
                    continue
                if not chunk:
                    sel.unregister(key.fileobj); key.fileobj.close(); continue
                buffers[name].extend(chunk)
                if len(buffers[name]) > limits[name]:
                    overflow = True
                    break
            if overflow: break
    finally:
        if sel is not None:
            try: sel.close()
            except OSError: close_failed = True
        for pipe in (proc.stdout, proc.stderr):
            try: pipe.close()
            except OSError: close_failed = True
        if closed is not None: closed.append((proc.stdout.closed, proc.stderr.closed))
        # This reaps only our Popen child, sends no signal and may block forever.
        code = proc.wait()
        if waited is not None: waited.append(code)
        if close_failed: raise RuntimeError('fixed test pipe close failed')
    if overflow: raise RuntimeError('fixed test output exceeded its cap')
    return code, bytes(buffers['stdout']), bytes(buffers['stderr'])

calls = 0

def invoke(command, manifest, status, omit=None):
    global calls
    calls += 1
    env = {'BEND_NO_TELEMETRY': '1'}
    if omit != 'manifest': env['WRIT_SYNTHETIC_MANIFEST_HEX'] = manifest
    if omit != 'status': env['WRIT_SYNTHETIC_STATUS_HEX'] = status
    return run_bounded(command, env)


def expect_rejected(command, manifest, status, message, omit=None):
    code, out, err = invoke(command, manifest, status, omit)
    assert code == 2 and out == b'' and err == message, 'expected fixed decoder refusal'


def expect_result(result, manifest, status, expected):
    code, out, err = result
    assert code == 0 and err == b'', 'fixed Bend entry failed'
    expected_output = ('manifest=' + manifest.hex() + '\nstatus=' + status.hex() +
                       '\nresult=' + expected + '\n').encode('ascii')
    assert out == expected_output, 'Bend did not return exactly the captured bytes and outcome'


def write_fixed(root, name, data):
    fd = os.open(root / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(data)


def bounded_snapshot(snapshot):
    # ctypes slices silently truncate: prove each native length before slicing.
    assert snapshot.manifest_size <= 4096 and snapshot.status_size <= 512, 'capture length exceeds ABI cap'
    m = bytes(snapshot.manifest[:snapshot.manifest_size])
    s = bytes(snapshot.status[:snapshot.status_size])
    assert not any(snapshot.manifest[snapshot.manifest_size:])
    assert not any(snapshot.status[snapshot.status_size:])
    return m, s


def handoff(rc, snapshot, commands):
    # The actual capture result gates every invocation, not the test oracle.
    if rc != 1:
        assert bytes(snapshot) == bytes(ctypes.sizeof(snapshot)), 'failed capture returned partial bytes'
        return None
    m, s = bounded_snapshot(snapshot)
    return m, s, [invoke(command, m.hex(), s.hex()) for command in commands]


def trial(label, manifest, status, commands, outcome=None, fault_close=0, missing=False):
    before_calls = calls
    with tempfile.TemporaryDirectory(prefix='writ-pair-handoff-', dir='/tmp') as temp:
        root = Path(temp)
        if not missing: write_fixed(root, 'public-manifest.txt', manifest)
        write_fixed(root, 'public-status.txt', status)
        fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        try:
            snapshot = Snapshot()
            ctypes.memset(ctypes.byref(snapshot), 0xa5, ctypes.sizeof(snapshot))
            lib.writ_capture_test_fault(0, fault_close, 0)
            rc = lib.writ_pair_capture(fd, ctypes.byref(snapshot))
            lib.writ_capture_test_fault(0, 0, 0)
            got = handoff(rc, snapshot, commands)
            if outcome is None:
                assert rc == (-1 if fault_close else 0)
                assert calls == before_calls, 'capture failure must not launch Bend'
                assert got is None
            else:
                assert rc == 1 and got is not None
                m, s, results = got
                assert snapshot.manifest_size == len(manifest) and snapshot.status_size == len(status)
                assert m == manifest and s == status, 'native snapshot changed the fixed input'
                for result in results: expect_result(result, m, s, outcome)
                assert calls == before_calls + len(commands)
            os.fstat(fd)  # Capture borrows rather than closes this directory FD.
        finally:
            os.close(fd)
    print('PASS', label)


# The producer is a fixed test-only child, never a caller-selected command.
# Returned bytes are compared in memory and are not printed or retained.
emitter = str(here / 'emit-output-test.py')
for stream, cap in (('stdout', 16384), ('stderr', 8192)):
    waited = []
    code, out, err = run_bounded([sys.executable, emitter, stream + '-cap'], {}, waited)
    assert code == 0 and waited == [0]
    assert (out if stream == 'stdout' else err) == b'x' * cap
    assert (err if stream == 'stdout' else out) == b''
    waited = []
    try:
        run_bounded([sys.executable, emitter, stream + '-over'], {}, waited)
    except RuntimeError as exc:
        assert str(exc) == 'fixed test output exceeded its cap' and len(waited) == 1
    else:
        raise AssertionError('over-cap output was accepted')
print('PASS bounded stdout and stderr exact cap and cap plus one; direct children waited')

# Test selector setup failure after Popen; no signal or process scan is used.
selector_closed = []
class FailingSelector:
    def register(self, *_args): raise OSError('synthetic selector failure')
    def close(self): selector_closed.append(True)

original_selector = selectors.DefaultSelector
waited = []
closed = []
try:
    selectors.DefaultSelector = FailingSelector
    try:
        run_bounded([sys.executable, emitter, 'stdout-cap'], {}, waited, closed)
    except OSError as exc:
        assert str(exc) == 'synthetic selector failure' and len(waited) == 1
        assert closed == [(True, True)] and selector_closed == [True]
    else:
        raise AssertionError('selector failure not propagated')
finally:
    selectors.DefaultSelector = original_selector
print('PASS selector setup failure closes pipes and waits the direct child')

with tempfile.TemporaryDirectory(prefix='writ-pair-handoff-build-', dir='/tmp') as temp:
    js = str(Path(temp) / 'handoff.js')
    build_env = {'BEND_NO_TELEMETRY': '1'}
    code, out, err = run_bounded([bend, str(entry), '-o', js], build_env)
    assert code == 0 and out == b'' and err == b'', 'fixed Node build failed'
    with open(js, 'rb') as stream:
        generated = stream.read(8 * 1024 * 1024 + 1)
    assert len(generated) <= 8 * 1024 * 1024, 'generated test entry exceeds cap'
    print('generated test JS SHA-256', hashlib.sha256(generated).hexdigest())
    commands = ([bend, str(entry)], [node, js])
    # Forged ABI lengths exercise the actual success-result path before slicing
    # or launching. They are test-only values, not claims about native capture.
    for field, value in (('manifest_size', 4097), ('status_size', 513)):
        snapshot = Snapshot(); setattr(snapshot, field, value)
        before_calls = calls
        try:
            handoff(1, snapshot, commands)
        except AssertionError:
            pass
        else:
            raise AssertionError('oversized ABI result was not rejected')
        assert calls == before_calls
    print('PASS oversized ABI lengths rejected before slicing and invocation')
    trial('canonical positive pair', fixture_manifest, fixture_status, commands, 'PairSyntaxMatch')
    changed = bytearray(fixture_manifest); changed[0] ^= 1
    trial('changed manifest rejected', bytes(changed), fixture_status, commands, 'PairMalformed')
    changed_status = bytearray(fixture_status); changed_status[-2] = ord('g')
    trial('changed status rejected', fixture_manifest, bytes(changed_status), commands, 'PairMalformed')
    trial('swapped canonical pair exceeds status cap and does not launch', fixture_status, fixture_manifest, commands)
    trial('NUL LF high bytes preserved', bytes(range(256)), bytes(range(255, -1, -1)), commands, 'PairMalformed')
    trial('empty snapshots preserved', b'', b'', commands, 'PairMalformed')
    trial('both native caps preserved', bytes(range(256))*16, bytes(range(256))*2, commands, 'PairMalformed')
    trial('manifest syntax cap plus one preserved', b'a'*1467, fixture_status, commands, 'PairMalformed')
    trial('status syntax cap plus one preserved', fixture_manifest, b'a'*226, commands, 'PairMalformed')
    trial('manifest capture cap plus one does not launch', b'a'*4097, b'', commands)
    trial('status capture cap plus one does not launch', b'', b'a'*513, commands)
    trial('missing entry does not launch', b'', b'', commands, missing=True)
    trial('close uncertainty does not launch', b'a', b'b', commands, fault_close=1)
    for command in commands:
        expect_rejected(command, '00a', '', b'invalid synthetic hex\n')                 # Odd length.
        expect_rejected(command, '00AF', '', b'invalid synthetic hex\n')                # Uppercase.
        expect_rejected(command, '00gg', '', b'invalid synthetic hex\n')                # Non-hex.
        expect_rejected(command, '0'*8193, '', b'synthetic manifest hex exceeds cap\n')              # Manifest cap+1 character.
        expect_rejected(command, '00'*4097, '', b'synthetic manifest hex exceeds cap\n')             # Manifest cap+1 byte.
        expect_rejected(command, '', '0'*1025, b'synthetic status hex exceeds cap\n')              # Status cap+1 character.
        expect_rejected(command, '', '00'*513, b'synthetic status hex exceeds cap\n')              # Status cap+1 byte.
        missing = b'No such file or directory\n' if command[0] == bend else b'errno 2\n'
        expect_rejected(command, '', '', missing, omit='manifest')   # Missing is not empty.
        expect_rejected(command, '', '', missing, omit='status')
    print('PASS fixed decoder rejects malformed, oversized and missing hex on Bend and Node')
print('ALL SYNTHETIC PAIR HANDOFF CHECKS PASSED')
