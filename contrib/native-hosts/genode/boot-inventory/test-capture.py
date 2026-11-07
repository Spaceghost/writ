#!/usr/bin/env python3
"""Owned synthetic temporary files and child only; no worker or host fixture."""
import ctypes
import os
from pathlib import Path
import socket
import sys
import tempfile

if len(sys.argv) != 2:
    raise SystemExit('usage: test-capture.py TEST_SHARED_LIBRARY')
lib = ctypes.CDLL(sys.argv[1])
class Snapshot(ctypes.Structure):
    _fields_ = [('manifest', ctypes.c_ubyte * 4096), ('status', ctypes.c_ubyte * 512),
                ('manifest_size', ctypes.c_uint32), ('status_size', ctypes.c_uint32)]
lib.writ_pair_capture.argtypes = [ctypes.c_int, ctypes.POINTER(Snapshot)]
lib.writ_pair_capture.restype = ctypes.c_int
HOOK = ctypes.CFUNCTYPE(None, ctypes.c_uint, ctypes.c_void_p)
lib.writ_capture_test_hook.argtypes = [HOOK, ctypes.c_void_p]
lib.writ_capture_test_fault.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.c_uint]
lib.writ_capture_test_io.argtypes = [ctypes.c_uint]
lib.writ_capture_test_replacement.argtypes = [ctypes.c_int]
lib.writ_capture_test_own_fault.argtypes = [ctypes.c_uint]
lib.writ_capture_test_manifest_pin.restype = ctypes.c_int
for name in ('writ_capture_test_steps', 'writ_capture_test_closes', 'writ_capture_test_data_opens', 'writ_capture_test_owns'):
    getattr(lib, name).restype = ctypes.c_uint
count = 0

def trial(name, manifest=b'abc\0\xff', status=b'synthetic', expect=1, setup=None, callback=None,
          fault=0, close_at=0, chunk=0, io=0, dir_case=None, expected_phase=None, quiet=False, own_fault=0):
    global count
    with tempfile.TemporaryDirectory(prefix='writ-pair-capture-', dir='/tmp') as temp:
        root = Path(temp)
        m, s = root/'public-manifest.txt', root/'public-status.txt'
        m.write_bytes(manifest); s.write_bytes(status)
        os.chmod(m, 0o600); os.chmod(s, 0o600)
        extra = []
        errors = []
        phases = []
        if setup: setup(root, m, s, extra)
        fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        if dir_case == 'inheritable': os.set_inheritable(fd, True)
        if dir_case == 'mode': os.chmod(root, 0o755)
        use_fd = -1 if dir_case == 'missing' else fd
        def run_hook(phase, _):
            try:
                phases.append(phase)
                if callback: callback(phase, root, m, s)
            except BaseException as e:
                errors.append(repr(e))
        hook = HOOK(run_hook) if callback else HOOK()
        lib.writ_capture_test_hook(hook, None)
        lib.writ_capture_test_fault(fault, close_at, chunk)
        lib.writ_capture_test_io(io)
        lib.writ_capture_test_own_fault(own_fault)
        replacement = -1
        if io == 7:
            replacement = os.open(s, os.O_RDONLY | os.O_CLOEXEC)
        lib.writ_capture_test_replacement(replacement)
        result = Snapshot()
        ctypes.memset(ctypes.byref(result), 0xa5, ctypes.sizeof(result))
        before = len(os.listdir('/proc/self/fd'))
        actual = lib.writ_pair_capture(use_fd, ctypes.byref(result))
        steps = lib.writ_capture_test_steps(); closes = lib.writ_capture_test_closes()
        opens = lib.writ_capture_test_data_opens()
        owns = lib.writ_capture_test_owns()
        assert not errors, (name, errors)
        assert actual == expect, (name, actual, expect, steps, closes)
        if expected_phase is not None: assert expected_phase in phases, (name, phases)
        if expect == 1:
            assert bytes(result.manifest[:result.manifest_size]) == manifest, name
            assert bytes(result.status[:result.status_size]) == status, name
            assert result.manifest_size == len(manifest) and result.status_size == len(status), name
            assert not any(result.manifest[result.manifest_size:]) and not any(result.status[result.status_size:]), name
        else:
            assert bytes(result) == bytes(ctypes.sizeof(result)), name
        assert len(os.listdir('/proc/self/fd')) == before, name
        os.fstat(fd)
        os.close(fd)
        if replacement >= 0: os.close(replacement)
        for item in extra: item.close()
        lib.writ_capture_test_hook(HOOK(), None)
        count += 1
        if not quiet: print('PASS', name)
        return steps, closes, opens, owns

with tempfile.TemporaryDirectory(prefix='writ-pair-null-', dir='/tmp') as temp:
    fd = os.open(temp, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    assert lib.writ_pair_capture(fd, None) == 0
    os.fstat(fd); os.close(fd)
    count += 1
print('PASS null result refuses and leaves borrowed FD open')
trial('empty byte snapshots', b'', b'')
trial('binary bytes preserve NUL and 255', bytes(range(256)), bytes(range(255, -1, -1)))
trial('both exact caps and short reads', bytes(range(256))*16, bytes(range(256))*2, chunk=7)
trial('arbitrary malformed snapshots', b'not a schema', b'not a status')
trial('manifest cap plus one', b'x'*4097, b'', expect=0)
trial('status cap plus one', b'', b'x'*513, expect=0)
trial('single interrupted read recovers', io=1)
trial('early EOF refuses', io=2, expect=0)
trial('growth EOF probe refuses', io=3, expect=0)
trial('repeated EINTR bounded', io=4, expect=0)
for mode, name in ((5, 'wrong procfs'), (6, 'wrong PID view'), (7, 'reopen inode mismatch'),
                   (8, 'cross-mount refusal'), (9, 'unsupported syscall'),
                   (10, 'wrong owner simulation'), (11, 'device classification simulation')):
    _, _, opened, _ = trial(name, io=mode, expect=0)
    if mode in (5, 6, 8, 9, 10, 11): assert opened == 0, name
for case in ('inheritable', 'mode', 'missing'):
    trial('borrowed directory '+case, dir_case=case, expect=0)

def missing(root, m, s, extra): m.unlink()
def symlink(root, m, s, extra): m.unlink(); m.symlink_to(s.name)
def fifo(root, m, s, extra): m.unlink(); os.mkfifo(m, 0o600)
def subdir(root, m, s, extra): m.unlink(); m.mkdir()
def wrongmode(root, m, s, extra): os.chmod(m, 0o644)
def hardlink(root, m, s, extra): os.link(m, root/'extra')
def sock(root, m, s, extra):
    m.unlink(); x = socket.socket(socket.AF_UNIX); x.bind(str(m)); extra.append(x)
for label, fn in [('missing', missing), ('symlink', symlink), ('FIFO', fifo), ('directory', subdir),
                  ('wrong mode', wrongmode), ('hardlink', hardlink), ('socket', sock)]:
    for selected in ('manifest', 'status'):
        def setup_side(root, m, s, extra, selected=selected, fn=fn):
            fn(root, m if selected == 'manifest' else s, s if selected == 'manifest' else m, extra)
        _, _, opens, _ = trial('nonregular or invalid '+selected+' '+label, setup=setup_side, expect=0)
        assert opens == 0, label

def replace(which, phase, with_symlink=False):
    state = [False]
    def action(current, root, m, s):
        if current != phase or state[0]: return
        state[0] = True
        target = m if which == 'manifest' else s
        target.rename(root/'held-old')
        if with_symlink: target.symlink_to('held-old')
        else:
            target.write_bytes(b'replacement')
            os.chmod(target, 0o600)
    return action
for which in ('manifest', 'status'):
    for phase in (3, 4):
        for link in (False, True):
            trial(f'{which} replacement after phase {phase} link={link}',
                  callback=replace(which, phase, link), expected_phase=phase, expect=0)

def mutate(which, phase):
    done = [False]
    def action(current, root, m, s):
        if current != phase or done[0]: return
        done[0] = True
        target = m if which == 'manifest' else s
        target.write_bytes(b'X' * len(target.read_bytes()))
    return action
for which in ('manifest','status'):
    trial(which+' in-place late mutation', callback=mutate(which, 4), expected_phase=4, expect=0)
trial('manifest during-read mutation', manifest=b'a'*40, chunk=7,
      callback=mutate('manifest', 2), expected_phase=2, expect=0)
def status_read_mutation():
    stage = [False, False]
    def action(phase, root, m, s):
        if phase == 3: stage[0] = True
        if phase == 2 and stage[0] and not stage[1]:
            stage[1] = True; s.write_bytes(b'X' * len(s.read_bytes()))
    return action
trial('status during-read mutation', status=b'b'*40, chunk=7,
      callback=status_read_mutation(), expected_phase=3, expect=0)
steps, closes, _, owns = trial('baseline failure-injection census', quiet=True)
for i in range(1, steps+1): trial(f'injected operation {i}', fault=i, expect=0, quiet=True)
print('PASS', steps, 'independent operation failures leave outputs zero and no owned FDs')
for i in range(1, closes+1): trial(f'injected close {i}', close_at=i, expect=-1, quiet=True)
print('PASS', closes, 'independent close uncertainties leave outputs zero and no owned FDs')
for i in range(1, owns+1): trial(f'injected acquisition identity {i}', own_fault=i, expect=-1, quiet=True)
print('PASS', owns, 'acquisition identity failures attempt one close and report cleanup unverified')
trial('acquisition identity plus close uncertainty', own_fault=1, close_at=1, expect=-1)
# Deliberately violate the trusted FD-table boundary using only owned FDs.
for same_inode in (False, True):
    with tempfile.TemporaryDirectory(prefix='writ-pair-sentinel-', dir='/tmp') as temp:
        root=Path(temp)
        for name in ('public-manifest.txt','public-status.txt','other'):
            p=root/name; p.write_bytes(b'owned public bytes'); os.chmod(p, 0o600)
        fd=os.open(root, os.O_RDONLY|os.O_DIRECTORY|os.O_CLOEXEC)
        sentinel=os.open(root/('public-manifest.txt' if same_inode else 'other'), os.O_PATH|os.O_CLOEXEC)
        replacement=[]
        def swap_hook(phase, _):
            if phase == 1:
                pin=lib.writ_capture_test_manifest_pin()
                os.dup2(sentinel, pin, inheritable=False)
                replacement.append(pin)
        cb=HOOK(swap_hook)
        lib.writ_capture_test_hook(cb, None); lib.writ_capture_test_fault(0,0,0)
        result=Snapshot(); ctypes.memset(ctypes.byref(result), 0xa5, ctypes.sizeof(result))
        actual=lib.writ_pair_capture(fd, ctypes.byref(result))
        assert len(replacement) == 1
        if same_inode:
            assert actual == 1
            try: os.fstat(replacement[0])
            except OSError as e: assert e.errno == 9
            else: raise AssertionError('same-inode replacement unexpectedly remained open')
        else:
            assert actual == -1 and bytes(result) == bytes(ctypes.sizeof(result))
            os.fstat(replacement[0]); os.close(replacement[0])
        os.fstat(sentinel); os.fstat(fd)
        os.close(sentinel); os.close(fd)
        lib.writ_capture_test_hook(HOOK(), None)
        count += 1
print('PASS different-inode replacement left open with cleanup unverified')
print('PASS known limitation: same-inode FD replacement closes and returns partial')
# Another deliberate stable-FD-table violation: close the pin before cleanup.
with tempfile.TemporaryDirectory(prefix='writ-pair-closed-', dir='/tmp') as temp:
    root=Path(temp)
    for name in ('public-manifest.txt','public-status.txt'):
        p=root/name; p.write_bytes(b'owned public bytes'); os.chmod(p, 0o600)
    fd=os.open(root, os.O_RDONLY|os.O_DIRECTORY|os.O_CLOEXEC)
    closed=[]
    def close_pin(phase, _):
        if phase == 1:
            pin=lib.writ_capture_test_manifest_pin(); os.close(pin); closed.append(pin)
    cb=HOOK(close_pin)
    lib.writ_capture_test_hook(cb, None); lib.writ_capture_test_fault(0,0,0)
    result=Snapshot(); ctypes.memset(ctypes.byref(result), 0xa5, ctypes.sizeof(result))
    assert lib.writ_pair_capture(fd, ctypes.byref(result)) == -1
    assert len(closed) == 1 and bytes(result) == bytes(ctypes.sizeof(result))
    os.fstat(fd); os.close(fd); lib.writ_capture_test_hook(HOOK(), None)
    count += 1
print('PASS closed pin produces cleanup unverified and zero output')
for phase in (1, 2, 3, 4, 5):
    with tempfile.TemporaryDirectory(prefix='writ-pair-child-', dir='/tmp') as temp:
        root=Path(temp)
        for name in ('public-manifest.txt','public-status.txt'):
            p=root/name; p.write_bytes(b'owned public bytes'); os.chmod(p, 0o600)
        fd=os.open(root, os.O_RDONLY|os.O_DIRECTORY|os.O_CLOEXEC)
        pid=os.fork()
        if pid == 0:
            def exit_hook(current, _):
                if current == phase: os._exit(73)
            cb=HOOK(exit_hook)
            lib.writ_capture_test_hook(cb, None); lib.writ_capture_test_fault(0,0,0)
            result=Snapshot()
            code=lib.writ_pair_capture(fd, ctypes.byref(result))
            os._exit(0 if code == 1 else 2)
        waited, state=os.waitpid(pid, 0)
        assert waited == pid and os.WIFEXITED(state) and os.WEXITSTATUS(state) == 73, phase
        os.fstat(fd); os.close(fd)
        count += 1
print('PASS child-local _exit at each of five phases, parent wait without signals')
print('ALL', count, 'SYNTHETIC PAIR CAPTURE CHECKS PASSED')
