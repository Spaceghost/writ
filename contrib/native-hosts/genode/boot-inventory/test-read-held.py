#!/usr/bin/env python3
"""Exercise only files and descriptors owned by this synthetic test."""
import ctypes
import hashlib
import os
from pathlib import Path
import socket
import sys
import tempfile

if len(sys.argv) != 2:
    raise SystemExit('usage: test-read-held.py TEST_SHARED_LIBRARY')
lib = ctypes.CDLL(sys.argv[1])
read_held = lib.writ_boot_read_held
read_held.argtypes = [ctypes.c_int, ctypes.c_uint64, ctypes.c_void_p,
                      ctypes.POINTER(ctypes.c_uint64)]
read_held.restype = ctypes.c_int
HOOK = ctypes.CFUNCTYPE(None, ctypes.c_void_p)
lib.writ_read_test_after_stat.argtypes = [HOOK, ctypes.c_void_p]
lib.writ_read_test_after_chunk.argtypes = [HOOK, ctypes.c_void_p]
lib.writ_read_test_fault.argtypes = [ctypes.c_int, ctypes.c_int]
lib.writ_read_test_proc_fd.argtypes = [ctypes.c_int]
checks = 0

with tempfile.TemporaryDirectory(prefix='writ-held-read-synthetic-', dir='/tmp') as work:
    root = Path(work)
    sequence = 0

    def trial(name, payload=b'public synthetic', good=False, cap=16384, kind='file',
              hook=None, hook_after='stat', fault=0, wrong_proc=False, replacement=False):
        global checks, sequence
        sequence += 1
        path = root / f'file-{sequence}'
        peer = root / f'peer-{sequence}'
        sock = None
        replacement_fd = -1
        proc_fd = -1
        fd = -1
        callback = None
        callback_errors = []
        try:
            if kind == 'fifo':
                os.mkfifo(path)
            elif kind == 'socket':
                sock = socket.socket(socket.AF_UNIX)
                sock.bind(str(path))
            elif kind == 'symlink':
                peer.write_bytes(payload)
                path.symlink_to(peer)
            else:
                path.write_bytes(payload)
                if kind == 'hardlink': os.link(path, peer)
            flags = (os.O_RDONLY if kind == 'non-path' else os.O_PATH) | os.O_CLOEXEC
            flags |= os.O_NOFOLLOW
            fd = os.open(path, flags)
            if kind == 'missing':
                os.close(fd)
                fd = -1
            if replacement:
                peer.write_bytes(b'a different synthetic file')
                replacement_fd = os.open(peer, os.O_RDONLY | os.O_CLOEXEC)
            if wrong_proc:
                proc_fd = os.open(root, os.O_PATH | os.O_DIRECTORY | os.O_CLOEXEC)
                lib.writ_read_test_proc_fd(proc_fd)
            if hook:
                def run_hook(_arg):
                    try: hook(path, peer)
                    except BaseException as exc: callback_errors.append(exc)
                callback = HOOK(run_hook)
                (lib.writ_read_test_after_stat if hook_after == 'stat' else
                 lib.writ_read_test_after_chunk)(callback, None)
            lib.writ_read_test_fault(fault, replacement_fd)
            digest = (ctypes.c_ubyte * 32)(*([0xA5] * 32))
            length = ctypes.c_uint64(0xABCDEF)
            result = read_held(fd, cap, digest, ctypes.byref(length))
            assert not callback_errors, (name, callback_errors)
            assert (result == 0) == good, (name, result)
            if good:
                assert bytes(digest) == hashlib.sha256(payload).digest(), name
                assert length.value == len(payload), name
            else:
                assert bytes(digest) == bytes(32) and length.value == 0, name
            checks += 1
            print(f'PASS {name}')
        finally:
            lib.writ_read_test_after_stat(HOOK(), None)
            lib.writ_read_test_after_chunk(HOOK(), None)
            lib.writ_read_test_fault(0, -1)
            lib.writ_read_test_proc_fd(-1)
            if fd >= 0: os.close(fd)
            if replacement_fd >= 0: os.close(replacement_fd)
            if proc_fd >= 0: os.close(proc_fd)
            if sock: sock.close()

    trial('ordinary held file', good=True)
    trial('empty held file', payload=b'', good=True)
    trial('exact config cap', payload=b'x' * 16384, good=True)
    trial('oversize config', payload=b'x' * 16385)
    trial('multi-chunk binary', payload=b'a' * 131073, cap=268435456, good=True)
    trial('non-profile cap', cap=1024)
    trial('non-O_PATH input', kind='non-path')
    trial('missing input', kind='missing')
    trial('held symlink', kind='symlink')
    trial('held fifo', kind='fifo')
    trial('held unix socket', kind='socket')
    trial('hard-linked regular', kind='hardlink')
    trial('unsupported openat2', fault=1)
    trial('synthetic procfs rejection', fault=2)
    trial('actual wrong filesystem', wrong_proc=True)
    trial('synthetic failed reopen', fault=3)
    trial('different reopened inode', fault=4, replacement=True)
    trial('expired deadline', fault=5)
    trial('wrong current PID view', fault=6)
    trial('interrupted read retry', fault=7, good=True)
    trial('procfs recheck failure', fault=8)
    trial('unlink after stat', hook=lambda path, peer: path.unlink())
    trial('replace inode after stat', hook=lambda path, peer: (path.unlink(), path.write_bytes(b'other')))
    trial('length drift during read', payload=b'a' * 131073, cap=268435456,
          hook=lambda path, peer: path.write_bytes(b'b' * 131074), hook_after='chunk')
    def inplace_change(path, peer):
        with path.open('r+b') as changed:
            changed.seek(0)
            changed.write(b'X')
            changed.flush()
        os.utime(path, ns=(1_000_000_000, 1_000_000_000))
    trial('same-size mutation during read', payload=b'a' * 131073, cap=268435456,
          hook=inplace_change, hook_after='chunk')
print(f'PASS {checks} synthetic held-read checks')
