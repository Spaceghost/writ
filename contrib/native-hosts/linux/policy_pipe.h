#ifndef WRIT_LINUX_POLICY_PIPE_H
#define WRIT_LINUX_POLICY_PIPE_H

#include <pthread.h>
#include <stdint.h>
#include <sys/types.h>

/* Transport only. This process never reconstructs or replaces Bend state. */
struct writ_policy {
    int input, output, live;
    pid_t pid;
    uint32_t sequence;
    pthread_mutex_t lock;
};

struct writ_reply {
    uint32_t value;
    enum { WRIT_OK, WRIT_DENY, WRIT_ERROR } status;
    char detail[65];
};

int writ_policy_start(struct writ_policy *, const char *node,
                      const char *bridge, const char *module);
int writ_policy_call(struct writ_policy *, const char *operation,
                     uint32_t actor, uint32_t handle, uint32_t offset,
                     uint32_t count, const char *argument, struct writ_reply *);
/* Raw exchange for a protocol other than WRITFS1 (LINUXSUP1, see
   supervisor_owner.c): writes `length` bytes of `frame`, which must end in its
   only LF, and reads exactly one reply line of at most 256 bytes into `line`
   (LF replaced by NUL; TAB and printable ASCII only). The caller checks the
   reply's own fields. Any failure kills the interpreter and leaves the pipe
   dead; there is no restart or replay. Returns 0 or -1. */
int writ_policy_exchange(struct writ_policy *, const char *frame, size_t length,
                         char line[256]);
/* Marks the pipe dead and kills the interpreter without reaping it (that is
   writ_policy_stop's job). Used when a caller rejects a reply. */
void writ_policy_abandon(struct writ_policy *);
void writ_policy_stop(struct writ_policy *);

#endif
