/* See supervisor_channel.h. Translates kernel facts only; policy, grants and
   principal naming stay in Bend (hosts/linux/monitor/LocalChannel.bend). */
#define _GNU_SOURCE
#include "supervisor_channel.h"

#include <errno.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/vfs.h>
#include <unistd.h>

#ifndef SO_PASSPIDFD
#define SO_PASSPIDFD 76
#endif
#ifndef SCM_PIDFD
#define SCM_PIDFD 0x04
#endif
#ifndef PID_FS_MAGIC
#define PID_FS_MAGIC 0x50494446
#endif

_Static_assert(sizeof(ino_t) == 8, "pidfs inode identity needs a 64-bit ino_t");

#define CONTROL_FDS 4 /* receive buffer room; parsing never clamps to it */

union control_buffer {
    char buf[CMSG_SPACE(sizeof(int) * CONTROL_FDS) * 2];
    struct cmsghdr align;
};

/* pidfs identity of a descriptor. 0 on success, ENOTSUP when it is not a
   pidfs file, else errno from fstatfs/fstat. */
static int pidfs_identity(int fd, dev_t *dev, ino_t *ino)
{
    struct statfs fs;
    struct stat st;
    if (fstatfs(fd, &fs)) return errno;
    if ((unsigned long)fs.f_type != PID_FS_MAGIC) return ENOTSUP;
    if (fstat(fd, &st)) return errno;
    *dev = st.st_dev;
    *ino = st.st_ino;
    return 0;
}

int writ_channel_enable(int fd)
{
    int on = 1;
    return setsockopt(fd, SOL_SOCKET, SO_PASSPIDFD, &on, sizeof on);
}

int writ_roles_add(struct writ_roles *roles, uint32_t index, int pidfd)
{
    dev_t dev;
    ino_t ino;
    if (index == 0) return EINVAL;
    if (pidfs_identity(pidfd, &dev, &ino)) return EINVAL;
    for (size_t i = 0; i < roles->count; ++i) {
        if (roles->role[i].index == index) return EINVAL;
        if (roles->role[i].dev == dev && roles->role[i].ino == ino) return EINVAL;
    }
    if (roles->count >= WRIT_CHANNEL_ROLES) return ENOSPC;
    roles->role[roles->count].index = index;
    roles->role[roles->count].dev = dev;
    roles->role[roles->count].ino = ino;
    ++roles->count;
    return 0;
}

static int receive_impl(int fd, const struct writ_roles *roles,
                        struct writ_channel_record *out, size_t control_len)
{
    union control_buffer control;
    memset(&control, 0, sizeof control);
    memset(out, 0, sizeof *out);
    out->verdict = WRIT_UNKNOWN_SENDER;
    if (control_len > sizeof control.buf) control_len = sizeof control.buf;

    struct iovec iov = { .iov_base = out->payload, .iov_len = sizeof out->payload };
    struct msghdr msg = { .msg_iov = &iov, .msg_iovlen = 1,
                          .msg_control = control_len ? control.buf : NULL,
                          .msg_controllen = control_len };
    ssize_t got = recvmsg(fd, &msg, MSG_CMSG_CLOEXEC | MSG_DONTWAIT);
    if (got < 0) return -1;
    out->length = (size_t)got < sizeof out->payload ? (size_t)got : sizeof out->payload;

    int pidfd = -1;
    int pidfds = 0, rights = 0, other = 0, negative = 0, short_control = 0;
    const unsigned char *control_end = (const unsigned char *)control.buf + msg.msg_controllen;
    for (struct cmsghdr *c = CMSG_FIRSTHDR(&msg); c; c = CMSG_NXTHDR(&msg, c)) {
        if (c->cmsg_level != SOL_SOCKET || c->cmsg_len < CMSG_LEN(0)) { ++other; continue; }
        /* Read only bytes the kernel actually returned: a header claiming
           more than msg_controllen is control truncation, and every
           descriptor within the returned bytes is still closed. */
        const unsigned char *data = CMSG_DATA(c);
        size_t claimed = c->cmsg_len - CMSG_LEN(0);
        size_t available = data <= control_end ? (size_t)(control_end - data) : 0;
        if (claimed > available) { ++short_control; claimed = available; }
        size_t n = claimed / sizeof(int);
        for (size_t i = 0; i < n; ++i) {
            int value;
            memcpy(&value, data + i * sizeof(int), sizeof(int));
            if (c->cmsg_type == SCM_PIDFD) {
                ++pidfds;
                if (value < 0) { ++negative; continue; }
                if (pidfd < 0) pidfd = value; else close(value);
            } else if (c->cmsg_type == SCM_RIGHTS) {
                ++rights;
                if (value >= 0) close(value);
            }
        }
        if (c->cmsg_type != SCM_PIDFD && c->cmsg_type != SCM_RIGHTS) ++other;
    }

    enum writ_channel_verdict verdict = WRIT_UNKNOWN_SENDER;
    if ((msg.msg_flags & MSG_CTRUNC) || short_control) verdict = WRIT_CONTROL_TRUNCATED;
    else if (msg.msg_flags & MSG_TRUNC) verdict = WRIT_PAYLOAD_TRUNCATED;
    else if (rights) verdict = WRIT_UNEXPECTED_RIGHTS;
    else if (other) verdict = WRIT_UNEXPECTED_CONTROL;
    else if (negative) verdict = WRIT_SENDER_ERROR;
    else if (pidfds > 1) verdict = WRIT_DUPLICATE_SENDER;
    else if (pidfds == 0) verdict = WRIT_MISSING_SENDER;
    else {
        dev_t dev;
        ino_t ino;
        if (pidfs_identity(pidfd, &dev, &ino)) {
            verdict = WRIT_SENDER_ERROR;
        } else {
            for (size_t i = 0; i < roles->count; ++i) {
                if (roles->role[i].dev == dev && roles->role[i].ino == ino) {
                    verdict = WRIT_FROM_ROLE;
                    out->role = roles->role[i].index;
                    break;
                }
            }
        }
    }
    if (pidfd >= 0) close(pidfd);

    if (verdict != WRIT_FROM_ROLE && verdict != WRIT_UNKNOWN_SENDER) {
        out->length = 0;
        memset(out->payload, 0, sizeof out->payload);
    }
    out->verdict = verdict;
    return 0;
}

int writ_channel_receive(int fd, const struct writ_roles *roles, struct writ_channel_record *out)
{
    return receive_impl(fd, roles, out, sizeof(union control_buffer));
}

#ifdef WRIT_CHANNEL_TESTING
int writ_channel_receive_with_control(int fd, const struct writ_roles *roles,
                                      struct writ_channel_record *out, size_t control_len)
{
    return receive_impl(fd, roles, out, control_len);
}
#endif

int writ_channel_profile_check(void)
{
    int pair[2];
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, pair)) return errno;
    int result = 0;
    if (writ_channel_enable(pair[0])) result = errno == ENOPROTOOPT ? ENOTSUP : errno;
    close(pair[0]);
    close(pair[1]);
    if (result) return result;

    long self = syscall(SYS_pidfd_open, getpid(), 0);
    if (self < 0) return errno == ENOSYS ? ENOTSUP : errno;
    dev_t dev;
    ino_t ino;
    result = pidfs_identity((int)self, &dev, &ino);
    close((int)self);
    return result;
}
