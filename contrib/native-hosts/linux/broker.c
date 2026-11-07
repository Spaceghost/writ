#define _GNU_SOURCE
#include "broker.h"

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/pidfd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/*
 * Broker transport and kernel observations (see broker.h). Each function
 * either reports what one kernel interface returned or moves bytes; none
 * compares a credential with a launch record. The Bend monitor's
 * launch_check/session_check do that.
 */

#define CALL_MILLISECONDS 15000
#define LINE_MAX_BYTES (2u * BROKER_MAX_FRAME + 2u)

static int64_t milliseconds(void)
{
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts)) return -1;
    return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int ready(int fd, short events, int64_t deadline)
{
    struct pollfd p = { .fd = fd, .events = events };
    for (;;) {
        int64_t now = milliseconds();
        if (now < 0 || now >= deadline) return -1;
        int n = poll(&p, 1, (int)(deadline - now));
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0 || (p.revents & (POLLERR | POLLNVAL))) return -1;
        if (p.revents & events) return 0;
        if (p.revents & POLLHUP) return -1;
    }
}

int broker_monitor_start(struct broker_monitor *m, const char *node,
                         const char *harness, const char *module)
{
    memset(m, 0, sizeof *m);
    m->input = m->output = -1;
    m->pid = -1;
    /* Absolute operator-owned executable/module paths are a launch precondition. */
    if (*node != '/' || *harness != '/' || *module != '/') return -1;
    int in[2], out[2];
    if (pipe2(in, O_CLOEXEC | O_NONBLOCK)) return -1;
    if (pipe2(out, O_CLOEXEC | O_NONBLOCK)) {
        close(in[0]); close(in[1]); return -1;
    }
    posix_spawn_file_actions_t a;
    int error = posix_spawn_file_actions_init(&a);
    if (error) {
        close(in[0]); close(in[1]); close(out[0]); close(out[1]); return -1;
    }
    if (!error) error = posix_spawn_file_actions_adddup2(&a, in[0], STDIN_FILENO);
    if (!error) error = posix_spawn_file_actions_adddup2(&a, out[1], STDOUT_FILENO);
    if (!error) error = posix_spawn_file_actions_addopen(&a, STDERR_FILENO,
                                                       "/dev/null", O_WRONLY, 0);
    if (!error) error = posix_spawn_file_actions_addclosefrom_np(&a, 3);
    char *argv[] = { (char *)node, "--no-addons", "--disable-proto=throw",
        "--max-old-space-size=256", (char *)harness, (char *)module, NULL };
    char *environment[] = { "PATH=/usr/bin:/bin", "LANG=C", "LC_ALL=C", NULL };
    if (!error) error = posix_spawn(&m->pid, node, &a, NULL, argv, environment);
    posix_spawn_file_actions_destroy(&a);
    close(in[0]); close(out[1]);
    if (error) { close(in[1]); close(out[0]); m->pid = -1; return -1; }
    m->input = in[1]; m->output = out[0]; m->live = 1;
    return 0;
}

static int send_all(int fd, const char *bytes, size_t size, int64_t deadline)
{
    while (size) {
        if (ready(fd, POLLOUT, deadline)) return -1;
        ssize_t n = write(fd, bytes, size);
        if (n < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (n <= 0) return -1;
        bytes += n;
        size -= (size_t)n;
    }
    return 0;
}

static int receive_line(int fd, char line[BROKER_REPLY_MAX], int64_t deadline)
{
    size_t used = 0;
    while (used < BROKER_REPLY_MAX) {
        if (ready(fd, POLLIN, deadline)) return -1;
        ssize_t n = read(fd, line + used, BROKER_REPLY_MAX - used);
        if (n < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (n <= 0) return -1;
        size_t end = used + (size_t)n;
        for (size_t i = used; i < end; ++i) {
            unsigned char c = (unsigned char)line[i];
            if (c == '\n') {
                if (i + 1 != end) return -1;
                line[i] = 0;
                return 0;
            }
            if (c != '\t' && (c < 33 || c > 126)) return -1;
        }
        used = end;
    }
    return -1;
}

static int copy_field(char *out, size_t cap, const char *field)
{
    size_t length = strlen(field);
    if (!length || length >= cap) return -1;
    memcpy(out, field, length + 1);
    return 0;
}

/* `<sequence> TAB LINUXMON1 TAB status TAB detail TAB table`; the Bend reply
 * is copied verbatim. The broker reads the status only to report it. */
static int parse_reply(char *line, uint32_t expected, struct broker_reply *r)
{
    char *field[5];
    field[0] = line;
    for (unsigned i = 1; i < 5; ++i) {
        char *tab = strchr(field[i - 1], '\t');
        if (!tab) return -1;
        *tab = 0;
        field[i] = tab + 1;
    }
    if (strchr(field[4], '\t')) return -1;
    char *end = NULL;
    errno = 0;
    unsigned long sequence = strtoul(field[0], &end, 10);
    if (errno || !end || *end || field[0][0] == '0' || sequence != expected) return -1;
    if (strcmp(field[1], "LINUXMON1")) return -1;
    r->sequence = (uint32_t)sequence;
    return copy_field(r->status, sizeof r->status, field[2]) ||
           copy_field(r->detail, sizeof r->detail, field[3]) ||
           copy_field(r->table, sizeof r->table, field[4]);
}

void broker_hex(const uint8_t *bytes, size_t length, char *out, size_t cap)
{
    static const char digits[] = "0123456789abcdef";
    size_t j = 0;
    for (size_t i = 0; i < length && j + 2 < cap; ++i) {
        out[j++] = digits[bytes[i] >> 4];
        out[j++] = digits[bytes[i] & 15];
    }
    if (cap) out[j < cap ? j : cap - 1] = 0;
}

int broker_monitor_call(struct broker_monitor *m, const uint8_t *frame,
                        size_t length, struct broker_reply *r)
{
    if (!m->live || m->sequence == UINT32_MAX || length > BROKER_MAX_FRAME) goto broken;
    char line[LINE_MAX_BYTES];
    broker_hex(frame, length, line, sizeof line - 1);
    size_t used = strlen(line);
    line[used++] = '\n';
    int64_t now = milliseconds();
    if (now < 0) goto broken;
    int64_t deadline = now + CALL_MILLISECONDS;
    char reply[BROKER_REPLY_MAX];
    if (send_all(m->input, line, used, deadline) ||
        receive_line(m->output, reply, deadline) ||
        parse_reply(reply, m->sequence + 1, r)) goto broken;
    ++m->sequence;
    return 0;
broken:
    /* No restart or replay: the monitor may have retained the last state. */
    m->live = 0;
    if (m->pid > 0) kill(m->pid, SIGKILL);
    return -1;
}

void broker_monitor_stop(struct broker_monitor *m)
{
    m->live = 0;
    if (m->input >= 0) close(m->input);
    if (m->output >= 0) close(m->output);
    m->input = m->output = -1;
    if (m->pid > 0) {
        kill(m->pid, SIGKILL);
        while (waitpid(m->pid, NULL, 0) < 0 && errno == EINTR) {}
    }
    m->pid = -1;
}

/* --- LINUXB v1 encoders ----------------------------------------------------- */

struct words { uint32_t w[BROKER_MAX_FRAME / 4]; size_t n; int over; };

static void put(struct words *b, uint32_t v)
{
    if (b->n == sizeof b->w / sizeof b->w[0]) { b->over = 1; return; }
    b->w[b->n++] = v;
}

static void put_cred(struct words *b, const struct broker_cred *c)
{
    put(b, c->uid); put(b, c->gid); put(b, c->pid);
    put(b, (uint32_t)(c->start & 0xffffffffu)); put(b, (uint32_t)(c->start >> 32));
}

static void put_fact(struct words *b, const struct broker_fact *f)
{
    put(b, f->subject);
    for (unsigned i = 0; i < 8; ++i) put(b, f->token[i]);
    put(b, f->incarnation);
    put_cred(b, &f->launch);
    put_cred(b, &f->peer);
    put(b, f->endpoint_kind); put(b, f->endpoint_session);
    put(b, f->families); put(b, f->controls);
    if (f->route_count > BROKER_MAX_ROUTES) { b->over = 1; return; }
    put(b, f->route_count);
    for (uint32_t i = 0; i < f->route_count; ++i) {
        put(b, f->routes[i].descriptor); put(b, f->routes[i].kind);
        put(b, f->routes[i].mediated);
    }
}

static void put_request(struct words *b, const uint8_t *request, size_t length)
{
    if (length > BROKER_MAX_REQUEST) { b->over = 1; return; }
    put(b, (uint32_t)length);
    for (size_t i = 0; i < length; ++i) put(b, request[i]);
}

static size_t finish(struct words *b, uint32_t tag, uint8_t *out, size_t cap)
{
    if (b->over || b->n < 3) return 0;
    b->w[0] = 1; b->w[1] = tag; b->w[2] = (uint32_t)(b->n - 3);
    size_t length = b->n * 4;
    if (length > cap || length > BROKER_MAX_FRAME) return 0;
    for (size_t i = 0; i < b->n; ++i) {
        out[4 * i] = (uint8_t)(b->w[i] & 255);
        out[4 * i + 1] = (uint8_t)((b->w[i] >> 8) & 255);
        out[4 * i + 2] = (uint8_t)((b->w[i] >> 16) & 255);
        out[4 * i + 3] = (uint8_t)(b->w[i] >> 24);
    }
    return length;
}

size_t broker_encode_launch(const struct broker_fact *f, uint8_t *out, size_t cap)
{
    struct words b = { .n = 3 };
    put_fact(&b, f);
    return finish(&b, BROKER_LAUNCH, out, cap);
}

size_t broker_encode_barrier(uint32_t session, const struct broker_fact *f,
                             const uint8_t *request, size_t request_length,
                             uint8_t *out, size_t cap)
{
    struct words b = { .n = 3 };
    put(&b, session);
    put_fact(&b, f);
    put_request(&b, request, request_length);
    return finish(&b, BROKER_BARRIER, out, cap);
}

size_t broker_encode_worker(uint32_t session, const uint8_t *request,
                            size_t request_length, uint8_t *out, size_t cap)
{
    struct words b = { .n = 3 };
    put(&b, session);
    put_request(&b, request, request_length);
    return finish(&b, BROKER_WORKER, out, cap);
}

/* --- Kernel observations ---------------------------------------------------- */

/* Field 22 (starttime) of /proc/PID/stat, parsed after the last ')' so a
 * command name cannot shift fields. Reads the procfs mounted at /proc, which
 * must belong to the broker's PID namespace. */
int broker_start_time(pid_t pid, uint64_t *start)
{
    char path[64], buffer[1024];
    snprintf(path, sizeof path, "/proc/%d/stat", (int)pid);
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t n = read(fd, buffer, sizeof buffer - 1);
    close(fd);
    if (n <= 0) return -1;
    buffer[n] = 0;
    char *p = strrchr(buffer, ')');
    if (!p) return -1;
    p += 2; /* field 3 */
    for (int field = 3; field < 22; ++field) {
        p = strchr(p, ' ');
        if (!p) return -1;
        ++p;
    }
    char *end = NULL;
    errno = 0;
    unsigned long long value = strtoull(p, &end, 10);
    if (errno || end == p || (*end != ' ' && *end != '\n' && *end)) return -1;
    *start = value;
    return 0;
}

/*
 * The start time of the process a pidfd names, read race-free: the pidfd's
 * pid (PIDFD_GET_INFO) must be `expected_pid`, /proc/PID/stat is read, and
 * the pidfd must still name a live (or unreaped) process afterwards, so the
 * pid was not reassigned during the read. On any failure `start` is 0
 * (unverified) and -1 is returned.
 */
int broker_observe_pidfd(int pidfd, uint32_t expected_pid, uint64_t *start)
{
    *start = 0;
    struct pidfd_info info;
    memset(&info, 0, sizeof info);
    info.mask = PIDFD_INFO_PID;
    if (ioctl(pidfd, PIDFD_GET_INFO, &info) < 0) return -1;
    if (!(info.mask & PIDFD_INFO_PID) || info.tgid != expected_pid) return -1;
    uint64_t value;
    if (broker_start_time((pid_t)expected_pid, &value)) return -1;
    if (pidfd_send_signal(pidfd, 0, NULL, 0) < 0) return -1;
    *start = value;
    return 0;
}

int broker_set_passcred(int fd)
{
    int one = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_PASSCRED, &one, sizeof one)) return -1;
    if (setsockopt(fd, SOL_SOCKET, SO_PASSPIDFD, &one, sizeof one)) return -1;
    return 0;
}

/* A bounded SOCK_SEQPACKET listener at `path` (inside a private 0700
 * directory the caller owns). Per-message credentials are requested on the
 * listener so every accepted socket carries them from its first message. */
int broker_listen(const char *path)
{
    struct sockaddr_un address = { .sun_family = AF_UNIX };
    if (strlen(path) >= sizeof address.sun_path) return -1;
    strcpy(address.sun_path, path);
    int fd = socket(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0);
    if (fd < 0) return -1;
    if (broker_set_passcred(fd) ||
        bind(fd, (struct sockaddr *)&address, sizeof address) ||
        listen(fd, 4)) {
        close(fd);
        return -1;
    }
    return fd;
}

/* The connection-time peer: SO_PEERCRED uid/gid/pid and, through
 * SO_PEERPIDFD, its start time. */
int broker_peer(int fd, struct broker_cred *peer)
{
    memset(peer, 0, sizeof *peer);
    struct ucred cred;
    socklen_t length = sizeof cred;
    if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &cred, &length) || length != sizeof cred)
        return -1;
    peer->uid = cred.uid;
    peer->gid = cred.gid;
    peer->pid = cred.pid > 0 ? (uint32_t)cred.pid : 0;
    int pidfd = -1;
    length = sizeof pidfd;
    if (getsockopt(fd, SOL_SOCKET, SO_PEERPIDFD, &pidfd, &length) || pidfd < 0)
        return 0; /* start stays 0: unverified */
    if (broker_observe_pidfd(pidfd, peer->pid, &peer->start)) peer->start = 0;
    close(pidfd);
    return 0;
}

int broker_accept(int listener, struct broker_cred *peer)
{
    int fd = accept4(listener, NULL, NULL, SOCK_CLOEXEC);
    if (fd < 0) return -1;
    if (broker_set_passcred(fd) || broker_peer(fd, peer)) {
        close(fd);
        return -1;
    }
    return fd;
}

/*
 * Receive one worker message: a bounded snapshot of its bytes, the
 * kernel-attached sender (SCM_CREDENTIALS uid/gid/pid, start time through
 * SCM_PIDFD), and any SCM_RIGHTS descriptors, which are closed at once and
 * never installed in a table: a transferred descriptor is not authority, and
 * no admitted step asks the broker to keep one.
 */
int broker_receive(int fd, struct broker_message *m)
{
    memset(m, 0, sizeof *m);
    union {
        char buffer[CMSG_SPACE(sizeof(struct ucred)) + CMSG_SPACE(sizeof(int)) +
                    CMSG_SPACE(sizeof(int) * BROKER_MAX_DROPPED)];
        struct cmsghdr align;
    } control;
    memset(&control, 0, sizeof control);
    struct iovec io = { .iov_base = m->bytes, .iov_len = sizeof m->bytes };
    struct msghdr h = { .msg_iov = &io, .msg_iovlen = 1,
                        .msg_control = control.buffer, .msg_controllen = sizeof control.buffer };
    ssize_t n;
    do n = recvmsg(fd, &h, MSG_CMSG_CLOEXEC); while (n < 0 && errno == EINTR);
    if (n < 0) return -1;
    if (n == 0 && !(h.msg_flags & MSG_TRUNC)) {
        /* A zero-length SEQPACKET read with no control data is end of stream. */
        if (!h.msg_controllen) return 1;
    }
    m->length = (size_t)n;
    m->truncated = (h.msg_flags & MSG_TRUNC) != 0;
    m->ctrunc = (h.msg_flags & MSG_CTRUNC) != 0;
    int pidfd = -1;
    int dropped[BROKER_MAX_DROPPED];
    for (struct cmsghdr *c = CMSG_FIRSTHDR(&h); c; c = CMSG_NXTHDR(&h, c)) {
        if (c->cmsg_level != SOL_SOCKET) continue;
        if (c->cmsg_type == SCM_CREDENTIALS && c->cmsg_len == CMSG_LEN(sizeof(struct ucred))) {
            struct ucred cred;
            memcpy(&cred, CMSG_DATA(c), sizeof cred);
            m->have_sender = 1;
            m->sender.uid = cred.uid;
            m->sender.gid = cred.gid;
            m->sender.pid = cred.pid > 0 ? (uint32_t)cred.pid : 0;
        } else if (c->cmsg_type == SCM_PIDFD && c->cmsg_len == CMSG_LEN(sizeof(int))) {
            memcpy(&pidfd, CMSG_DATA(c), sizeof pidfd);
        } else if (c->cmsg_type == SCM_RIGHTS) {
            size_t count = (c->cmsg_len - CMSG_LEN(0)) / sizeof(int);
            for (size_t i = 0; i < count; ++i) {
                int received;
                memcpy(&received, CMSG_DATA(c) + i * sizeof(int), sizeof received);
                if (m->dropped < BROKER_MAX_DROPPED) dropped[m->dropped] = received;
                close(received);
                m->dropped++;
            }
        }
    }
    m->dropped_closed = 1;
    for (unsigned i = 0; i < m->dropped && i < BROKER_MAX_DROPPED; ++i)
        if (fcntl(dropped[i], F_GETFD) != -1 || errno != EBADF) m->dropped_closed = 0;
    if (pidfd >= 0) {
        if (m->have_sender && broker_observe_pidfd(pidfd, m->sender.pid, &m->sender.start))
            m->sender.start = 0;
        close(pidfd);
    }
    return 0;
}
