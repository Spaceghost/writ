/* Exercise the production retirement helper with only process/close calls mocked.
   No process identity, privileged worker, signal or FUSE mount is exercised. */
#define _GNU_SOURCE
#include <errno.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int fake_waitid(idtype_t, id_t, siginfo_t *, int);
pid_t fake_waitpid(pid_t, int *, int);
int fake_close(int);
long fake_syscall(long, ...);
#define waitid fake_waitid
#define waitpid fake_waitpid
#define close fake_close
#define syscall fake_syscall
#include "worker.c"
#undef waitid
#undef waitpid
#undef close
#undef syscall

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #x); exit(1); } } while (0)
static struct {
    int check_error, check_intr, exited, mismatch, signal_error, wait_error, wait_intr, not_ready;
    int close_error_fd, close_errno, checks, signals, waits, closes, wait_flags;
    int closed[3];
} mock;

int fake_waitid(idtype_t type, id_t id, siginfo_t *info, int flags)
{
    CHECK(type == P_PIDFD && id == 30 && flags == (WEXITED | WNOHANG | WNOWAIT));
    CHECK(info->si_pid == 0);
    ++mock.checks;
    if (mock.check_intr) { --mock.check_intr; errno = EINTR; return -1; }
    if (mock.check_error) { errno = mock.check_error; return -1; }
    if (mock.exited) info->si_pid = 42;
    if (mock.mismatch) info->si_pid = 43;
    return 0;
}

long fake_syscall(long number, ...)
{
    CHECK(number == SYS_pidfd_send_signal);
    va_list args; va_start(args, number);
    int fd = va_arg(args, int), signal_number = va_arg(args, int);
    void *info = va_arg(args, void *); int flags = va_arg(args, int);
    va_end(args);
    CHECK(fd == 30 && signal_number == SIGKILL && !info && !flags);
    ++mock.signals;
    if (mock.signal_error) { errno = mock.signal_error; return -1; }
    return 0;
}

pid_t fake_waitpid(pid_t pid, int *status, int flags)
{
    CHECK(pid == 42 && !status && (flags == 0 || flags == WNOHANG));
    ++mock.waits; mock.wait_flags = flags;
    if (mock.wait_intr) { --mock.wait_intr; errno = EINTR; return -1; }
    if (mock.wait_error) { errno = mock.wait_error; return -1; }
    return mock.not_ready ? 0 : pid;
}

int fake_close(int fd)
{
    CHECK(mock.closes < 3);
    mock.closed[mock.closes++] = fd;
    if (fd == mock.close_error_fd) { errno = mock.close_errno; return -1; }
    return 0;
}

static void reset(void) { memset(&mock, 0, sizeof mock); mock.close_error_fd = -1; }
static struct writ_child child(void)
{ return (struct writ_child){ .pid = 42, .command = 10, .result = 20, .pidfd = 30, .start_time = 99 }; }
static void checked_close(void)
{ CHECK(mock.closes == 3 && mock.closed[0] == 10 && mock.closed[1] == 20 && mock.closed[2] == 30); }

int main(void)
{
    reset(); struct writ_child c = child();
    CHECK(!writ_retire_child(&c)); CHECK(mock.checks == 1 && mock.signals == 1 && mock.waits == 1 && !mock.wait_flags); checked_close();
    CHECK(c.pid == -1 && c.pidfd == -1 && !c.retirement_error);

    reset(); c = child(); mock.exited = 1;
    CHECK(!writ_retire_child(&c)); CHECK(!mock.signals && !mock.wait_flags); checked_close();

    reset(); c = child(); mock.check_intr = mock.wait_intr = 1;
    CHECK(!writ_retire_child(&c)); CHECK(mock.checks == 2 && mock.waits == 2 && mock.signals == 1); checked_close();

    reset(); c = child(); mock.check_error = ECHILD; mock.not_ready = 1; mock.close_error_fd = 10; mock.close_errno = EIO;
    CHECK(writ_retire_child(&c) == ECHILD && c.pid == 42 && c.retirement_error == ECHILD);
    CHECK(!mock.signals && !mock.waits); checked_close();
    CHECK(writ_retire_child(&c) == ECHILD && !mock.waits && mock.closes == 3);

    reset(); c = child(); mock.mismatch = 1;
    CHECK(writ_retire_child(&c) == ECHILD && !mock.signals && !mock.waits && c.pid == 42); checked_close();

    reset(); c = child(); mock.check_error = EINVAL;
    CHECK(writ_retire_child(&c) == EINVAL && !mock.signals && !mock.waits && c.pid == 42); checked_close();

    reset(); c = child(); mock.signal_error = EPERM; mock.not_ready = 1;
    CHECK(writ_retire_child(&c) == EPERM && mock.signals == 1 && mock.wait_flags == WNOHANG && c.pid == 42); checked_close();

    reset(); c = child(); mock.signal_error = ESRCH;
    CHECK(writ_retire_child(&c) == ESRCH && c.pid == -1 && mock.wait_flags == WNOHANG); checked_close();

    reset(); c = child(); c.pidfd = -1; mock.not_ready = 1;
    CHECK(writ_retire_child(&c) == ENOTSUP && !mock.checks && !mock.signals && !mock.waits && c.pid == 42);
    CHECK(mock.closes == 2);

    reset(); c = child(); mock.wait_error = ECHILD;
    CHECK(writ_retire_child(&c) == ECHILD && c.pid == 42); checked_close();

    reset(); c = child(); mock.close_error_fd = 10; mock.close_errno = EINTR;
    CHECK(writ_retire_child(&c) == EINTR && c.pid == -1 && c.command == -1); checked_close();
    CHECK(writ_retire_child(&c) == EINTR && mock.closes == 3);

    reset(); c = child(); c.result = c.command;
    CHECK(writ_retire_child(&c) == EINVAL && mock.closes == 2 && mock.closed[0] == 10 && mock.closed[1] == 30);

    reset(); c = child(); c.pid = -1;
    CHECK(writ_retire_child(&c) == EINVAL && !mock.checks && !mock.signals && !mock.waits); checked_close();
    puts("ALL SYNTHETIC RETIREMENT ERROR CHECKS PASSED");
    return 0;
}
