#define _GNU_SOURCE
#include "policy_pipe.h"

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define FRAME_MAX 131200u
#define REPLY_MAX 256u
#define CALL_MILLISECONDS 15000

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

static int send_frame(int fd, const char *frame, size_t size, int64_t deadline)
{
    while (size) {
        if (ready(fd, POLLOUT, deadline)) return -1;
        ssize_t n = write(fd, frame, size);
        if (n < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (n <= 0) return -1;
        frame += n;
        size -= (size_t)n;
    }
    return 0;
}

static int receive_line(int fd, char line[REPLY_MAX], int64_t deadline)
{
    size_t used = 0;
    while (used < REPLY_MAX) {
        if (ready(fd, POLLIN, deadline)) return -1;
        ssize_t n = read(fd, line + used, REPLY_MAX - used);
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
            if (c != '\t' && (c < 32 || c > 126)) return -1;
        }
        used = end;
    }
    return -1;
}

static int canonical_u32(const char *s, uint32_t *result)
{
    if (!*s || (*s == '0' && s[1])) return -1;
    uint32_t n = 0;
    for (; *s; ++s) {
        unsigned int d = (unsigned char)*s - '0';
        if (d > 9 || n > (UINT32_MAX - d) / 10) return -1;
        n = n * 10 + d;
    }
    *result = n;
    return 0;
}

static int decode(char *line, uint32_t expected, struct writ_reply *reply)
{
    char *field[5];
    field[0] = line;
    for (unsigned int i = 1; i < 5; ++i) {
        char *tab = strchr(field[i - 1], '\t');
        if (!tab) return -1;
        *tab = 0;
        field[i] = tab + 1;
    }
    uint32_t sequence;
    if (strchr(field[4], '\t') || strcmp(field[0], "WRITFS1") ||
        canonical_u32(field[1], &sequence) || sequence != expected ||
        canonical_u32(field[3], &reply->value)) return -1;
    if (!strcmp(field[2], "OK")) reply->status = WRIT_OK;
    else if (!strcmp(field[2], "DENY")) reply->status = WRIT_DENY;
    else if (!strcmp(field[2], "ERROR")) reply->status = WRIT_ERROR;
    else return -1;
    size_t length = strlen(field[4]);
    if (!length || length >= sizeof reply->detail) return -1;
    for (size_t i = 0; i < length; ++i) {
        unsigned char c = (unsigned char)field[4][i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '-' || c == '_')) return -1;
    }
    memcpy(reply->detail, field[4], length + 1);
    return 0;
}

int writ_policy_start(struct writ_policy *p, const char *node,
                      const char *bridge, const char *module)
{
    memset(p, 0, sizeof *p);
    p->input = p->output = -1;
    p->pid = -1;
    if (pthread_mutex_init(&p->lock, NULL)) return -1;
    /* Absolute operator-owned executable/module paths are a launch precondition. */
    if (*node != '/' || *bridge != '/' || *module != '/') return -1;
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
        "--max-old-space-size=256", (char *)bridge, (char *)module, NULL };
    char *environment[] = { "PATH=/usr/bin:/bin", "LANG=C", "LC_ALL=C", NULL };
    if (!error) error = posix_spawn(&p->pid, node, &a, NULL, argv, environment);
    posix_spawn_file_actions_destroy(&a);
    close(in[0]); close(out[1]);
    if (error) { close(in[1]); close(out[0]); p->pid = -1; return -1; }
    p->input = in[1]; p->output = out[0]; p->live = 1;
    return 0;
}

int writ_policy_call(struct writ_policy *p, const char *op,
                     uint32_t actor, uint32_t handle, uint32_t offset,
                     uint32_t count, const char *argument, struct writ_reply *r)
{
    if (pthread_mutex_lock(&p->lock)) return -1;
    int result = -1;
    if (!p->live || p->sequence == UINT32_MAX) goto done;
    size_t argument_length = strnlen(argument, FRAME_MAX + 1);
    if (argument_length > FRAME_MAX || strlen(op) > 16 ||
        strpbrk(op, "\t\r\n") || strpbrk(argument, "\t\r\n")) goto broken;
    char *frame = malloc(FRAME_MAX + 2);
    if (!frame) goto broken;
    int length = snprintf(frame, FRAME_MAX + 2,
        "WRITFS1\t%s\t%" PRIu32 "\t%" PRIu32 "\t%" PRIu32 "\t%" PRIu32 "\t%s\n",
        op, actor, handle, offset, count, argument);
    int64_t now = milliseconds();
    if (length <= 0 || (unsigned int)length > FRAME_MAX + 1 || now < 0) {
        free(frame); goto broken;
    }
    int64_t deadline = now + CALL_MILLISECONDS;
    int sent = send_frame(p->input, frame, (size_t)length, deadline);
    free(frame);
    char line[REPLY_MAX];
    if (sent || receive_line(p->output, line, deadline) ||
        decode(line, p->sequence + 1, r)) goto broken;
    ++p->sequence;
    result = 0;
    goto done;
broken:
    /* No restart or replay: the interpreter may have accepted the last effect. */
    p->live = 0;
    if (p->pid > 0) kill(p->pid, SIGKILL);
done:
    pthread_mutex_unlock(&p->lock);
    return result;
}

int writ_policy_exchange(struct writ_policy *p, const char *frame, size_t length,
                         char line[REPLY_MAX])
{
    if (pthread_mutex_lock(&p->lock)) return -1;
    int result = -1;
    if (!p->live) goto done;
    if (!length || length > FRAME_MAX + 1 || frame[length - 1] != '\n' ||
        memchr(frame, '\n', length - 1)) goto broken;
    int64_t now = milliseconds();
    if (now < 0) goto broken;
    int64_t deadline = now + CALL_MILLISECONDS;
    if (send_frame(p->input, frame, length, deadline) ||
        receive_line(p->output, line, deadline)) goto broken;
    result = 0;
    goto done;
broken:
    /* No restart or replay: the interpreter may have accepted the last frame. */
    p->live = 0;
    if (p->pid > 0) kill(p->pid, SIGKILL);
done:
    pthread_mutex_unlock(&p->lock);
    return result;
}

void writ_policy_abandon(struct writ_policy *p)
{
    if (pthread_mutex_lock(&p->lock)) return;
    p->live = 0;
    if (p->pid > 0) kill(p->pid, SIGKILL);
    pthread_mutex_unlock(&p->lock);
}

void writ_policy_stop(struct writ_policy *p)
{
    pthread_mutex_lock(&p->lock);
    p->live = 0;
    if (p->input >= 0) close(p->input);
    if (p->output >= 0) close(p->output);
    p->input = p->output = -1;
    if (p->pid > 0) {
        kill(p->pid, SIGKILL);
        while (waitpid(p->pid, NULL, 0) < 0 && errno == EINTR) {}
    }
    p->pid = -1;
    pthread_mutex_unlock(&p->lock);
    pthread_mutex_destroy(&p->lock);
}
