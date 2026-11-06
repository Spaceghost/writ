#ifndef WRIT_LINUX_LAUNCH_H
#define WRIT_LINUX_LAUNCH_H

/*
 * Trusted launch record and worker launch (add-linux-host task 1.2).
 *
 * The broker writes the launch record BEFORE the worker exists: the subject
 * and code token it was configured to run, the monitor incarnation, and a
 * fresh session generation. clone3(CLONE_PIDFD) then creates the worker and
 * returns its pidfd atomically; the record keeps that pidfd and the start
 * time read from /proc/PID/stat while the child is unreaped (so its pid
 * cannot have been reassigned). The record is the broker's own bookkeeping,
 * not a credential: it is reported to the Bend monitor as `LinuxFact`
 * subject/token/incarnation/launch, and the monitor compares it with what the
 * kernel says about each peer.
 *
 * Confinement is Task 3. Here a child only drops every capability, closes
 * every descriptor but the ones listed, and sets parent-death SIGKILL; with
 * LAUNCH_NAMESPACED it also runs in a new user and PID namespace (in-namespace
 * uid/gid `LAUNCH_INNER_ID`, pid 1) so that its own view of its identity
 * differs from the broker's.
 */

#include <stdint.h>
#include <sys/types.h>

#include "broker.h"

#define LAUNCH_NAMESPACED 1u
#define LAUNCH_INNER_ID 4242u
#define LAUNCH_MAX_KEEP 4u

struct launch_record {
    uint32_t subject;        /* SYNTHETIC selected subject (probe configuration) */
    uint32_t token[8];       /* SYNTHETIC code token (probe configuration) */
    uint32_t incarnation;    /* the monitor incarnation the broker was configured with */
    uint64_t generation;     /* fresh per launch record; broker bookkeeping only */
    uint32_t uid, gid;       /* the credentials the broker launched the child with, in its own namespaces */
    pid_t pid;               /* clone3 return, in the broker's PID namespace */
    int pidfd;               /* clone3 CLONE_PIDFD */
    uint64_t start;          /* /proc/PID/stat field 22 */
    unsigned flags;
};

typedef int (*launch_body)(void *argument, const int *kept, unsigned count);

/* Fill `record` (subject, token, incarnation, a fresh generation) and launch
 * `body` in a child holding only `keep[0..count)`, renumbered from fd 3.
 * Returns 0 with pid, pidfd, uid, gid, and start recorded, or -1. */
int launch_worker(struct launch_record *record, uint32_t subject,
                  const uint32_t token[8], uint32_t incarnation, unsigned flags,
                  const int *keep, unsigned count, launch_body body, void *argument);

/* Fork an UNRECORDED helper (no launch record): same descriptor and
 * capability treatment. With `exact_pid` nonzero it uses clone3 set_tid,
 * which needs CAP_CHECKPOINT_RESTORE over the broker's PID namespace (the
 * probe owns that namespace for the pid-reuse case). */
pid_t launch_helper(pid_t exact_pid, int *pidfd, const int *keep, unsigned count,
                    launch_body body, void *argument);

/* Drop every capability of the calling process (all sets). */
int launch_drop_capabilities(void);

/* Frame one observation for the monitor: the launch record's subject,
 * token, incarnation, and expected credential beside the kernel-observed
 * `peer`, with the endpoint, family and control bits, and route inventory the
 * broker established. A copy only: nothing here compares `peer` with the
 * record (LinuxHost.bend `launch_check` does). */
void launch_fact(struct broker_fact *fact, const struct launch_record *record,
                 const struct broker_cred *peer, uint32_t endpoint_kind,
                 uint32_t endpoint_session, uint32_t families, uint32_t controls,
                 const struct broker_route *routes, uint32_t route_count);

/* Wait for the child behind `pidfd` and close it. Returns its wait status. */
int launch_reap(int pidfd, int *status);

#endif
