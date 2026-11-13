#define _GNU_SOURCE
#include "supervisor_owner.h"

#include <errno.h>
#include <inttypes.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/syscall.h>
#include <time.h>
#include <unistd.h>

/* A stop is acknowledged only after the worker has exited. */
#define STOP_WAIT_MILLISECONDS 5000

static const char *const outcome_names[] = {
    [WRIT_OWNER_REVOKE_APPLIED] = "REVOKE_APPLIED",
    [WRIT_OWNER_REVOKE_REFUSED] = "REVOKE_REFUSED",
    [WRIT_OWNER_CHANNEL_DENIED] = "CHANNEL_DENIED",
    [WRIT_OWNER_CONTROL_UNDECODED] = "CONTROL_UNDECODED",
    [WRIT_OWNER_CONTAINED] = "CONTAINED",
    [WRIT_OWNER_SERVED] = "SERVED",
    [WRIT_OWNER_NOT_FRAMED] = "NOT_FRAMED",
    [WRIT_OWNER_DRAIN_STEP] = "DRAIN_STEP",
    [WRIT_OWNER_DRAIN_COMPLETE] = "DRAIN_COMPLETE",
    [WRIT_OWNER_DRAIN_INCOMPLETE] = "DRAIN_INCOMPLETE",
    [WRIT_OWNER_ERROR] = "ERROR",
    [WRIT_OWNER_STOPPED] = "STOPPED",
    [WRIT_OWNER_EXHAUSTED] = "EXHAUSTED",
};

struct writ_clock_sample writ_clock_boottime(void *unused)
{
    (void)unused;
    struct timespec ts;
    if (clock_gettime(CLOCK_BOOTTIME, &ts) || ts.tv_sec < 0)
        return (struct writ_clock_sample){ WRIT_CLOCK_UNAVAILABLE, 0 };
    if ((uint64_t)ts.tv_sec > UINT32_MAX)
        return (struct writ_clock_sample){ WRIT_CLOCK_OVERFLOW, 0 };
    return (struct writ_clock_sample){ WRIT_CLOCK_READING, (uint32_t)ts.tv_sec };
}

int writ_supervisor_init(struct writ_supervisor *s, struct writ_policy *policy,
                         writ_clock_source clock, void *clock_context)
{
    memset(s, 0, sizeof *s);
    s->policy = policy;
    s->clock = clock;
    s->clock_context = clock_context;
    return 0;
}

int writ_supervisor_add_worker(struct writ_supervisor *s, uint32_t worker, int pidfd)
{
    if (!worker || pidfd < 0) { errno = EINVAL; return -1; }
    for (size_t i = 0; i < s->workers; ++i)
        if (s->worker[i].worker == worker) { errno = EINVAL; return -1; }
    if (s->workers == WRIT_OWNER_WORKERS) { errno = ENOSPC; return -1; }
    s->worker[s->workers].worker = worker;
    s->worker[s->workers].pidfd = pidfd;
    ++s->workers;
    return 0;
}

static int canonical_u32(const char *text, size_t length, uint32_t *result)
{
    if (!length || length > 10 || (text[0] == '0' && length > 1)) return -1;
    uint64_t n = 0;
    for (size_t i = 0; i < length; ++i) {
        if (text[i] < '0' || text[i] > '9') return -1;
        n = n * 10u + (uint64_t)(text[i] - '0');
    }
    if (n > UINT32_MAX) return -1;
    *result = (uint32_t)n;
    return 0;
}

/* Only StopEffects tokens are executable here; any other kind fails. */
static int decode_effects(const char *field, struct writ_owner_reply *reply)
{
    reply->stops = 0;
    if (!strcmp(field, "-")) return 0;
    for (;;) {
        if (*field != 'S' || reply->stops == WRIT_OWNER_STOPS) return -1;
        ++field;
        size_t length = strcspn(field, ",");
        if (canonical_u32(field, length, &reply->stop[reply->stops])) return -1;
        ++reply->stops;
        field += length;
        if (!*field) return 0;
        ++field; /* ',' then another token is required */
    }
}

#ifndef WRIT_OWNER_TESTING
static
#endif
int writ_owner_decode(char *line, uint32_t sequence, struct writ_owner_reply *reply)
{
    char *field[5];
    field[0] = line;
    for (unsigned int i = 1; i < 5; ++i) {
        char *tab = strchr(field[i - 1], '\t');
        if (!tab) return -1;
        *tab = 0;
        field[i] = tab + 1;
    }
    uint32_t got;
    if (strchr(field[4], '\t') || strcmp(field[0], "LINUXSUP1") ||
        canonical_u32(field[1], strlen(field[1]), &got) || got != sequence) return -1;
    size_t names = sizeof outcome_names / sizeof outcome_names[0];
    size_t i = 0;
    while (i < names && strcmp(field[2], outcome_names[i])) ++i;
    if (i == names) return -1;
    reply->outcome = (enum writ_owner_outcome)i;
    if (!strcmp(field[3], "0")) reply->contain = 0;
    else if (!strcmp(field[3], "1")) reply->contain = 1;
    else return -1;
    return decode_effects(field[4], reply);
}

/* Fail-stop also kills the interpreter: nothing may exchange with it again. */
static int fail_stop(struct writ_supervisor *s)
{
    s->failed = 1;
    s->contained = 1;
    if (s->policy) writ_policy_abandon(s->policy);
    return -1;
}

/* Replies a control message may receive, and replies a drain may receive. */
static int control_outcome(enum writ_owner_outcome o)
{
    return o == WRIT_OWNER_REVOKE_APPLIED || o == WRIT_OWNER_REVOKE_REFUSED ||
           o == WRIT_OWNER_CHANNEL_DENIED || o == WRIT_OWNER_CONTROL_UNDECODED ||
           o == WRIT_OWNER_CONTAINED;
}

static int drain_outcome(enum writ_owner_outcome o)
{
    return o == WRIT_OWNER_DRAIN_STEP || o == WRIT_OWNER_DRAIN_COMPLETE ||
           o == WRIT_OWNER_DRAIN_INCOMPLETE;
}

/* One frame out, one reply in. A transport failure, a malformed or
   out-of-sequence reply, or an outcome outside `expected` (which includes the
   interpreter-side ERROR, STOPPED and EXHAUSTED) is fail-stop. `reply` is
   filled whenever the reply was well formed. */
static int call(struct writ_supervisor *s, const char *frame, size_t length,
                struct writ_owner_reply *reply, int (*expected)(enum writ_owner_outcome))
{
    if (s->failed || s->sequence == UINT32_MAX) return fail_stop(s);
    char line[256];
    if (writ_policy_exchange(s->policy, frame, length, line) ||
        writ_owner_decode(line, s->sequence + 1, reply)) return fail_stop(s);
    ++s->sequence;
    if (reply->contain) s->contained = 1;
    if (!expected(reply->outcome)) return fail_stop(s);
    return 0;
}

#ifndef WRIT_OWNER_TESTING
static
#endif
size_t writ_owner_format_control(const struct writ_channel_record *record,
                                 struct writ_clock_sample sample,
                                 char frame[WRIT_OWNER_FRAME_CAP])
{
    static const char hex[] = "0123456789abcdef";
    if (record->length > WRIT_CHANNEL_PAYLOAD_MAX || (unsigned int)record->verdict > WRIT_SENDER_ERROR ||
        (unsigned int)sample.kind > WRIT_CLOCK_OVERFLOW) return 0;
    /* The role word and payload are only meaningful for these verdicts
       (supervisor_channel.h); otherwise they are not forwarded. */
    int accepted = record->verdict == WRIT_FROM_ROLE || record->verdict == WRIT_UNKNOWN_SENDER;
    uint32_t role = record->verdict == WRIT_FROM_ROLE ? record->role : 0;
    size_t length = accepted ? record->length : 0;
    uint32_t now = sample.kind == WRIT_CLOCK_READING ? sample.now : 0;
    int used = snprintf(frame, WRIT_OWNER_FRAME_CAP, "LINUXSUP1\tCONTROL\t%u\t%" PRIu32 "\t%u\t%" PRIu32 "\t",
                        (unsigned int)record->verdict, role, (unsigned int)sample.kind, now);
    if (used <= 0 || (size_t)used + 2 * length + 1 > WRIT_OWNER_FRAME_CAP) return 0;
    size_t at = (size_t)used;
    for (size_t i = 0; i < length; ++i) {
        frame[at++] = hex[record->payload[i] >> 4];
        frame[at++] = hex[record->payload[i] & 15];
    }
    frame[at++] = '\n';
    return at;
}

int writ_supervisor_control(struct writ_supervisor *s, const struct writ_channel_record *record,
                            struct writ_owner_reply *reply)
{
    if (s->failed) return fail_stop(s);
    char frame[WRIT_OWNER_FRAME_CAP];
    /* Sampled after the record was received, before it is forwarded. */
    size_t length = writ_owner_format_control(record, s->clock(s->clock_context), frame);
    if (!length) return fail_stop(s);
    if (call(s, frame, length, reply, control_outcome)) return -1;
    if (reply->stops) return fail_stop(s);
    return 0;
}

int writ_supervisor_serve_one(struct writ_supervisor *s, int fd, const struct writ_roles *roles,
                              struct writ_owner_reply *reply)
{
    struct writ_channel_record record;
    if (s->failed) return fail_stop(s);
    if (writ_channel_receive(fd, roles, &record)) {
        int saved = errno;
        if (saved == EAGAIN || saved == EPIPE) { errno = saved; return -1; }
        return fail_stop(s);
    }
    return writ_supervisor_control(s, &record, reply);
}

/* Signals the worker and acknowledges the stop only once its pidfd reports
   exit, within STOP_WAIT_MILLISECONDS. A worker that does not exit in time
   (for example blocked uninterruptibly) is a failed stop. The child is not
   reaped here; its owner does that. */
static int stop_worker(struct writ_supervisor *s, uint32_t worker)
{
    for (size_t i = 0; i < s->workers; ++i) {
        if (s->worker[i].worker != worker) continue;
        if (syscall(SYS_pidfd_send_signal, s->worker[i].pidfd, SIGKILL, NULL, 0) && errno != ESRCH)
            return -1;
        struct pollfd p = { .fd = s->worker[i].pidfd, .events = POLLIN };
        for (;;) {
            int ready = poll(&p, 1, STOP_WAIT_MILLISECONDS);
            if (ready < 0 && errno == EINTR) continue;
            return ready == 1 && (p.revents & POLLIN) ? 0 : -1;
        }
    }
    return -1;
}

int writ_supervisor_drain(struct writ_supervisor *s, struct writ_owner_reply *reply)
{
    static const char frame[] = "LINUXSUP1\tDRAIN\t0\t0\t0\t0\t-\n";
    if (call(s, frame, sizeof frame - 1, reply, drain_outcome)) return -1;
    for (size_t i = 0; i < reply->stops; ++i)
        if (stop_worker(s, reply->stop[i])) return fail_stop(s);
    return 0;
}
