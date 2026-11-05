#define _GNU_SOURCE
#include "launch.h"
#include "broker.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/capability.h>
#include <linux/sched.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <unistd.h>

/* Monotone across this broker's lifetime; never reused, never wraps here. */
static uint64_t next_generation = 1;

int launch_drop_capabilities(void)
{
    /* Bounding set first (needs CAP_SETPCAP, absent for an unprivileged
     * child: EPERM is expected there), then ambient, then every set. */
    for (int cap = 0; cap <= 63; ++cap) {
        if (prctl(PR_CAPBSET_DROP, cap, 0, 0, 0) && errno != EINVAL && errno != EPERM) return -1;
    }
    if (prctl(PR_CAP_AMBIENT, PR_CAP_AMBIENT_CLEAR_ALL, 0, 0, 0) && errno != EINVAL) return -1;
    struct __user_cap_header_struct header = { .version = _LINUX_CAPABILITY_VERSION_3, .pid = 0 };
    struct __user_cap_data_struct data[2];
    memset(data, 0, sizeof data);
    if (syscall(SYS_capset, &header, data)) return -1;
    return 0;
}

static void write_file(const char *path, const char *text)
{
    int fd = open(path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;
    ssize_t ignored = write(fd, text, strlen(text));
    (void)ignored;
    close(fd);
}

/* In the child: keep only `keep`, renumbered from 3, then run `body`. */
static _Noreturn void child_run(const int *keep, unsigned count, int release,
                                launch_body body, void *argument)
{
    if (prctl(PR_SET_PDEATHSIG, SIGKILL, 0, 0, 0)) _exit(120);
    if (release >= 0) {
        char byte;
        ssize_t n;
        do n = read(release, &byte, 1); while (n < 0 && errno == EINTR);
        if (n != 1) _exit(121);
        close(release);
    }
    if (launch_drop_capabilities()) _exit(122);
    int moved[LAUNCH_MAX_KEEP];
    for (unsigned i = 0; i < count; ++i) {
        moved[i] = fcntl(keep[i], F_DUPFD_CLOEXEC, 100);
        if (moved[i] < 0) _exit(123);
    }
    int kept[LAUNCH_MAX_KEEP];
    for (unsigned i = 0; i < count; ++i) {
        kept[i] = 3 + (int)i;
        if (dup2(moved[i], kept[i]) < 0) _exit(124);
    }
    if (close_range((unsigned)(3 + count), ~0u, 0)) _exit(125);
    int null = open("/dev/null", O_RDWR | O_CLOEXEC);
    if (null >= 0) {
        dup2(null, 0); dup2(null, 1); dup2(null, 2);
        if (null > 2) close(null);
    }
    _exit(body(argument, kept, count) & 255);
}

static pid_t clone_child(uint64_t flags, int *pidfd, pid_t exact_pid)
{
    struct clone_args args;
    memset(&args, 0, sizeof args);
    pid_t tid[1] = { exact_pid };
    args.flags = flags | CLONE_PIDFD;
    args.pidfd = (uint64_t)(uintptr_t)pidfd;
    args.exit_signal = SIGCHLD;
    if (exact_pid > 0) {
        args.set_tid = (uint64_t)(uintptr_t)tid;
        args.set_tid_size = 1;
    }
    return (pid_t)syscall(SYS_clone3, &args, sizeof args);
}

int launch_worker(struct launch_record *r, uint32_t subject, const uint32_t token[8],
                  uint32_t incarnation, unsigned flags, const int *keep, unsigned count,
                  launch_body body, void *argument)
{
    if (count > LAUNCH_MAX_KEEP) return -1;
    /* The record exists before the process does. */
    memset(r, 0, sizeof *r);
    r->subject = subject;
    memcpy(r->token, token, sizeof r->token);
    r->incarnation = incarnation;
    r->generation = next_generation++;
    r->uid = (uint32_t)getuid();
    r->gid = (uint32_t)getgid();
    r->flags = flags;
    r->pidfd = -1;
    int release[2];
    if (pipe2(release, O_CLOEXEC)) return -1;
    uint64_t clone_flags = (flags & LAUNCH_NAMESPACED) ? (CLONE_NEWUSER | CLONE_NEWPID) : 0;
    int pidfd = -1;
    pid_t pid = clone_child(clone_flags, &pidfd, 0);
    if (pid < 0) { close(release[0]); close(release[1]); return -1; }
    if (pid == 0) {
        close(release[1]);
        child_run(keep, count, release[0], body, argument);
    }
    close(release[0]);
    r->pid = pid;
    r->pidfd = pidfd;
    if (flags & LAUNCH_NAMESPACED) {
        /* The broker maps one id: LAUNCH_INNER_ID inside is its own uid/gid outside. */
        char path[64], map[64];
        snprintf(map, sizeof map, "%u %u 1\n", LAUNCH_INNER_ID, r->uid);
        snprintf(path, sizeof path, "/proc/%d/uid_map", (int)pid);
        write_file(path, map);
        snprintf(path, sizeof path, "/proc/%d/setgroups", (int)pid);
        write_file(path, "deny\n");
        snprintf(map, sizeof map, "%u %u 1\n", LAUNCH_INNER_ID, r->gid);
        snprintf(path, sizeof path, "/proc/%d/gid_map", (int)pid);
        write_file(path, map);
    }
    /* Unreaped, so the pid still names this child while stat is read. */
    if (broker_observe_pidfd(pidfd, (uint32_t)pid, &r->start)) r->start = 0;
    char go = 1;
    ssize_t n;
    do n = write(release[1], &go, 1); while (n < 0 && errno == EINTR);
    close(release[1]);
    if (n != 1 || !r->start) return -1;
    return 0;
}

pid_t launch_helper(pid_t exact_pid, int *pidfd, const int *keep, unsigned count,
                    launch_body body, void *argument)
{
    if (count > LAUNCH_MAX_KEEP) return -1;
    *pidfd = -1;
    pid_t pid = clone_child(0, pidfd, exact_pid);
    if (pid == 0) child_run(keep, count, -1, body, argument);
    return pid;
}

int launch_reap(int pidfd, int *status)
{
    siginfo_t info;
    memset(&info, 0, sizeof info);
    int r;
    do r = waitid(P_PIDFD, (id_t)pidfd, &info, WEXITED); while (r < 0 && errno == EINTR);
    close(pidfd);
    if (r < 0) return -1;
    if (status) *status = info.si_code == CLD_EXITED ? info.si_status : 128 + info.si_status;
    return 0;
}

void launch_fact(struct broker_fact *f, const struct launch_record *r,
                 const struct broker_cred *peer, uint32_t endpoint_kind,
                 uint32_t endpoint_session, uint32_t families, uint32_t controls,
                 const struct broker_route *routes, uint32_t route_count)
{
    memset(f, 0, sizeof *f);
    f->subject = r->subject;
    memcpy(f->token, r->token, sizeof f->token);
    f->incarnation = r->incarnation;
    f->launch.uid = r->uid;
    f->launch.gid = r->gid;
    f->launch.pid = r->pid > 0 ? (uint32_t)r->pid : 0;
    f->launch.start = r->start;
    f->peer = *peer;
    f->endpoint_kind = endpoint_kind;
    f->endpoint_session = endpoint_session;
    f->families = families;
    f->controls = controls;
    /* An oversized inventory is copied whole into the count, so the encoder
     * refuses the frame rather than truncating the inventory. */
    f->route_count = route_count;
    for (uint32_t i = 0; i < route_count && i < BROKER_MAX_ROUTES; ++i) f->routes[i] = routes[i];
}
