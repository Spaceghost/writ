#!/usr/bin/env python3
"""Fixed public synthetic trees and test-owned FDs only; no Genode or QEMU."""
import ctypes
import errno
import hashlib
import os
from pathlib import Path
import shutil
import sys
from zipfile import ZipFile

if len(sys.argv) != 2:
    raise SystemExit('usage: test-observe.py TEST_SHARED_LIBRARY')
lib = ctypes.CDLL(sys.argv[1])
class Result(ctypes.Structure):
    _fields_ = [('digest', (ctypes.c_ubyte * 32) * 14), ('size', ctypes.c_uint64 * 14)]
lib.writ_boot_public_observe.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int,
    ctypes.c_uint64, ctypes.c_uint64, ctypes.c_int, ctypes.POINTER(Result)]
lib.writ_boot_public_observe.restype = ctypes.c_int
HOOK = ctypes.CFUNCTYPE(None, ctypes.c_int, ctypes.c_int, ctypes.c_void_p)
lib.writ_observe_test_set_hook.argtypes = [HOOK, ctypes.c_void_p]
lib.writ_observe_test_swap.argtypes = [ctypes.c_int, ctypes.c_int]
lib.writ_observe_test_fail_read.argtypes = [ctypes.c_int]
for name in ('writ_boot_test_own_at', 'writ_boot_test_drop_at', 'writ_boot_test_close_at', 'writ_read_test_close_at'):
    getattr(lib, name).argtypes = [ctypes.c_uint]
for name in ('writ_boot_test_own_count', 'writ_boot_test_drop_count', 'writ_boot_test_close_count', 'writ_read_test_close_count'):
    getattr(lib, name).restype = ctypes.c_uint
lib.writ_observe_test_read_count.restype = ctypes.c_int
lib.writ_read_test_fault.argtypes = [ctypes.c_int, ctypes.c_int]
lib.writ_read_test_chunk_limit.argtypes = [ctypes.c_size_t]
READ_HOOK = ctypes.CFUNCTYPE(None, ctypes.c_void_p)
lib.writ_read_test_after_chunk.argtypes = [READ_HOOK, ctypes.c_void_p]
for name in ('writ_read_test_compared', 'writ_read_test_hashed', 'writ_read_test_chunks'):
    getattr(lib, name).restype = ctypes.c_uint64
for name in ('writ_read_test_compare_digest', 'writ_read_test_hash_digest'):
    getattr(lib, name).restype = ctypes.POINTER(ctypes.c_ubyte)
MAPPING = [
    ('core', 'core-linux', 'build/core/linux/core-linux.stripped'),
    ('hpet_timer', 'hpet_timer', 'build/timer/hpet/hpet_timer.stripped'),
    ('init', 'init', 'build/init/init.stripped'),
    ('init.hsd', 'init.hsd', 'genode/repos/os/src/init/init.hsd'),
    ('init.xsd', 'init.xsd', 'genode/repos/os/src/init/config.xsd'),
    ('ld.lib.so', 'ld-linux.lib.so', 'build/var/libcache/ld-linux/ld-linux.lib.so.stripped'),
    ('libc.lib.so', 'libc.lib.so', 'build/var/libcache/libc/libc.lib.so.stripped'),
    ('libm.lib.so', 'libm.lib.so', 'build/var/libcache/libm/libm.lib.so.stripped'),
    ('timer', 'linux_timer', 'build/timer/linux/linux_timer.stripped'),
    ('vfs.lib.so', 'vfs.lib.so', 'build/var/libcache/vfs/vfs.lib.so.stripped'),
    ('vfs_pipe.lib.so', 'vfs_pipe.lib.so', 'build/var/libcache/vfs_pipe/vfs_pipe.lib.so.stripped'),
    ('writ_bend_monitor', 'writ_bend_monitor', 'build/app/writ_bend_monitor/writ_bend_monitor.stripped'),
    ('writ_channel_client', 'writ_channel_client', 'build/app/writ_channel_client/writ_channel_client.stripped'),
]
ROOT = Path(__file__).resolve().parents[4]
VECTORS = {}
for scenario, size, digest in (
    ('positive', 1710, '2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22'),
    ('negative', 1668, 'e2f60b4d32db4ab16259b4e5da762cf4a17ff919aad86cb9e41061c87d27865a'),
):
    with ZipFile(ROOT / 'verification/genode-route-retry-42361441863/raw' / (scenario + '.zip')) as archive:
        info = archive.getinfo('installed-config.txt')
        assert info.file_size == size and info.file_size <= 16384
        vector = archive.read(info)
    args = (ROOT / 'contrib/native-hosts/genode/nested-channel' / ('writ_guard_' + scenario + '.args')).read_bytes()
    assert vector == args + b'\n' and hashlib.sha256(vector).hexdigest() == digest
    VECTORS[scenario] = vector
run = os.getpid()
sequence = 0
checks = 0

def reset():
    lib.writ_observe_test_set_hook(HOOK(), None)
    lib.writ_observe_test_swap(-1, -1)
    lib.writ_observe_test_fail_read(-1)
    lib.writ_read_test_fault(0, -1)
    lib.writ_read_test_chunk_limit(0)
    lib.writ_read_test_after_chunk(READ_HOOK(), None)
    for name in ('writ_boot_test_own_at', 'writ_boot_test_drop_at', 'writ_boot_test_close_at', 'writ_read_test_close_at'):
        getattr(lib, name)(0)

def trial(name, scenario='positive', expected=1, hook=None, swap=None,
          fail_read=-1, fail_own=0, fail_drop=0, fail_temp_close=0,
          fail_read_close=0, reuse=False, quiet=False, inheritable=False, tweak=None, reuse_same_inode=False, fault=0, chunk=0, config_chunk_hook=None):
    global sequence, checks
    sequence += 1
    root = Path('/tmp') / f'writ-genode-ci.{run}-{sequence}.{scenario}'
    os.mkdir(root, 0o700)
    borrowed = []
    extra_fd = -1
    reused_fd = -1
    callback_errors = []
    callback = None
    read_callback = None
    phases = []
    try:
        build, source = root / 'build', root / 'genode'
        boot = build / 'var/run' / f'writ_bend_monitor_nested_guarded_{scenario}' / 'genode'
        boot.mkdir(parents=True)
        (build / 'bin').mkdir()
        source.mkdir()
        data = [VECTORS[scenario]]
        (boot / 'config').write_bytes(data[0])
        for entry, bin_name, target in MAPPING:
            dest = root / target
            dest.parent.mkdir(parents=True, exist_ok=True)
            payload = ('fixed synthetic ' + entry).encode('ascii')
            data.append(payload)
            dest.write_bytes(payload)
            (build / 'bin' / bin_name).symlink_to(dest)
            (boot / entry).symlink_to(build / 'bin' / bin_name)
        if tweak: tweak(root, boot, data)
        for path in (root, build, source):
            borrowed.append(os.open(path, os.O_PATH | os.O_DIRECTORY | os.O_CLOEXEC))
        if inheritable:
            for fd in borrowed: os.set_inheritable(fd, True)
        if reuse or reuse_same_inode:
            if reuse_same_inode:
                extra = root / MAPPING[0][2]  # separate open of the same synthetic inode
            else:
                extra = root / 'unrelated-test-owned'
                extra.write_bytes(b'other owned object')
            extra_fd = os.open(extra, os.O_PATH | os.O_CLOEXEC)
        before = len(os.listdir('/proc/self/fd'))
        if hook or reuse or reuse_same_inode:
            def run_hook(phase, fd, _arg):
                nonlocal reused_fd
                try:
                    phases.append((phase, lib.writ_observe_test_read_count()))
                    if (reuse or reuse_same_inode) and phase == 1:
                        os.dup2(extra_fd, fd, inheritable=False)
                        reused_fd = fd
                    if hook: hook(phase, fd, root, boot)
                except BaseException as exc:
                    callback_errors.append(exc)
            callback = HOOK(run_hook)
            lib.writ_observe_test_set_hook(callback, None)
        if config_chunk_hook:
            def run_read_hook(_arg):
                try: config_chunk_hook(root, boot)
                except BaseException as exc: callback_errors.append(exc)
            read_callback = READ_HOOK(run_read_hook)
            lib.writ_read_test_after_chunk(read_callback, None)
        if swap: lib.writ_observe_test_swap(*swap)
        lib.writ_observe_test_fail_read(fail_read)
        lib.writ_boot_test_own_at(fail_own)
        lib.writ_boot_test_drop_at(fail_drop)
        lib.writ_boot_test_close_at(fail_temp_close)
        lib.writ_read_test_close_at(fail_read_close)
        lib.writ_read_test_fault(fault, -1)
        lib.writ_read_test_chunk_limit(chunk)
        result = Result()
        ctypes.memset(ctypes.byref(result), 0xA5, ctypes.sizeof(result))
        status = lib.writ_boot_public_observe(*borrowed, run, sequence,
                 1 if scenario == 'positive' else 2, ctypes.byref(result))
        stats = (lib.writ_boot_test_own_count(), lib.writ_boot_test_drop_count(),
                 lib.writ_boot_test_close_count(), lib.writ_read_test_close_count())
        assert not callback_errors, (name, callback_errors)
        assert status == expected, (name, status, expected, stats)
        if status == 1:
            assert list(result.size) == list(map(len, data)), name
            assert [bytes(x) for x in result.digest] == [hashlib.sha256(x).digest() for x in data], name
            assert lib.writ_read_test_compared() == len(data[0]), name
            assert lib.writ_read_test_hashed() == len(data[0]), name
            expected_config_hash = hashlib.sha256(data[0]).digest()
            assert ctypes.string_at(lib.writ_read_test_compare_digest(), 32) == expected_config_hash, name
            assert ctypes.string_at(lib.writ_read_test_hash_digest(), 32) == expected_config_hash, name
            if chunk: assert lib.writ_read_test_chunks() > 1, name
        else:
            assert bytes(result) == bytes(ctypes.sizeof(result)), name
        if hook and expected != 1 and any(phase == 2 for phase, _ in phases):
            assert (2, 14) in phases, (name, phases)
        if reuse or reuse_same_inode:
            assert reused_fd >= 0, name
            if reuse_same_inode:
                # Known limitation: same-inode reuse is indistinguishable here.
                try:
                    os.fstat(reused_fd)
                except OSError as exc:
                    assert exc.errno == errno.EBADF, (name, exc)
                else:
                    raise AssertionError((name, 'known same-inode behavior changed'))
            else:
                # A demonstrably different inode must not be closed by the probe.
                assert os.fstat(reused_fd).st_ino == os.fstat(extra_fd).st_ino, name
                os.close(reused_fd)
            reused_fd = -1
        assert len(os.listdir('/proc/self/fd')) == before, (name, 'FD leak')
        checks += 1
        if not quiet: print(f'PASS {name}')
        return stats
    finally:
        reset()
        if reused_fd >= 0: os.close(reused_fd)
        if extra_fd >= 0: os.close(extra_fd)
        for fd in borrowed: os.close(fd)
        shutil.rmtree(root)

reset()
base = trial('positive ordered same-FD observation')
trial('negative ordered same-FD observation', scenario='negative')

def config_at_limit(root, boot, data):
    data[0] = b'c' * 16384
    (boot / 'config').write_bytes(data[0])
trial('observer rejects arbitrary config even at cap', tweak=config_at_limit, expected=0)

def config_over_limit(root, boot, data):
    (boot / 'config').write_bytes(b'c' * 16385)
trial('observer oversized config refused', expected=0, tweak=config_over_limit)

def leaf_above_config_cap(root, boot, data):
    data[1] = b'b' * 16385
    (root / MAPPING[0][2]).write_bytes(data[1])
trial('observer non-config uses larger cap', tweak=leaf_above_config_cap)

def leaf_over_limit(root, boot, data):
    os.truncate(root / MAPPING[0][2], 268435457)
trial('observer oversized leaf refused', expected=0, tweak=leaf_over_limit)
trial('positive short-read chunks compare and hash together', chunk=7)
trial('negative short-read chunks compare and hash together', scenario='negative', chunk=11)
trial('config EINTR retry preserves exact comparison', fault=7)

def mutate_config_after_first_chunk(root, boot):
    config = boot / 'config'
    data = bytearray(config.read_bytes())
    data[100] ^= 1
    config.write_bytes(data)
    os.utime(config, ns=(1_000_000_000, 1_000_000_000))
trial('config mutation during chunked same-FD read rejected',
      chunk=7, config_chunk_hook=mutate_config_after_first_chunk, expected=0)
for injected, label in ((9, 'read'), (10, 'compare'), (11, 'digest update'),
                        (12, 'digest final'), (13, 'premature EOF'), (14, 'growth probe')):
    trial('config ' + label + ' failure returns zero', fault=injected, expected=0)

def wrong_scenario(root, boot, data):
    (boot / 'config').write_bytes(VECTORS['negative'])
trial('wrong scenario config rejected', tweak=wrong_scenario, expected=0)

def mutate_byte(index, value):
    def change(root, boot, data):
        value_bytes = bytearray(data[0]); value_bytes[index] = value
        (boot / 'config').write_bytes(value_bytes)
    return change
for index, label in ((0, 'first'), (len(VECTORS['positive']) // 2, 'interior'), (-1, 'last')):
    trial('config ' + label + ' byte mutation rejected',
          tweak=mutate_byte(index, VECTORS['positive'][index] ^ 1), expected=0)
trial('config embedded NUL rejected', tweak=mutate_byte(100, 0), expected=0)
trial('config non-ASCII rejected', tweak=mutate_byte(100, 255), expected=0)
for label, content in (
    ('missing installer LF', VECTORS['positive'][:-1]),
    ('extra LF', VECTORS['positive'] + b'\n'),
    ('strict prefix', VECTORS['positive'][:-20]),
    ('extension', VECTORS['positive'] + b'X'),
):
    trial('config ' + label + ' rejected',
          tweak=lambda root, boot, data, content=content: (boot / 'config').write_bytes(content), expected=0)
trial('observer refuses inheritable borrowed roots', inheritable=True, expected=0)
trial('private slot swap refused', swap=(1, 2), expected=0)
trial('out-of-range private index refused', swap=(1, 14), expected=0)

def close_fd(phase, fd, root, boot):
    if phase == 1: os.close(fd)
trial('closed checked descriptor is cleanup-unverified', hook=close_fd, expected=-1)
trial('different-inode reused descriptor is not closed', reuse=True, expected=-1)
trial('known limitation: same-inode reused descriptor is closed', reuse_same_inode=True)

def moved_leaf(phase, fd, root, boot):
    if phase == 2:
        original = root / MAPPING[0][2]
        original.rename(original.with_name('test-held-original'))
        original.write_bytes(b'different replacement')
trial('post-read renamed leaf and replacement refused', hook=moved_leaf, expected=0)

def changed_link(phase, fd, root, boot):
    if phase == 2:
        link = boot / 'core'
        target = os.readlink(link)
        link.unlink()
        link.symlink_to(target)
trial('post-read identical-text new symlink refused', hook=changed_link, expected=0)

def alter_leaf(phase, fd, root, boot):
    if phase == 2:
        target = root / MAPPING[0][2]
        with target.open('r+b') as stream:
            stream.write(b'X')
        os.utime(target, ns=(1_000_000_000, 1_000_000_000))
trial('post-read same-size metadata drift refused', hook=alter_leaf, expected=0)

def remove_name(phase, fd, root, boot):
    if phase == 2: (boot / 'core').unlink()
trial('post-read missing fixed path refused', hook=remove_name, expected=0)

def unlink_before_reads(phase, fd, root, boot):
    if phase == 1: (boot / 'core').unlink()
trial('reads stay on held FDs after boot path removal', hook=unlink_before_reads, expected=0)

def root_change(phase, fd, root, boot):
    if phase == 2: (root / 'unrelated').write_bytes(b'')
trial('observer refuses borrowed root metadata drift', hook=root_change, expected=0)

def clear_cloexec(phase, fd, root, boot):
    if phase == 2: os.set_inheritable(fd, True)
trial('post-read lost CLOEXEC is refused', hook=clear_cloexec, expected=0)

for i in range(14):
    trial('read failure', fail_read=i, expected=0, quiet=True)
print('PASS all 14 hash-stage failures return no result')
for i in range(1, base[0] + 1):
    trial('owned acquisition failure', fail_own=i, expected=0, quiet=True)
print(f'PASS all {base[0]} retained-acquisition failures close owned descriptors')
for i in range(1, base[1] + 1):
    trial('owned close failure', fail_drop=i, expected=-1, quiet=True)
print(f'PASS all {base[1]} retained-close failure injections report uncertainty')
# Every read-helper close site is injected across all 14 reads; each simulated
# failure closes the test FD before reporting uncertainty.
for i in range(1, base[3] + 1):
    trial('read helper close failure', fail_read_close=i, expected=-1, quiet=True)
print(f'PASS all {base[3]} read-helper close failure injections propagate uncertainty')
# Every observed layout close (temporary and retained) is fault-injected after
# the actual synthetic close so uncertainty propagation cannot leak a test FD.
for i in range(1, base[2] + 1):
    trial('layout close failure', fail_temp_close=i, expected=-1, quiet=True)
print(f'PASS all {base[2]} layout-close failure injections report uncertainty')
print(f'PASS {checks} synthetic same-FD cases')
