#define _GNU_SOURCE
#include "supervisor_owner.h"

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/openat2.h>
#include <linux/sched.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <sys/prctl.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/* A stop is acknowledged only after the worker has exited. */
#define STOP_WAIT_MILLISECONDS 5000

static const char *const outcome_names[] = {
    [WRIT_OWNER_REVOKE_APPLIED] = "REVOKE_APPLIED",
    [WRIT_OWNER_REVOKE_REFUSED] = "REVOKE_REFUSED",
    [WRIT_OWNER_CHANNEL_DENIED] = "CHANNEL_DENIED",
    [WRIT_OWNER_CONTROL_UNDECODED] = "CONTROL_UNDECODED",
    [WRIT_OWNER_CONTAINED] = "CONTAINED",
    [WRIT_OWNER_SERVED] = "SERVED",
    [WRIT_OWNER_NOT_FRAMED] = "NOT_FRAMED",
    [WRIT_OWNER_DRAIN_STEP] = "DRAIN_STEP",
    [WRIT_OWNER_DRAIN_COMPLETE] = "DRAIN_COMPLETE",
    [WRIT_OWNER_DRAIN_INCOMPLETE] = "DRAIN_INCOMPLETE",
    [WRIT_OWNER_ERROR] = "ERROR",
    [WRIT_OWNER_STOPPED] = "STOPPED",
    [WRIT_OWNER_EXHAUSTED] = "EXHAUSTED",
    [WRIT_OWNER_PROVISIONED] = "PROVISIONED",
    [WRIT_OWNER_PROVISION_REFUSED] = "PROVISION_REFUSED",
    [WRIT_OWNER_APPROVAL_ACCEPTED] = "APPROVAL_ACCEPTED",
    [WRIT_OWNER_APPROVAL_REFUSED] = "APPROVAL_REFUSED",
    [WRIT_OWNER_ROLE_ADMITTED] = "ROLE_ADMITTED",
    [WRIT_OWNER_ROLE_REFUSED] = "ROLE_REFUSED",
};

struct writ_clock_sample writ_clock_boottime(void *unused)
{
    (void)unused;
    struct timespec ts;
    if (clock_gettime(CLOCK_BOOTTIME, &ts) || ts.tv_sec < 0)
        return (struct writ_clock_sample){ WRIT_CLOCK_UNAVAILABLE, 0 };
    if ((uint64_t)ts.tv_sec > UINT32_MAX)
        return (struct writ_clock_sample){ WRIT_CLOCK_OVERFLOW, 0 };
    return (struct writ_clock_sample){ WRIT_CLOCK_READING, (uint32_t)ts.tv_sec };
}

int writ_supervisor_init(struct writ_supervisor *s, struct writ_policy *policy,
                         writ_clock_source clock, void *clock_context)
{
    memset(s, 0, sizeof *s);
    s->policy = policy;
    s->clock = clock;
    s->clock_context = clock_context;
    return 0;
}

/* 0 when `worker` can be registered: nonzero, not yet registered, room left. */
static int worker_room(const struct writ_supervisor *s, uint32_t worker)
{
    if (!worker) { errno = EINVAL; return -1; }
    for (size_t i = 0; i < s->workers; ++i)
        if (s->worker[i].worker == worker) { errno = EINVAL; return -1; }
    if (s->workers == WRIT_OWNER_WORKERS) { errno = ENOSPC; return -1; }
    return 0;
}

static void register_worker(struct writ_supervisor *s, uint32_t worker, int pidfd, int owned)
{
    s->worker[s->workers].worker = worker;
    s->worker[s->workers].pidfd = pidfd;
    s->worker[s->workers].owned = owned;
    ++s->workers;
}

/* End of life only: the interpreter still counts released role indices as
   bound, so serving after release would see those processes as unknown. */
void writ_supervisor_release(struct writ_supervisor *s)
{
    for (size_t i = 0; i < s->workers; ++i)
        if (s->worker[i].owned) close(s->worker[i].pidfd);
    s->workers = 0;
    for (size_t i = 0; i < s->role_pidfds; ++i) close(s->role_pidfd[i]);
    s->role_pidfds = 0;
    memset(&s->roles, 0, sizeof s->roles);
}

#ifdef WRIT_OWNER_TESTING
int writ_supervisor_add_worker(struct writ_supervisor *s, uint32_t worker, int pidfd)
{
    if (pidfd < 0) { errno = EINVAL; return -1; }
    if (worker_room(s, worker)) return -1;
    register_worker(s, worker, pidfd, 0);
    return 0;
}
#endif

#ifndef CLOSE_RANGE_CLOEXEC
#define CLOSE_RANGE_CLOEXEC (1u << 2)
#endif

/* The child's descriptors. A worker keeps only 0 to 2. A role process gets
   `input` as descriptor 0 and `channel` (its end of the supervisor channel)
   as descriptor 3, keeps 1 and 2, and nothing else. Both are first copied
   above 3 so that neither dup2 overwrites the other's source. `status` is
   the write end of a close-on-exec pipe: a role child that fails before
   execve writes its errno there, and a successful execve closes it. */
struct child_fds { int input, channel, status; };

static _Noreturn void child_failed(int status)
{
    int error = errno;
    if (status >= 0) (void)write(status, &error, sizeof error);
    _exit(127);
}

/* In the child between clone3 and execve: only async-signal-safe calls.
   Every signal is still blocked (see spawn_child), so no handler inherited
   from the supervisor runs before the dispositions are reset. */
static _Noreturn void exec_child(pid_t parent, const char *path, char *const argv[], char *const envp[],
                                 const struct child_fds *fds)
{
    int status = -1;
    if (fds && (status = fcntl(fds->status, F_DUPFD_CLOEXEC, 4)) < 0) child_failed(fds->status);
    struct sigaction dfl;
    memset(&dfl, 0, sizeof dfl);
    dfl.sa_handler = SIG_DFL;
    for (int sig = 1; sig < NSIG; ++sig) (void)sigaction(sig, &dfl, NULL);
    /* A worker or role process must not outlive the supervisor thread that
       launched it. */
    if (prctl(PR_SET_PDEATHSIG, SIGKILL)) child_failed(status);
    if (getppid() != parent) { errno = ESRCH; child_failed(status); }
    sigset_t none;
    sigemptyset(&none);
    if (sigprocmask(SIG_SETMASK, &none, NULL)) child_failed(status);
    if (fds) {
        int input = fcntl(fds->input, F_DUPFD, 4);
        int channel = fcntl(fds->channel, F_DUPFD, 4);
        if (input < 0 || channel < 0 || dup2(input, 0) != 0 || dup2(channel, 3) != 3) child_failed(status);
        /* The child must not inherit the interpreter's pipes, another role's
           channel end or any other supervisor descriptor. Marking them
           close-on-exec (rather than closing) keeps `status` open until a
           successful execve. */
        if (syscall(SYS_close_range, 4u, ~0u, CLOSE_RANGE_CLOEXEC)) child_failed(status);
    } else if (syscall(SYS_close_range, 3u, ~0u, 0u)) {
        _exit(127);
    }
    execve(path, argv, envp);
    child_failed(status);
}

/* clone3 with every signal blocked in the caller across it; returns the
   child's pid with `*pidfd` set, or -1 with errno. */
static long spawn_child(const char *path, char *const argv[], char *const envp[],
                        const struct child_fds *fds, int *pidfd)
{
    sigset_t all, old;
    sigfillset(&all);
    if (sigprocmask(SIG_SETMASK, &all, &old)) return -1;
    pid_t parent = getpid();
    *pidfd = -1;
    struct clone_args args;
    memset(&args, 0, sizeof args);
    args.flags = CLONE_PIDFD;
    args.pidfd = (uint64_t)(uintptr_t)pidfd;
    args.exit_signal = SIGCHLD;
    long child = syscall(SYS_clone3, &args, sizeof args);
    if (child == 0) exec_child(parent, path, argv, envp, fds);
    int saved = errno;
    (void)sigprocmask(SIG_SETMASK, &old, NULL);
    errno = saved;
    return child;
}

int writ_supervisor_launch_worker(struct writ_supervisor *s, uint32_t worker, const char *path,
                                  char *const argv[], char *const envp[], pid_t *pid)
{
    /* Not transport policy: an unprovisioned or failed supervisor has no
       owner that could ever stop the worker. */
    if (!s->provisioned || s->failed) { errno = EPERM; return -1; }
    if (worker_room(s, worker)) return -1;
    int pidfd;
    long child = spawn_child(path, argv, envp, NULL, &pidfd);
    if (child < 0) return -1;
    register_worker(s, worker, pidfd, 1);
    *pid = (pid_t)child;
    return pidfd;
}

static int canonical_u32(const char *text, size_t length, uint32_t *result)
{
    if (!length || length > 10 || (text[0] == '0' && length > 1)) return -1;
    uint64_t n = 0;
    for (size_t i = 0; i < length; ++i) {
        if (text[i] < '0' || text[i] > '9') return -1;
        n = n * 10u + (uint64_t)(text[i] - '0');
    }
    if (n > UINT32_MAX) return -1;
    *result = (uint32_t)n;
    return 0;
}

/* Only StopEffects tokens are executable here; any other kind fails. */
static int decode_effects(const char *field, struct writ_owner_reply *reply)
{
    reply->stops = 0;
    if (!strcmp(field, "-")) return 0;
    for (;;) {
        if (*field != 'S' || reply->stops == WRIT_OWNER_STOPS) return -1;
        ++field;
        size_t length = strcspn(field, ",");
        if (canonical_u32(field, length, &reply->stop[reply->stops])) return -1;
        ++reply->stops;
        field += length;
        if (!*field) return 0;
        ++field; /* ',' then another token is required */
    }
}

#ifndef WRIT_OWNER_TESTING
static
#endif
int writ_owner_decode(char *line, uint32_t sequence, struct writ_owner_reply *reply)
{
    char *field[5];
    field[0] = line;
    for (unsigned int i = 1; i < 5; ++i) {
        char *tab = strchr(field[i - 1], '\t');
        if (!tab) return -1;
        *tab = 0;
        field[i] = tab + 1;
    }
    uint32_t got;
    if (strchr(field[4], '\t') || strcmp(field[0], "LINUXSUP1") ||
        canonical_u32(field[1], strlen(field[1]), &got) || got != sequence) return -1;
    size_t names = sizeof outcome_names / sizeof outcome_names[0];
    size_t i = 0;
    while (i < names && strcmp(field[2], outcome_names[i])) ++i;
    if (i == names) return -1;
    reply->outcome = (enum writ_owner_outcome)i;
    if (!strcmp(field[3], "0")) reply->contain = 0;
    else if (!strcmp(field[3], "1")) reply->contain = 1;
    else return -1;
    return decode_effects(field[4], reply);
}

/* Fail-stop also kills the interpreter: nothing may exchange with it again. */
static int fail_stop(struct writ_supervisor *s)
{
    int saved = errno;
    s->failed = 1;
    s->contained = 1;
    if (s->policy) writ_policy_abandon(s->policy);
    errno = saved;
    return -1;
}

/* Replies a control message may receive, and replies a drain may receive.
   A provisioning frame may only be PROVISIONED; PROVISION_REFUSED leaves the
   profile unprovisioned and the interpreter stopped, so it is fail-stop. */
static int provision_outcome(enum writ_owner_outcome o)
{
    return o == WRIT_OWNER_PROVISIONED;
}

static int control_outcome(enum writ_owner_outcome o)
{
    return o == WRIT_OWNER_REVOKE_APPLIED || o == WRIT_OWNER_REVOKE_REFUSED ||
           o == WRIT_OWNER_APPROVAL_ACCEPTED || o == WRIT_OWNER_APPROVAL_REFUSED ||
           o == WRIT_OWNER_CHANNEL_DENIED || o == WRIT_OWNER_CONTROL_UNDECODED ||
           o == WRIT_OWNER_CONTAINED;
}

static int role_outcome(enum writ_owner_outcome o)
{
    return o == WRIT_OWNER_ROLE_ADMITTED || o == WRIT_OWNER_ROLE_REFUSED;
}

static int drain_outcome(enum writ_owner_outcome o)
{
    return o == WRIT_OWNER_DRAIN_STEP || o == WRIT_OWNER_DRAIN_COMPLETE ||
           o == WRIT_OWNER_DRAIN_INCOMPLETE;
}

/* One frame out, one reply in. A transport failure, a malformed or
   out-of-sequence reply, or an outcome outside `expected` (which includes the
   interpreter-side ERROR, STOPPED and EXHAUSTED) is fail-stop. `reply` is
   filled whenever the reply was well formed. */
static int call(struct writ_supervisor *s, const char *frame, size_t length,
                struct writ_owner_reply *reply, int (*expected)(enum writ_owner_outcome))
{
    if (s->failed || s->sequence == UINT32_MAX) return fail_stop(s);
    char line[256];
    if (writ_policy_exchange(s->policy, frame, length, line) ||
        writ_owner_decode(line, s->sequence + 1, reply)) return fail_stop(s);
    ++s->sequence;
    if (reply->contain) s->contained = 1;
    if (!expected(reply->outcome)) return fail_stop(s);
    return 0;
}

#ifndef WRIT_OWNER_TESTING
static
#endif
size_t writ_owner_format_control(const struct writ_channel_record *record,
                                 struct writ_clock_sample sample,
                                 char frame[WRIT_OWNER_FRAME_CAP])
{
    static const char hex[] = "0123456789abcdef";
    if (record->length > WRIT_CHANNEL_PAYLOAD_MAX || (unsigned int)record->verdict > WRIT_SENDER_ERROR ||
        (unsigned int)sample.kind > WRIT_CLOCK_OVERFLOW) return 0;
    /* The role word and payload are only meaningful for these verdicts
       (supervisor_channel.h); otherwise they are not forwarded. */
    int accepted = record->verdict == WRIT_FROM_ROLE || record->verdict == WRIT_UNKNOWN_SENDER;
    uint32_t role = record->verdict == WRIT_FROM_ROLE ? record->role : 0;
    size_t length = accepted ? record->length : 0;
    uint32_t now = sample.kind == WRIT_CLOCK_READING ? sample.now : 0;
    int used = snprintf(frame, WRIT_OWNER_FRAME_CAP, "LINUXSUP1\tCONTROL\t%u\t%" PRIu32 "\t%u\t%" PRIu32 "\t",
                        (unsigned int)record->verdict, role, (unsigned int)sample.kind, now);
    if (used <= 0 || (size_t)used + 2 * length + 1 > WRIT_OWNER_FRAME_CAP) return 0;
    size_t at = (size_t)used;
    for (size_t i = 0; i < length; ++i) {
        frame[at++] = hex[record->payload[i] >> 4];
        frame[at++] = hex[record->payload[i] & 15];
    }
    frame[at++] = '\n';
    return at;
}

static size_t append_hex(char *frame, size_t at, const unsigned char *bytes, size_t length)
{
    static const char hex[] = "0123456789abcdef";
    for (size_t i = 0; i < length; ++i) {
        frame[at++] = hex[bytes[i] >> 4];
        frame[at++] = hex[bytes[i] & 15];
    }
    frame[at++] = '\n';
    return at;
}

#ifndef WRIT_OWNER_TESTING
static
#endif
size_t writ_owner_format_provision(const struct stat *st, uint32_t euid, const unsigned char *bytes,
                                   size_t length, char frame[WRIT_OWNER_FRAME_CAP])
{
    if (length > WRIT_CHANNEL_PAYLOAD_MAX) return 0;
    uint32_t links = st->st_nlink > UINT32_MAX ? UINT32_MAX : (uint32_t)st->st_nlink;
    int used = snprintf(frame, WRIT_OWNER_FRAME_CAP, "LINUXSUP1\tPROVISION\t%" PRIu32 "\t%" PRIu32 "\t%" PRIu32 "\t%" PRIu32 "\t",
                        (uint32_t)st->st_mode, links, (uint32_t)st->st_uid, euid);
    if (used <= 0 || (size_t)used + 2 * length + 1 > WRIT_OWNER_FRAME_CAP) return 0;
    return append_hex(frame, (size_t)used, bytes, length);
}

/* Reads a regular file to its end; -1 with EFBIG beyond the record maximum. */
static int read_record(int fd, unsigned char *bytes, size_t *length)
{
    unsigned char extra;
    *length = 0;
    for (;;) {
        int full = *length == WRIT_CHANNEL_PAYLOAD_MAX;
        ssize_t got = full ? read(fd, &extra, 1)
                           : read(fd, bytes + *length, WRIT_CHANNEL_PAYLOAD_MAX - *length);
        if (got < 0 && errno == EINTR) continue;
        if (got < 0) return -1;
        if (got == 0) return 0;
        if (full) { errno = EFBIG; return -1; }
        *length += (size_t)got;
    }
}

int writ_supervisor_provision(struct writ_supervisor *s, int dirfd, const char *name,
                              struct writ_owner_reply *reply)
{
    if (s->failed) return fail_stop(s);
    unsigned char bytes[WRIT_CHANNEL_PAYLOAD_MAX];
    size_t length = 0;
    struct stat st;
    /* An O_PATH resolution opens nothing for I/O: no FIFO, device or
       terminal open happens, whatever `name` names. */
    struct open_how how;
    memset(&how, 0, sizeof how);
    /* No O_NOFOLLOW: with O_PATH it would return the trailing symlink
       itself; RESOLVE_NO_SYMLINKS instead refuses any symlink with ELOOP. */
    how.flags = O_PATH | O_CLOEXEC;
    how.resolve = RESOLVE_NO_SYMLINKS | RESOLVE_NO_MAGICLINKS | RESOLVE_BENEATH;
    int path = (int)syscall(SYS_openat2, dirfd, name, &how, sizeof how);
    if (path < 0) return fail_stop(s);
    if (fstat(path, &st)) {
        int saved = errno;
        close(path);
        errno = saved;
        return fail_stop(s);
    }
    /* Only a regular file is reopened (the same inode, through its O_PATH
       descriptor) and read; for anything else Bend sees the facts and
       refuses. */
    if (S_ISREG(st.st_mode)) {
        char self[64];
        snprintf(self, sizeof self, "/proc/self/fd/%d", path);
        int fd = open(self, O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOCTTY);
        int bad = fd < 0 || read_record(fd, bytes, &length);
        int saved = errno;
        if (fd >= 0) close(fd);
        if (bad) {
            close(path);
            errno = saved;
            return fail_stop(s);
        }
    }
    close(path);
    char frame[WRIT_OWNER_FRAME_CAP];
    size_t used = writ_owner_format_provision(&st, (uint32_t)geteuid(), bytes, length, frame);
    if (!used) return fail_stop(s);
    if (call(s, frame, used, reply, provision_outcome)) return -1;
    s->provisioned = 1;
    return 0;
}

int writ_supervisor_control(struct writ_supervisor *s, const struct writ_channel_record *record,
                            struct writ_owner_reply *reply)
{
    if (s->failed) return fail_stop(s);
    char frame[WRIT_OWNER_FRAME_CAP];
    /* Sampled after the record was received, before it is forwarded. */
    size_t length = writ_owner_format_control(record, s->clock(s->clock_context), frame);
    if (!length) return fail_stop(s);
    if (call(s, frame, length, reply, control_outcome)) return -1;
    if (reply->stops) return fail_stop(s);
    return 0;
}

int writ_supervisor_launch_role(struct writ_supervisor *s, uint32_t index, int channel, int input,
                                const char *path, char *const argv[], char *const envp[], pid_t *pid,
                                struct writ_owner_reply *reply)
{
    if (!s->provisioned || s->failed) { errno = EPERM; return -1; }
    if (channel < 0 || input < 0) { errno = EBADF; return -1; }
    if (s->role_pidfds == WRIT_CHANNEL_ROLES) { errno = ENOSPC; return -1; }
    char frame[64];
    int used = snprintf(frame, sizeof frame, "LINUXSUP1\tROLE\t%" PRIu32 "\t0\t0\t0\t-\n", index);
    if (used <= 0 || (size_t)used >= sizeof frame) return fail_stop(s);
    if (call(s, frame, (size_t)used, reply, role_outcome)) return -1;
    /* ROLE never requires containment and never carries an effect. */
    if (reply->stops || reply->contain) return fail_stop(s);
    if (reply->outcome == WRIT_OWNER_ROLE_REFUSED) { errno = EPERM; return -1; }
    /* Admitted: from here a failure to start the program or to register it
       leaves Bend believing the index bound, so it is fail-stop. */
    int status[2];
    if (pipe2(status, O_CLOEXEC)) return fail_stop(s);
    struct child_fds fds = { input, channel, status[1] };
    int pidfd;
    long child = spawn_child(path, argv, envp, &fds, &pidfd);
    int saved = errno;
    close(status[1]);
    if (child < 0) { close(status[0]); errno = saved; return fail_stop(s); }
    /* End of file: execve succeeded. An errno: the child failed before or in
       execve and has exited. */
    int error = 0;
    ssize_t got;
    do got = read(status[0], &error, sizeof error); while (got < 0 && errno == EINTR);
    close(status[0]);
    int err = got == 0 ? writ_roles_add(&s->roles, index, pidfd) : got > 0 && error ? error : EIO;
    if (err) {
        (void)syscall(SYS_pidfd_send_signal, pidfd, SIGKILL, NULL, 0);
        siginfo_t info;
        (void)waitid(P_PIDFD, (id_t)pidfd, &info, WEXITED);
        close(pidfd);
        errno = err;
        return fail_stop(s);
    }
    s->role_pidfd[s->role_pidfds++] = pidfd;
    *pid = (pid_t)child;
    return pidfd;
}

int writ_supervisor_serve_one(struct writ_supervisor *s, int fd, struct writ_owner_reply *reply)
{
    struct writ_channel_record record;
    if (s->failed) return fail_stop(s);
    if (writ_channel_receive(fd, &s->roles, &record)) {
        int saved = errno;
        if (saved == EAGAIN || saved == EPIPE) { errno = saved; return -1; }
        return fail_stop(s);
    }
    return writ_supervisor_control(s, &record, reply);
}

/* Signals the worker and acknowledges the stop only once its pidfd reports
   exit, within STOP_WAIT_MILLISECONDS. A worker that does not exit in time
   (for example blocked uninterruptibly) is a failed stop. The child is not
   reaped here; its owner does that. */
static int stop_worker(struct writ_supervisor *s, uint32_t worker)
{
    for (size_t i = 0; i < s->workers; ++i) {
        if (s->worker[i].worker != worker) continue;
        if (syscall(SYS_pidfd_send_signal, s->worker[i].pidfd, SIGKILL, NULL, 0) && errno != ESRCH)
            return -1;
        struct pollfd p = { .fd = s->worker[i].pidfd, .events = POLLIN };
        for (;;) {
            int ready = poll(&p, 1, STOP_WAIT_MILLISECONDS);
            if (ready < 0 && errno == EINTR) continue;
            return ready == 1 && (p.revents & POLLIN) ? 0 : -1;
        }
    }
    return -1;
}

int writ_supervisor_drain(struct writ_supervisor *s, struct writ_owner_reply *reply)
{
    static const char frame[] = "LINUXSUP1\tDRAIN\t0\t0\t0\t0\t-\n";
    if (call(s, frame, sizeof frame - 1, reply, drain_outcome)) return -1;
    for (size_t i = 0; i < reply->stops; ++i)
        if (stop_worker(s, reply->stop[i])) return fail_stop(s);
    return 0;
}
