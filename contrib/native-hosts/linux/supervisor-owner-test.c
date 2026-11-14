/* Owned-process test of the native supervisor driver (supervisor_owner.c)
   against the real Bend owner, approved scope: board question 23.

   Usage: supervisor-owner-test NODE BRIDGE MODULE FAKE (absolute paths; FAKE is
   supervisor-owner-fake.mjs, an explicitly malformed peer; BRIDGE is
   runtime/supervisor-policy.mjs, MODULE the generated
   hosts/linux/monitor/SupervisorDriverModule.bend: the SYNTHETIC canary
   issuer, in which principal 101 issued approval 5 and worker 1 holds a grant
   expiring at 120, with the owner's clock at 110 and no role map).
   The role map comes from a provisioning record this test writes to a 0600
   file in a private directory under $TMPDIR (or /tmp): role 1 is principal
   101, role 2 is 102, over the canary issuer root. Worker 1 is launched by
   the driver (this binary re-executed with --worker).

   Every process, socket and descriptor here is created by this test. It
   requests no privilege, signals only its own children (the drained worker
   through its pidfd and its own interpreter), changes no namespace, mounts
   nothing, probes nothing host-wide and starts no VM. Clock samples are
   scripted because the synthetic issuer's times are not a host time base;
   CLOCK_BOOTTIME is exercised separately.

   Exit status: 0 every expected outcome observed; 1 an outcome changed or a
   system call failed; 77 a required kernel feature is missing. */
#define _GNU_SOURCE
#include "supervisor_owner.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/sched.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <unistd.h>

#define TIMEOUT_SECONDS 120u
#define CHILD_TIMEOUT_SECONDS 100u

static int failures;
static const char *node, *bridge, *module, *fake;

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

static _Noreturn void unsupported(const char *what)
{
    printf("UNSUPPORTED %s: %s\n", what, strerror(errno));
    exit(77);
}

static int count_own_fds(void)
{
    DIR *dir = opendir("/proc/self/fd");
    if (!dir) die("opendir /proc/self/fd");
    int count = 0;
    struct dirent *entry;
    while ((entry = readdir(dir))) if (entry->d_name[0] != '.') ++count;
    closedir(dir);
    return count - 1;
}

/* LINUXSUP v1 control payloads (SupervisorOwner.encode_control). */
static const unsigned char revoke5[16] = { 1,0,0,0, 1,0,0,0, 1,0,0,0, 5,0,0,0 };
static const unsigned char malformed[3] = { 1, 2, 3 };
static const unsigned char revoke16[16] = { 1,0,0,0, 1,0,0,0, 1,0,0,0, 16,0,0,0 };

/* SupervisorApprovalTests.fresh_source() and fresh_write() as tags 2 and 3:
   serial 900 of principal 101 (read domain 5, source 10v4) and of principal
   102 (write domain 6, destination 20v8), over the fixture scope (live 1/2/3,
   invocation 99, manifest [10v4], destination 20v8, code 7 x 8, Summarize,
   output 2, write domain 6, subject 7), rights 3, valid until 200. */
#define APPROVAL_WORDS 32
#define APPROVAL_SCOPE 1, 2, 3, 99, 1, 10, 4, 20, 8, 7, 7, 7, 7, 7, 7, 7, 7, 3, 2, 6, 7
static const uint32_t source_words[APPROVAL_WORDS] = {
    1, 2, 29, 1, 900, 101, 10, 4, 5, APPROVAL_SCOPE, 3, 200
};
static const uint32_t write_words[APPROVAL_WORDS] = {
    1, 3, 29, 1, 900, 102, 20, 8, 6, APPROVAL_SCOPE, 3, 200
};
static unsigned char submit_source[4 * APPROVAL_WORDS], submit_write[4 * APPROVAL_WORDS];

/* SupervisorProvisionTests.canary(): live 1/2/3, roles 1 -> 101 and 2 -> 102,
   the canary directory (five authorities) and placements (four). */
static const uint32_t canary_words[42] = {
    1, 1, 2, 3, 2, 1, 101, 2, 102,
    5, 1, 101, 5, 2, 102, 6, 1, 103, 9, 1, 104, 7, 2, 105, 5,
    4, 1, 10, 4, 5, 1, 11, 4, 7, 2, 20, 8, 6, 2, 20, 9, 6
};

static int records = -1;          /* the private record directory */
static int inheritable = -1;      /* a descriptor without close-on-exec */
static char records_path[256];

static void record_bytes(const uint32_t *words, size_t count, unsigned char *out)
{
    for (size_t i = 0; i < count; ++i)
        for (unsigned int b = 0; b < 4; ++b) out[4 * i + b] = (unsigned char)(words[i] >> (8 * b));
}

static void write_record(const char *name, const unsigned char *bytes, size_t length, mode_t mode)
{
    int fd = openat(records, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd < 0) die(name);
    if (write(fd, bytes, length) != (ssize_t)length || fchmod(fd, mode) || close(fd)) die(name);
}

static const char *const record_names[] = {
    "canary", "writable", "linked", "linked-too", "fifo", "mismatch", "symlink", "oversized", "via"
};

/* At exit after a failure: remove what is left, ignoring errors. */
static void discard_records(void)
{
    if (records < 0) return;
    for (size_t i = 0; i < sizeof record_names / sizeof record_names[0]; ++i)
        (void)unlinkat(records, record_names[i], 0);
    (void)rmdir(records_path);
}

static void make_records(void)
{
    const char *base = getenv("TMPDIR");
    if (!base || base[0] != '/') base = "/tmp";
    if (snprintf(records_path, sizeof records_path, "%s/writ-provision-XXXXXX", base) >= (int)sizeof records_path) {
        errno = ENAMETOOLONG;
        die("record directory");
    }
    if (!mkdtemp(records_path)) die("mkdtemp");
    records = open(records_path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (records < 0) { (void)rmdir(records_path); die("open record directory"); }
    if (atexit(discard_records)) die("atexit");
    unsigned char bytes[sizeof canary_words];
    record_bytes(canary_words, 42, bytes);
    write_record("canary", bytes, sizeof bytes, 0600);
    write_record("writable", bytes, sizeof bytes, 0620);
    write_record("linked", bytes, sizeof bytes, 0600);
    if (linkat(records, "linked", records, "linked-too", 0)) die("linkat");
    if (mkfifoat(records, "fifo", 0600)) die("mkfifoat");
    uint32_t other[42];
    memcpy(other, canary_words, sizeof other);
    other[3] = 4; /* live stamp authority 4: not the canary issuer's root */
    record_bytes(other, 42, bytes);
    write_record("mismatch", bytes, sizeof bytes, 0600);
    if (symlinkat("canary", records, "symlink")) die("symlinkat");
    if (symlinkat(".", records, "via")) die("symlinkat via");
    static unsigned char big[WRIT_CHANNEL_PAYLOAD_MAX + 1];
    write_record("oversized", big, sizeof big, 0600);
}

static void remove_records(void)
{
    for (size_t i = 0; i < sizeof record_names / sizeof record_names[0]; ++i)
        if (unlinkat(records, record_names[i], 0)) die("unlink record");
    close(records);
    records = -1;
    if (rmdir(records_path)) die("rmdir record directory");
}

/* Re-executed worker: exits 12 unless the driver set its parent-death
   signal to SIGKILL, 9 if it inherited any descriptor beyond 0-2, 10 if
   SIGPIPE is still ignored (the test ignores it) and 11 if any signal is
   blocked (the test blocks SIGUSR2); otherwise stops itself once so the test
   sees the checks passed, then waits to be killed. */
static _Noreturn void worker_main(void)
{
    int death = 0;
    if (prctl(PR_GET_PDEATHSIG, &death) || death != SIGKILL) _exit(12);
    alarm(CHILD_TIMEOUT_SECONDS);
    if (count_own_fds() != 3) _exit(9);
    struct sigaction old;
    if (sigaction(SIGPIPE, NULL, &old) || old.sa_handler != SIG_DFL) _exit(10);
    sigset_t mask;
    if (sigprocmask(SIG_SETMASK, NULL, &mask) || sigismember(&mask, SIGUSR2)) _exit(11);
    raise(SIGSTOP);
    for (;;) pause();
}

/* ---- owned children ----
   Commands are one byte on a private SEQPACKET socket; the child replies 'k'
   after the send succeeded, 'e' otherwise.
     r  send revoke(5) on tx     b  send a 3-byte payload on tx
     s  send submit_source       w  send submit_write      v  send revoke(16)
   A child with tx == -1 is a worker that only waits. */
static void child_loop(int cmd, int tx)
{
    for (;;) {
        char op;
        if (recv(cmd, &op, 1, 0) != 1) _exit(2);
        int ok = 0;
        if (op == 'r') ok = send(tx, revoke5, sizeof revoke5, MSG_NOSIGNAL) == (ssize_t)sizeof revoke5;
        else if (op == 'b') ok = send(tx, malformed, sizeof malformed, MSG_NOSIGNAL) == (ssize_t)sizeof malformed;
        else if (op == 's') ok = send(tx, submit_source, sizeof submit_source, MSG_NOSIGNAL) == (ssize_t)sizeof submit_source;
        else if (op == 'w') ok = send(tx, submit_write, sizeof submit_write, MSG_NOSIGNAL) == (ssize_t)sizeof submit_write;
        else if (op == 'v') ok = send(tx, revoke16, sizeof revoke16, MSG_NOSIGNAL) == (ssize_t)sizeof revoke16;
        char reply = ok ? 'k' : 'e';
        if (send(cmd, &reply, 1, MSG_NOSIGNAL) != 1) _exit(2);
    }
}

/* `borrowed`: the pidfd belongs to the driver (a launched worker). */
struct child { int pidfd; int cmd; int borrowed; };

static struct child spawn(int tx)
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
        int keep[2] = { pair[1], tx };
        if (keep[1] >= 0 && keep[1] < keep[0]) { int t = keep[0]; keep[0] = keep[1]; keep[1] = t; }
        unsigned int next = 3;
        for (int i = 0; i < 2; ++i) {
            if (keep[i] < (int)next) continue;
            if ((unsigned int)keep[i] > next && syscall(SYS_close_range, next, (unsigned int)keep[i] - 1u, 0u)) _exit(5);
            next = (unsigned int)keep[i] + 1u;
        }
        if (syscall(SYS_close_range, next, ~0u, 0u)) _exit(5);
        child_loop(pair[1], tx);
        _exit(4);
    }
    close(pair[1]);
    return (struct child){ pidfd, pair[0], 0 };
}

static void command(struct child *c, char op, const char *name)
{
    char reply;
    if (send(c->cmd, &op, 1, MSG_NOSIGNAL) != 1) die(name);
    ssize_t got = recv(c->cmd, &reply, 1, 0);
    if (got != 1) { if (got == 0) errno = EPIPE; die(name); }
    if (reply != 'k') { errno = EPROTO; die(name); }
}

/* Nonblocking: is the child still running? */
static int alive(struct child *c)
{
    siginfo_t info;
    memset(&info, 0, sizeof info);
    if (waitid(P_PIDFD, (id_t)c->pidfd, &info, WEXITED | WNOHANG | WNOWAIT)) die("waitid alive");
    return info.si_pid == 0;
}

/* Waits at most five seconds for the child to exit, then reaps it; returns 1
   only when it was killed by SIGKILL. A child still running is not reaped. */
static int reaped_by_kill(struct child *c)
{
    struct pollfd p = { .fd = c->pidfd, .events = POLLIN };
    int ready = poll(&p, 1, 5000);
    if (ready < 0) die("poll pidfd");
    if (ready == 0) return 0;
    siginfo_t info;
    memset(&info, 0, sizeof info);
    if (waitid(P_PIDFD, (id_t)c->pidfd, &info, WEXITED)) die("waitid reap");
    return info.si_code == CLD_KILLED && info.si_status == SIGKILL;
}

static void retire(struct child *c)
{
    if (c->pidfd < 0) return;
    if (alive(c)) {
        if (syscall(SYS_pidfd_send_signal, c->pidfd, SIGKILL, NULL, 0)) die("kill own child");
        (void)reaped_by_kill(c);
    } else {
        siginfo_t info;
        if (waitid(P_PIDFD, (id_t)c->pidfd, &info, WEXITED | WNOHANG)) die("waitid retire");
    }
    if (!c->borrowed) close(c->pidfd);
    if (c->cmd >= 0) close(c->cmd);
    c->pidfd = c->cmd = -1;
}

/* After reaped_by_kill: release a reaped child's handles, or retire one that
   is still running. */
static void settle(struct child *c, int reaped)
{
    if (!reaped) { retire(c); return; }
    if (!c->borrowed) close(c->pidfd);
    if (c->cmd >= 0) close(c->cmd);
    c->pidfd = c->cmd = -1;
}

/* ---- scripted clock ---- */
struct script { size_t next, count; struct writ_clock_sample sample[8]; };

static struct writ_clock_sample scripted(void *context)
{
    struct script *s = context;
    if (s->next == s->count) { errno = ERANGE; die("clock script exhausted"); }
    return s->sample[s->next++];
}

static struct writ_clock_sample at(uint32_t now)
{
    return (struct writ_clock_sample){ WRIT_CLOCK_READING, now };
}

/* ---- one scenario: fresh interpreter, channel and children ---- */
struct scenario {
    struct writ_policy policy;
    struct writ_supervisor sup;
    struct writ_roles roles;
    struct script clock;
    int channel;
    int fake;
    struct child a, b, c, w;
    int worker_clean;   /* the launched worker saw only descriptors 0-2 */
    int provisioned;    /* `provision` was sent and PROVISIONED */
};

/* Launches worker `worker` through the driver and waits for its descriptor
   check: stopped means it passed, exited means it failed. */
static struct child launch(struct writ_supervisor *sup, uint32_t worker, int *clean)
{
    char *argv[] = { "supervisor-owner-worker", "--worker", NULL };
    char *envp[] = { NULL };
    pid_t pid;
    int pidfd = writ_supervisor_launch_worker(sup, worker, "/proc/self/exe", argv, envp, &pid);
    if (pidfd < 0) die("launch worker");
    siginfo_t info;
    memset(&info, 0, sizeof info);
    if (waitid(P_PIDFD, (id_t)pidfd, &info, WSTOPPED | WEXITED | WNOWAIT)) die("waitid worker");
    *clean = info.si_code == CLD_STOPPED;
    if (*clean && syscall(SYS_pidfd_send_signal, pidfd, SIGCONT, NULL, 0)) die("continue worker");
    return (struct child){ pidfd, -1, 1 };
}

static void begin_raw(struct scenario *s, const struct writ_clock_sample *samples, size_t count,
                      int with_fake, const char *provision)
{
    memset(s, 0, sizeof *s);
    s->fake = with_fake;
    if (count > 8) { errno = EINVAL; die("script"); }
    if (count) memcpy(s->clock.sample, samples, count * sizeof *samples);
    s->clock.count = count;
    if (writ_policy_start(&s->policy, node, bridge, s->fake ? fake : module)) die("policy start");
    writ_supervisor_init(&s->sup, &s->policy, scripted, &s->clock);
    int ch[2];
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, ch)) die("socketpair channel");
    if (writ_channel_enable(ch[0])) die("channel enable");
    s->channel = ch[0];
    s->a = spawn(ch[1]);
    s->b = spawn(ch[1]);
    s->c = spawn(ch[1]);
    close(ch[1]);
    s->w = (struct child){ -1, -1, 1 };
    if (writ_roles_add(&s->roles, 1, s->a.pidfd) || writ_roles_add(&s->roles, 2, s->b.pidfd))
        die("roles");
    if (provision) {
        struct writ_owner_reply r;
        s->provisioned = writ_supervisor_provision(&s->sup, records, provision, &r) == 0 &&
                         r.outcome == WRIT_OWNER_PROVISIONED && !r.contain && !r.stops;
        if (!s->provisioned) { errno = EPROTO; die("provision canary"); }
        /* Workers can be launched only once provisioned. */
        s->w = launch(&s->sup, 1, &s->worker_clean);
    }
}

static void begin_with(struct scenario *s, const struct writ_clock_sample *samples, size_t count,
                       int with_fake)
{
    begin_raw(s, samples, count, with_fake, "canary");
}

static void begin(struct scenario *s, const struct writ_clock_sample *samples, size_t count)
{
    begin_with(s, samples, count, 0);
}

static void end(struct scenario *s)
{
    retire(&s->a); retire(&s->b); retire(&s->c); retire(&s->w);
    writ_supervisor_release(&s->sup);
    close(s->channel);
    writ_policy_stop(&s->policy);
}

/* Waits for the queued record, then forwards it. */
static int serve(struct scenario *s, struct writ_owner_reply *r)
{
    struct pollfd p = { .fd = s->channel, .events = POLLIN };
    if (poll(&p, 1, 5000) != 1) die("poll channel");
    return writ_supervisor_serve_one(&s->sup, s->channel, &s->roles, r);
}

static int is(const struct writ_owner_reply *r, enum writ_owner_outcome outcome, int contain, size_t stops)
{
    return r->outcome == outcome && r->contain == contain && r->stops == stops;
}

static void ordered_revocation(void)
{
    const struct writ_clock_sample samples[] = { at(111), at(112), at(113), at(114) };
    struct scenario s;
    begin(&s, samples, 4);
    struct writ_owner_reply r;

    check(s.provisioned && s.sup.sequence == 1 && !s.sup.contained,
          "protected_record_provisioned", "0600 canary record: PROVISIONED, sequence 1, no containment");
    check(s.worker_clean, "launched_worker_clean", "launched worker 1: parent-death SIGKILL, only descriptors 0-2 (an inheritable one is closed), default SIGPIPE, empty mask");

    command(&s.b, 'r', "B revoke");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_REVOKE_REFUSED, 0, 0) && alive(&s.w) && !s.sup.contained,
          "non_issuer_revoke_refused", "role 2 (102) revoke 5: REVOKE_REFUSED, no containment, worker alive");

    command(&s.c, 'r', "C revoke");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_CHANNEL_DENIED, 0, 0) && alive(&s.w),
          "unregistered_sender_denied", "unregistered process revoke 5: CHANNEL_DENIED");

    command(&s.a, 'b', "A malformed");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_CONTROL_UNDECODED, 0, 0) && alive(&s.w),
          "malformed_payload_undecoded", "role 1 three-byte payload: CONTROL_UNDECODED");

    command(&s.a, 'r', "A revoke");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_REVOKE_APPLIED, 1, 0) && s.sup.contained && alive(&s.w),
          "issuer_revoke_applied", "role 1 (101) revoke 5: REVOKE_APPLIED, containment, control kills nothing");

    check(writ_supervisor_drain(&s.sup, &r) == 0 && is(&r, WRIT_OWNER_DRAIN_STEP, 1, 1) && r.stop[0] == 1,
          "drain_returns_worker_stop", "DRAIN: DRAIN_STEP with S1");
    int killed = reaped_by_kill(&s.w);
    check(killed, "drained_worker_killed", "worker 1 reaped, killed by SIGKILL through its pidfd");
    settle(&s.w, killed);

    check(writ_supervisor_drain(&s.sup, &r) == 0 && is(&r, WRIT_OWNER_DRAIN_COMPLETE, 1, 0),
          "second_drain_complete", "second DRAIN: DRAIN_COMPLETE, no stop");

    errno = 0;
    check(writ_supervisor_serve_one(&s.sup, s.channel, &s.roles, &r) == -1 && errno == EAGAIN &&
          s.sup.sequence == 7 && s.clock.next == 4 && !s.sup.failed,
          "idle_channel_not_forwarded", "nothing queued: EAGAIN, no frame sent, no sample taken");
    end(&s);
}

/* Each role submits its own approval through the channel; the principal is
   the receiver's attribution, not the record's issuer field. */
static void approval_submission(void)
{
    const struct writ_clock_sample samples[] = { at(111), at(112), at(113), at(114), at(115) };
    struct scenario s;
    begin(&s, samples, 5);
    struct writ_owner_reply r;

    command(&s.a, 's', "A submit source");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_APPROVAL_ACCEPTED, 0, 0) && alive(&s.w) && !s.sup.contained,
          "source_role_submission_accepted", "role 1 (101) submits its read-domain-5 approval: APPROVAL_ACCEPTED, no containment");

    command(&s.b, 's', "B submit source");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_APPROVAL_REFUSED, 0, 0) && !s.sup.contained,
          "other_role_submission_refused", "role 2 (102) sends principal 101's approval: APPROVAL_REFUSED");

    command(&s.c, 's', "C submit source");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_CHANNEL_DENIED, 0, 0) && !s.sup.contained,
          "unregistered_submission_denied", "unregistered process submits: CHANNEL_DENIED");

    command(&s.b, 'w', "B submit write");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_APPROVAL_ACCEPTED, 0, 0) && alive(&s.w) && !s.sup.contained,
          "write_role_submission_accepted", "role 2 (102) submits its write-domain-6 approval: APPROVAL_ACCEPTED");

    command(&s.a, 'v', "A revoke 16");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_REVOKE_APPLIED, 1, 0) && s.sup.contained,
          "submitted_approval_revoked", "role 1 revokes its submitted approval 16: REVOKE_APPLIED, containment");
    end(&s);
}

static void regressing_clock(void)
{
    const struct writ_clock_sample samples[] = { at(115), at(112) };
    struct scenario s;
    begin(&s, samples, 2);
    struct writ_owner_reply r;
    command(&s.b, 'r', "B revoke");
    int first = serve(&s, &r) == 0 && is(&r, WRIT_OWNER_REVOKE_REFUSED, 0, 0);
    command(&s.b, 'r', "B revoke again");
    check(first && serve(&s, &r) == 0 && is(&r, WRIT_OWNER_CONTAINED, 1, 0) && alive(&s.w),
          "regressing_sample_contains", "samples 115 then 112: second message CONTAINED");
    int drained = writ_supervisor_drain(&s.sup, &r) == 0 && is(&r, WRIT_OWNER_DRAIN_STEP, 1, 1);
    int killed = reaped_by_kill(&s.w);
    check(drained && killed, "regressing_then_drain_stops", "DRAIN after clock containment stops worker 1");
    settle(&s.w, killed);
    end(&s);
}

static void expired_and_unavailable(void)
{
    const struct writ_clock_sample late[] = { at(125) };
    struct scenario s;
    begin(&s, late, 1);
    struct writ_owner_reply r;
    command(&s.b, 'r', "B revoke");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_CONTAINED, 1, 0),
          "expired_grant_contains", "sample 125 past expiry 120: refused revoke reported CONTAINED");
    end(&s);

    const struct writ_clock_sample missing[] = { { WRIT_CLOCK_UNAVAILABLE, 0 } };
    begin(&s, missing, 1);
    command(&s.a, 'r', "A revoke");
    check(serve(&s, &r) == 0 && is(&r, WRIT_OWNER_REVOKE_APPLIED, 1, 0),
          "unavailable_clock_issuer_revoke_applies", "unavailable sample: issuer revoke still applies, containment");
    end(&s);
}

static void unregistered_worker(void)
{
    const struct writ_clock_sample samples[] = { at(111) };
    struct scenario s;
    begin(&s, samples, 1);
    s.sup.worker[0].worker = 9; /* the driver knows this pidfd only as worker 9 */
    struct writ_owner_reply r;
    command(&s.a, 'r', "A revoke");
    int applied = serve(&s, &r) == 0 && is(&r, WRIT_OWNER_REVOKE_APPLIED, 1, 0);
    check(applied && writ_supervisor_drain(&s.sup, &r) == -1 && r.stops == 1 && s.sup.failed && alive(&s.w),
          "unregistered_worker_fail_stop", "S1 for an unregistered worker: fail-stop, nothing signalled");
    end(&s);
}

static void interpreter_loss(void)
{
    const struct writ_clock_sample samples[] = { at(111) };
    struct scenario s;
    begin(&s, samples, 1);
    struct writ_owner_reply r;
    if (kill(s.policy.pid, SIGKILL)) die("kill own interpreter");
    command(&s.a, 'r', "A revoke");
    int lost = serve(&s, &r) == -1 && s.sup.failed && s.sup.contained;
    uint32_t sequence = s.sup.sequence;
    char *argv[] = { "supervisor-owner-worker", "--worker", NULL };
    char *envp[] = { NULL };
    pid_t pid;
    errno = 0;
    int no_launch = writ_supervisor_launch_worker(&s.sup, 2, "/proc/self/exe", argv, envp, &pid) == -1 &&
                    errno == EPERM && s.sup.workers == 1;
    check(lost && writ_supervisor_drain(&s.sup, &r) == -1 && s.sup.sequence == sequence && alive(&s.w) && no_launch,
          "interpreter_loss_fail_stop", "killed interpreter: fail-stop, later DRAIN not sent, no replay, no further launch (EPERM)");
    end(&s);
}

/* Exact CONTROL frames: the verdict number and clock kind reach the
   interpreter unchanged; the role and payload only where they are defined. */
static void frame_formatting(void)
{
    static struct writ_channel_record record;
    static char frame[WRIT_OWNER_FRAME_CAP], want[128];
    int ok = 1;
    for (unsigned int v = WRIT_FROM_ROLE; v <= WRIT_SENDER_ERROR; ++v) {
        memset(&record, 0, sizeof record);
        record.verdict = (enum writ_channel_verdict)v;
        record.role = 3;
        record.length = 2;
        record.payload[0] = 0xab; record.payload[1] = 0x01;
        size_t n = writ_owner_format_control(&record, at(7), frame);
        snprintf(want, sizeof want, "LINUXSUP1\tCONTROL\t%u\t%u\t0\t7\t%s\n", v,
                 v == WRIT_FROM_ROLE ? 3u : 0u, v <= WRIT_UNKNOWN_SENDER ? "ab01" : "");
        ok = ok && n == strlen(want) && !memcmp(frame, want, n);
    }
    check(ok, "frame_verdicts_exact", "verdicts 0-8 framed by number; role and payload only where defined");
    ok = 1;
    for (unsigned int k = WRIT_CLOCK_UNAVAILABLE; k <= WRIT_CLOCK_OVERFLOW; ++k) {
        memset(&record, 0, sizeof record);
        size_t n = writ_owner_format_control(&record,
            (struct writ_clock_sample){ (enum writ_clock_kind)k, 9 }, frame);
        snprintf(want, sizeof want, "LINUXSUP1\tCONTROL\t0\t0\t%u\t0\t\n", k);
        ok = ok && n == strlen(want) && !memcmp(frame, want, n);
    }
    check(ok, "frame_clock_kinds_exact", "unavailable, ambiguous and overflow framed by kind with now 0");
    memset(&record, 0, sizeof record);
    record.verdict = (enum writ_channel_verdict)(WRIT_SENDER_ERROR + 1);
    size_t bad_verdict = writ_owner_format_control(&record, at(7), frame);
    record.verdict = WRIT_FROM_ROLE;
    record.length = WRIT_CHANNEL_PAYLOAD_MAX + 1;
    size_t bad_length = writ_owner_format_control(&record, at(7), frame);
    record.length = WRIT_CHANNEL_PAYLOAD_MAX;
    size_t full = writ_owner_format_control(&record, at(7), frame);
    check(!bad_verdict && !bad_length && full == strlen("LINUXSUP1\tCONTROL\t0\t0\t0\t7\t\n") + 2u * WRIT_CHANNEL_PAYLOAD_MAX,
          "frame_bounds", "verdict 9 and 4097 bytes refused; 4096 bytes framed");
}

/* Whether this scenario's interpreter was killed (bounded wait). */
static int interpreter_killed(struct scenario *s)
{
    int dead = 0;
    int pidfd = (int)syscall(SYS_pidfd_open, s->policy.pid, 0);
    if (pidfd < 0) die("pidfd_open interpreter");
    struct pollfd p = { .fd = pidfd, .events = POLLIN };
    if (poll(&p, 1, 5000) == 1) {
        siginfo_t info;
        memset(&info, 0, sizeof info);
        dead = waitid(P_PIDFD, (id_t)pidfd, &info, WEXITED | WNOWAIT) == 0 && info.si_code == CLD_KILLED;
    }
    close(pidfd);
    return dead;
}

/* Whether launching a worker is refused with EPERM (and nothing started). */
static int unlaunchable(struct scenario *s)
{
    char *argv[] = { "supervisor-owner-worker", "--worker", NULL };
    char *envp[] = { NULL };
    pid_t pid;
    errno = 0;
    return writ_supervisor_launch_worker(&s->sup, 1, "/proc/self/exe", argv, envp, &pid) == -1 &&
           errno == EPERM && s->sup.workers == 0;
}

/* One refused or failed provisioning: fail-stop, `sent` replies received,
   the interpreter killed, and no worker can be launched afterwards. */
static void provision_fails(const char *file, int sent, enum writ_owner_outcome outcome, int want_errno,
                            const char *name, const char *detail)
{
    struct scenario s;
    begin_raw(&s, NULL, 0, 0, NULL);
    struct writ_owner_reply r;
    memset(&r, 0, sizeof r);
    r.outcome = WRIT_OWNER_ERROR;
    /* Holding the FIFO's write side open means a read would fail with EAGAIN
       rather than see end of file, so reading it would be observable. */
    int writer = -1;
    if (!strcmp(file, "fifo") && (writer = openat(records, file, O_RDWR | O_NONBLOCK | O_CLOEXEC)) < 0)
        die("open fifo writer");
    errno = 0;
    int failed = writ_supervisor_provision(&s.sup, records, file, &r) == -1;
    int saved = errno;
    if (writer >= 0) close(writer);
    int replied = sent ? (int)s.sup.sequence == sent && r.outcome == outcome && r.contain
                       : s.sup.sequence == 0 && (!want_errno || saved == want_errno);
    check(failed && replied && s.sup.failed && s.sup.contained && interpreter_killed(&s) && unlaunchable(&s),
          name, detail);
    end(&s);
}

static void provisioning(void)
{
    provision_fails("writable", 1, WRIT_OWNER_PROVISION_REFUSED, 0, "group_writable_record_refused",
                    "0620 record: PROVISION_REFUSED, fail-stop, interpreter killed, no worker launchable");
    provision_fails("linked", 1, WRIT_OWNER_PROVISION_REFUSED, 0, "linked_record_refused",
                    "record with two links: PROVISION_REFUSED, fail-stop");
    provision_fails("fifo", 1, WRIT_OWNER_PROVISION_REFUSED, 0, "fifo_record_refused",
                    "FIFO with a writer: not read, facts forwarded, PROVISION_REFUSED, fail-stop");
    provision_fails("mismatch", 1, WRIT_OWNER_PROVISION_REFUSED, 0, "foreign_root_record_refused",
                    "record whose issuer root differs: PROVISION_REFUSED, fail-stop");
    provision_fails("symlink", 0, WRIT_OWNER_ERROR, ELOOP, "symlink_record_not_followed",
                    "symlink to the canary record: not opened (ELOOP), nothing sent, fail-stop");
    provision_fails("oversized", 0, WRIT_OWNER_ERROR, EFBIG, "oversized_record_not_sent",
                    "4097-byte file: EFBIG, nothing sent, fail-stop");
    provision_fails("via/canary", 0, WRIT_OWNER_ERROR, ELOOP, "intermediate_symlink_not_followed",
                    "canary record through a symlinked directory: ELOOP, nothing sent, fail-stop");
    char escape[300];
    const char *base = strrchr(records_path, '/');
    snprintf(escape, sizeof escape, "..%s/canary", base);
    provision_fails(escape, 0, WRIT_OWNER_ERROR, EXDEV, "record_outside_directory_refused",
                    "canary record named through ..: EXDEV, nothing sent, fail-stop");

    const struct writ_clock_sample samples[] = { at(111) };
    struct scenario s;
    begin_raw(&s, samples, 1, 0, NULL);
    struct writ_owner_reply r;
    int early = unlaunchable(&s);
    command(&s.a, 'r', "A revoke unprovisioned");
    int failed = serve(&s, &r) == -1 && r.outcome == WRIT_OWNER_ERROR && s.sup.sequence == 1;
    check(early && failed && s.sup.failed && interpreter_killed(&s) && unlaunchable(&s),
          "control_before_provision_fail_stop",
          "unprovisioned: launch refused (EPERM); revoke before PROVISION: interpreter ERROR, fail-stop");
    end(&s);

    begin(&s, NULL, 0);
    failed = writ_supervisor_provision(&s.sup, records, "canary", &r) == -1 && r.outcome == WRIT_OWNER_ERROR &&
             s.sup.sequence == 2;
    check(failed && s.sup.failed && interpreter_killed(&s), "second_provision_fail_stop",
          "a second PROVISION: interpreter ERROR, fail-stop");
    end(&s);
}

static void launching(void)
{
    struct scenario s;
    begin(&s, NULL, 0);
    int clean = 0;
    struct child w = launch(&s.sup, 4, &clean);
    char *argv[] = { "absent", NULL };
    char *envp[] = { NULL };
    pid_t pid;
    errno = 0;
    int zero = writ_supervisor_launch_worker(&s.sup, 0, "/proc/self/exe", argv, envp, &pid) == -1 && errno == EINVAL;
    errno = 0;
    int again = writ_supervisor_launch_worker(&s.sup, 4, "/proc/self/exe", argv, envp, &pid) == -1 && errno == EINVAL;
    check(clean && zero && again && s.sup.workers == 2 && s.sup.worker[1].worker == 4 &&
          s.sup.worker[1].pidfd == w.pidfd && s.sup.worker[1].owned,
          "launch_registers_worker", "after PROVISIONED, launch registers worker 4's pidfd, owned by the driver; worker 0 and a duplicate refused (EINVAL), registry unchanged");
    retire(&w);

    char missing[300];
    snprintf(missing, sizeof missing, "%s/absent-program", records_path);
    int pidfd = writ_supervisor_launch_worker(&s.sup, 5, missing, argv, envp, &pid);
    if (pidfd < 0) die("launch missing program");
    siginfo_t info;
    memset(&info, 0, sizeof info);
    if (waitid(P_PIDFD, (id_t)pidfd, &info, WEXITED)) die("waitid missing program");
    check(info.si_code == CLD_EXITED && info.si_status == 127, "launch_exec_failure_visible",
          "execve of a missing program: the child exits 127");
    end(&s);
}

/* Exact PROVISION frames: facts by number, the link count saturated. */
static void provision_formatting(void)
{
    static char frame[WRIT_OWNER_FRAME_CAP];
    static unsigned char big[WRIT_CHANNEL_PAYLOAD_MAX + 1];
    struct stat st;
    memset(&st, 0, sizeof st);
    st.st_mode = S_IFREG | 0600;
    st.st_nlink = 1;
    st.st_uid = 1000;
    const unsigned char bytes[2] = { 0xab, 0x01 };
    const char *want = "LINUXSUP1\tPROVISION\t33152\t1\t1000\t1001\tab01\n";
    size_t n = writ_owner_format_provision(&st, 1001, bytes, 2, frame);
    int exact = n == strlen(want) && !memcmp(frame, want, n);
    st.st_mode = S_IFIFO | 0600;
    st.st_nlink = (nlink_t)UINT32_MAX + 5;
    want = "LINUXSUP1\tPROVISION\t4480\t4294967295\t1000\t1000\t\n";
    n = writ_owner_format_provision(&st, 1000, bytes, 0, frame);
    int saturated = sizeof(nlink_t) <= 4 || (n == strlen(want) && !memcmp(frame, want, n));
    check(exact && saturated && !writ_owner_format_provision(&st, 1000, big, sizeof big, frame) &&
          writ_owner_format_provision(&st, 1000, big, WRIT_CHANNEL_PAYLOAD_MAX, frame),
          "frame_provision_exact", "mode, links, owner and euid by number; links saturate; 4097 bytes refused");
}

/* Against the malformed peer: each reply the owner never sends is fail-stop,
   kills the interpreter and signals no worker. */
static int peer_fails_stop(char sender, uint32_t role_seen, int drain, const char *name, const char *detail)
{
    const struct writ_clock_sample samples[] = { at(111) };
    struct scenario s;
    begin_with(&s, samples, 1, 1);
    struct writ_owner_reply r;
    struct child *from = sender == 'a' ? &s.a : &s.b;
    int failed;
    if (drain) {
        failed = writ_supervisor_drain(&s.sup, &r) == -1;
    } else {
        if (role_seen == 3) s.roles.role[1].index = 3; /* B registered as role 3 */
        command(from, 'r', "peer send");
        failed = serve(&s, &r) == -1;
    }
    int dead = interpreter_killed(&s);
    int ok = failed && s.sup.failed && s.sup.contained && dead && alive(&s.w);
    check(ok, name, detail);
    end(&s);
    return ok;
}

static void malformed_peer(void)
{
    peer_fails_stop('a', 1, 0, "peer_wrong_operation_outcome", "SERVED for CONTROL: fail-stop, interpreter killed");
    peer_fails_stop('b', 2, 0, "peer_control_effect", "control reply with S1: fail-stop, no worker signalled");
    peer_fails_stop('b', 3, 0, "peer_interpreter_error", "interpreter ERROR: fail-stop, interpreter killed");
    peer_fails_stop('a', 0, 1, "peer_drain_wrong_outcome", "REVOKE_APPLIED for DRAIN: fail-stop, no worker signalled");
}

static void reply_decoding(void)
{
    struct writ_owner_reply r;
    char ok[] = "LINUXSUP1\t3\tDRAIN_STEP\t1\tS1,S7";
    check(writ_owner_decode(ok, 3, &r) == 0 && is(&r, WRIT_OWNER_DRAIN_STEP, 1, 2) && r.stop[1] == 7,
          "decode_stop_list", "S1,S7 decoded in order");
    char other[] = "LINUXSUP1\t3\tDRAIN_STEP\t1\tR1";
    char order[] = "LINUXSUP1\t4\tCONTAINED\t1\t-";
    char comma[] = "LINUXSUP1\t3\tDRAIN_STEP\t1\tS1,";
    char zero[] = "LINUXSUP1\t3\tDRAIN_STEP\t1\tS01";
    char name[] = "LINUXSUP1\t3\tREVOKED\t1\t-";
    char flag[] = "LINUXSUP1\t3\tCONTAINED\t2\t-";
    char nine[] = "LINUXSUP1\t3\tDRAIN_STEP\t1\tS1,S2,S3,S4,S5,S6,S7,S8,S9";
    char eight[] = "LINUXSUP1\t3\tDRAIN_STEP\t1\tS1,S2,S3,S4,S5,S6,S7,S8";
    check(writ_owner_decode(eight, 3, &r) == 0 && r.stops == 8 && r.stop[7] == 8 &&
          writ_owner_decode(nine, 3, &r) != 0,
          "decode_stop_bound", "eight stops decoded, a ninth rejected");
    check(writ_owner_decode(other, 3, &r) && writ_owner_decode(order, 3, &r) &&
          writ_owner_decode(comma, 3, &r) && writ_owner_decode(zero, 3, &r) &&
          writ_owner_decode(name, 3, &r) && writ_owner_decode(flag, 3, &r),
          "decode_rejects", "non-stop effect, wrong sequence, trailing comma, leading zero, unknown outcome, bad flag");
}

static void boottime(void)
{
    struct writ_clock_sample first = writ_clock_boottime(NULL), second = writ_clock_boottime(NULL);
    check(first.kind == WRIT_CLOCK_READING && second.kind == WRIT_CLOCK_READING && first.now <= second.now,
          "boottime_reading", "CLOCK_BOOTTIME seconds read twice, nondecreasing");
}

int main(int argc, char **argv)
{
    if (argc == 2 && !strcmp(argv[1], "--worker")) worker_main();
    setvbuf(stdout, NULL, _IOLBF, 0);
    alarm(TIMEOUT_SECONDS);
    if (argc != 5 || argv[1][0] != '/' || argv[2][0] != '/' || argv[3][0] != '/' || argv[4][0] != '/') {
        fprintf(stderr, "usage: %s NODE BRIDGE MODULE FAKE (absolute)\n", argv[0]);
        return 1;
    }
    node = argv[1]; bridge = argv[2]; module = argv[3]; fake = argv[4];
    /* A dead interpreter must surface as a failed write, not kill the driver. */
    if (signal(SIGPIPE, SIG_IGN) == SIG_ERR) die("ignore SIGPIPE");
    /* A blocked signal the launched worker must not inherit. */
    sigset_t blocked;
    sigemptyset(&blocked);
    sigaddset(&blocked, SIGUSR2);
    if (sigprocmask(SIG_BLOCK, &blocked, NULL)) die("block SIGUSR2");
    printf("INFO supervisor-owner-test: owned processes only, timeout %us\n", TIMEOUT_SECONDS);
    int profile = writ_channel_profile_check();
    if (profile == ENOTSUP) { errno = ENOTSUP; unsupported("pidfs, SO_PASSPIDFD or SO_PASSRIGHTS"); }
    if (profile) { errno = profile; die("profile check"); }
    make_records();
    record_bytes(source_words, APPROVAL_WORDS, submit_source);
    record_bytes(write_words, APPROVAL_WORDS, submit_write);
    /* Launched workers must not inherit this (see worker_main). */
    inheritable = dup(records);
    if (inheritable < 0) die("dup");
    int baseline = count_own_fds();

    reply_decoding();
    frame_formatting();
    provision_formatting();
    launching();
    provisioning();
    boottime();
    ordered_revocation();
    approval_submission();
    regressing_clock();
    expired_and_unavailable();
    unregistered_worker();
    interpreter_loss();
    malformed_peer();

    check(count_own_fds() == baseline, "descriptor_cleanup", "descriptor count unchanged");
    close(inheritable);
    remove_records();
    printf("RESULT %s (%d failures)\n", failures ? "FAIL" : "PASS", failures);
    return failures ? 1 : 0;
}
