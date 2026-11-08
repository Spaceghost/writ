#ifndef WRIT_LINUX_WORKER_H
#define WRIT_LINUX_WORKER_H

#include <stdint.h>
#include <sys/types.h>

/* Native probes have one private command pipe and one private result pipe. */
#define WRIT_COMMAND_FD 3
#define WRIT_RESULT_FD 4
#define WRIT_REPORT_MAGIC UINT32_C(0x57525431)
#define WRIT_CANARY_LIMIT 65536u

enum writ_probe {
    W_READY = 1, W_PRE_ADMIT, W_OPEN, W_FULL_READ, W_RANGE, W_EOF,
    W_DUP, W_DUP_READ, W_LIST, W_WRITE_DENY, W_MMAP_SHARED_DENY,
    W_MMAP_PRIVATE_DENY, W_IPV4_DENY, W_IPV6_DENY, W_UNIX_DENY,
    W_EXEC_DENY, W_FORK_DENY, W_PTRACE_DENY, W_VM_DENY, W_SIGNAL_DENY,
    W_SHM_DENY, W_MEMFD_DENY, W_IOURING_DENY, W_PATH_HIDDEN, W_PROC_HIDDEN,
    W_STDOUT_DENY, W_RIGHTS_DENY, W_IOCTL_DENY, W_SENDFILE_DENY, W_COPY_DENY,
    W_REVOKE_READ, W_REVOKE_DUP, W_REVOKE_OPEN, W_REVOKE_STAT, W_CLOSED,
    W_DONE, W_OUTSIDE_OPEN, W_OUTSIDE_STAT, W_OUTSIDE_LIST, W_OUTSIDE_PTRACE,
    W_SETUP_FAIL
};

struct writ_report { uint32_t magic, probe, ok, value; };
struct writ_child { pid_t pid; int command, result, pidfd; uint64_t start_time; int retirement_error; };

int writ_spawn_worker(struct writ_child *, const char *root, uid_t, gid_t,
                      unsigned int required_landlock, int outsider);
/* Returns the first errno-style failure; a failed attempt is not retried. */
int writ_retire_child(struct writ_child *);
int writ_process_start(pid_t, uint64_t *);
int writ_process_alive(const struct writ_child *);
int writ_private_read(int, void *, size_t, int milliseconds);
int writ_private_write(int, const void *, size_t, int milliseconds);

#endif
