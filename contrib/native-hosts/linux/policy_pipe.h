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
void writ_policy_stop(struct writ_policy *);

#endif
