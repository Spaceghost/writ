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

   Not established here: provisioning (the interpreter's initial owner comes
   from a provisioning module; the only one is a synthetic test module),
   alignment of the host clock with the issuer's time base, restart
   continuity, monitor frames from a broker (LINUXSUP1 FRAME is not sent by
   this driver), and host qualification. */
#ifndef WRIT_SUPERVISOR_OWNER_H
#define WRIT_SUPERVISOR_OWNER_H

#include <stddef.h>
#include <stdint.h>

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
    WRIT_OWNER_EXHAUSTED
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
    struct { uint32_t worker; int pidfd; } worker[WRIT_OWNER_WORKERS];
    int contained;                     /* sticky: some reply required containment */
    int failed;                        /* sticky: fail-stop, nothing more is sent */
};

/* Prepares `s` over a started interpreter. Returns 0. */
int writ_supervisor_init(struct writ_supervisor *s, struct writ_policy *policy,
                         writ_clock_source clock, void *clock_context);

/* Registers the pidfd the supervisor holds for worker `worker` (the Bend
   worker number). The caller keeps the pidfd open. 0, or -1 with EINVAL
   (worker 0, duplicate, negative pidfd) or ENOSPC. Not an authority fact:
   Bend decides whether a worker stops; this only says which process that is. */
int writ_supervisor_add_worker(struct writ_supervisor *s, uint32_t worker, int pidfd);

/* Forwards one classified record with a fresh clock sample. 0 when a
   well-formed reply was received (whatever its outcome), -1 on fail-stop.
   A control reply carrying any effect is fail-stop: the owner never returns
   one for a control message. */
int writ_supervisor_control(struct writ_supervisor *s, const struct writ_channel_record *record,
                            struct writ_owner_reply *reply);

/* Receives one record from the enabled channel `fd` (non-blocking, see
   writ_channel_receive) and forwards it. 0 forwarded; -1 with errno EAGAIN
   (nothing queued) or EPIPE (peer closed) without contacting the
   interpreter; -1 otherwise on fail-stop. */
int writ_supervisor_serve_one(struct writ_supervisor *s, int fd, const struct writ_roles *roles,
                              struct writ_owner_reply *reply);

/* Sends one DRAIN and executes the returned StopEffects in order: SIGKILL
   through the worker's pidfd, then a wait of at most five seconds for that
   pidfd to report exit. 0 when the reply was a drain outcome and every
   stopped worker exited, -1 on fail-stop. Only one thread may use a
   supervisor at a time. */
int writ_supervisor_drain(struct writ_supervisor *s, struct writ_owner_reply *reply);

#ifdef WRIT_OWNER_TESTING
/* Test seam: decode one reply line (LF removed) expecting `sequence`. */
int writ_owner_decode(char *line, uint32_t sequence, struct writ_owner_reply *reply);
/* Test seam: the CONTROL frame (with LF) for one record and sample; returns
   its length, or 0 when it cannot be formed. */
size_t writ_owner_format_control(const struct writ_channel_record *record,
                                 struct writ_clock_sample sample,
                                 char frame[WRIT_OWNER_FRAME_CAP]);
#endif

#endif
