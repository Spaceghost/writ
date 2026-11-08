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

#define pthread_mutex_lock fake_mutex_lock
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
#include "writfs.c"
#undef pthread_mutex_lock
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
{ (void)child; return 1; }

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
    CHECK(!pthread_mutex_init(&h->effect_lock, NULL));
    h->uid = 1000; h->gid = 1000; h->reader.pid = 42; h->policy.pid = 1234;
    h->length = 3; h->sealed = 55;
    h->handles[0] = (struct native_handle){1, 1, DATA_INODE};
    request->host = h;
    request->context = (struct fuse_ctx){ .uid = 1000, .gid = 1000, .pid = 42 };
    CHECK(!pthread_mutex_lock(&mock.lock));
    mock.count = 0; mock.revoked = 0; mock.broken = 0; mock.kill_error = 0;
    mock.cancel_open = 0; mock.pause_read = 0; mock.paused = 0; mock.proceed = 0;
    mock.attempted = 0; mock.completed = 0; mock.last_error = 0; mock.seals_error = 0;
    mock.mutex_error = 0; mock.revoke_deny = 0; mock.host = h;
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
    return 0;
}
