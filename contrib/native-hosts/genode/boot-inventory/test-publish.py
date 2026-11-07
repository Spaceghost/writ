#!/usr/bin/env python3
"""Synthetic public staging on exclusive, test-owned temporary directories."""
import ctypes
import errno
import hashlib
import os
from pathlib import Path
import re
import shutil
import socket
import sys
import tempfile

if len(sys.argv) != 2:
    raise SystemExit('usage: test-publish.py TEST_SHARED_LIBRARY')
lib = ctypes.CDLL(sys.argv[1])
class Observation(ctypes.Structure):
    _fields_ = [('digest', (ctypes.c_ubyte * 32) * 14), ('size', ctypes.c_uint64 * 14)]
lib.writ_public_synthetic_publish.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64,
                                               ctypes.c_uint64, ctypes.POINTER(Observation)]
lib.writ_public_synthetic_publish.restype = ctypes.c_int
HOOK = ctypes.CFUNCTYPE(None, ctypes.c_int, ctypes.c_void_p)
lib.writ_publish_test_set_hook.argtypes = [HOOK, ctypes.c_void_p]
lib.writ_publish_test_fault.argtypes = [ctypes.c_int, ctypes.c_int]
lib.writ_publish_test_append_count.restype = ctypes.c_uint
lib.writ_read_test_close_at.argtypes = [ctypes.c_uint]
lib.writ_read_test_close_count.restype = ctypes.c_uint
NAMES = ('config', 'core', 'hpet_timer', 'init', 'init.hsd', 'init.xsd', 'ld.lib.so',
         'libc.lib.so', 'libm.lib.so', 'timer', 'vfs.lib.so', 'vfs_pipe.lib.so',
         'writ_bend_monitor', 'writ_channel_client')
FIXED = {
    'positive': (1710, '2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22'),
    'negative': (1668, 'e2f60b4d32db4ab16259b4e5da762cf4a17ff919aad86cb9e41061c87d27865a'),
}
FILES = ('public-manifest.tmp', 'public-manifest.txt', 'public-status.tmp', 'public-status.txt')
checks = 0

def observation(scenario):
    result = Observation()
    result.size[0] = FIXED[scenario][0]
    for i, b in enumerate(bytes.fromhex(FIXED[scenario][1])): result.digest[0][i] = b
    for i in range(1, 14):
        result.size[i] = i * 17
        for j in range(32): result.digest[i][j] = (i + j) & 255
    return result

def expected_pair(scenario, run, attempt, obs):
    lines = ['WRIT-PUBLIC-BOOT-MANIFEST-V1', 'scenario=' + scenario,
             'run=' + str(run), 'attempt=' + str(attempt)]
    for i, name in enumerate(NAMES):
        lines.append(f'{name} size={obs.size[i]} sha256={bytes(obs.digest[i]).hex()}')
    manifest = ('\n'.join(lines) + '\n').encode('ascii')
    status = ('WRIT-PUBLIC-BOOT-STATUS-V1\nstatus=synthetic-partial\nscenario=' + scenario +
              '\nrun=' + str(run) + '\nattempt=' + str(attempt) +
              '\nmanifest_bytes=' + str(len(manifest)) + '\nmanifest_sha256=' +
              hashlib.sha256(manifest).hexdigest() + '\n').encode('ascii')
    return manifest, status

def reset():
    lib.writ_publish_test_set_hook(HOOK(), None)
    lib.writ_publish_test_fault(0, 0)
    lib.writ_read_test_close_at(0)

def trial(name, scenario='positive', run=0, attempt=0, mutate=None, fault=0, stage=0,
          expected=1, hook=None, sentinel=None, inheritable=False, quiet=False, read_close_at=0, post=None, scenario_id=None, unsafe_mode=False, expect_empty=False, known_post_drift=False):
    global checks
    with tempfile.TemporaryDirectory(prefix='writ-public-stage-', dir='/tmp') as directory:
        root = Path(directory)
        os.chmod(root, 0o700)
        fd = os.open(root, os.O_PATH | os.O_DIRECTORY | os.O_CLOEXEC)
        callback = None
        errors = []
        sock = None
        try:
            if inheritable: os.set_inheritable(fd, True)
            if unsafe_mode: os.chmod(root, 0o755)
            obs = observation(scenario)
            if mutate: mutate(obs)
            if sentinel:
                filename, kind = sentinel
                path = root / filename
                if kind == 'file': path.write_bytes(b'owned sentinel')
                elif kind == 'symlink': path.symlink_to(root / 'missing')
                elif kind == 'fifo': os.mkfifo(path)
                elif kind == 'socket':
                    sock = socket.socket(socket.AF_UNIX); sock.bind(str(path))
                before_stat = path.lstat()
            else:
                path = None
            if hook:
                def run_hook(phase, _arg):
                    try: hook(phase, root)
                    except BaseException as exc: errors.append(exc)
                callback = HOOK(run_hook)
                lib.writ_publish_test_set_hook(callback, None)
            lib.writ_publish_test_fault(fault, stage)
            lib.writ_read_test_close_at(read_close_at)
            before_fds = len(os.listdir('/proc/self/fd'))
            selected = (1 if scenario == 'positive' else 2) if scenario_id is None else scenario_id
            status = lib.writ_public_synthetic_publish(fd, selected, run, attempt, ctypes.byref(obs))
            assert not errors, (name, errors)
            assert status == expected, (name, status, expected)
            assert len(os.listdir('/proc/self/fd')) == before_fds, (name, 'FD leak')
            if status == 1:
                m, s = expected_pair(scenario, run, attempt, obs)
                if known_post_drift:
                    assert not valid_pair(root, scenario, run, attempt), name
                else:
                    assert (root / FILES[1]).read_bytes() == m, name
                    assert (root / FILES[3]).read_bytes() == s, name
                assert not (root / FILES[0]).exists() and not (root / FILES[2]).exists(), name
            if post: post(root, status)
            if expect_empty: assert not any((root / filename).exists() for filename in FILES), name
            if sentinel:
                after_stat = path.lstat()
                assert (before_stat.st_dev, before_stat.st_ino, before_stat.st_mode) == (after_stat.st_dev, after_stat.st_ino, after_stat.st_mode), name
                if kind == 'file': assert path.read_bytes() == b'owned sentinel', name
            stats = (lib.writ_publish_test_append_count(), lib.writ_read_test_close_count())
            checks += 1
            if not quiet: print('PASS ' + name)
            return stats
        finally:
            reset()
            if sock: sock.close()
            os.close(fd)

def too_much_total(obs):
    for i in range(1, 5): obs.size[i] = 268435456

def exact_total(obs):
    for i in range(1, 4): obs.size[i] = 268435456
    obs.size[4] = 268435456 - obs.size[0]
    for i in range(5, 14): obs.size[i] = 0

# This test-only consumer parses the pair and recomputes the digest. It is not
# an authority engine: the supplied exit value/expected keys are not bound to
# a real worker or authenticated by this function.
def bounded_bytes(path, cap):
    try:
        with path.open('rb') as stream: data = stream.read(cap + 1)
    except FileNotFoundError:
        return None
    return data if len(data) <= cap else None

def valid_pair(root, scenario, run, attempt):
    manifest = bounded_bytes(root / FILES[1], 4096)
    status = bounded_bytes(root / FILES[3], 512)
    if manifest is None or status is None: return False
    m = manifest.split(b'\n')
    st = status.split(b'\n')
    if len(m) != 19 or len(st) != 8 or m[-1] != b'' or st[-1] != b'': return False
    key_lines = [b'scenario=' + scenario.encode('ascii'), b'run=' + str(run).encode('ascii'),
                 b'attempt=' + str(attempt).encode('ascii')]
    if m[:4] != [b'WRIT-PUBLIC-BOOT-MANIFEST-V1'] + key_lines: return False
    if st[:5] != [b'WRIT-PUBLIC-BOOT-STATUS-V1', b'status=synthetic-partial'] + key_lines: return False
    if st[5] != b'manifest_bytes=' + str(len(manifest)).encode('ascii'): return False
    if st[6] != b'manifest_sha256=' + hashlib.sha256(manifest).hexdigest().encode('ascii'): return False
    total = 0
    for i, name in enumerate(NAMES):
        match = re.fullmatch(re.escape(name.encode('ascii')) + rb' size=(0|[1-9][0-9]*) sha256=([0-9a-f]{64})', m[4 + i])
        if not match: return False
        size = int(match.group(1))
        if size > 2**64 - 1 or (i and size > 268435456): return False
        total += size
        if total > 1073741824: return False
        if i == 0 and (size != FIXED[scenario][0] or match.group(2).decode('ascii') != FIXED[scenario][1]): return False
    return True

def synthetic_pair_and_exit(root, scenario, run, attempt, observed_exit):
    return observed_exit == 0 and valid_pair(root, scenario, run, attempt)

reset()
base = trial('positive canonical pair')
trial('negative canonical pair with maximum u64 keys', scenario='negative', run=2**64-1, attempt=2**64-1)
def leading_zero_digest(obs):
    obs.digest[1][0] = 0
    obs.digest[1][1] = 1
trial('leading zero digest preserved', mutate=leading_zero_digest)
trial('aggregate cap accepted', mutate=exact_total)
trial('aggregate cap rejected', mutate=too_much_total, expected=0)
trial('leaf cap rejected', mutate=lambda obs: obs.size.__setitem__(1, 268435457), expected=0)
trial('u64 leaf overflow rejected', mutate=lambda obs: obs.size.__setitem__(1, 2**64-1), expected=0)
trial('wrong config size rejected', mutate=lambda obs: obs.size.__setitem__(0, 1709), expected=0)
trial('wrong config digest rejected', mutate=lambda obs: obs.digest[0].__setitem__(0, 0), expected=0)
trial('inheritable output FD rejected', inheritable=True, expected=0, expect_empty=True)
trial('unsafe output directory mode rejected', unsafe_mode=True, expected=0, expect_empty=True)
trial('unknown scenario rejected', scenario_id=3, expected=0, expect_empty=True)
for filename in FILES:
    for kind in ('file', 'symlink', 'fifo', 'socket'):
        trial('existing sentinel rejected', sentinel=(filename, kind), expected=0, quiet=True)
print('PASS all 16 fixed-name file/symlink/FIFO/socket sentinels preserved')
for stage in (1, 2):
    trial('partial writes and EINTR stage ' + str(stage), fault=1, stage=stage)
    trial('write error stage ' + str(stage), fault=2, stage=stage, expected=0)
    trial('unsupported NOREPLACE stage ' + str(stage), fault=5, stage=stage, expected=0)
for stage in (1, 2, 11, 12, 33, 34):
    trial('close uncertainty stage ' + str(stage), fault=3, stage=stage, expected=-1)
for stage in (1, 2, 3, 4):
    trial('readback failure stage ' + str(stage), fault=4, stage=stage, expected=0)
    trial('post-read digest failure stage ' + str(stage), fault=9, stage=stage, expected=0)
trial('format hash failure', fault=6, expected=0)

def substitute_fifo(phase, root):
    if phase == 4:
        path = root / FILES[0]
        path.unlink()
        os.mkfifo(path)
def verify_fifo(root, status):
    import stat
    assert stat.S_ISFIFO((root / FILES[0]).lstat().st_mode)
    assert not (root / FILES[1]).exists() and not (root / FILES[3]).exists()
trial('substituted FIFO is not opened as data', hook=substitute_fifo, post=verify_fifo, expected=-1)

def substitute_symlink(phase, root):
    if phase == 5:
        path = root / FILES[0]
        path.unlink()
        target = root / 'test-owned-target'
        target.write_bytes(b'untouched sentinel')
        path.symlink_to(target)
def verify_symlink(root, status):
    assert (root / FILES[1]).is_symlink()
    assert (root / 'test-owned-target').read_bytes() == b'untouched sentinel'
    assert not (root / FILES[3]).exists()
trial('post-check symlink replacement remains uncredited', hook=substitute_symlink, post=verify_symlink, expected=0)

def mutate_before_final_check(phase, root):
    if phase == 18:
        path = root / FILES[1]
        data = bytearray(path.read_bytes())
        data[-2] ^= 1
        path.write_bytes(data)
def verify_changed_pair(root, status):
    assert not valid_pair(root, 'positive', 0, 0)
trial('post-status manifest drift rejected', hook=mutate_before_final_check,
      post=verify_changed_pair, expected=0)

def mutate_after_final_check(phase, root):
    if phase == 19:
        path = root / FILES[1]
        data = bytearray(path.read_bytes())
        data[-2] ^= 1
        path.write_bytes(data)
trial('known limitation: post-check mutation can leave invalid pair after partial return',
      hook=mutate_after_final_check, expected=1, known_post_drift=True)
trial('manifest formatting cap refused', fault=8, stage=1, expected=0)
trial('status formatting cap refused', fault=8, stage=2, expected=0)
for i in range(1, base[0] + 1):
    trial('format stage failure', fault=7, stage=i, expected=0, quiet=True, expect_empty=True)
print(f'PASS all {base[0]} formatting-stage failures leave no credited output')
for i in range(1, base[1] + 1):
    trial('reader close failure', read_close_at=i, expected=-1, quiet=True)
print(f'PASS all {base[1]} reader-close failure injections report uncertainty')

def interruption_case(phase):
    global checks
    with tempfile.TemporaryDirectory(prefix='writ-public-interrupt-', dir='/tmp') as directory:
        root = Path(directory); os.chmod(root, 0o700)
        fd = os.open(root, os.O_PATH | os.O_DIRECTORY | os.O_CLOEXEC)
        obs = observation('positive')
        pid = os.fork()
        if pid == 0:
            def stop(at, _arg):
                if at == phase: os._exit(73)
            callback = HOOK(stop)
            lib.writ_publish_test_set_hook(callback, None)
            lib.writ_public_synthetic_publish(fd, 1, 0, 0, ctypes.byref(obs))
            os._exit(0)
        waited, child_status = os.waitpid(pid, 0)
        assert waited == pid and os.WIFEXITED(child_status) and os.WEXITSTATUS(child_status) == 73, phase
        exit_code = os.WEXITSTATUS(child_status)
        matches = valid_pair(root, 'positive', 0, 0)
        assert not synthetic_pair_and_exit(root, 'positive', 0, 0, exit_code), phase
        assert not synthetic_pair_and_exit(root, 'positive', 0, 0, None), phase
        if phase >= 16: assert matches, ('post-status promotion pair should remain syntactically valid', phase)
        os.close(fd)
        checks += 1
for phase in (1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18, 19):
    interruption_case(phase)
print('PASS 16 owned-child interruption phases retain no completion credit')

with tempfile.TemporaryDirectory(prefix='writ-public-exit0-', dir='/tmp') as directory:
    root = Path(directory); os.chmod(root, 0o700)
    fd = os.open(root, os.O_PATH | os.O_DIRECTORY | os.O_CLOEXEC)
    obs = observation('positive')
    pid = os.fork()
    if pid == 0:
        rc = lib.writ_public_synthetic_publish(fd, 1, 0, 0, ctypes.byref(obs))
        os._exit(0 if rc == 1 else 1)
    waited, child_status = os.waitpid(pid, 0)
    assert waited == pid and os.WIFEXITED(child_status)
    code = os.WEXITSTATUS(child_status)
    assert code == 0 and synthetic_pair_and_exit(root, 'positive', 0, 0, code)
    assert not synthetic_pair_and_exit(root, 'positive', 0, 0, None)
    assert not synthetic_pair_and_exit(root, 'positive', 0, 0, 73)
    os.close(fd)
    checks += 1
print('PASS exact owned-child exit zero and independently validated pair control')

with tempfile.TemporaryDirectory(prefix='writ-public-pair-', dir='/tmp') as directory:
    root = Path(directory); obs = observation('positive')
    manifest, status = expected_pair('positive', 0, 0, obs)
    m, s = root / FILES[1], root / FILES[3]
    m.write_bytes(manifest); s.write_bytes(status)
    assert valid_pair(root, 'positive', 0, 0)
    for label, bad_manifest, bad_status in (
        ('manifest byte', b'X' + manifest[1:], status),
        ('entry order', manifest.replace(b'core size=', b'bad! size=', 1), status),
        ('scenario', manifest, status.replace(b'scenario=positive', b'scenario=negative')),
        ('key', manifest, status.replace(b'run=0', b'run=1')),
        ('decimal', manifest, status.replace(b'run=0', b'run=00')),
        ('status length', manifest, status.replace(b'manifest_bytes=', b'manifest_bytes=9')),
        ('digest', manifest, status.replace(b'manifest_sha256=', b'manifest_sha256=0')),
        ('trailing byte', manifest, status + b'X'),
    ):
        m.write_bytes(bad_manifest); s.write_bytes(bad_status)
        assert not valid_pair(root, 'positive', 0, 0), label
        checks += 1
    # Rebind status to malformed manifest bytes: syntax/bounds must still fail.
    def rebound(data):
        return (b'WRIT-PUBLIC-BOOT-STATUS-V1\nstatus=synthetic-partial\nscenario=positive\n'
                b'run=0\nattempt=0\nmanifest_bytes=' + str(len(data)).encode('ascii') +
                b'\nmanifest_sha256=' + hashlib.sha256(data).hexdigest().encode('ascii') + b'\n')
    for label, malformed in (
        ('fixed name', manifest.replace(b'core size=', b'bad! size=', 1)),
        ('noncanonical decimal', manifest.replace(b'core size=17', b'core size=017', 1)),
        ('oversized value', manifest.replace(b'core size=17', b'core size=268435457', 1)),
        ('config hash', manifest.replace(FIXED['positive'][1].encode('ascii'), b'0' * 64, 1)),
    ):
        m.write_bytes(malformed); s.write_bytes(rebound(malformed))
        assert not valid_pair(root, 'positive', 0, 0), label
        checks += 1
    # Correctly formatted caller-fabricated digests still pass syntax/hash;
    # this is not provenance or worker authentication.
    fabricated = manifest.replace(bytes(obs.digest[1]).hex().encode('ascii'), b'0' * 64, 1)
    m.write_bytes(fabricated); s.write_bytes(rebound(fabricated))
    assert valid_pair(root, 'positive', 0, 0)
    checks += 1
    m.write_bytes(manifest); s.write_bytes(status)
    with tempfile.TemporaryDirectory(prefix='writ-public-replay-', dir='/tmp') as copied:
        destination = Path(copied)
        shutil.copyfile(m, destination / FILES[1])
        shutil.copyfile(s, destination / FILES[3])
        assert valid_pair(destination, 'positive', 0, 0)  # Replay is not authentication.
    checks += 1
print('PASS 8 pair mutations and 4 rehashed malformed records rejected')
print('PASS fabricated digest and copied replay remain unauthenticated syntax matches')
print(f'PASS {checks} synthetic publication cases')
