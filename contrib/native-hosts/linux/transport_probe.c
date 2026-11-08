#define _GNU_SOURCE
#include "policy_pipe.h"
#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

/* These malformed peers test only native framing failure. They never mount or
   serve data, and are not alternate policy implementations. */
static int malformed_peer(const char *which)
{
    char buffer[512];
    if (read(STDIN_FILENO, buffer, sizeof buffer) <= 0) return 2;
    if (!strcmp(which, "/sequence")) fputs("WRITFS1\t2\tOK\t1\tADMITTED\n", stdout);
    else if (!strcmp(which, "/leading-zero")) fputs("WRITFS1\t01\tOK\t1\tADMITTED\n", stdout);
    else if (!strcmp(which, "/overflow")) fputs("WRITFS1\t1\tOK\t4294967296\tSTAT\n", stdout);
    else if (!strcmp(which, "/trailing")) fputs("WRITFS1\t1\tOK\t0\tSTAT\textra\n", stdout);
    else if (!strcmp(which, "/status")) fputs("WRITFS1\t1\tALLOW\t0\tSTAT\n", stdout);
    else if (!strcmp(which, "/partial")) fputs("WRITFS1\t1\tOK\t0\tSTAT", stdout);
    else if (!strcmp(which, "/oversize")) {
        for (unsigned int i = 0; i < 300; ++i) fputc('x', stdout);
        fputc('\n', stdout);
    } else if (!strcmp(which, "/timeout")) {
        fputc('W', stdout); fflush(stdout);
        for (;;) pause();
    } else return 2;
    return fflush(stdout) ? 1 : 0;
}

static int real_policy(const char *node, const char *bridge, const char *module)
{
    struct writ_policy p;
    if (writ_policy_start(&p, node, bridge, module)) return 1;
    struct writ_reply r;
    int result = 1;
    if (writ_policy_call(&p, "INIT", 0, 0, 0, 0, "0061ff0a", &r) ||
        r.status != WRIT_OK || r.value != 4 || strlen(r.detail) != 64) goto done;
    if (writ_policy_call(&p, "ADMIT", 1, 0, 0, 0, "public-canary", &r) ||
        r.status != WRIT_OK) goto done;
    if (writ_policy_call(&p, "OPEN", 1, 0, 0, 0, "data", &r) ||
        r.status != WRIT_OK || !r.value) goto done;
    uint32_t handle = r.value;
    if (writ_policy_call(&p, "READ", 1, handle, 1, 10, "-", &r) ||
        r.status != WRIT_OK || r.value != 3) goto done;
    if (writ_policy_call(&p, "REVOKE", 0, 0, 0, 0, "-", &r) ||
        r.status != WRIT_OK) goto done;
    if (writ_policy_call(&p, "READ", 1, handle, 0, 1, "-", &r) ||
        r.status != WRIT_DENY) goto done;
    if (writ_policy_call(&p, "CLOSE", 1, handle, 0, 0, "-", &r) ||
        r.status != WRIT_OK) goto done;
    if (writ_policy_call(&p, "STOP", 0, 0, 0, 0, "-", &r) || r.status != WRIT_OK) goto done;
    result = 0;
done:
    writ_policy_stop(&p);
    return result;
}

/* This tests a real owned interpreter's loss at the pipe, not FUSE service or
   spontaneous death timing. WNOWAIT preserves normal policy_stop reaping. */
static int real_policy_loss(const char *node, const char *bridge, const char *module)
{
    struct writ_policy p;
    if (writ_policy_start(&p, node, bridge, module)) return 1;
    struct writ_reply r;
    int result = 1;
    if (writ_policy_call(&p, "STATUS", 0, 0, 0, 0, "-", &r) || r.status != WRIT_OK)
        goto done;
    if (p.pid <= 0 || kill(p.pid, SIGKILL)) goto done;
    siginfo_t info;
    int waited;
    do { waited = waitid(P_PID, (id_t)p.pid, &info, WEXITED | WNOWAIT); }
    while (waited && errno == EINTR);
    if (waited || info.si_pid != p.pid || info.si_code != CLD_KILLED || info.si_status != SIGKILL)
        goto done;
    int first = writ_policy_call(&p, "STATUS", 0, 0, 0, 0, "-", &r);
    int retry = writ_policy_call(&p, "STATUS", 0, 0, 0, 0, "-", &r);
    if (!first || !retry || p.live) goto done;
    result = 0;
done:
    writ_policy_stop(&p);
    return result;
}

int main(int argc, char **argv)
{
    if (argc == 6 && !strcmp(argv[1], "--no-addons")) return malformed_peer(argv[4]);
    if (argc != 4) {
        fputs("Usage: transport-probe ABS_NODE ABS_BRIDGE ABS_MODULE\n", stderr); return 2;
    }
    signal(SIGPIPE, SIG_IGN);
    setvbuf(stdout, NULL, _IOLBF, 0);
    /* Any inherited runtime injection makes the real Node invocation fail. */
    if (setenv("NODE_OPTIONS", "--this-option-must-not-reach-the-policy-child", 1) ||
        setenv("NODE_PATH", "/unapproved-modules", 1) ||
        setenv("LD_PRELOAD", "/unapproved-preload.so", 1)) return 1;
    if (real_policy(argv[1], argv[2], argv[3])) {
        fputs("FAIL native pipe to generated Bend policy\n", stderr); return 1;
    }
    puts("PASS native private pipes execute actual Bend admission, read and revocation");
    puts("PASS Node and loader injection environment is removed");
    if (real_policy_loss(argv[1], argv[2], argv[3])) {
        fputs("FAIL actual policy-process loss poisons the private pipe\n", stderr); return 1;
    }
    puts("PASS actual policy-process loss poisons the private pipe and denies retry");
    char self[PATH_MAX];
    ssize_t n = readlink("/proc/self/exe", self, sizeof self - 1);
    if (n <= 0 || n == (ssize_t)sizeof self - 1) return 1;
    self[n] = 0;
    const char *cases[] = { "/sequence", "/leading-zero", "/overflow", "/trailing",
                            "/status", "/partial", "/oversize", "/timeout" };
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; ++i) {
        struct writ_policy p;
        struct writ_reply r;
        if (writ_policy_start(&p, self, cases[i], "/unused-test-module")) return 1;
        int first = writ_policy_call(&p, "STATUS", 0, 0, 0, 0, "-", &r);
        int retry = writ_policy_call(&p, "STATUS", 0, 0, 0, 0, "-", &r);
        writ_policy_stop(&p);
        if (!first || !retry) { fprintf(stderr, "FAIL malformed native peer %s\n", cases[i]); return 1; }
        printf("PASS malformed native peer %s stops without retry\n", cases[i] + 1);
    }
    puts("ALL LINUX NATIVE TRANSPORT CHECKS PASSED");
    return 0;
}
