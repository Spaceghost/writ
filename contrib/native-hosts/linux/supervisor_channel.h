/* Native receiver for the local supervisor channel (Linux, AF_UNIX
   SOCK_SEQPACKET). The Bend side is hosts/linux/monitor/LocalChannel.bend.

   This module translates kernel facts and nothing else: it receives one
   bounded record, reads the sender from the per-message SCM_PIDFD, compares
   that pidfd's pidfs device/inode with a supervisor-provisioned role table,
   and classifies the record. It does not authorize, grant, name a principal,
   decode the payload or decide anything; an unknown or malformed observation
   is reported as such and the Bend policy denies it. A role index is a
   supervisor label for a process lifetime, not a credential. Identity is
   pidfs dev/ino, never a numeric PID, and never descriptor numbers.

   The verdicts from WRIT_MISSING_SENDER onward correspond 1:1, in order, to
   the constructors of `ChannelReject` in LocalChannel.bend. */
#ifndef WRIT_SUPERVISOR_CHANNEL_H
#define WRIT_SUPERVISOR_CHANNEL_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#define WRIT_CHANNEL_PAYLOAD_MAX 4096
#define WRIT_CHANNEL_ROLES 8

enum writ_channel_verdict {
    WRIT_FROM_ROLE,           /* FromRole{role}: sender lifetime matches a role */
    WRIT_UNKNOWN_SENDER,      /* UnknownSender: a valid pidfd matching no role */
    WRIT_MISSING_SENDER,      /* ChannelReject.MissingSender */
    WRIT_DUPLICATE_SENDER,    /* DuplicateSender */
    WRIT_PAYLOAD_TRUNCATED,   /* PayloadTruncated */
    WRIT_CONTROL_TRUNCATED,   /* ControlTruncated */
    WRIT_UNEXPECTED_RIGHTS,   /* UnexpectedRights */
    WRIT_UNEXPECTED_CONTROL,  /* UnexpectedControl */
    WRIT_SENDER_ERROR         /* SenderError: kernel error or non-pidfs sender */
};

/* The table retains pidfs identity, not descriptor numbers. The caller keeps
   its own pidfds open for each role's lifetime so the identity cannot be
   recycled; this module never stores or closes them. */
struct writ_roles {
    size_t count;
    struct {
        uint32_t index; /* nonzero, unique */
        dev_t dev;
        ino_t ino;
    } role[WRIT_CHANNEL_ROLES];
};

struct writ_channel_record {
    enum writ_channel_verdict verdict;
    uint32_t role;  /* meaningful only for WRIT_FROM_ROLE */
    size_t length;  /* payload bytes; meaningful only for the two accepted verdicts */
    unsigned char payload[WRIT_CHANNEL_PAYLOAD_MAX];
};

/* Returns 0, or an errno (ENOTSUP when pidfs or SO_PASSPIDFD is unavailable).
   Probes on a private socket pair and on pidfd_open(getpid()). */
int writ_channel_profile_check(void);

/* Returns 0 on success. EINVAL: index 0, duplicate index, a pidfd whose
   lifetime is already registered, or a non-pidfs descriptor. ENOSPC: table
   full. On any error the table is unchanged. */
int writ_roles_add(struct writ_roles *roles, uint32_t index, int pidfd);

/* Sets SO_PASSPIDFD on the receiving end. Call before any record is queued. */
int writ_channel_enable(int fd);

/* Receives one record without blocking (MSG_DONTWAIT). Returns 0 when one
   record was consumed, whatever its verdict, or -1 with errno on a syscall
   failure (EAGAIN when nothing is queued). Every descriptor installed by the
   kernel is closed before return; no descriptor reaches the caller. */
int writ_channel_receive(int fd, const struct writ_roles *roles,
                         struct writ_channel_record *out);

#ifdef WRIT_CHANNEL_TESTING
/* Test seam: as writ_channel_receive with a caller-chosen control buffer size
   (clamped to the internal buffer). Not part of the public interface. */
int writ_channel_receive_with_control(int fd, const struct writ_roles *roles,
                                      struct writ_channel_record *out,
                                      size_t control_len);
#endif

#endif
