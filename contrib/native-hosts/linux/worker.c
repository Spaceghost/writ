#define _GNU_SOURCE
#include "worker.h"

#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <inttypes.h>
#include <limits.h>
#include <linux/audit.h>
#include <linux/capability.h>
#include <linux/filter.h>
#include <linux/io_uring.h>
#include <linux/landlock.h>
#include <linux/seccomp.h>
#include <poll.h>
#include <sched.h>
#include <signal.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/prctl.h>
#include <sys/ptrace.h>
#include <sys/resource.h>
#include <sys/sendfile.h>
#include <sys/shm.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#if !defined(__x86_64__)
#error This bounded native probe profile is qualified only for Linux x86_64.
#endif

extern char **environ;

static int64_t now_ms(void)
{
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts)) return -1;
    return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int transfer(int fd, void *buffer, size_t size, int timeout, int writing)
{
    int64_t now = now_ms(), deadline = now + timeout;
    if (now < 0) return -1;
    unsigned char *p = buffer;
    while (size) {
        now = now_ms();
        if (now < 0 || now >= deadline) return -1;
        struct pollfd descriptor = { .fd = fd, .events = writing ? POLLOUT : POLLIN };
        int status = poll(&descriptor, 1, (int)(deadline - now));
        if (status < 0 && errno == EINTR) continue;
        if (status <= 0 || !(descriptor.revents & descriptor.events)) return -1;
        ssize_t n = writing ? write(fd, p, size) : read(fd, p, size);
        if (n < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (n <= 0) return -1;
        p += n; size -= (size_t)n;
    }
    return 0;
}

int writ_private_read(int fd, void *buf, size_t n, int timeout)
{ return transfer(fd, buf, n, timeout, 0); }
int writ_private_write(int fd, const void *buf, size_t n, int timeout)
{ return transfer(fd, (void *)buf, n, timeout, 1); }

int writ_process_start(pid_t pid, uint64_t *result)
{
    char path[64], data[4096];
    int n = snprintf(path, sizeof path, "/proc/%ld/stat", (long)pid);
    if (pid <= 0 || n <= 0 || (size_t)n >= sizeof path) return -1;
    int fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return -1;
    ssize_t length = read(fd, data, sizeof data - 1);
    close(fd);
    if (length <= 0 || length == (ssize_t)sizeof data - 1) return -1;
    data[length] = 0;
    /* comm may contain spaces and ')' characters; the final ')' ends it. */
    char *p = strrchr(data, ')');
    if (!p || p[1] != ' ') return -1;
    p += 2;
    for (unsigned int field = 3; field < 22; ++field) {
        p = strchr(p, ' ');
        if (!p) return -1;
        ++p;
    }
    uint64_t value = 0;
    if (*p < '0' || *p > '9') return -1;
    while (*p >= '0' && *p <= '9') {
        unsigned int digit = (unsigned char)*p++ - '0';
        if (value > (UINT64_MAX - digit) / 10) return -1;
        value = value * 10 + digit;
    }
    if (*p != ' ') return -1;
    *result = value;
    return 0;
}

int writ_process_alive(const struct writ_child *child)
{
    if (child->pidfd < 0 || child->pid <= 0) return 0;
    struct pollfd p = { .fd = child->pidfd, .events = POLLIN };
    uint64_t current;
    return poll(&p, 1, 0) == 0 &&
        !writ_process_start(child->pid, &current) && current == child->start_time;
}

static void emit(enum writ_probe probe, int ok, uint32_t value)
{
    struct writ_report r = { WRIT_REPORT_MAGIC, (uint32_t)probe, !!ok, value };
    if (writ_private_write(WRIT_RESULT_FD, &r, sizeof r, 15000)) _exit(120);
}

static void setup_fail(unsigned int step)
{
    /* Only a fixed setup step number crosses the private diagnostic channel. */
    emit(W_SETUP_FAIL, 0, step);
    _exit(121);
}

static void expect_command(char expected)
{
    char c;
    if (writ_private_read(WRIT_COMMAND_FD, &c, 1, 60000) || c != expected) _exit(122);
}

static int limit(int resource, rlim_t amount)
{
    const struct rlimit limit = { amount, amount };
    return setrlimit(resource, &limit);
}

static int drop_identity(uid_t uid, gid_t gid, pid_t parent)
{
    if (!uid || !gid || setgroups(0, NULL) || prctl(PR_SET_KEEPCAPS, 0) ||
        prctl(PR_CAP_AMBIENT, PR_CAP_AMBIENT_CLEAR_ALL, 0, 0, 0)) return -1;
    for (unsigned int capability = 0; capability < 64; ++capability) {
        if (prctl(PR_CAPBSET_DROP, capability, 0, 0, 0)) {
            if (errno == EINVAL) break;
            return -1;
        }
    }
    if (setresgid(gid, gid, gid) || setresuid(uid, uid, uid) ||
        prctl(PR_SET_DUMPABLE, 0) || prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) ||
        prctl(PR_SET_PDEATHSIG, SIGKILL) || getppid() != parent) return -1;
    return 0;
}

static int landlock_readonly(int root_fd, unsigned int required)
{
    int abi = (int)syscall(SYS_landlock_create_ruleset, NULL, 0,
                          LANDLOCK_CREATE_RULESET_VERSION);
    if (abi < 3 || (unsigned int)abi < required) return -1;
    struct landlock_ruleset_attr rules = {
        .handled_access_fs = LANDLOCK_ACCESS_FS_EXECUTE | LANDLOCK_ACCESS_FS_WRITE_FILE |
            LANDLOCK_ACCESS_FS_READ_FILE | LANDLOCK_ACCESS_FS_READ_DIR |
            LANDLOCK_ACCESS_FS_REMOVE_DIR | LANDLOCK_ACCESS_FS_REMOVE_FILE |
            LANDLOCK_ACCESS_FS_MAKE_CHAR | LANDLOCK_ACCESS_FS_MAKE_DIR |
            LANDLOCK_ACCESS_FS_MAKE_REG | LANDLOCK_ACCESS_FS_MAKE_SOCK |
            LANDLOCK_ACCESS_FS_MAKE_FIFO | LANDLOCK_ACCESS_FS_MAKE_BLOCK |
            LANDLOCK_ACCESS_FS_MAKE_SYM | LANDLOCK_ACCESS_FS_REFER |
            LANDLOCK_ACCESS_FS_TRUNCATE
    };
    /* ABI 3 profile: filesystem rights through TRUNCATE; network/IPC use namespaces
       and a syscall allowlist. No claimed right is dropped on an older kernel. */
    int fd = (int)syscall(SYS_landlock_create_ruleset, &rules,
                         sizeof rules.handled_access_fs, 0);
    if (fd < 0) return -1;
    struct landlock_path_beneath_attr path = {
        .allowed_access = LANDLOCK_ACCESS_FS_READ_FILE | LANDLOCK_ACCESS_FS_READ_DIR,
        .parent_fd = root_fd
    };
    int result = syscall(SYS_landlock_add_rule, fd, LANDLOCK_RULE_PATH_BENEATH,
                          &path, 0) || syscall(SYS_landlock_restrict_self, fd, 0);
    close(fd);
    return result ? -1 : abi;
}

#define ALLOW_SYSCALL(n) \
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, (n), 0, 1), \
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW)

static int install_filter(void)
{
    const struct sock_filter filter[] = {
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, arch)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, AUDIT_ARCH_X86_64, 1, 0),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS),
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
        /* The only writable inherited endpoint is the broker's private pipe. */
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, SYS_write, 0, 4),
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, args[0])),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, WRIT_RESULT_FD, 0, 1),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EPERM),
        /* openat can only obtain read-only descriptors inside the chroot/LSM view. */
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, SYS_openat, 0, 5),
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, args[2])),
        BPF_STMT(BPF_ALU | BPF_AND | BPF_K,
            O_ACCMODE | O_CREAT | O_TRUNC | O_APPEND | (O_TMPFILE & ~O_DIRECTORY)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, 0, 0, 1),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EPERM),
        ALLOW_SYSCALL(SYS_read), ALLOW_SYSCALL(SYS_pread64),
        ALLOW_SYSCALL(SYS_close), ALLOW_SYSCALL(SYS_dup),
        ALLOW_SYSCALL(SYS_fstat), ALLOW_SYSCALL(SYS_newfstatat),
        ALLOW_SYSCALL(SYS_getdents64), ALLOW_SYSCALL(SYS_lseek),
        ALLOW_SYSCALL(SYS_poll), ALLOW_SYSCALL(SYS_clock_gettime),
        ALLOW_SYSCALL(SYS_getpid), ALLOW_SYSCALL(SYS_getppid),
        ALLOW_SYSCALL(SYS_getuid), ALLOW_SYSCALL(SYS_geteuid),
        ALLOW_SYSCALL(SYS_getgid), ALLOW_SYSCALL(SYS_getegid),
        ALLOW_SYSCALL(SYS_rt_sigreturn), ALLOW_SYSCALL(SYS_exit),
        ALLOW_SYSCALL(SYS_exit_group),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EPERM)
    };
    const struct sock_fprog program = { .len = sizeof filter / sizeof filter[0],
                                       .filter = (struct sock_filter *)filter };
    return prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, &program);
}

static int sole_data_entry(int fd)
{
    unsigned char buf[1024];
    ssize_t n = syscall(SYS_getdents64, fd, buf, sizeof buf);
    if (n <= 0) return 0;
    unsigned int data = 0;
    for (size_t i = 0; i < (size_t)n;) {
        if ((size_t)n - i < 20) return 0;
        unsigned short record;
        memcpy(&record, buf + i + 16, sizeof record);
        if (record < 20 || record > (size_t)n - i) return 0;
        const char *name = (const char *)buf + i + 19;
        if (!memchr(name, 0, record - 19)) return 0;
        if (!strcmp(name, "data")) ++data;
        else if (strcmp(name, ".") && strcmp(name, "..")) return 0;
        i += record;
    }
    return data == 1;
}

static void confined_probes(pid_t parent)
{
    expect_command('N');
    errno = 0;
    int fd = open("/view/data", O_RDONLY | O_CLOEXEC);
    emit(W_PRE_ADMIT, fd < 0 && errno == EACCES, (uint32_t)errno);
    if (fd >= 0) { close(fd); _exit(123); }
    expect_command('R');
    fd = open("/view/data", O_RDONLY | O_CLOEXEC);
    emit(W_OPEN, fd >= 0, (uint32_t)errno);
    if (fd < 0) _exit(124);
    unsigned char bytes[WRIT_CANARY_LIMIT], small[3];
    ssize_t n = pread(fd, bytes, sizeof bytes, 0);
    emit(W_FULL_READ, n >= 0, n >= 0 ? (uint32_t)n : (uint32_t)errno);
    if (n < 0) _exit(125);
    if (writ_private_write(WRIT_RESULT_FD, bytes, (size_t)n, 15000)) _exit(126);
    ssize_t expected = n > 1 ? (n - 1 > 3 ? 3 : n - 1) : 0;
    ssize_t range = pread(fd, small, sizeof small, 1);
    emit(W_RANGE, range == expected && (!expected || !memcmp(small, bytes + 1, (size_t)expected)), 0);
    emit(W_EOF, pread(fd, small, 1, WRIT_CANARY_LIMIT) == 0, 0);
    int duplicate = dup(fd);
    emit(W_DUP, duplicate >= 0, (uint32_t)errno);
    if (duplicate < 0) _exit(127);
    ssize_t first = pread(duplicate, small, 1, 0);
    emit(W_DUP_READ, first == (n ? 1 : 0) && (!n || small[0] == bytes[0]), 0);
    int dir = open("/view", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    emit(W_LIST, dir >= 0 && sole_data_entry(dir), (uint32_t)errno);
    if (dir >= 0) close(dir);

#define DENIED(test, expression) do { errno = 0; long value = (long)(expression); \
    int error = errno; emit((test), value == -1 && error == EPERM, (uint32_t)error); } while (0)
    DENIED(W_WRITE_DENY, open("/view/data", O_WRONLY));
    DENIED(W_MMAP_SHARED_DENY, mmap(NULL, 4096, PROT_READ, MAP_SHARED, fd, 0));
    DENIED(W_MMAP_PRIVATE_DENY, mmap(NULL, 4096, PROT_READ, MAP_PRIVATE, fd, 0));
    DENIED(W_IPV4_DENY, socket(AF_INET, SOCK_STREAM, 0));
    DENIED(W_IPV6_DENY, socket(AF_INET6, SOCK_DGRAM, 0));
    DENIED(W_UNIX_DENY, socket(AF_UNIX, SOCK_DGRAM, 0));
    char *arguments[] = { "/bin/sh", NULL }, *environment[] = { NULL };
    DENIED(W_EXEC_DENY, execve(arguments[0], arguments, environment));
    DENIED(W_FORK_DENY, syscall(SYS_fork));
    DENIED(W_PTRACE_DENY, ptrace(PTRACE_ATTACH, parent, NULL, NULL));
    struct iovec local = { small, 1 }, remote = { (void *)(uintptr_t)1, 1 };
    DENIED(W_VM_DENY, process_vm_readv(parent, &local, 1, &remote, 1, 0));
    DENIED(W_SIGNAL_DENY, kill(parent, 0));
    DENIED(W_SHM_DENY, shmget(IPC_PRIVATE, 4096, IPC_CREAT | 0600));
    DENIED(W_MEMFD_DENY, memfd_create("unapproved", MFD_CLOEXEC));
    struct io_uring_params ring;
    memset(&ring, 0, sizeof ring);
    DENIED(W_IOURING_DENY, syscall(SYS_io_uring_setup, 1, &ring));
    errno = 0;
    int hidden = open("/etc/passwd", O_RDONLY);
    emit(W_PATH_HIDDEN, hidden < 0 && errno == ENOENT, (uint32_t)errno);
    if (hidden >= 0) close(hidden);
    errno = 0;
    hidden = open("/proc/self/mem", O_RDONLY);
    emit(W_PROC_HIDDEN, hidden < 0 && errno == ENOENT, (uint32_t)errno);
    if (hidden >= 0) close(hidden);
    DENIED(W_STDOUT_DENY, write(STDOUT_FILENO, bytes, n ? 1 : 0));
    struct msghdr message;
    memset(&message, 0, sizeof message);
    DENIED(W_RIGHTS_DENY, sendmsg(WRIT_COMMAND_FD, &message, 0));
    DENIED(W_IOCTL_DENY, ioctl(fd, FIONREAD, &hidden));
    DENIED(W_SENDFILE_DENY, sendfile(WRIT_RESULT_FD, fd, NULL, 1));
    DENIED(W_COPY_DENY, syscall(SYS_copy_file_range, fd, NULL, WRIT_RESULT_FD, NULL, 1, 0));
#undef DENIED

    char command;
    if (writ_private_read(WRIT_COMMAND_FD, &command, 1, 60000) ||
        (command != 'V' && command != 'E')) _exit(128);
    int denied = command == 'V' ? EACCES : EIO;
    errno = 0;
    ssize_t after = pread(fd, small, 1, 0);
    emit(W_REVOKE_READ, after < 0 && errno == denied, (uint32_t)errno);
    errno = 0;
    after = pread(duplicate, small, 1, 0);
    emit(W_REVOKE_DUP, after < 0 && errno == denied, (uint32_t)errno);
    errno = 0;
    int reopened = open("/view/data", O_RDONLY);
    emit(W_REVOKE_OPEN, reopened < 0 && errno == denied, (uint32_t)errno);
    if (reopened >= 0) close(reopened);
    struct stat st;
    errno = 0;
    int stated = stat("/view/data", &st);
    emit(W_REVOKE_STAT, stated < 0 && errno == denied, (uint32_t)errno);
    int a = close(fd), b = close(duplicate);
    emit(W_CLOSED, a == 0 && b == 0, 0);
    emit(W_DONE, 1, 0);
    _exit(0);
}

static void outsider_probes(const char *root)
{
    char path[PATH_MAX];
    int n = snprintf(path, sizeof path, "%s/view/data", root);
    if (n <= 0 || (size_t)n >= sizeof path) setup_fail(20);
    emit(W_READY, 1, 0);
    for (unsigned int round = 0; round < 2; ++round) {
        expect_command('X');
        n = snprintf(path, sizeof path, "%s/view/data", root);
        if (n <= 0 || (size_t)n >= sizeof path) setup_fail(21);
        errno = 0;
        int fd = open(path, O_RDONLY | O_CLOEXEC);
        emit(W_OUTSIDE_OPEN, fd < 0 && errno == EACCES, (uint32_t)errno);
        if (fd >= 0) close(fd);
        struct stat st;
        errno = 0;
        int result = stat(path, &st);
        emit(W_OUTSIDE_STAT, result < 0 && errno == EACCES, (uint32_t)errno);
        n = snprintf(path, sizeof path, "%s/view", root);
        if (n <= 0 || (size_t)n >= sizeof path) setup_fail(22);
        errno = 0;
        fd = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        emit(W_OUTSIDE_LIST, fd < 0 && errno == EACCES, (uint32_t)errno);
        if (fd >= 0) close(fd);
        uint32_t pid;
        if (writ_private_read(WRIT_COMMAND_FD, &pid, sizeof pid, 15000) || pid > INT_MAX) _exit(129);
        errno = 0;
        long attached = ptrace(PTRACE_ATTACH, (pid_t)pid, NULL, NULL);
        emit(W_OUTSIDE_PTRACE, attached < 0 && errno == EPERM, (uint32_t)errno);
        if (!attached) ptrace(PTRACE_DETACH, (pid_t)pid, NULL, NULL);
        emit(W_DONE, 1, 0);
    }
    _exit(0);
}

int writ_spawn_worker(struct writ_child *child, const char *root, uid_t uid, gid_t gid,
                      unsigned int required_landlock, int outsider)
{
    memset(child, 0, sizeof *child);
    child->pid = -1;
    child->command = child->result = child->pidfd = -1;
    int command[2], result[2];
    if (pipe2(command, O_CLOEXEC)) return -1;
    if (pipe2(result, O_CLOEXEC)) { close(command[0]); close(command[1]); return -1; }
    pid_t parent = getpid(), pid = fork();
    if (pid == 0) {
        /* The prelude runs before admission and before any untrusted work.
           Remove inherited environment bytes as well as the lookup pointers. */
        for (char **entry = environ; entry && *entry; ++entry)
            explicit_bzero(*entry, strlen(*entry));
        if (clearenv()) _exit(134);
        if (dup2(command[0], WRIT_COMMAND_FD) < 0 || dup2(result[1], WRIT_RESULT_FD) < 0)
            _exit(130);
        close(0); close(1); close(2);
        if (syscall(SYS_close_range, 5u, UINT_MAX, 0)) _exit(131);
        if (prctl(PR_SET_PDEATHSIG, SIGKILL) || getppid() != parent) _exit(132);
        if (limit(RLIMIT_CORE, 0) || limit(RLIMIT_FSIZE, 0) || limit(RLIMIT_NPROC, 0) ||
            limit(RLIMIT_NOFILE, 16) || limit(RLIMIT_AS, 128 * 1024 * 1024) ||
            limit(RLIMIT_CPU, 5)) setup_fail(1);
        if (outsider) {
            if (drop_identity(uid, gid, parent)) setup_fail(2);
            outsider_probes(root);
        }
        if (unshare(CLONE_NEWNS | CLONE_NEWNET | CLONE_NEWIPC | CLONE_NEWUTS)) setup_fail(3);
        if (mount(NULL, "/", NULL, MS_REC | MS_PRIVATE, NULL)) setup_fail(4);
        if (chroot(root) || chdir("/")) setup_fail(5);
        int root_fd = open("/", O_PATH | O_DIRECTORY | O_CLOEXEC);
        if (root_fd < 0) setup_fail(6);
        if (drop_identity(uid, gid, parent)) setup_fail(7);
        int abi = landlock_readonly(root_fd, required_landlock);
        close(root_fd);
        if (abi < 0) setup_fail(8);
        if (install_filter()) setup_fail(9);
        emit(W_READY, 1, (uint32_t)abi);
        confined_probes(parent);
        _exit(133);
    }
    close(command[0]); close(result[1]);
    if (pid < 0) { close(command[1]); close(result[0]); return -1; }
    child->pid = pid; child->command = command[1]; child->result = result[0];
    child->pidfd = (int)syscall(SYS_pidfd_open, pid, 0);
    if (child->pidfd < 0 || writ_process_start(pid, &child->start_time)) {
        writ_retire_child(child); return -1;
    }
    return 0;
}

void writ_retire_child(struct writ_child *child)
{
    if (child->pid > 0) {
        if (child->pidfd >= 0) syscall(SYS_pidfd_send_signal, child->pidfd, SIGKILL, NULL, 0);
        else kill(child->pid, SIGKILL);
        while (waitpid(child->pid, NULL, 0) < 0 && errno == EINTR) {}
    }
    if (child->command >= 0) close(child->command);
    if (child->result >= 0) close(child->result);
    if (child->pidfd >= 0) close(child->pidfd);
    child->pid = -1; child->command = child->result = child->pidfd = -1;
}
