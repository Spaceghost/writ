#ifndef WRIT_LINUX_BROKER_H
#define WRIT_LINUX_BROKER_H

/*
 * Linux protected-worker broker, section 1 (add-linux-host task 1.2).
 *
 * The broker observes and reports; the generated Bend monitor
 * (hosts/linux/monitor/LinuxHost.bend, run under Node through
 * broker_monitor.mjs on two private pipes) decides. Nothing here grants,
 * labels, budgets, plans, compares identities, or releases: the broker frames
 * kernel observations and its own launch record into LINUXB v1 frames
 * (LinuxHost.bend "Broker channel codec") and reports the monitor's reply.
 * It executes an effect only when a reply says ADMITTED with effects, and in
 * this task no frame it sends can return one (no input is issued).
 *
 * A uid, gid, pid, start time, or descriptor number is a local observation,
 * never a portable credential. A field the broker could not verify from the
 * kernel is reported as 0 (pid and start time), which never equals a launch
 * record's nonzero value, so the monitor refuses it; it is never reported as
 * verified.
 */

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#define BROKER_MAX_ROUTES 16u
#define BROKER_MAX_REQUEST 44u /* HostWire max_bytes() + 4: a longer frame is TooLong in Bend */
#define BROKER_MAX_FRAME 512u
#define BROKER_REPLY_MAX 512u
#define BROKER_MAX_DROPPED 8u

/* Frame tags, LinuxHost.bend frame_launch() .. frame_worker(). */
enum { BROKER_LAUNCH = 1, BROKER_BARRIER = 2, BROKER_USAGE = 3,
       BROKER_EMISSION = 4, BROKER_WORKER = 5 };
/* Endpoint kinds, LinuxHost.bend endpoint_of. */
enum { BROKER_LAUNCHED = 0, BROKER_INHERITED = 1, BROKER_TRANSFERRED = 2 };

/* One process credential as the broker's namespaces observe it. */
struct broker_cred {
    uint32_t uid, gid, pid;
    uint64_t start; /* /proc/PID/stat field 22, clock ticks; 0 = unverified */
};

struct broker_route { uint32_t descriptor, kind, mediated; };

/* LinuxHost.LinuxFact, field for field. */
struct broker_fact {
    uint32_t subject;
    uint32_t token[8];
    uint32_t incarnation;
    struct broker_cred launch, peer;
    uint32_t endpoint_kind, endpoint_session;
    uint32_t families, controls;
    uint32_t route_count;
    struct broker_route routes[BROKER_MAX_ROUTES];
};

/* The private monitor process and its two pipes (request, reply). */
struct broker_monitor {
    int input, output, live;
    pid_t pid;
    uint32_t sequence;
};

/* One parsed reply line: LINUXMON1 status detail table. */
struct broker_reply {
    uint32_t sequence;
    char status[16], detail[64], table[256];
};

/* Kernel observations of one received worker message. */
struct broker_message {
    uint8_t bytes[BROKER_MAX_REQUEST];
    size_t length;          /* bytes kept (the bounded snapshot) */
    int truncated;          /* MSG_TRUNC: the sender wrote more */
    int ctrunc;             /* MSG_CTRUNC: ancillary data was cut */
    int have_sender;        /* SCM_CREDENTIALS present */
    struct broker_cred sender;
    unsigned dropped;       /* SCM_RIGHTS descriptors received and closed */
    int dropped_closed;     /* every dropped number is EBADF after close */
};

/* Monitor transport. */
int broker_monitor_start(struct broker_monitor *, const char *node,
                         const char *harness, const char *module);
int broker_monitor_call(struct broker_monitor *, const uint8_t *frame,
                        size_t length, struct broker_reply *);
void broker_monitor_stop(struct broker_monitor *);
/* The session id the monitor allocated, read back from a reply's table:
 * the largest listed id (HostIdentity allocates ids in increasing order).
 * The broker records the monitor's allocation; it does not choose it.
 * Returns 0 with `*session` set, or -1 when the table lists no session. */
int broker_reply_session(const struct broker_reply *, uint32_t *session);

/* Frame encoders (LINUXB v1, little-endian words). Return the byte length,
 * or 0 when a bound is exceeded. */
size_t broker_encode_launch(const struct broker_fact *, uint8_t *out, size_t cap);
size_t broker_encode_barrier(uint32_t session, const struct broker_fact *,
                             const uint8_t *request, size_t request_length,
                             uint8_t *out, size_t cap);
size_t broker_encode_worker(uint32_t session, const uint8_t *request,
                            size_t request_length, uint8_t *out, size_t cap);
void broker_hex(const uint8_t *bytes, size_t length, char *out, size_t cap);

/* Kernel observations. */
int broker_start_time(pid_t pid, uint64_t *start);
int broker_observe_pidfd(int pidfd, uint32_t expected_pid, uint64_t *start);
int broker_listen(const char *path);
int broker_set_passcred(int fd);
int broker_accept(int listener, struct broker_cred *peer);
int broker_peer(int fd, struct broker_cred *peer);
int broker_receive(int fd, struct broker_message *);

#endif
