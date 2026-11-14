/* Native driver for the supervisor issuer and clock owner (Linux).
   Bend side: hosts/linux/monitor/SupervisorOwner.bend, over the LINUXSUP1
   protocol in hosts/linux/monitor/SupervisorWire.bend, run by
   runtime/supervisor-policy.mjs in a private interpreter (policy_pipe.c).

   This module forwards native facts and executes returned effects, nothing
   else. For one channel record it reads one clock sample and sends the
   receiver's verdict number, role word, sample and payload bytes to the
   interpreter; it never attributes, decodes, compares times, decides
   containment or chooses which worker stops. It executes only a returned
   StopEffects, by SIGKILL through the pidfd the supervisor registered for that
   worker number. Any other effect, an unregistered worker, a malformed or
   out-of-sequence reply, or an interpreter failure is fail-stop: the driver
   marks itself failed and contained, kills the interpreter and sends nothing
   further. A reply outcome that does not belong to the operation sent is
   also fail-stop. The caller
   ignores SIGPIPE so a dead interpreter is a failed write.

   Provisioning: the interpreter starts with no role map. The first call must
   be writ_supervisor_provision, which forwards one protected configuration
   file's fstat facts and bytes; Bend decides whether the file is protected
   and the record acceptable. Through this API workers are registered only
   by writ_supervisor_launch_worker, as the supervisor starts them, and only
   after PROVISIONED; the struct's fields are not an enforcement boundary.
   Likewise a channel role index names only a process the supervisor
   started with writ_supervisor_launch_role after Bend admitted that index
   (ROLE_ADMITTED); the receiver attributes datagrams through that internal
   table, never a caller-supplied one.
   Not established here: an authenticated operator (file ownership and mode
   are local facts), an installed issuer (the issuer the interpreter retains
   comes from its provisioning module; the only one is a synthetic test
   module), alignment of the host clock with the issuer's time base, restart
   continuity, monitor frames from a broker (LINUXSUP1 FRAME is not sent by
   this driver), and host qualification. */
#ifndef WRIT_SUPERVISOR_OWNER_H
#define WRIT_SUPERVISOR_OWNER_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#include "policy_pipe.h"
#include "supervisor_channel.h"

#define WRIT_OWNER_WORKERS 8
#define WRIT_OWNER_STOPS 8
/* "LINUXSUP1\tCONTROL\t" + four U32 fields + payload hex + LF. */
#define WRIT_OWNER_FRAME_CAP (64u + 2u * WRIT_CHANNEL_PAYLOAD_MAX)

/* The sample kinds of LH.ClockSample, in LINUXSUP1 order. */
enum writ_clock_kind {
    WRIT_CLOCK_READING = 0,
    WRIT_CLOCK_UNAVAILABLE = 1,
    WRIT_CLOCK_AMBIGUOUS = 2,
    WRIT_CLOCK_OVERFLOW = 3
};

struct writ_clock_sample {
    enum writ_clock_kind kind;
    uint32_t now; /* meaningful only for WRIT_CLOCK_READING */
};

typedef struct writ_clock_sample (*writ_clock_source)(void *context);

/* CLOCK_BOOTTIME in whole seconds. A failed read is UNAVAILABLE and a value
   beyond 32 bits is OVERFLOW. Whether this time base matches the issuer's
   grant times is a provisioning question this module does not answer. */
struct writ_clock_sample writ_clock_boottime(void *unused);

enum writ_owner_outcome {
    WRIT_OWNER_REVOKE_APPLIED,
    WRIT_OWNER_REVOKE_REFUSED,
    WRIT_OWNER_CHANNEL_DENIED,
    WRIT_OWNER_CONTROL_UNDECODED,
    WRIT_OWNER_CONTAINED,
    WRIT_OWNER_SERVED,
    WRIT_OWNER_NOT_FRAMED,
    WRIT_OWNER_DRAIN_STEP,
    WRIT_OWNER_DRAIN_COMPLETE,
    WRIT_OWNER_DRAIN_INCOMPLETE,
    WRIT_OWNER_ERROR,
    WRIT_OWNER_STOPPED,
    WRIT_OWNER_EXHAUSTED,
    WRIT_OWNER_PROVISIONED,
    WRIT_OWNER_PROVISION_REFUSED,
    WRIT_OWNER_APPROVAL_ACCEPTED,
    WRIT_OWNER_APPROVAL_REFUSED,
    WRIT_OWNER_ROLE_ADMITTED,
    WRIT_OWNER_ROLE_REFUSED
};

struct writ_owner_reply {
    enum writ_owner_outcome outcome;
    int contain;                       /* the interpreter requires containment */
    size_t stops;                      /* StopEffects returned, in order */
    uint32_t stop[WRIT_OWNER_STOPS];
};

struct writ_supervisor {
    struct writ_policy *policy;        /* started with supervisor-policy.mjs */
    uint32_t sequence;                 /* replies accepted so far */
    writ_clock_source clock;
    void *clock_context;
    size_t workers;
    struct { uint32_t worker; int pidfd; int owned; } worker[WRIT_OWNER_WORKERS];
    struct writ_roles roles;           /* role processes this supervisor launched */
    size_t role_pidfds;
    int role_pidfd[WRIT_CHANNEL_ROLES];
    int provisioned;                   /* PROVISIONED was received */
    int contained;                     /* sticky: some reply required containment */
    int failed;                        /* sticky: fail-stop, nothing more is sent */
};

/* Prepares `s` over a started interpreter. Returns 0. */
int writ_supervisor_init(struct writ_supervisor *s, struct writ_policy *policy,
                         writ_clock_source clock, void *clock_context);

/* Resolves `name` beneath `dirfd` with openat2 as an O_PATH descriptor (no
   symlink in any component, no magic link, no escape from `dirfd`), takes
   fstat from that descriptor, and only for a regular file reopens it through
   /proc/self/fd to read its bytes, so a FIFO or device is never opened for
   I/O. It then sends one PROVISION frame: st_mode,
   st_nlink (saturated), st_uid, the effective user ID and the bytes. Bend
   decides. 0 when the reply was PROVISIONED; -1 on fail-stop, which includes
   PROVISION_REFUSED (then `reply` holds it), an open or read failure, and a
   file of more than WRIT_CHANNEL_PAYLOAD_MAX bytes (errno EFBIG); in those
   last cases nothing is sent. Bend refuses anything but the first frame, so
   this must be the first call. */
int writ_supervisor_provision(struct writ_supervisor *s, int dirfd, const char *name,
                              struct writ_owner_reply *reply);

/* Starts `path` with `argv` and `envp` as a child of this process (clone3
   with CLONE_PIDFD, then execve) and registers its pidfd as worker `worker`
   (the Bend worker number). Every signal is blocked in the caller across
   clone3, so no handler of the caller runs in the child; the child then gets
   default dispositions, PR_SET_PDEATHSIG SIGKILL (it dies with this thread),
   an empty signal mask and only descriptors 0 to 2. On success returns the
   pidfd, which the supervisor owns: the caller may poll and waitid on it but
   must not close it; writ_supervisor_release closes it. Sets `*pid`; the
   caller reaps the child. -1 with EPERM (not provisioned, or failed),
   EINVAL (worker 0 or already registered) or ENOSPC before anything is
   started, or with the errno of clone3. A failed execve shows as the child
   exiting with status 127. This says which process a worker number is;
   Bend decides whether it stops. */
int writ_supervisor_launch_worker(struct writ_supervisor *s, uint32_t worker, const char *path,
                                  char *const argv[], char *const envp[], pid_t *pid);

/* Asks Bend whether a process may be started for channel role `index`
   (LINUXSUP1 ROLE; SupervisorRoleLaunch.bend) and, only on ROLE_ADMITTED,
   starts `path` as for writ_supervisor_launch_worker except for its
   descriptors: `input` becomes its descriptor 0 and `channel` (its end of the
   supervisor channel) its descriptor 3; it keeps 1 and 2 and nothing else.
   The child's pidfs identity is then registered under `index` in the
   supervisor's own role table, which writ_supervisor_serve_one uses. The
   caller keeps `input` and `channel` (the child has its own copies). On
   success, which means execve succeeded, returns the pidfd, owned by the
   supervisor as for workers, and sets `*pid`; the caller reaps the child.
   -1 with EPERM (not provisioned, failed) or EBADF (a negative descriptor)
   or ENOSPC (the table is full) before anything is sent; -1 with EPERM and
   `reply` set after ROLE_REFUSED, which is not fail-stop and starts nothing;
   -1 on fail-stop otherwise: a reply other than a clean ROLE_ADMITTED or
   ROLE_REFUSED (containment or an effect included), or after admission a
   clone3 failure, a child that failed before or in execve (it is reaped;
   errno is the child's), or a registration failure (the child is killed and
   reaped). A bound index with no process would differ from Bend's state.
   The admitted index stays bound for the interpreter's lifetime, even after
   its process exits. */
int writ_supervisor_launch_role(struct writ_supervisor *s, uint32_t index, int channel, int input,
                                const char *path, char *const argv[], char *const envp[], pid_t *pid,
                                struct writ_owner_reply *reply);

/* Closes every pidfd the supervisor owns (launched workers and role
   processes) and empties both tables. Kills and reaps nothing. End of life
   only: the interpreter still counts the released role indices as bound. */
void writ_supervisor_release(struct writ_supervisor *s);

/* Forwards one classified record with a fresh clock sample. 0 when a
   well-formed reply was received (whatever its outcome), -1 on fail-stop.
   A control reply carrying any effect is fail-stop: the owner never returns
   one for a control message. */
int writ_supervisor_control(struct writ_supervisor *s, const struct writ_channel_record *record,
                            struct writ_owner_reply *reply);

/* Receives one record from the enabled channel `fd` (non-blocking, see
   writ_channel_receive), attributing its sender through the role processes
   launched by writ_supervisor_launch_role, and forwards it. 0 forwarded; -1 with errno EAGAIN
   (nothing queued) or EPIPE (peer closed) without contacting the
   interpreter; -1 otherwise on fail-stop. */
int writ_supervisor_serve_one(struct writ_supervisor *s, int fd, struct writ_owner_reply *reply);

/* Sends one DRAIN and executes the returned StopEffects in order: SIGKILL
   through the worker's pidfd, then a wait of at most five seconds for that
   pidfd to report exit. 0 when the reply was a drain outcome and every
   stopped worker exited, -1 on fail-stop. Only one thread may use a
   supervisor at a time. */
int writ_supervisor_drain(struct writ_supervisor *s, struct writ_owner_reply *reply);

#ifdef WRIT_OWNER_TESTING
#include <sys/stat.h>
/* Test seam: registers an existing pidfd, which the caller keeps owning, as
   worker `worker` without launching it. 0, or -1
   with EINVAL (worker 0, duplicate, negative pidfd) or ENOSPC. */
int writ_supervisor_add_worker(struct writ_supervisor *s, uint32_t worker, int pidfd);
/* Test seam: the PROVISION frame (with LF) for the facts and bytes; returns
   its length, or 0 when it cannot be formed. */
size_t writ_owner_format_provision(const struct stat *st, uint32_t euid, const unsigned char *bytes,
                                   size_t length, char frame[WRIT_OWNER_FRAME_CAP]);
/* Test seam: decode one reply line (LF removed) expecting `sequence`. */
int writ_owner_decode(char *line, uint32_t sequence, struct writ_owner_reply *reply);
/* Test seam: the CONTROL frame (with LF) for one record and sample; returns
   its length, or 0 when it cannot be formed. */
size_t writ_owner_format_control(const struct writ_channel_record *record,
                                 struct writ_clock_sample sample,
                                 char frame[WRIT_OWNER_FRAME_CAP]);
#endif

#endif
