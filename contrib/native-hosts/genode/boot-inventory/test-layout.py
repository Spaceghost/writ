#!/usr/bin/env python3
"""Synthetic layout-only checks; uses only privately created /tmp objects."""
import ctypes
import errno
import os
from pathlib import Path
import shutil
import socket
import sys

if len(sys.argv) != 2:
    raise SystemExit('usage: test-layout.py TEST_SHARED_LIBRARY')
lib = ctypes.CDLL(sys.argv[1], use_errno=True)
lib.writ_boot_layout_check.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                       ctypes.c_uint64, ctypes.c_uint64, ctypes.c_int]
lib.writ_boot_layout_check.restype = ctypes.c_int
HOOK = ctypes.CFUNCTYPE(None, ctypes.c_void_p)
lib.writ_boot_test_between_scans.argtypes = [HOOK, ctypes.c_void_p]
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
run = os.getpid()
sequence = 0
checks = 0

def trial(name, change=None, valid=False, scenario='positive', hook=None, wrong_fd=False, fault=0):
    global sequence, checks
    sequence += 1
    root = Path('/tmp') / f'writ-genode-ci.{run}-{sequence}.{scenario}'
    os.mkdir(root, 0o700)  # never adopt an existing path
    opened = []
    sock = None
    cb = None
    try:
        build, genode = root / 'build', root / 'genode'
        boot = build / 'var/run' / f'writ_bend_monitor_nested_guarded_{scenario}' / 'genode'
        boot.mkdir(parents=True)
        (build / 'bin').mkdir()
        genode.mkdir()
        (boot / 'config').write_bytes(b'public synthetic config')
        for entry, bin_name, target in MAPPING:
            dest = root / target
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(b'public synthetic leaf')
            (build / 'bin' / bin_name).symlink_to(dest)
            (boot / entry).symlink_to(build / 'bin' / bin_name)
        if change:
            outcome = change(root, boot)
            if isinstance(outcome, socket.socket):
                sock = outcome
        for path in (root, build, genode):
            opened.append(os.open(path, os.O_PATH | os.O_DIRECTORY | os.O_CLOEXEC))
        if hook:
            cb = HOOK(lambda _arg: hook(root, boot))
            lib.writ_boot_test_between_scans(cb, None)
        fds = opened.copy()
        if wrong_fd:
            fds[1], fds[2] = fds[2], fds[1]
        lib.writ_boot_test_open_error(fault)
        result = lib.writ_boot_layout_check(*fds, run, sequence, 1 if scenario == 'positive' else 2)
        lib.writ_boot_test_open_error(0)
        lib.writ_boot_test_between_scans(HOOK(), None)
        assert (result == 0) == valid, (name, result)
        checks += 1
        print(f'PASS {name}')
    finally:
        for fd in opened:
            os.close(fd)
        if sock:
            sock.close()
        # Only this invocation's exclusively created fixture tree is removed.
        shutil.rmtree(root)

def replace(path, value):
    path.unlink()
    path.symlink_to(value)

def socket_leaf(root, boot):
    p = root / MAPPING[0][2]
    p.unlink()
    s = socket.socket(socket.AF_UNIX)
    s.bind(str(p))
    return s

trial('positive fixture', valid=True)
trial('negative fixture', valid=True, scenario='negative')
trial('missing entry', lambda r, b: (b / 'init').unlink())
trial('extra entry', lambda r, b: (b / 'unexpected').write_bytes(b''))
trial('too many entries', lambda r, b: [(b / f'extra{i}').write_bytes(b'') for i in range(33)])
trial('long name', lambda r, b: (b / ('x' * 129)).write_bytes(b''))
trial('nonascii name', lambda r, b: (b / 'é').write_bytes(b''))
trial('direct non-config', lambda r, b: ((b / 'core').unlink(), (b / 'core').write_bytes(b'')))
trial('wrong root', lambda r, b: replace(b / 'core', '/tmp/unrelated/build/bin/core-linux'))
trial('relative link', lambda r, b: replace(b / 'core', '../bin/core-linux'))
trial('prefix collision', lambda r, b: replace(b / 'core', str(r) + '-sibling/build/bin/core-linux'))
trial('extra hop', lambda r, b: replace(r / 'build/bin/core-linux', r / 'build/bin/init'))
trial('parent component', lambda r, b: replace(b / 'core', str(r / 'build/bin/../bin/core-linux')))
trial('wrong schema root', lambda r, b: replace(r / 'build/bin/init.hsd', r / 'build/init/init.stripped'))
trial('config symlink', lambda r, b: ((b / 'config').unlink(), (b / 'config').symlink_to(r / MAPPING[0][2])))
trial('config size limit accepted', lambda r, b: (b / 'config').write_bytes(b'x' * 16384), valid=True)
trial('oversize config', lambda r, b: (b / 'config').write_bytes(b'x' * 16385))
trial('leaf size limit accepted', lambda r, b: os.truncate(r / MAPPING[0][2], 268435456), valid=True)
trial('total size limit exceeded', lambda r, b: [os.truncate(r / item[2], 268435456) for item in MAPPING[:4]])
trial('oversize leaf', lambda r, b: os.truncate(r / MAPPING[0][2], 268435457))
trial('leaf fifo', lambda r, b: ((r / MAPPING[0][2]).unlink(), os.mkfifo(r / MAPPING[0][2])))
trial('leaf socket', socket_leaf)
trial('hard-linked leaf', lambda r, b: os.link(r / MAPPING[0][2], r / 'other'))
trial('swapped roots', wrong_fd=True)
trial('late added entry', hook=lambda r, b: (b / 'late').write_bytes(b''))
trial('late removed entry', hook=lambda r, b: (b / 'init').unlink())
trial('late link replacement', hook=lambda r, b: replace(b / 'core', '/tmp/unrelated'))
trial('late leaf replacement', hook=lambda r, b: ((r / MAPPING[0][2]).unlink(), (r / MAPPING[0][2]).write_bytes(b'new')))
trial('late in-place leaf change', hook=lambda r, b: (r / MAPPING[0][2]).write_bytes(b'changed'))
trial('unsupported openat2', fault=errno.ENOSYS)
trial('unsupported flags', fault=errno.EINVAL)
trial('structure size unsupported', fault=errno.E2BIG)
trial('different config contents do not establish exactness', lambda r, b: (b / 'config').write_bytes(b'wrong'), valid=True)
print(f'PASS {checks} synthetic layout checks')
