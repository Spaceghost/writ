/* Owned-process test of the native supervisor driver (supervisor_owner.c)
   against the real Bend owner, approved scope: board question 23.

   Usage: supervisor-owner-test NODE BRIDGE MODULE FAKE (absolute paths; FAKE is
   supervisor-owner-fake.mjs, an explicitly malformed peer; BRIDGE is
   runtime/supervisor-policy.mjs, MODULE the generated
   hosts/linux/monitor/SupervisorDriverModule.bend, a SYNTHETIC provisioning
   module: role 1 is principal 101, which issued approval 5; role 2 is 102;
   worker 1 holds a grant expiring at 120; the owner's clock is at 110).

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
#include <linux/sched.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/socket.h>
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

/* ---- owned children ----
   Commands are one byte on a private SEQPACKET socket; the child replies 'k'
   after the send succeeded, 'e' otherwise.
     r  send revoke(5) on tx     b  send a 3-byte payload on tx
   A child with tx == -1 is a worker that only waits. */
static void child_loop(int cmd, int tx)
{
    for (;;) {
        char op;
        if (recv(cmd, &op, 1, 0) != 1) _exit(2);
        int ok = 0;
        if (op == 'r') ok = send(tx, revoke5, sizeof revoke5, MSG_NOSIGNAL) == (ssize_t)sizeof revoke5;
        else if (op == 'b') ok = send(tx, malformed, sizeof malformed, MSG_NOSIGNAL) == (ssize_t)sizeof malformed;
        char reply = ok ? 'k' : 'e';
        if (send(cmd, &reply, 1, MSG_NOSIGNAL) != 1) _exit(2);
    }
}

struct child { int pidfd; int cmd; };

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
    close(c->pidfd);
    close(c->cmd);
    c->pidfd = c->cmd = -1;
}

/* After reaped_by_kill: release a reaped child's handles, or retire one that
   is still running. */
static void settle(struct child *c, int reaped)
{
    if (!reaped) { retire(c); return; }
    close(c->pidfd);
    close(c->cmd);
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
};

static void begin_with(struct scenario *s, const struct writ_clock_sample *samples, size_t count,
                       int with_fake)
{
    memset(s, 0, sizeof *s);
    s->fake = with_fake;
    if (count > 8) { errno = EINVAL; die("script"); }
    memcpy(s->clock.sample, samples, count * sizeof *samples);
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
    s->w = spawn(-1);
    close(ch[1]);
    if (writ_roles_add(&s->roles, 1, s->a.pidfd) || writ_roles_add(&s->roles, 2, s->b.pidfd))
        die("roles");
    if (writ_supervisor_add_worker(&s->sup, 1, s->w.pidfd)) die("worker");
}

static void begin(struct scenario *s, const struct writ_clock_sample *samples, size_t count)
{
    begin_with(s, samples, count, 0);
}

static void end(struct scenario *s)
{
    retire(&s->a); retire(&s->b); retire(&s->c); retire(&s->w);
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
          s.sup.sequence == 6 && s.clock.next == 4 && !s.sup.failed,
          "idle_channel_not_forwarded", "nothing queued: EAGAIN, no frame sent, no sample taken");
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
    s.sup.workers = 0; /* worker 1's pidfd is not registered with the driver */
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
    check(lost && writ_supervisor_drain(&s.sup, &r) == -1 && s.sup.sequence == sequence && alive(&s.w),
          "interpreter_loss_fail_stop", "killed interpreter: fail-stop, later DRAIN not sent, no replay");
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
    int dead = 0;
    int pidfd = (int)syscall(SYS_pidfd_open, s.policy.pid, 0);
    if (pidfd < 0) die("pidfd_open interpreter");
    struct pollfd p = { .fd = pidfd, .events = POLLIN };
    if (poll(&p, 1, 5000) == 1) {
        siginfo_t info;
        memset(&info, 0, sizeof info);
        dead = waitid(P_PIDFD, (id_t)pidfd, &info, WEXITED | WNOWAIT) == 0 && info.si_code == CLD_KILLED;
    }
    close(pidfd);
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
    setvbuf(stdout, NULL, _IOLBF, 0);
    alarm(TIMEOUT_SECONDS);
    if (argc != 5 || argv[1][0] != '/' || argv[2][0] != '/' || argv[3][0] != '/' || argv[4][0] != '/') {
        fprintf(stderr, "usage: %s NODE BRIDGE MODULE FAKE (absolute)\n", argv[0]);
        return 1;
    }
    node = argv[1]; bridge = argv[2]; module = argv[3]; fake = argv[4];
    /* A dead interpreter must surface as a failed write, not kill the driver. */
    if (signal(SIGPIPE, SIG_IGN) == SIG_ERR) die("ignore SIGPIPE");
    printf("INFO supervisor-owner-test: owned processes only, timeout %us\n", TIMEOUT_SECONDS);
    int profile = writ_channel_profile_check();
    if (profile == ENOTSUP) { errno = ENOTSUP; unsupported("pidfs, SO_PASSPIDFD or SO_PASSRIGHTS"); }
    if (profile) { errno = profile; die("profile check"); }
    int baseline = count_own_fds();

    reply_decoding();
    frame_formatting();
    boottime();
    ordered_revocation();
    regressing_clock();
    expired_and_unavailable();
    unregistered_worker();
    interpreter_loss();
    malformed_peer();

    check(count_own_fds() == baseline, "descriptor_cleanup", "descriptor count unchanged");
    printf("RESULT %s (%d failures)\n", failures ? "FAIL" : "PASS", failures);
    return failures ? 1 : 0;
}
