/* Owned-process test of the native supervisor channel receiver
   (supervisor_channel.c), approved scope: board question 23.

   Every process, socket and descriptor here is created by this test. It
   requests no privilege, signals nothing it did not create, changes no
   namespace, mounts nothing, probes nothing host-wide and starts no VM.
   Children are clone3(CLONE_PIDFD) disposable processes; identity is pidfs
   dev/ino through writ_roles_add, never a numeric PID. The role indices here
   are synthetic supervisor labels, not authenticated principals.

   Exit status: 0 every expected outcome observed; 1 an outcome changed or a
   system call failed; 77 a required kernel feature is missing. Death by
   SIGALRM (the fixed timeout) is a failure. */
#define _GNU_SOURCE
#include "supervisor_channel.h"

#include <dirent.h>
#include <errno.h>
#include <linux/sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <unistd.h>

#define TIMEOUT_SECONDS 30u
#define CHILD_TIMEOUT_SECONDS 20u
#define OVERSIZE (WRIT_CHANNEL_PAYLOAD_MAX + 1)
#define EXTRAS (WRIT_CHANNEL_ROLES + 1)

static int failures;

static void check(int ok, const char *name, const char *detail)
{
    printf("%s %s: %s\n", ok ? "PASS" : "FAIL", name, detail);
    if (!ok) ++failures;
}

static _Noreturn void die(const char *what)
{
    printf("ERROR %s: %s\n", what, strerror(errno));
    exit(1);
}

static int count_own_fds(void)
{
    DIR *dir = opendir("/proc/self/fd");
    if (!dir) die("opendir /proc/self/fd");
    int count = 0;
    struct dirent *entry;
    while ((entry = readdir(dir))) if (entry->d_name[0] != '.') ++count;
    closedir(dir);
    return count - 1; /* the directory stream's own descriptor */
}

/* ---- child-side sending ---- */

static int send_bytes(int fd, const void *bytes, size_t len, int attach_fd)
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
    return sendmsg(fd, &msg, MSG_NOSIGNAL) == (ssize_t)len ? 0 : -1;
}

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

/* Child commands are one byte on a private SEQPACKET socket; the child
   replies 'k' after the action succeeded or 'e' otherwise.
     g  send "ok" on tx          e  send a zero-length record on tx
     r  send "R" on tx carrying SCM_RIGHTS   L  send an oversize record on tx
     n  send "ok" on tx2         p  pass tx to the peer on xfer, drop own copy
     v  receive an endpoint from xfer into tx    x  exit 0 without replying */
static void child_loop(int cmd, int tx, int tx2, int xfer)
{
    static unsigned char large[OVERSIZE];
    for (;;) {
        char op;
        if (recv(cmd, &op, 1, 0) != 1) _exit(2);
        int ok = 0;
        switch (op) {
        case 'g': ok = send_bytes(tx, "ok", 2, -1) == 0; break;
        case 'e': ok = send_bytes(tx, "", 0, -1) == 0; break;
        case 'r': ok = send_bytes(tx, "R", 1, tx) == 0; break;
        case 'L': memset(large, 'L', sizeof large); ok = send_bytes(tx, large, sizeof large, -1) == 0; break;
        case 'n': ok = send_bytes(tx2, "ok", 2, -1) == 0; break;
        case 'p': ok = send_bytes(xfer, "P", 1, tx) == 0 && close(tx) == 0; tx = -1; break;
        case 'v': tx = receive_endpoint(xfer); ok = tx >= 0; break;
        case 'x': _exit(0);
        default: break;
        }
        char reply = ok ? 'k' : 'e';
        if (send(cmd, &reply, 1, MSG_NOSIGNAL) != 1) _exit(2);
    }
}

struct child { int pidfd; int cmd; };

static _Noreturn void unsupported(const char *what)
{
    printf("UNSUPPORTED %s: %s\n", what, strerror(errno));
    exit(77);
}

/* clone3(CLONE_PIDFD) returns the pidfd atomically with creation. The child
   keeps only stdio, its command socket and its listed endpoints. */
static struct child spawn(int tx, int tx2, int xfer)
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
        int keep[4] = { pair[1], tx, tx2, xfer };
        for (int i = 1; i < 4; ++i)
            for (int j = i; j > 0 && keep[j] < keep[j - 1]; --j) { int t = keep[j]; keep[j] = keep[j - 1]; keep[j - 1] = t; }
        unsigned int next = 3;
        for (int i = 0; i < 4; ++i) {
            if (keep[i] < (int)next) continue;
            if ((unsigned int)keep[i] > next && syscall(SYS_close_range, next, (unsigned int)keep[i] - 1u, 0u)) _exit(5);
            next = (unsigned int)keep[i] + 1u;
        }
        if (syscall(SYS_close_range, next, ~0u, 0u)) _exit(5);
        child_loop(pair[1], tx, tx2, xfer);
        _exit(4);
    }
    close(pair[1]);
    return (struct child){ pidfd, pair[0] };
}

static void command(struct child *c, char op, const char *name)
{
    char reply;
    if (send(c->cmd, &op, 1, MSG_NOSIGNAL) != 1) die(name);
    ssize_t got = recv(c->cmd, &reply, 1, 0);
    if (got != 1) { if (got == 0) errno = EPIPE; die(name); }
    if (reply != 'k') { errno = EPROTO; die(name); }
}

/* 'x' makes the child exit without replying: require end-of-stream on its
   command socket, reap it through the retained pidfd, release both handles. */
static void exit_child(struct child *c, const char *name)
{
    char op = 'x', reply;
    if (send(c->cmd, &op, 1, MSG_NOSIGNAL) != 1) die(name);
    ssize_t got = recv(c->cmd, &reply, 1, 0);
    if (got != 0) { if (got > 0) errno = EPROTO; die(name); }
    siginfo_t info;
    memset(&info, 0, sizeof info);
    if (waitid(P_PIDFD, (id_t)c->pidfd, &info, WEXITED)) die(name);
    if (info.si_code != CLD_EXITED || info.si_status != 0) { errno = ECHILD; die(name); }
    close(c->cmd);
    close(c->pidfd);
}

/* ---- receiver helpers ---- */

static void socketpair_or_die(int pair[2], const char *name)
{
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, pair)) die(name);
}

static struct writ_channel_record receive(int fd, const struct writ_roles *roles)
{
    struct writ_channel_record r;
    if (writ_channel_receive(fd, roles, &r)) die("writ_channel_receive");
    return r;
}

static void expect(const char *name, const struct writ_channel_record *r,
                   enum writ_channel_verdict verdict, uint32_t role)
{
    char detail[96];
    snprintf(detail, sizeof detail, "verdict %d role %u length %zu (expected %d role %u)",
             (int)r->verdict, r->role, r->length, (int)verdict, role);
    check(r->verdict == verdict && r->role == role, name, detail);
}

static void add_or_die(struct writ_roles *roles, uint32_t index, int pidfd)
{
    int err = writ_roles_add(roles, index, pidfd);
    if (err) { errno = err; die("writ_roles_add"); }
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    alarm(TIMEOUT_SECONDS);
    printf("INFO supervisor-channel-test: owned processes only, timeout %us\n", TIMEOUT_SECONDS);
    int baseline = count_own_fds();

    int profile = writ_channel_profile_check();
    if (profile == ENOTSUP) { errno = ENOTSUP; unsupported("pidfs or SO_PASSPIDFD"); }
    if (profile) { errno = profile; die("profile check"); }
    check(1, "profile_check_passes", "pidfs and SO_PASSPIDFD available");

    /* B exists before the channel, so only an explicit transfer gives it the
       sending endpoint. A also holds a sender whose receiver never enabled
       SO_PASSPIDFD. C is spawned but never registered. */
    int xfer[2], ch[2], chn[2], chc[2];
    socketpair_or_die(xfer, "socketpair xfer");
    struct child b = spawn(-1, -1, xfer[1]);
    close(xfer[1]);
    socketpair_or_die(ch, "socketpair ch");
    socketpair_or_die(chn, "socketpair chn");
    socketpair_or_die(chc, "socketpair chc");
    if (writ_channel_enable(ch[0])) die("enable ch");
    if (writ_channel_enable(chc[0])) die("enable chc");
    struct child a = spawn(ch[1], chn[1], xfer[0]);
    struct child c = spawn(chc[1], -1, -1);
    close(ch[1]); close(chn[1]); close(chc[1]); close(xfer[0]);

    struct writ_roles roles;
    memset(&roles, 0, sizeof roles);
    add_or_die(&roles, 1, a.pidfd);
    add_or_die(&roles, 2, b.pidfd);

    command(&a, 'g', "A send");
    struct writ_channel_record r = receive(ch[0], &roles);
    expect("role_one_attributed", &r, WRIT_FROM_ROLE, 1);
    check(r.length == 2 && !memcmp(r.payload, "ok", 2), "role_one_payload", "payload ok, length 2");

    command(&a, 'e', "A send empty");
    r = receive(ch[0], &roles);
    expect("empty_record_attributed", &r, WRIT_FROM_ROLE, 1);
    check(r.length == 0, "empty_record_length", "length 0");

    command(&a, 'r', "A send rights");
    r = receive(ch[0], &roles);
    expect("rights_rejected", &r, WRIT_UNEXPECTED_RIGHTS, 0);

    command(&a, 'r', "A send rights again");
    command(&a, 'g', "A send good");
    struct writ_channel_record first = receive(ch[0], &roles);
    r = receive(ch[0], &roles);
    check(first.verdict == WRIT_UNEXPECTED_RIGHTS && r.verdict == WRIT_FROM_ROLE && r.role == 1,
          "reject_then_accept", "rights record rejected, next record from role 1");

    command(&a, 'L', "A send oversize");
    r = receive(ch[0], &roles);
    expect("payload_truncated", &r, WRIT_PAYLOAD_TRUNCATED, 0);

    command(&a, 'g', "A send for short control");
    if (writ_channel_receive_with_control(ch[0], &roles, &r, sizeof(struct cmsghdr))) die("receive_with_control");
    expect("control_truncated", &r, WRIT_CONTROL_TRUNCATED, 0);

    command(&c, 'g', "C send");
    r = receive(chc[0], &roles);
    expect("unregistered_sender_unknown", &r, WRIT_UNKNOWN_SENDER, 0);

    command(&a, 'n', "A send without enable");
    r = receive(chn[0], &roles);
    expect("missing_sender_without_enable", &r, WRIT_MISSING_SENDER, 0);

    /* Role table edges. */
    {
        struct writ_roles snap = roles;
        int ok = writ_roles_add(&roles, 3, a.pidfd) == EINVAL           /* same lifetime, new index */
              && writ_roles_add(&roles, 1, c.pidfd) == EINVAL           /* same index, new lifetime */
              && writ_roles_add(&roles, 0, c.pidfd) == EINVAL           /* reserved index */
              && writ_roles_add(&roles, 4, ch[0]) == EINVAL             /* not a pidfd */
              && roles.count == snap.count && !memcmp(&roles, &snap, sizeof roles);
        check(ok, "duplicate_role_rejected", "duplicate lifetime/index, index 0, non-pidfd: EINVAL, table unchanged");

        struct writ_roles full;
        memset(&full, 0, sizeof full);
        struct child extra[EXTRAS];
        for (int i = 0; i < EXTRAS; ++i) extra[i] = spawn(-1, -1, -1);
        for (int i = 0; i < WRIT_CHANNEL_ROLES; ++i) add_or_die(&full, (uint32_t)i + 1u, extra[i].pidfd);
        struct writ_roles before = full;
        int err = writ_roles_add(&full, 99, extra[WRIT_CHANNEL_ROLES].pidfd);
        check(err == ENOSPC && !memcmp(&full, &before, sizeof full) && full.count == WRIT_CHANNEL_ROLES,
              "role_table_full", "ninth add: ENOSPC, table unchanged");
        for (int i = 0; i < EXTRAS; ++i) exit_child(&extra[i], "extra exit");
    }

    /* A queues a record, passes the endpoint to B and is reaped; the queued
       record stays attributed to A's lifetime (or fails closed), while B's
       record on the transferred endpoint names role 2. */
    command(&a, 'g', "A send before transfer");
    command(&a, 'p', "A pass endpoint");
    command(&b, 'v', "B receive endpoint");
    exit_child(&a, "A exit");
    r = receive(ch[0], &roles);
    check((r.verdict == WRIT_FROM_ROLE && r.role == 1) || r.verdict == WRIT_SENDER_ERROR,
          "reaped_role_sender", r.verdict == WRIT_FROM_ROLE ? "role 1 after reaping" : "fail-closed sender error");
    command(&b, 'g', "B send");
    r = receive(ch[0], &roles);
    expect("transferred_endpoint_attributes_receiver_role", &r, WRIT_FROM_ROLE, 2);

    exit_child(&b, "B exit");
    exit_child(&c, "C exit");
    close(ch[0]); close(chn[0]); close(chc[0]);

    int end = count_own_fds();
    char detail[80];
    snprintf(detail, sizeof detail, "%d descriptors at start and %d at end", baseline, end);
    check(end == baseline, "descriptor_cleanup", detail);

    printf("RESULT %s (%d failure%s)\n", failures ? "FAIL" : "PASS", failures, failures == 1 ? "" : "s");
    return failures ? 1 : 0;
}
