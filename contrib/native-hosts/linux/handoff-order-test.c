/* Nonprivileged callback interleaving test. This includes the actual canary
   callbacks and supervisor helpers; only FUSE, policy and OS boundary calls
   are replaced. It neither mounts FUSE nor observes native process identity. */
#define _GNU_SOURCE
#define FUSE_USE_VERSION 35
#include <fuse_lowlevel.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <sys/wait.h>
#include <unistd.h>

void *fake_req_userdata(fuse_req_t);
const struct fuse_ctx *fake_req_ctx(fuse_req_t);
int fake_reply_err(fuse_req_t, int);
int fake_reply_buf(fuse_req_t, const char *, size_t);
int fake_reply_entry(fuse_req_t, const struct fuse_entry_param *);
int fake_reply_attr(fuse_req_t, const struct stat *, double);
int fake_reply_open(fuse_req_t, const struct fuse_file_info *);
size_t fake_add_direntry(fuse_req_t, char *, size_t, const char *, const struct stat *, off_t);
int fake_fcntl(int, int, ...);
ssize_t fake_pread(int, void *, size_t, off_t);
int fake_kill(pid_t, int);
int fake_mutex_lock(pthread_mutex_t *);
int fake_mutex_clocklock(pthread_mutex_t *, clockid_t, const struct timespec *);
int fake_mutex_unlock(pthread_mutex_t *);
int fake_thread_join(pthread_t, void **);
void fake_session_exit(struct fuse_session *);
void fake_session_unmount(struct fuse_session *);
void fake_remove_signal_handlers(struct fuse_session *);
void fake_session_destroy(struct fuse_session *);

#define pthread_mutex_lock fake_mutex_lock
#define pthread_mutex_clocklock fake_mutex_clocklock
#define pthread_mutex_unlock fake_mutex_unlock
#define pthread_join fake_thread_join
#define fuse_session_exit fake_session_exit
#define fuse_session_unmount fake_session_unmount
#define fuse_remove_signal_handlers fake_remove_signal_handlers
#define fuse_session_destroy fake_session_destroy
#define writ_retire_child fake_retire_child
#define main canary_program_main
#define fuse_req_userdata fake_req_userdata
#define fuse_req_ctx fake_req_ctx
#define fuse_reply_err fake_reply_err
#define fuse_reply_buf fake_reply_buf
#define fuse_reply_entry fake_reply_entry
#define fuse_reply_attr fake_reply_attr
#define fuse_reply_open fake_reply_open
#define fuse_add_direntry fake_add_direntry
#define writ_policy_call fake_policy_call
#define writ_process_alive fake_process_alive
#define fcntl fake_fcntl
#define pread fake_pread
#define kill fake_kill
/* Shorter than production so timeout scenarios stay quick; the brief-hold
   test below still holds for only a tenth of this bound. */
#define WRIT_CLEANUP_LOCK_WAIT_MS 200
#include "writfs.c"
#undef pthread_mutex_lock
#undef pthread_mutex_clocklock
#undef pthread_mutex_unlock
#undef pthread_join
#undef fuse_session_exit
#undef fuse_session_unmount
#undef fuse_remove_signal_handlers
#undef fuse_session_destroy
#undef writ_retire_child
#undef main
#undef fuse_req_userdata
#undef fuse_req_ctx
#undef fuse_reply_err
#undef fuse_reply_buf
#undef fuse_reply_entry
#undef fuse_reply_attr
#undef fuse_reply_open
#undef fuse_add_direntry
#undef writ_policy_call
#undef writ_process_alive
#undef fcntl
#undef pread
#undef kill

#define CHECK(expr) do { if (!(expr)) { \
    fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #expr); exit(1); \
} } while (0)

struct fake_request { struct host *host; struct fuse_ctx context; };
enum event { E_READ, E_REPLY, E_REVOKE, E_KILL, E_DENY, E_CLOSE, E_OPEN, E_OPEN_REPLY };
static struct {
    pthread_mutex_t lock;
    pthread_cond_t changed;
    enum event events[64];
    size_t count;
    int revoked, broken, kill_error, cancel_open, pause_read, paused, proceed, attempted, completed;
    int last_error, seals_error, mutex_error, revoke_deny;
    int lock_error, forbid_lock, unlock_error, join_error, join_real, join_started, joined;
    int pause_actor, actor_paused, actor_continue, actor_calls;
    int lock_contended, reader_actor_while_waiting;
    int pause_retire, retire_paused, retire_continue, reader_retires, other_retires;
    int exit_calls, unmount_calls, destroy_calls, forbidden_cleanup, forbidden_early_retire;
    int forbidden_session_calls;
    int reader_retire_error, other_retire_error;
    pid_t retired_pid;
    int retired_pidfd, retired_command, retired_result, reused_fd, reused_fd_lookups;
    uint64_t retired_start;
    struct host *host;
} mock = { .lock = PTHREAD_MUTEX_INITIALIZER, .changed = PTHREAD_COND_INITIALIZER };

/* Observe the real production lock attempt before a paused read proceeds.
   Calls outside this included production unit use the real pthread function. */
static _Thread_local int is_control_thread;
int fake_mutex_lock(pthread_mutex_t *lock)
{
    if (mock.host && lock == &mock.host->effect_lock && mock.mutex_error) return EINVAL;
    if (is_control_thread && mock.host && lock == &mock.host->effect_lock) {
        CHECK(!pthread_mutex_lock(&mock.lock));
        mock.attempted = 1;
        CHECK(!pthread_cond_broadcast(&mock.changed));
        CHECK(!pthread_mutex_unlock(&mock.lock));
    }
    return pthread_mutex_lock(lock);
}

int fake_mutex_clocklock(pthread_mutex_t *lock, clockid_t clock, const struct timespec *deadline)
{
    if (mock.host && lock == &mock.host->effect_lock) CHECK(clock == CLOCK_MONOTONIC && deadline);
    if (mock.host && lock == &mock.host->effect_lock && mock.forbid_lock) _Exit(80);
    if (mock.host && lock == &mock.host->effect_lock && mock.lock_error == EOWNERDEAD) {
        CHECK(!pthread_mutex_trylock(lock));
        return EOWNERDEAD; /* Model an error that also acquired ownership. */
    }
    if (mock.host && lock == &mock.host->effect_lock && mock.lock_error) return mock.lock_error;
    if (mock.host && lock == &mock.host->effect_lock) {
        /* The deadline must be about now + WRIT_CLEANUP_LOCK_WAIT_MS. */
        struct timespec now;
        CHECK(!clock_gettime(CLOCK_MONOTONIC, &now));
        long long ms = (long long)(deadline->tv_sec - now.tv_sec) * 1000 +
                       (deadline->tv_nsec - now.tv_nsec) / 1000000;
        CHECK(ms > WRIT_CLEANUP_LOCK_WAIT_MS - 50 && ms <= WRIT_CLEANUP_LOCK_WAIT_MS);
        int first = pthread_mutex_trylock(lock);
        if (!first) return 0;
        CHECK(first == EBUSY);
        ++mock.lock_contended;
        /* While cleanup waits, the reader's own request must not map to it.
           Skipped when the liveness mock is deliberately paused. */
        if (!mock.pause_actor) {
        struct fuse_ctx reader_ctx = { .uid = mock.host->uid, .gid = mock.host->gid,
                                       .pid = mock.host->reader.pid };
        mock.reader_actor_while_waiting = (int)actor(mock.host, &reader_ctx);
        }
    }
    return pthread_mutex_clocklock(lock, clock, deadline);
}

int fake_mutex_unlock(pthread_mutex_t *lock)
{
    if (mock.host && lock == &mock.host->effect_lock && mock.unlock_error) return EPERM;
    return pthread_mutex_unlock(lock);
}

int fake_thread_join(pthread_t thread, void **out)
{
    CHECK(!pthread_mutex_lock(&mock.lock));
    mock.join_started = 1;
    CHECK(!pthread_cond_broadcast(&mock.changed));
    int failure = mock.join_error, real = mock.join_real;
    CHECK(!pthread_mutex_unlock(&mock.lock));
    if (failure) return EINVAL;
    int result = real ? pthread_join(thread, out) : 0;
    CHECK(!pthread_mutex_lock(&mock.lock));
    mock.joined = !result;
    CHECK(!pthread_mutex_unlock(&mock.lock));
    return result;
}

void fake_session_exit(struct fuse_session *session)
{
    (void)session;
    if (mock.forbidden_session_calls) _Exit(77);
    mock.exit_calls++;
}
void fake_session_unmount(struct fuse_session *session)
{ (void)session; mock.unmount_calls++; }
void fake_remove_signal_handlers(struct fuse_session *session)
{ (void)session; }
void fake_session_destroy(struct fuse_session *session)
{
    (void)session;
    if (mock.forbidden_cleanup && !mock.joined) _Exit(78);
    mock.destroy_calls++;
}

int fake_retire_child(struct writ_child *child)
{
    if (child->pid <= 0) return 0;
    CHECK(!pthread_mutex_lock(&mock.lock));
    if (mock.forbidden_early_retire && !mock.joined) _Exit(79);
    int failure = child->pid == 42 ? mock.reader_retire_error : mock.other_retire_error;
    if (child->pid == 42) {
        mock.reader_retires++;
        mock.retired_pid = child->pid;
        mock.retired_pidfd = child->pidfd;
        mock.retired_command = child->command;
        mock.retired_result = child->result;
        mock.retired_start = child->start_time;
        if (mock.pause_retire) {
            mock.retire_paused = 1;
            CHECK(!pthread_cond_broadcast(&mock.changed));
            while (!mock.retire_continue) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
        }
    } else {
        mock.other_retires++;
    }
    CHECK(!pthread_mutex_unlock(&mock.lock));
    child->pid = -1; child->pidfd = -1; child->command = -1; child->result = -1;
    return failure;
}

static void assert_effect_locked(void)
{ CHECK(pthread_mutex_trylock(&mock.host->effect_lock) == EBUSY); }

static void add_event(enum event event)
{
    CHECK(mock.count < sizeof mock.events / sizeof mock.events[0]);
    mock.events[mock.count++] = event;
}

void *fake_req_userdata(fuse_req_t req)
{ return ((struct fake_request *)req)->host; }

const struct fuse_ctx *fake_req_ctx(fuse_req_t req)
{ return &((struct fake_request *)req)->context; }

int fake_process_alive(const struct writ_child *child)
{
    CHECK(!pthread_mutex_lock(&mock.lock));
    mock.actor_calls++;
    if (child->pidfd == mock.reused_fd) mock.reused_fd_lookups++;
    if (mock.pause_actor) {
        mock.actor_paused = 1;
        CHECK(!pthread_cond_broadcast(&mock.changed));
        while (!mock.actor_continue) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
        CHECK(child->pid == 42 && child->pidfd == 77 && child->start_time == 999u);
    }
    CHECK(!pthread_mutex_unlock(&mock.lock));
    return 1;
}

int fake_policy_call(struct writ_policy *policy, const char *operation,
                     uint32_t actor, uint32_t id, uint32_t offset,
                     uint32_t count, const char *argument, struct writ_reply *reply)
{
    (void)policy; (void)id; (void)offset; (void)count; (void)argument;
    CHECK(!pthread_mutex_lock(&mock.lock));
    memset(reply, 0, sizeof *reply);
    if (mock.broken) { CHECK(!pthread_mutex_unlock(&mock.lock)); return -1; }
    if (!strcmp(operation, "REVOKE")) {
        add_event(E_REVOKE);
        if (mock.revoke_deny) reply->status = WRIT_DENY;
        else { mock.revoked = 1; reply->status = WRIT_OK; }
    } else if (!strcmp(operation, "CLOSE")) {
        /* CLOSE remains cleanup even after revocation and is called under the lock. */
        CHECK(pthread_mutex_trylock(&mock.host->effect_lock) == EBUSY);
        add_event(E_CLOSE); reply->status = WRIT_OK;
    } else if (mock.revoked || actor != 1u) {
        add_event(E_DENY); reply->status = WRIT_DENY;
    } else if (!strcmp(operation, "READ")) {
        add_event(E_READ); reply->status = WRIT_OK; reply->value = 3;
    } else if (!strcmp(operation, "OPEN")) {
        add_event(E_OPEN); reply->status = WRIT_OK; reply->value = 2;
    } else if (!strcmp(operation, "STAT")) {
        reply->status = WRIT_OK; reply->value = 3;
    } else if (!strcmp(operation, "LIST")) {
        reply->status = WRIT_OK; reply->value = 1;
    } else {
        CHECK(0);
    }
    CHECK(!pthread_mutex_unlock(&mock.lock));
    return 0;
}

int fake_fcntl(int fd, int command, ...)
{
    (void)fd;
    CHECK(command == F_GET_SEALS);
    CHECK(!pthread_mutex_lock(&mock.lock));
    if (mock.pause_read) {
        mock.paused = 1;
        CHECK(!pthread_cond_broadcast(&mock.changed));
        while (!mock.proceed) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
    }
    int error = mock.seals_error;
    CHECK(!pthread_mutex_unlock(&mock.lock));
    return error ? -1 : REQUIRED_SEALS;
}

ssize_t fake_pread(int fd, void *buffer, size_t count, off_t offset)
{ (void)fd; (void)offset; memset(buffer, 'x', count); return (ssize_t)count; }

int fake_kill(pid_t pid, int signal_number)
{
    CHECK(pid == 1234 && signal_number == SIGKILL);
    CHECK(!pthread_mutex_lock(&mock.lock));
    add_event(E_KILL);
    int error = mock.kill_error;
    CHECK(!pthread_mutex_unlock(&mock.lock));
    return error ? -1 : 0;
}

int fake_reply_err(fuse_req_t req, int error)
{
    (void)req;
    if (!mock.mutex_error) assert_effect_locked();
    CHECK(!pthread_mutex_lock(&mock.lock));
    mock.last_error = error;
    CHECK(!pthread_mutex_unlock(&mock.lock));
    return 0;
}

int fake_reply_buf(fuse_req_t req, const char *buffer, size_t size)
{
    (void)req; (void)buffer; (void)size;
    assert_effect_locked();
    CHECK(!pthread_mutex_lock(&mock.lock));
    add_event(E_REPLY);
    CHECK(!pthread_mutex_unlock(&mock.lock));
    return 0;
}

int fake_reply_entry(fuse_req_t req, const struct fuse_entry_param *entry)
{ (void)req; (void)entry; assert_effect_locked(); return 0; }
int fake_reply_attr(fuse_req_t req, const struct stat *st, double timeout)
{ (void)req; (void)st; (void)timeout; assert_effect_locked(); return 0; }
int fake_reply_open(fuse_req_t req, const struct fuse_file_info *fi)
{
    (void)req; (void)fi;
    assert_effect_locked();
    CHECK(!pthread_mutex_lock(&mock.lock));
    add_event(E_OPEN_REPLY);
    int canceled = mock.cancel_open;
    CHECK(!pthread_mutex_unlock(&mock.lock));
    return canceled ? -ENOENT : 0;
}
size_t fake_add_direntry(fuse_req_t req, char *buf, size_t size,
                         const char *name, const struct stat *st, off_t off)
{ (void)req; (void)buf; (void)size; (void)name; (void)st; (void)off; return 0; }

static void reset(struct host *h, struct fake_request *request)
{
    memset(h, 0, sizeof *h);
    atomic_init(&h->fatal, 0);
    atomic_init(&h->initialized, 0);
    atomic_init(&h->event_count, 0);
    pthread_mutexattr_t attr; /* Mirror production's error-checking mutex. */
    CHECK(!pthread_mutexattr_init(&attr));
    CHECK(!pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_ERRORCHECK));
    CHECK(!pthread_mutex_init(&h->effect_lock, &attr));
    CHECK(!pthread_mutexattr_destroy(&attr));
    h->uid = 1000; h->gid = 1000; h->reader.pid = 42; h->reader.pidfd = 77;
    h->reader.command = 10; h->reader.result = 11; h->reader.start_time = 999u;
    h->policy.pid = 1234;
    h->length = 3; h->sealed = 55;
    h->handles[0] = (struct native_handle){1, 1, DATA_INODE};
    request->host = h;
    request->context = (struct fuse_ctx){ .uid = 1000, .gid = 1000, .pid = 42 };
    CHECK(!pthread_mutex_lock(&mock.lock));
    mock.count = 0; mock.revoked = 0; mock.broken = 0; mock.kill_error = 0;
    mock.cancel_open = 0; mock.pause_read = 0; mock.paused = 0; mock.proceed = 0;
    mock.attempted = 0; mock.completed = 0; mock.last_error = 0; mock.seals_error = 0;
    mock.mutex_error = 0; mock.revoke_deny = 0; mock.host = h;
    mock.lock_error = 0; mock.forbid_lock = 0; mock.lock_contended = 0; mock.reader_actor_while_waiting = -1; mock.unlock_error = 0; mock.join_error = 0; mock.join_real = 0;
    mock.join_started = 0; mock.joined = 0; mock.pause_actor = 0; mock.actor_paused = 0;
    mock.actor_continue = 0; mock.actor_calls = 0; mock.pause_retire = 0;
    mock.retire_paused = 0; mock.retire_continue = 0; mock.reader_retires = 0;
    mock.other_retires = 0; mock.exit_calls = 0; mock.unmount_calls = 0; mock.destroy_calls = 0;
    mock.forbidden_cleanup = 0; mock.forbidden_early_retire = 0; mock.forbidden_session_calls = 0;
    mock.reader_retire_error = mock.other_retire_error = 0;
    mock.retired_pid = -1; mock.retired_pidfd = -1;
    mock.retired_command = -1; mock.retired_result = -1; mock.retired_start = 0;
    mock.reused_fd = -1; mock.reused_fd_lookups = 0;
    CHECK(!pthread_mutex_unlock(&mock.lock));
}

static void unlocked(struct host *h)
{
    CHECK(!pthread_mutex_trylock(&h->effect_lock));
    CHECK(!pthread_mutex_unlock(&h->effect_lock));
}

static void *reader(void *value)
{
    struct fake_request *request = value;
    struct fuse_file_info fi = { .fh = 1 };
    fs_read((fuse_req_t)request, DATA_INODE, 3, 0, &fi);
    return NULL;
}

static void *control(void *value)
{
    struct host *h = mock.host;
    int terminate = *(int *)value;
    is_control_thread = 1;
    int result = terminate ? terminate_policy(h) : revoke_view(h);
    CHECK(!pthread_mutex_lock(&mock.lock));
    mock.completed = 1;
    CHECK(!pthread_cond_broadcast(&mock.changed));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    CHECK(!result);
    return NULL;
}

static void blocked_handoff(int terminate)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    mock.pause_read = 1;
    pthread_t read_thread, control_thread;
    CHECK(!pthread_create(&read_thread, NULL, reader, &request));
    CHECK(!pthread_mutex_lock(&mock.lock));
    while (!mock.paused) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    CHECK(pthread_mutex_trylock(&h.effect_lock) == EBUSY);
    CHECK(!pthread_create(&control_thread, NULL, control, &terminate));
    CHECK(!pthread_mutex_lock(&mock.lock));
    while (!mock.attempted && !mock.completed) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
    CHECK(mock.attempted && !mock.completed);
    CHECK(mock.count == 1 && mock.events[0] == E_READ);
    mock.proceed = 1;
    CHECK(!pthread_cond_broadcast(&mock.changed));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    CHECK(!pthread_join(read_thread, NULL));
    CHECK(!pthread_join(control_thread, NULL));
    CHECK(mock.count == 3 && mock.events[0] == E_READ && mock.events[1] == E_REPLY &&
          mock.events[2] == (terminate ? E_KILL : E_REVOKE));
    if (terminate) {
        struct fuse_file_info fi = { .fh = 1 };
        CHECK(atomic_load(&h.fatal));
        fs_read((fuse_req_t)&request, DATA_INODE, 3, 0, &fi);
        CHECK(mock.last_error == EIO && mock.count == 3);
    }
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

static void reverse_and_cleanup(void)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    CHECK(!revoke_view(&h));
    struct fuse_file_info fi = { .fh = 1 };
    fs_read((fuse_req_t)&request, DATA_INODE, 3, 0, &fi);
    CHECK(mock.count == 2 && mock.events[0] == E_REVOKE && mock.events[1] == E_DENY);
    CHECK(mock.last_error == EACCES);
    fs_release((fuse_req_t)&request, DATA_INODE, &fi);
    CHECK(mock.events[2] == E_CLOSE && h.handles[0].id == 0 && mock.last_error == 0);
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

static void canceled_open(void)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    mock.cancel_open = 1;
    struct fuse_file_info fi = { .flags = O_RDONLY };
    fs_open((fuse_req_t)&request, DATA_INODE, &fi);
    CHECK(mock.count == 3 && mock.events[0] == E_OPEN && mock.events[1] == E_OPEN_REPLY &&
          mock.events[2] == E_CLOSE && h.handles[1].id == 0 && !atomic_load(&h.fatal));
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

static void error_paths(void)
{
    struct host h;
    struct fake_request request;
    struct fuse_file_info fi = { .fh = 1 };
    reset(&h, &request);
    fs_read((fuse_req_t)&request, DATA_INODE, 3, -1, &fi);
    CHECK(mock.last_error == EINVAL && mock.count == 0);
    unlocked(&h);
    mock.seals_error = 1;
    fs_read((fuse_req_t)&request, DATA_INODE, 3, 0, &fi);
    CHECK(mock.last_error == EIO && atomic_load(&h.fatal));
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));

    reset(&h, &request);
    mock.broken = 1;
    fs_read((fuse_req_t)&request, DATA_INODE, 3, 0, &fi);
    CHECK(mock.last_error == EIO && atomic_load(&h.fatal));
    CHECK(atomic_load(&h.event_count) == 1 && h.events[0].status == WRIT_ERROR &&
          !strcmp(h.events[0].detail, "TRANSPORT") && mock.count == 0);
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));

    reset(&h, &request);
    mock.broken = 1;
    CHECK(revoke_view(&h) == -1 && atomic_load(&h.fatal));
    mock.broken = 0;
    fs_read((fuse_req_t)&request, DATA_INODE, 3, 0, &fi);
    CHECK(mock.last_error == EIO && mock.count == 0);
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));

    reset(&h, &request);
    mock.kill_error = 1;
    CHECK(terminate_policy(&h) == -1 && atomic_load(&h.fatal));
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));

    reset(&h, &request);
    mock.revoke_deny = 1;
    CHECK(revoke_view(&h) == -1 && atomic_load(&h.fatal) && !mock.revoked);
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));

    reset(&h, &request);
    mock.mutex_error = 1;
    fs_read((fuse_req_t)&request, DATA_INODE, 3, 0, &fi);
    CHECK(mock.last_error == EIO && atomic_load(&h.fatal) && mock.count == 0);
    mock.mutex_error = 0;
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

static void protected_metadata(void)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    CHECK(!revoke_view(&h));
    fs_lookup((fuse_req_t)&request, FUSE_ROOT_ID, "data");
    CHECK(mock.last_error == EACCES);
    fs_getattr((fuse_req_t)&request, DATA_INODE, NULL);
    CHECK(mock.last_error == EACCES);
    struct fuse_file_info fi = { .flags = O_RDONLY };
    fs_open((fuse_req_t)&request, DATA_INODE, &fi);
    CHECK(mock.last_error == EACCES);
    h.handles[1] = (struct native_handle){2, 1, FUSE_ROOT_ID};
    fi.fh = 2;
    fs_readdir((fuse_req_t)&request, FUSE_ROOT_ID, 100, 0, &fi);
    CHECK(mock.last_error == EACCES);
    CHECK(mock.count == 5 && mock.events[0] == E_REVOKE);
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

static void positive_metadata(void)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    fs_lookup((fuse_req_t)&request, FUSE_ROOT_ID, "data");
    fs_getattr((fuse_req_t)&request, DATA_INODE, NULL);
    struct fuse_file_info file = { .flags = O_RDONLY };
    fs_open((fuse_req_t)&request, DATA_INODE, &file);
    CHECK(file.fh == 2 && mock.count == 2 && mock.events[0] == E_OPEN && mock.events[1] == E_OPEN_REPLY);
    h.handles[2] = (struct native_handle){3, 1, FUSE_ROOT_ID};
    struct fuse_file_info dir = { .fh = 3 };
    fs_readdir((fuse_req_t)&request, FUSE_ROOT_ID, 100, 0, &dir);
    CHECK(mock.count == 3 && mock.events[2] == E_REPLY);
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

/* The reader/pidfd values below are synthetic. No native identity lookup,
   signal or descriptor close is performed by fake_process_alive/retire. */
struct cleanup_args {
    struct host *host;
    struct writ_child other;
    pthread_t callback;
    int result, destroy_lock;
};

static void *cleanup_thread(void *value)
{
    struct cleanup_args *args = value;
    args->result = retire_children_and_session(args->host, &args->other, 1, 1,
        args->callback, 1, 1, &args->destroy_lock);
    return NULL;
}

static void busy_reader_then_join(void)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    h.session = (struct fuse_session *)(uintptr_t)1;
    mock.pause_actor = 1; mock.join_real = 1; mock.forbidden_cleanup = 1; mock.forbidden_early_retire = 1;
    pthread_t read_thread, cleanup;
    CHECK(!pthread_create(&read_thread, NULL, reader, &request));
    CHECK(!pthread_mutex_lock(&mock.lock));
    while (!mock.actor_paused) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    struct cleanup_args args = { .host = &h,
        .other = { .pid = 43, .pidfd = 78, .command = 12, .result = 13 },
        .callback = read_thread, .result = 0, .destroy_lock = 0 };
    CHECK(!pthread_create(&cleanup, NULL, cleanup_thread, &args));
    CHECK(!pthread_mutex_lock(&mock.lock));
    while (!mock.join_started) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
    CHECK(mock.exit_calls == 1 && mock.unmount_calls == 1 && mock.reader_retires == 0 &&
          mock.other_retires == 0 && h.reader.pid == 42 && h.reader.pidfd == 77);
    CHECK(atomic_load(&h.fatal));
    mock.actor_continue = 1;
    CHECK(!pthread_cond_broadcast(&mock.changed));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    CHECK(!pthread_join(cleanup, NULL));
    CHECK(args.result == EBUSY && args.destroy_lock == 1 && mock.joined &&
          mock.reader_retires == 1 && mock.other_retires == 1 && mock.destroy_calls == 1);
    CHECK(h.reader.pid == -1 && h.reader.pidfd == -1);
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

static void *paused_retirement(void *value)
{
    struct cleanup_args *args = value;
    args->result = retire_children_and_session(args->host, &args->other, 1, 1,
        args->callback, 1, 1, &args->destroy_lock);
    return NULL;
}

static void detached_reap_and_reuse(void)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    h.session = (struct fuse_session *)(uintptr_t)1;
    mock.pause_retire = 1;
    struct cleanup_args args = { .host = &h,
        .other = { .pid = -1, .pidfd = -1, .command = -1, .result = -1 },
        .callback = (pthread_t)0, .result = -1, .destroy_lock = 0 };
    pthread_t cleanup;
    CHECK(!pthread_create(&cleanup, NULL, paused_retirement, &args));
    CHECK(!pthread_mutex_lock(&mock.lock));
    while (!mock.retire_paused) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
    CHECK(mock.retired_pid == 42 && mock.retired_pidfd == 77 && mock.retired_command == 10 &&
          mock.retired_result == 11 && mock.retired_start == 999u && h.reader.pid == -1 &&
          h.reader.pidfd == -1 && h.reader.command == -1 && h.reader.result == -1 && h.reader.start_time == 0);
    CHECK(!atomic_load(&h.fatal));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    /* Reaping is paused, yet another thread can acquire the effect lock. */
    unlocked(&h);
    struct fuse_file_info fi = { .fh = 1 };
    fs_read((fuse_req_t)&request, DATA_INODE, 3, 0, &fi);
    CHECK(mock.last_error == EACCES && mock.actor_calls == 0);
    CHECK(!pthread_mutex_lock(&mock.lock));
    mock.retire_continue = 1;
    CHECK(!pthread_cond_broadcast(&mock.changed));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    CHECK(!pthread_join(cleanup, NULL));
    CHECK(args.result == 0 && args.destroy_lock == 1 && mock.reader_retires == 1 && mock.joined);
    /* Model numeric fd 77 being assigned to an unrelated live object. A stale
       lookup would be counted and fake_process_alive would return true. */
    mock.reused_fd = 77;
    fs_read((fuse_req_t)&request, DATA_INODE, 3, 0, &fi);
    CHECK(mock.last_error == EACCES && mock.actor_calls == 0 && mock.reused_fd_lookups == 0);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

/* A FUSE release can still hold the effect lock for a moment after the
   reader's last close (observed in CI run 43059416003: 1 ms). Cleanup must
   wait for that bounded hold and take the ordinary detached path, not the
   fatal busy fallback. The holder below is a synthetic stand-in callback. */
struct transient_holder { struct host *host; int held; };

static void *hold_effect_lock_briefly(void *value)
{
    struct transient_holder *t = value;
    CHECK(!pthread_mutex_lock(&t->host->effect_lock));
    CHECK(!pthread_mutex_lock(&mock.lock));
    t->held = 1;
    CHECK(!pthread_cond_broadcast(&mock.changed));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    struct timespec hold = { 0, 20 * 1000 * 1000 };
    while (nanosleep(&hold, &hold) && errno == EINTR) {}
    CHECK(!pthread_mutex_unlock(&t->host->effect_lock));
    return NULL;
}

static void transient_holder_then_cleanup(void)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    h.session = (struct fuse_session *)(uintptr_t)1;
    struct transient_holder t = { .host = &h, .held = 0 };
    pthread_t holder;
    CHECK(!pthread_create(&holder, NULL, hold_effect_lock_briefly, &t));
    CHECK(!pthread_mutex_lock(&mock.lock));
    while (!t.held) CHECK(!pthread_cond_wait(&mock.changed, &mock.lock));
    CHECK(!pthread_mutex_unlock(&mock.lock));
    struct writ_child other = { .pid = 43, .pidfd = 78, .command = 12, .result = 13 };
    int destroy_lock = 0;
    int result = retire_children_and_session(&h, &other, 1, 1, (pthread_t)0, 1, 1, &destroy_lock);
    CHECK(!pthread_join(holder, NULL));
    CHECK(mock.lock_contended == 1 && mock.reader_actor_while_waiting == 0);
    CHECK(result == 0 && destroy_lock == 1 && !atomic_load(&h.fatal));
    CHECK(mock.reader_retires == 1 && mock.other_retires == 1 && mock.retired_pid == 42 &&
          h.reader.pid == -1 && h.reader.pidfd == -1 && mock.joined && mock.destroy_calls == 1);
    unlocked(&h);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

static void no_thread_or_lock(void)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
    mock.forbid_lock = 1;
    struct writ_child other = { .pid = -1, .pidfd = -1, .command = -1, .result = -1 };
    int destroy_lock = 1;
    CHECK(!retire_children_and_session(&h, &other, 0, 0, (pthread_t)0, 0, 0, &destroy_lock));
    CHECK(destroy_lock == 0 && mock.reader_retires == 1 && !atomic_load(&h.fatal));
}

static void retire_failures_continue_cleanup(void)
{
    struct host h; struct fake_request request;
    reset(&h, &request);
    h.session = (struct fuse_session *)(uintptr_t)1;
    mock.reader_retire_error = EPERM; mock.other_retire_error = EIO;
    struct writ_child other = { .pid = 43, .pidfd = 78, .command = 12, .result = 13 };
    int destroy_lock = 0;
    CHECK(retire_children_and_session(&h, &other, 1, 1, (pthread_t)0, 1, 1,
                                      &destroy_lock) == EPERM);
    CHECK(mock.reader_retires == 1 && mock.other_retires == 1 && mock.joined &&
          mock.exit_calls == 1 && mock.unmount_calls == 1 && mock.destroy_calls == 1);
    CHECK(destroy_lock == 1);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

static void fail_stop_child(int scenario)
{
    struct host h;
    struct fake_request request;
    reset(&h, &request);
    h.session = (struct fuse_session *)(uintptr_t)1;
    mock.forbidden_cleanup = 1;
    if (scenario == 1) { mock.unlock_error = 1; mock.forbidden_early_retire = 1; }
    else if (scenario == 0) { mock.lock_error = EINVAL; mock.forbidden_early_retire = 1; mock.forbidden_session_calls = 1; }
    else if (scenario == 3) { mock.lock_error = ETIMEDOUT; mock.join_error = 1; mock.forbidden_early_retire = 1; }
    else if (scenario == 4) { mock.forbid_lock = 1; mock.forbidden_early_retire = 1; mock.forbidden_session_calls = 1; }
    else if (scenario == 6) { mock.forbidden_early_retire = 1; mock.forbidden_session_calls = 1; }
    else if (scenario == 5) { mock.lock_error = EOWNERDEAD; mock.forbidden_early_retire = 1; mock.forbidden_session_calls = 1; }
    else mock.join_error = 1;
    struct writ_child other = { .pid = 43, .pidfd = 78, .command = 12, .result = 13 };
    int destroy_lock = 1;
    pid_t child = fork();
    CHECK(child >= 0);
    if (!child) {
        if (scenario == 6) CHECK(!pthread_mutex_lock(&h.effect_lock)); /* cleanup's own thread holds it */
        (void)retire_children_and_session(&h, &other, scenario == 4 ? 0 : 1, 1,
                                          (pthread_t)0, 1, 1, &destroy_lock);
        _Exit(99);
    }
    int status;
    CHECK(waitpid(child, &status, 0) == child);
    CHECK(WIFEXITED(status) && WEXITSTATUS(status) == 1);
    CHECK(!pthread_mutex_destroy(&h.effect_lock));
}

int main(void)
{
    /* An ordering or unlock regression must fail instead of hanging forever. */
    alarm(30);
    blocked_handoff(0); puts("PASS paused READ reply attempt precedes REVOKE");
    blocked_handoff(1); puts("PASS paused READ reply attempt precedes intentional policy termination");
    reverse_and_cleanup(); puts("PASS REVOKE first denies later READ and permits CLOSE cleanup");
    canceled_open(); puts("PASS canceled OPEN closes its admitted handle while locked");
    error_paths(); puts("PASS malformed and failed operations poison or release the lock");
    protected_metadata(); puts("PASS revoked lookup, getattr, open and directory listing deny");
    positive_metadata(); puts("PASS successful protected metadata replies hold the effect lock");
    busy_reader_then_join(); puts("PASS busy reader record stays intact until checked join");
    detached_reap_and_reuse(); puts("PASS detached pidfd retirement is outside the lock and cannot restore actor");
    transient_holder_then_cleanup(); puts("PASS brief callback lock hold is awaited and cleanup completes");
    no_thread_or_lock(); puts("PASS no-thread cleanup avoids the uninitialized lock");
    retire_failures_continue_cleanup(); puts("PASS retirement failures preserve the first error and continue cleanup");
    fail_stop_child(0); puts("PASS unexpected cleanup lock failure immediately fail-stops without cleanup");
    fail_stop_child(1); puts("PASS failed unlock fail-stops without retiring shared resources");
    fail_stop_child(2); puts("PASS failed join after detachment fail-stops without destroying shared state");
    fail_stop_child(3); puts("PASS busy-path failed join fail-stops before touching shared reader");
    fail_stop_child(4); puts("PASS started thread without initialized lock fail-stops without touching it");
    fail_stop_child(6); puts("PASS cleanup on a thread already holding the lock fail-stops (EDEADLK)");
    fail_stop_child(5); puts("PASS ownership-granting unexpected cleanup lock result fail-stops before cleanup");
    return 0;
}
