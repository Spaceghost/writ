#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static int dead(int pidfd, int timeout)
{
    struct pollfd fd = { .fd = pidfd, .events = POLLIN };
    int result;
    do { result = poll(&fd, 1, timeout); } while (result < 0 && errno == EINTR);
    return result == 1 && (fd.revents & POLLIN);
}

static int signal_process(int fd)
{ return (int)syscall(SYS_pidfd_send_signal, fd, SIGKILL, NULL, 0); }

static int pid_line(const char *line, const char *key, pid_t *pid)
{
    size_t length = strlen(key);
    if (strncmp(line, key, length) || line[length] != ' ') return -1;
    const char *p = line + length + 1;
    if (*p < '1' || *p > '9') return -1;
    unsigned int number = 0;
    for (; *p; ++p) {
        unsigned int d = (unsigned char)*p - '0';
        if (d > 9 || number > ((unsigned int)INT_MAX - d) / 10) return -1;
        number = number * 10 + d;
    }
    *pid = (pid_t)number;
    return 0;
}

static int read_record(const char *file, const char *work, pid_t expected,
                        pid_t *worker, pid_t *policy, char *root, char *mount)
{
    char text[PATH_MAX * 3], prefix[PATH_MAX];
    int fd = open(file, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return -1;
    ssize_t length = read(fd, text, sizeof text - 1);
    close(fd);
    if (length <= 0 || length == (ssize_t)sizeof text - 1 ||
        memchr(text, 0, (size_t)length) || text[length - 1] != '\n') return -1;
    text[length] = 0;
    char *lines[5], *save = NULL;
    for (unsigned int i = 0; i < 5; ++i) {
        lines[i] = strtok_r(i ? NULL : text, "\n", &save);
        if (!lines[i]) return -1;
    }
    if (strtok_r(NULL, "\n", &save)) return -1;
    pid_t broker;
    if (pid_line(lines[0], "broker", &broker) || broker != expected ||
        pid_line(lines[1], "worker", worker) || pid_line(lines[2], "policy", policy) ||
        strncmp(lines[3], "root ", 5) || strncmp(lines[4], "mount ", 6)) return -1;
    const char *r = lines[3] + 5, *m = lines[4] + 6;
    int n = snprintf(prefix, sizeof prefix, "%s/writfs-linux.", work);
    if (n <= 0 || (size_t)n >= sizeof prefix || strncmp(r, prefix, (size_t)n) ||
        strlen(r + n) != 6 || strlen(r) >= PATH_MAX || strlen(m) >= PATH_MAX) return -1;
    for (const char *p = r + n; *p; ++p)
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
              (*p >= '0' && *p <= '9'))) return -1;
    size_t rlength = strlen(r);
    if (strncmp(m, r, rlength) || strcmp(m + rlength, "/view")) return -1;
    memcpy(root, r, rlength + 1);
    memcpy(mount, m, strlen(m) + 1);
    return 0;
}

static void show_log(int fd)
{
    if (lseek(fd, 0, SEEK_SET) < 0) return;
    char bytes[4096];
    size_t total = 0;
    while (total < 65536) {
        ssize_t n = read(fd, bytes, sizeof bytes);
        if (n <= 0) break;
        total += (size_t)n;
        if (fwrite(bytes, 1, (size_t)n, stdout) != (size_t)n) break;
    }
}

int main(int argc, char **argv)
{
    if (argc != 9 || geteuid() != 0) {
        fputs("Usage (root): crash-probe ABS_HOST ABS_NODE ABS_BRIDGE ABS_MODULE "
              "ABS_PUBLIC_FIXTURE ABS_WORK_DIR UID GID\n", stderr); return 2;
    }
    for (unsigned int i = 1; i <= 6; ++i) if (*argv[i] != '/') return 2;
    char ready[PATH_MAX], log[PATH_MAX], root[PATH_MAX] = {0}, mount[PATH_MAX] = {0};
    int a = snprintf(ready, sizeof ready, "%s/crash-ready.%ld", argv[6], (long)getpid());
    int b = snprintf(log, sizeof log, "%s/crash-native.%ld.log", argv[6], (long)getpid());
    if (a <= 0 || (size_t)a >= sizeof ready || b <= 0 || (size_t)b >= sizeof log) return 2;
    struct stat existing;
    if (!lstat(ready, &existing) || errno != ENOENT) return 1;
    int log_fd = open(log, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (log_fd < 0) return 1;
    pid_t broker = fork();
    if (broker == 0) {
        if (dup2(log_fd, STDOUT_FILENO) < 0 || dup2(log_fd, STDERR_FILENO) < 0 ||
            syscall(SYS_close_range, 3u, UINT_MAX, 0)) _exit(120);
        char *args[] = { argv[1], "--node", argv[2], "--bridge", argv[3], "--module", argv[4],
            "--public-fixture", argv[5], "--work-dir", argv[6], "--uid", argv[7], "--gid", argv[8],
            "--case", "hold", "--ready-file", ready, NULL };
        char *env[] = { "PATH=/usr/bin:/bin", "LANG=C", "LC_ALL=C", NULL };
        execve(argv[1], args, env);
        _exit(121);
    }
    int broker_fd = -1, worker_fd = -1, policy_fd = -1, trusted_children = 0, result = 1;
    if (broker < 0) goto cleanup;
    broker_fd = (int)syscall(SYS_pidfd_open, broker, 0);
    if (broker_fd < 0) goto cleanup;
    for (unsigned int i = 0; i < 600; ++i) {
        if (!access(ready, F_OK)) break;
        if (dead(broker_fd, 0)) goto cleanup;
        struct timespec interval = { .tv_nsec = 100000000 };
        nanosleep(&interval, NULL);
    }
    pid_t worker, policy;
    if (dead(broker_fd, 0) || read_record(ready, argv[6], broker, &worker, &policy, root, mount))
        goto cleanup;
    /* The still-live broker retains both unreaped children. PID reuse cannot
       occur while these pidfds are captured. Do not signal an ambiguous record. */
    worker_fd = (int)syscall(SYS_pidfd_open, worker, 0);
    policy_fd = (int)syscall(SYS_pidfd_open, policy, 0);
    if (worker_fd < 0 || policy_fd < 0 || dead(broker_fd, 0)) goto cleanup;
    trusted_children = 1;
    if (dead(worker_fd, 0) || dead(policy_fd, 0)) goto cleanup;
    puts("PASS mounted reader and policy are live before broker crash");
    if (signal_process(broker_fd)) goto cleanup;
    int status;
    if (waitpid(broker, &status, 0) != broker || !WIFSIGNALED(status) || WTERMSIG(status) != SIGKILL)
        goto cleanup;
    broker = -1;
    puts("PASS broker was terminated without graceful cleanup");
    if (!dead(worker_fd, 10000) || !dead(policy_fd, 10000)) goto cleanup;
    puts("PASS broker death retires confined reader and private policy process");
    char data[PATH_MAX];
    int n = snprintf(data, sizeof data, "%s/data", mount);
    if (n <= 0 || (size_t)n >= sizeof data) goto cleanup;
    errno = 0;
    int stale = open(data, O_RDONLY | O_CLOEXEC | O_NONBLOCK);
    if (stale >= 0) { close(stale); goto cleanup; }
    if (errno != ENOTCONN) goto cleanup;
    puts("PASS abandoned FUSE connection returns ENOTCONN without bytes");
    result = 0;
cleanup:
    if (broker > 0) {
        if (broker_fd >= 0) signal_process(broker_fd); else kill(broker, SIGKILL);
        while (waitpid(broker, NULL, 0) < 0 && errno == EINTR) {}
    }
    if (trusted_children) {
        if (!dead(worker_fd, 0)) signal_process(worker_fd);
        if (!dead(policy_fd, 0)) signal_process(policy_fd);
        if (!dead(worker_fd, 10000) || !dead(policy_fd, 10000)) result = 1;
    }
    if (*mount) {
        if (umount2(mount, 0) && errno != EINVAL && errno != ENOENT) result = 1;
        if (rmdir(mount) && errno != ENOENT) result = 1;
    }
    if (*root && rmdir(root) && errno != ENOENT) result = 1;
    if (unlink(ready) && errno != ENOENT) result = 1;
    show_log(log_fd);
    close(log_fd);
    if (unlink(log)) result = 1;
    if (broker_fd >= 0) close(broker_fd);
    if (worker_fd >= 0) close(worker_fd);
    if (policy_fd >= 0) close(policy_fd);
    if (!result) puts("ALL LINUX BROKER CRASH CHECKS PASSED; owned abandoned mount removed");
    else fputs("LINUX BROKER CRASH CHECK FAILED\n", stderr);
    return result;
}
