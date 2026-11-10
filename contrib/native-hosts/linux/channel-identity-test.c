/* Owned-process channel identity test (board question 23).

   Observes what the kernel's per-message SCM_PIDFD reports when a Unix
   SOCK_SEQPACKET sending endpoint is passed from one disposable child to
   another. Every process, socket and descriptor here is created by this
   test; it inspects only its own /proc/self entries, requests no privilege,
   changes no namespace or security setting, mounts nothing and starts no VM.

   Authority note: this is kernel-behaviour evidence for the candidate
   local-supervisor channel, not an authenticated bridge. A matching pidfd
   names a process lifetime only; it does not establish a human, an
   executable image, a role, or permission to disclose data, and a sender
   with CAP_SYS_ADMIN/CAP_SETUID in the right namespace could supply other
   credentials (see openspec/changes/add-linux-host/local-supervisor-profile.md).

   Process identity is compared only through pidfs device/inode identity of
   pidfds the parent retains from clone3(CLONE_PIDFD), never by numeric PID.
   If pidfs or SO_PASSPIDFD is unavailable the test reports UNSUPPORTED and
   exits 77; it never falls back to a weaker comparison.

   Exit status: 0 every expected outcome observed; 1 an expected outcome
   changed or a system call failed; 77 a required kernel feature is missing.
   A harness must count death by SIGALRM (the fixed timeout) as a failure. */
#define _GNU_SOURCE
#include <errno.h>
#include <dirent.h>
#include <fcntl.h>
#include <linux/sched.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/vfs.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef SO_PASSPIDFD
#define SO_PASSPIDFD 76
#endif
#ifndef SCM_PIDFD
#define SCM_PIDFD 0x04
#endif
#ifndef SO_PEERPIDFD
#define SO_PEERPIDFD 77
#endif
#ifndef PID_FS_MAGIC
#define PID_FS_MAGIC 0x50494446
#endif

_Static_assert(sizeof(ino_t) == 8, "pidfs inode identity needs a 64-bit ino_t");

#define TIMEOUT_SECONDS 30u
#define CHILD_TIMEOUT_SECONDS 20u
#define PAYLOAD_MAX 16
#define LARGE_PAYLOAD 64
#define CONTROL_FDS 4 /* receive buffer room; parsing never clamps to it */

static int failures;

static void fail(const char *name, const char *detail)
{
    printf("FAIL %s: %s\n", name, detail);
    ++failures;
}

static void pass(const char *name, const char *detail)
{
    printf("PASS %s: %s\n", name, detail);
}

static _Noreturn void die(const char *what)
{
    printf("ERROR %s: %s\n", what, strerror(errno));
    exit(1);
}

static _Noreturn void unsupported(const char *what)
{
    printf("UNSUPPORTED %s: %s\n", what, strerror(errno));
    exit(77);
}

/* ---- descriptor accounting (own process only) ---- */

static int count_own_fds(void)
{
    DIR *dir = opendir("/proc/self/fd");
    if (!dir) die("opendir /proc/self/fd");
    int count = 0;
    struct dirent *entry;
    while ((entry = readdir(dir))) {
        if (entry->d_name[0] != '.') ++count;
    }
    closedir(dir);
    return count - 1; /* the directory stream's own descriptor */
}

/* ---- process identity: pidfs device/inode of two pidfds ---- */

enum identity { SAME, DIFFERENT, NOT_PIDFS };

static enum identity same_process(int a, int b)
{
    struct statfs fa, fb;
    struct stat sa, sb;
    if (fstatfs(a, &fa) || fstatfs(b, &fb)) die("fstatfs pidfd");
    if ((unsigned long)fa.f_type != PID_FS_MAGIC || (unsigned long)fb.f_type != PID_FS_MAGIC)
        return NOT_PIDFS;
    if (fstat(a, &sa) || fstat(b, &sb)) die("fstat pidfd");
    return sa.st_dev == sb.st_dev && sa.st_ino == sb.st_ino ? SAME : DIFFERENT;
}

/* ---- message send helpers used by the children ---- */

static int send_payload(int fd, const char *bytes, size_t len, int attach_fd)
{
    struct iovec iov = { .iov_base = (void *)bytes, .iov_len = len };
    union { char buf[CMSG_SPACE(sizeof(int))]; struct cmsghdr align; } control;
    struct msghdr msg = { .msg_iov = &iov, .msg_iovlen = 1 };
    if (attach_fd >= 0) {
        memset(&control, 0, sizeof control);
        msg.msg_control = control.buf;
        msg.msg_controllen = sizeof control.buf;
        struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
        cmsg->cmsg_level = SOL_SOCKET;
        cmsg->cmsg_type = SCM_RIGHTS;
        cmsg->cmsg_len = CMSG_LEN(sizeof(int));
        memcpy(CMSG_DATA(cmsg), &attach_fd, sizeof(int));
    }
    ssize_t sent = sendmsg(fd, &msg, MSG_NOSIGNAL);
    return sent == (ssize_t)len ? 0 : -1;
}

/* Receives exactly one SCM_RIGHTS descriptor (the transferred endpoint). */
static int receive_endpoint(int fd)
{
    char byte;
    struct iovec iov = { .iov_base = &byte, .iov_len = 1 };
    union { char buf[CMSG_SPACE(sizeof(int))]; struct cmsghdr align; } control;
    struct msghdr msg = { .msg_iov = &iov, .msg_iovlen = 1,
                          .msg_control = control.buf, .msg_controllen = sizeof control.buf };
    if (recvmsg(fd, &msg, MSG_CMSG_CLOEXEC) != 1 || (msg.msg_flags & (MSG_TRUNC | MSG_CTRUNC)))
        return -1;
    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
    if (!cmsg || cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS
        || cmsg->cmsg_len != CMSG_LEN(sizeof(int)) || CMSG_NXTHDR(&msg, cmsg))
        return -1;
    int received;
    memcpy(&received, CMSG_DATA(cmsg), sizeof(int));
    return received;
}

/* ---- disposable children ---- */

/* Child commands arrive as one byte on a private SEQPACKET socket; the child
   replies 'k' after the action succeeded or 'e' otherwise. */
static void child_loop(char role, int cmd, int tx, int nopass, int xfer)
{
    for (;;) {
        char op;
        if (recv(cmd, &op, 1, 0) != 1) _exit(2);
        int ok = 0;
        if (role == 'A') {
            switch (op) {
            case '1': ok = send_payload(tx, "A1", 2, -1) == 0; break;
            case '2': ok = send_payload(tx, "A2", 2, -1) == 0 && send_payload(tx, "A3", 2, -1) == 0; break;
            case 'n': ok = send_payload(nopass, "AN", 2, -1) == 0; break;
            /* Pass the sending endpoint to B and drop A's own copy, so B is
               the only remaining holder. A stays alive (no PID reuse). */
            case 'p': ok = send_payload(xfer, "P", 1, tx) == 0 && close(tx) == 0; tx = -1; break;
            case 'x': _exit(0);
            default: break;
            }
        } else {
            static char large[LARGE_PAYLOAD];
            switch (op) {
            case 'r': tx = receive_endpoint(xfer); ok = tx >= 0; break;
            case 'b': ok = send_payload(tx, "B1", 2, -1) == 0; break;
            case 'f': ok = send_payload(tx, "B2", 2, xfer) == 0; break;
            case 't': memset(large, 'B', sizeof large); ok = send_payload(tx, large, sizeof large, -1) == 0; break;
            case 'c': ok = send_payload(tx, "B4", 2, -1) == 0; break;
            case 'x': _exit(0);
            default: break;
            }
        }
        char reply = ok ? 'k' : 'e';
        if (send(cmd, &reply, 1, MSG_NOSIGNAL) != 1) _exit(2);
    }
}

struct child { pid_t pid; int pidfd; int cmd; };

/* clone3(CLONE_PIDFD) returns the pidfd atomically with creation, so no
   numeric-PID reuse window exists between fork and pidfd_open. */
static struct child spawn(char role, int keep_tx, int keep_nopass, int keep_xfer)
{
    int pair[2];
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, pair)) die("socketpair cmd");
    pid_t parent = getpid();
    int pidfd = -1;
    struct clone_args args;
    memset(&args, 0, sizeof args);
    args.flags = CLONE_PIDFD;
    args.pidfd = (uint64_t)(uintptr_t)&pidfd;
    args.exit_signal = SIGCHLD;
    long pid = syscall(SYS_clone3, &args, sizeof args);
    if (pid < 0) {
        if (errno == ENOSYS) unsupported("clone3");
        die("clone3");
    }
    if (pid == 0) {
        if (prctl(PR_SET_PDEATHSIG, SIGKILL) || getppid() != parent) _exit(3);
        alarm(CHILD_TIMEOUT_SECONDS);
        /* Keep only stdio, the command socket and this role's endpoints, so
           a child cannot read the receiver's socket or use the other
           child's command channel. */
        int keep[4] = { pair[1], keep_tx, keep_nopass, keep_xfer };
        for (int i = 1; i < 4; ++i)
            for (int j = i; j > 0 && keep[j] < keep[j - 1]; --j) { int t = keep[j]; keep[j] = keep[j - 1]; keep[j - 1] = t; }
        unsigned int next = 3;
        for (int i = 0; i < 4; ++i) {
            if (keep[i] < (int)next) continue;
            if ((unsigned int)keep[i] > next && syscall(SYS_close_range, next, (unsigned int)keep[i] - 1u, 0u)) _exit(5);
            next = (unsigned int)keep[i] + 1u;
        }
        if (syscall(SYS_close_range, next, ~0u, 0u)) _exit(5);
        child_loop(role, pair[1], keep_tx, keep_nopass, keep_xfer);
        _exit(4);
    }
    close(pair[1]);
    return (struct child){ (pid_t)pid, pidfd, pair[0] };
}

static void command(struct child *c, char op, const char *name)
{
    char reply;
    if (send(c->cmd, &op, 1, MSG_NOSIGNAL) != 1) die(name);
    ssize_t got = recv(c->cmd, &reply, 1, 0);
    if (got != 1) { if (got == 0) errno = EPIPE; die(name); }
    if (reply != 'k') { errno = EPROTO; die(name); }
}

static void reap(struct child *c, const char *name)
{
    siginfo_t info;
    memset(&info, 0, sizeof info);
    if (waitid(P_PIDFD, (id_t)c->pidfd, &info, WEXITED)) die(name);
    if (info.si_code != CLD_EXITED || info.si_status != 0) { errno = ECHILD; die(name); }
}

/* 'x' makes the child _exit without replying: require end-of-stream on its
   command socket, then reap it through the retained pidfd. */
static void exit_child(struct child *c, const char *name)
{
    char op = 'x', reply;
    if (send(c->cmd, &op, 1, MSG_NOSIGNAL) != 1) die(name);
    ssize_t got = recv(c->cmd, &reply, 1, 0);
    if (got != 0) { if (got > 0) errno = EPROTO; die(name); }
    reap(c, name);
}

/* ---- the prospective receiver ---- */

enum verdict { ACCEPT, MISSING, DUPLICATE, TRUNC, CTRUNC, UNEXPECTED_RIGHTS, UNEXPECTED_CONTROL, BAD_PIDFD };

static const char *verdict_name(enum verdict v)
{
    static const char *names[] = { "accept", "missing-pidfd", "duplicate-pidfd", "payload-truncated",
                                   "control-truncated", "unexpected-rights", "unexpected-control",
                                   "bad-pidfd" };
    return names[v];
}

struct received { enum verdict verdict; int pidfd; char payload[PAYLOAD_MAX + 1]; };

/* One bounded record per receive. Every installed descriptor is closed on
   every rejecting path; only an accepted record returns its single pidfd. */
static struct received receive_record(int fd, size_t control_len)
{
    struct received out = { .verdict = ACCEPT, .pidfd = -1 };
    char payload[PAYLOAD_MAX];
    union { char buf[CMSG_SPACE(sizeof(int) * CONTROL_FDS) * 2]; struct cmsghdr align; } control;
    memset(&control, 0, sizeof control);
    if (control_len > sizeof control.buf) control_len = sizeof control.buf;
    struct iovec iov = { .iov_base = payload, .iov_len = sizeof payload };
    struct msghdr msg = { .msg_iov = &iov, .msg_iovlen = 1,
                          .msg_control = control_len ? control.buf : NULL, .msg_controllen = control_len };
    ssize_t got = recvmsg(fd, &msg, MSG_CMSG_CLOEXEC | MSG_DONTWAIT);
    if (got < 0) die("recvmsg");
    size_t len = (size_t)got < sizeof payload ? (size_t)got : sizeof payload;
    memcpy(out.payload, payload, len);
    out.payload[len] = 0;

    int pidfd = -1, pidfds = 0, rights = 0, other = 0, negative = 0, short_control = 0;
    const unsigned char *control_end = (const unsigned char *)control.buf + msg.msg_controllen;
    for (struct cmsghdr *c = CMSG_FIRSTHDR(&msg); c; c = CMSG_NXTHDR(&msg, c)) {
        if (c->cmsg_level != SOL_SOCKET) { ++other; continue; }
        if (c->cmsg_len < CMSG_LEN(0)) { ++other; continue; }
        /* Read only bytes the kernel actually returned: a header claiming
           more than msg_controllen is treated as control truncation, and
           every descriptor within the returned bytes is closed (no clamp). */
        const unsigned char *data = CMSG_DATA(c);
        size_t claimed = c->cmsg_len - CMSG_LEN(0);
        size_t available = data <= control_end ? (size_t)(control_end - data) : 0;
        if (claimed > available) { ++short_control; claimed = available; }
        size_t n = claimed / sizeof(int);
        for (size_t i = 0; i < n; ++i) {
            int value;
            memcpy(&value, data + i * sizeof(int), sizeof(int));
            if (c->cmsg_type == SCM_PIDFD) {
                ++pidfds;
                if (value < 0) { ++negative; continue; }
                if (pidfd < 0) pidfd = value; else close(value);
            } else if (c->cmsg_type == SCM_RIGHTS) {
                ++rights;
                if (value >= 0) close(value);
            }
        }
        if (c->cmsg_type != SCM_PIDFD && c->cmsg_type != SCM_RIGHTS) ++other;
    }

    if ((msg.msg_flags & MSG_CTRUNC) || short_control) out.verdict = CTRUNC;
    else if (msg.msg_flags & MSG_TRUNC) out.verdict = TRUNC;
    else if (rights) out.verdict = UNEXPECTED_RIGHTS;
    else if (other) out.verdict = UNEXPECTED_CONTROL;
    else if (negative) out.verdict = BAD_PIDFD;
    else if (pidfds > 1) out.verdict = DUPLICATE;
    else if (pidfds == 0) out.verdict = MISSING;

    if (out.verdict == ACCEPT) out.pidfd = pidfd;
    else if (pidfd >= 0) close(pidfd);
    return out;
}

/* Expects an accepted record from `want` and not from `other`. */
static void expect_sender(const char *name, struct received r, const char *payload,
                          const struct child *want, const struct child *other)
{
    char detail[160];
    if (strcmp(r.payload, payload)) {
        snprintf(detail, sizeof detail, "payload %s, expected %s", r.payload, payload);
        fail(name, detail);
    } else if (r.verdict != ACCEPT) {
        snprintf(detail, sizeof detail, "receiver verdict %s", verdict_name(r.verdict));
        fail(name, detail);
    } else {
        enum identity w = same_process(r.pidfd, want->pidfd);
        enum identity o = same_process(r.pidfd, other->pidfd);
        if (w == NOT_PIDFS || o == NOT_PIDFS) { close(r.pidfd); errno = ENOTSUP; unsupported("pidfs identity"); }
        if (w == SAME && o == DIFFERENT) pass(name, "SCM_PIDFD names the expected retained lifetime");
        else fail(name, w == SAME ? "SCM_PIDFD also matches the other child" : "SCM_PIDFD does not match the expected child");
    }
    if (r.pidfd >= 0) close(r.pidfd);
}

static void expect_reject(const char *name, struct received r, enum verdict want)
{
    char detail[160];
    snprintf(detail, sizeof detail, "receiver verdict %s (payload %s)", verdict_name(r.verdict), r.payload);
    if (r.verdict == want) pass(name, detail); else fail(name, detail);
    if (r.pidfd >= 0) close(r.pidfd);
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    alarm(TIMEOUT_SECONDS); /* default SIGALRM ends the parent; children have PDEATHSIG */
    printf("INFO channel-identity-test: owned processes only, timeout %us\n", TIMEOUT_SECONDS);
    int baseline = count_own_fds();

    /* B is spawned before the channel exists, so it can only obtain the
       sending endpoint through A's explicit transfer. */
    int xfer[2];
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, xfer)) die("socketpair xfer");
    struct child b = spawn('B', -1, -1, xfer[1]);
    close(xfer[1]);

    int chan[2], nopass[2];
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, chan)) die("socketpair chan");
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, nopass)) die("socketpair nopass");
    int on = 1;
    /* The receiver enables SO_PASSPIDFD before any message is queued. */
    if (setsockopt(chan[0], SOL_SOCKET, SO_PASSPIDFD, &on, sizeof on)) unsupported("SO_PASSPIDFD");
    struct child a = spawn('A', chan[1], nopass[1], xfer[0]);
    close(chan[1]);
    close(nopass[1]);
    close(xfer[0]);
    int rx = chan[0];

    /* 1. Direct message from the original holder. */
    command(&a, '1', "A send A1");
    expect_sender("original-holder", receive_record(rx, 256), "A1", &a, &b);

    /* 2. A queues A2/A3 and an unauthenticated-channel message, then passes
          the endpoint; B sends B1 on the transferred endpoint. */
    command(&a, '2', "A send A2 A3");
    command(&a, 'n', "A send nopass");
    command(&a, 'p', "A pass endpoint");
    command(&b, 'r', "B receive endpoint");
    command(&b, 'b', "B send B1");

    /* 3. Queued before transfer, received after it: still attributed to A. */
    expect_sender("queued-before-transfer", receive_record(rx, 256), "A2", &a, &b);

    /* 4. Receiver without SO_PASSPIDFD gets no pidfd and must reject. */
    expect_reject("missing-passpidfd", receive_record(nopass[0], 256), MISSING);
    close(nopass[0]);

    /* 5. Sender exits and is reaped while its message is still queued. The
          retained pidfd keeps the lifetime's pidfs identity; only an exact
          match or a kernel-reported pidfd error is acceptable. A match with B is not. */
    exit_child(&a, "A exit");
    {
        struct received r = receive_record(rx, 256);
        char detail[160];
        if (strcmp(r.payload, "A3")) {
            fail("reaped-sender", "unexpected payload");
        } else if (r.verdict == BAD_PIDFD) {
            /* Older kernels return a negative errno in the pidfd slot. */
            pass("reaped-sender", "fail-closed: kernel returned an error instead of a pidfd");
        } else if (r.verdict != ACCEPT) {
            snprintf(detail, sizeof detail, "receiver verdict %s", verdict_name(r.verdict));
            fail("reaped-sender", detail);
        } else {
            enum identity w = same_process(r.pidfd, a.pidfd), o = same_process(r.pidfd, b.pidfd);
            if (w == SAME && o == DIFFERENT) pass("reaped-sender", "SCM_PIDFD names the exited, reaped A lifetime");
            else if (w == NOT_PIDFS || o == NOT_PIDFS) { errno = ENOTSUP; unsupported("pidfs identity"); }
            else fail("reaped-sender", "SCM_PIDFD does not name A");
        }
        if (r.pidfd >= 0) close(r.pidfd);
    }

    /* 6. The key case: after transfer the kernel names B, not the original A. */
    expect_sender("after-transfer", receive_record(rx, 256), "B1", &b, &a);

    /* 7. Unexpected SCM_RIGHTS is closed and rejected. */
    command(&b, 'f', "B send B2 with rights");
    expect_reject("unexpected-rights", receive_record(rx, 256), UNEXPECTED_RIGHTS);

    /* 8. Payload larger than one bounded record. */
    command(&b, 't', "B send large");
    expect_reject("payload-truncated", receive_record(rx, 256), TRUNC);

    /* 9. Control buffer too small for the pidfd. */
    command(&b, 'c', "B send B4");
    expect_reject("control-truncated", receive_record(rx, sizeof(struct cmsghdr)), CTRUNC);

    /* 10. Connection-time peer identity on a socketpair names its creator
           (this parent), not the later sender: possession of the endpoint is
           not sender identity. Compared by pidfs identity, not numeric PID. */
    {
        int peer = -1, self = (int)syscall(SYS_pidfd_open, getpid(), 0);
        socklen_t len = sizeof peer;
        if (self < 0) die("pidfd_open self");
        if (getsockopt(rx, SOL_SOCKET, SO_PEERPIDFD, &peer, &len) || len != sizeof peer || peer < 0) die("SO_PEERPIDFD");
        enum identity s = same_process(peer, self), wa = same_process(peer, a.pidfd), wb = same_process(peer, b.pidfd);
        if (s == NOT_PIDFS || wa == NOT_PIDFS || wb == NOT_PIDFS) { errno = ENOTSUP; unsupported("pidfs identity"); }
        if (s == SAME && wa == DIFFERENT && wb == DIFFERENT)
            pass("peer-snapshot", "SO_PEERPIDFD names the socketpair creator, not A or B");
        else fail("peer-snapshot", "SO_PEERPIDFD did not name only the creator");
        close(peer);
        close(self);
    }

    exit_child(&b, "B exit");
    close(rx);
    close(a.cmd); close(a.pidfd);
    close(b.cmd); close(b.pidfd);

    /* 11. No received or retained descriptor leaked on any path. */
    int end = count_own_fds();
    char detail[80];
    snprintf(detail, sizeof detail, "%d descriptors at start and %d at end", baseline, end);
    if (end == baseline) pass("descriptor-cleanup", detail); else fail("descriptor-cleanup", detail);

    printf("RESULT %s (%d failure%s)\n", failures ? "FAIL" : "PASS", failures, failures == 1 ? "" : "s");
    return failures ? 1 : 0;
}
