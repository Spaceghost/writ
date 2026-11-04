/* Native private-pipe checks. Fake peers below are deliberately malformed
   transport fixtures; they cannot mount a filesystem or release input bytes. */
#define _WIN32_WINNT 0x0A00
#include "policy_pipe.h"
#include <strsafe.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char status_request[] = "WRITFS1\tSTATUS\t0\t0\t0\t0\t-\n";
static const char status_reply[] = "WRITFS1\t1\tOK\t0\tSTATUS\n";

static BOOL write_bytes(HANDLE output, const char *bytes, size_t length)
{
    if (length > MAXDWORD) return FALSE;
    DWORD total = 0, count = (DWORD)length;
    while (total < count) {
        DWORD written = 0;
        if (!WriteFile(output, bytes + total, count - total, &written, NULL) || !written) return FALSE;
        total += written;
    }
    return TRUE;
}

static BOOL read_frame(HANDLE input)
{
    for (unsigned int i = 0; i < WRIT_POLICY_FRAME_MAX; ++i) {
        char byte;
        DWORD got = 0;
        if (!ReadFile(input, &byte, 1, &got, NULL) || got != 1) return FALSE;
        if (byte == '\n') return TRUE;
    }
    return FALSE;
}

static int fake_peer(const wchar_t *mode)
{
    HANDLE input = GetStdHandle(STD_INPUT_HANDLE), output = GetStdHandle(STD_OUTPUT_HANDLE);
    const char *reply = NULL;
    if (!input || input == INVALID_HANDLE_VALUE || !output || output == INVALID_HANDLE_VALUE) return 101;
    if (!wcscmp(mode, L"early")) {
        if (!write_bytes(output, status_reply, sizeof(status_reply) - 1)) return 102;
        Sleep(INFINITE);
        return 103;
    }
    if (!wcscmp(mode, L"write-timeout")) { Sleep(INFINITE); return 104; }
    if (!read_frame(input)) return 105;
    if (!wcscmp(mode, L"read-timeout")) { Sleep(INFINITE); return 106; }
    if (!wcscmp(mode, L"eof")) return 0;
    if (!wcscmp(mode, L"partial")) {
        return write_bytes(output, status_reply, sizeof(status_reply) - 2) ? 0 : 107;
    }
    if (!wcscmp(mode, L"fragmented")) {
        if (!write_bytes(output, status_reply, 9)) return 108;
        Sleep(20);
        if (!write_bytes(output, status_reply + 9, sizeof(status_reply) - 1 - 9)) return 109;
        Sleep(INFINITE);
        return 110;
    }
    if (!wcscmp(mode, L"replay")) {
        if (!write_bytes(output, status_reply, sizeof(status_reply) - 1) || !read_frame(input)) return 111;
        reply = status_reply;
    } else if (!wcscmp(mode, L"sequence")) reply = "WRITFS1\t2\tOK\t0\tSTATUS\n";
    else if (!wcscmp(mode, L"leading-zero")) reply = "WRITFS1\t01\tOK\t0\tSTATUS\n";
    else if (!wcscmp(mode, L"sequence-overflow")) reply = "WRITFS1\t4294967296\tOK\t0\tSTATUS\n";
    else if (!wcscmp(mode, L"value-overflow")) reply = "WRITFS1\t1\tOK\t4294967296\tSTATUS\n";
    else if (!wcscmp(mode, L"trailing-field")) reply = "WRITFS1\t1\tOK\t0\tSTATUS\textra\n";
    else if (!wcscmp(mode, L"status")) reply = "WRITFS1\t1\tMAYBE\t0\tSTATUS\n";
    else if (!wcscmp(mode, L"reason")) reply = "WRITFS1\t1\tOK\t0\tuntrusted/path\n";
    else if (!wcscmp(mode, L"cr")) reply = "WRITFS1\t1\tOK\t0\tSTATUS\r\n";
    else if (!wcscmp(mode, L"non-ascii")) reply = "WRITFS1\t1\tOK\t0\tS\x80\n";
    else if (!wcscmp(mode, L"after-lf")) reply = "WRITFS1\t1\tOK\t0\tSTATUS\nWRITFS1\t2\tOK\t0\tSTATUS\n";
    else if (!wcscmp(mode, L"nul")) {
        static const char nul_reply[] = "WRITFS1\t1\tOK\t0\tSTAT\0US\n";
        if (!write_bytes(output, nul_reply, sizeof(nul_reply) - 1)) return 112;
        Sleep(INFINITE);
        return 113;
    } else if (!wcscmp(mode, L"oversize")) {
        char oversized[300];
        memset(oversized, 'A', sizeof(oversized));
        memcpy(oversized, "WRITFS1\t1\tOK\t0\t", sizeof("WRITFS1\t1\tOK\t0\t") - 1);
        oversized[sizeof(oversized) - 1] = '\n';
        if (!write_bytes(output, oversized, sizeof(oversized))) return 114;
        Sleep(INFINITE);
        return 115;
    }
    if (!reply || !write_bytes(output, reply, strlen(reply))) return 116;
    Sleep(INFINITE);
    return 117;
}

static BOOL exchange(WRIT_POLICY_PIPE *pipe, const char *request, const char *expected)
{
    char reply[WRIT_POLICY_REPLY_MAX];
    return writ_policy_exchange(pipe, request, reply, sizeof(reply)) && !strcmp(reply, expected);
}

static char *large_request(void)
{
    static const char prefix[] = "WRITFS1\tINIT\t0\t0\t0\t0\t";
    const size_t length = sizeof(prefix) - 1 + 2 * 65536;
    char *frame = malloc(length + 2);
    if (!frame) return NULL;
    memcpy(frame, prefix, sizeof(prefix) - 1);
    memset(frame + sizeof(prefix) - 1, '0', 2 * 65536);
    frame[length] = '\n';
    frame[length + 1] = 0;
    return frame;
}

static BOOL actual_bend(const wchar_t *node, const wchar_t *bridge, const wchar_t *module)
{
    WRIT_POLICY_PIPE pipe = {0};
    BOOL ok = FALSE;
    /* A child that inherited these variables could not start Node normally. */
    if (!SetEnvironmentVariableW(L"NODE_OPTIONS", L"--writ-transport-must-strip-this") ||
        !SetEnvironmentVariableW(L"NODE_PATH", L"C:\\writ-transport-must-not-load")) return FALSE;
    if (!writ_policy_start(&pipe, node, bridge, module)) goto done;
    ok = exchange(&pipe, "WRITFS1\tINIT\t0\t0\t0\t0\t616263\n",
        "WRITFS1\t1\tOK\t3\tba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") &&
        exchange(&pipe, "WRITFS1\tADMIT\t1\t0\t0\t0\tpublic-canary\n", "WRITFS1\t2\tOK\t1\tADMITTED") &&
        exchange(&pipe, "WRITFS1\tOPEN\t1\t0\t0\t0\tdata\n", "WRITFS1\t3\tOK\t1\tOPEN") &&
        exchange(&pipe, "WRITFS1\tREAD\t1\t1\t0\t8\t-\n", "WRITFS1\t4\tOK\t3\tREAD") &&
        exchange(&pipe, "WRITFS1\tREVOKE\t0\t0\t0\t0\t-\n", "WRITFS1\t5\tOK\t2\tREVOKED") &&
        exchange(&pipe, "WRITFS1\tREAD\t1\t1\t0\t8\t-\n", "WRITFS1\t6\tDENY\t0\tACTOR_OR_PHASE") &&
        exchange(&pipe, "WRITFS1\tCLOSE\t1\t1\t0\t0\t-\n", "WRITFS1\t7\tOK\t0\tCLOSE") &&
        exchange(&pipe, "WRITFS1\tSTOP\t0\t0\t0\t0\t-\n", "WRITFS1\t8\tOK\t0\tSTOPPED");
done:
    if (!writ_policy_stop(&pipe)) ok = FALSE;
    return ok;
}

static BOOL actual_large_frame(const wchar_t *node, const wchar_t *bridge, const wchar_t *module)
{
    WRIT_POLICY_PIPE pipe = {0};
    char *frame = large_request();
    BOOL ok = frame && writ_policy_start(&pipe, node, bridge, module) &&
        exchange(&pipe, frame, "WRITFS1\t1\tOK\t65536\tde2f256064a0af797747c2b97505dc0b9f3df0de4f489eac731c23ae9ca9cc31") &&
        exchange(&pipe, "WRITFS1\tSTOP\t0\t0\t0\t0\t-\n", "WRITFS1\t2\tOK\t0\tSTOPPED");
    free(frame);
    if (!writ_policy_stop(&pipe)) ok = FALSE;
    return ok;
}

static BOOL start_fake(WRIT_POLICY_PIPE *pipe, const wchar_t *self, const wchar_t *mode)
{
    wchar_t selector[160];
    /* The fake executable interprets only this selector; it never opens it. */
    return SUCCEEDED(StringCchPrintfW(selector, ARRAYSIZE(selector),
        L"C:\\writ-native-transport-probe\\%s", mode)) && writ_policy_start(pipe, self, self, selector);
}

static BOOL wait_for_unsolicited_output(WRIT_POLICY_PIPE *pipe)
{
    ULONGLONG deadline = GetTickCount64() + 5000;
    while (GetTickCount64() < deadline) {
        DWORD available = 0;
        if (WaitForSingleObject(pipe->process, 0) != WAIT_TIMEOUT ||
            !PeekNamedPipe(pipe->output, NULL, 0, NULL, &available, NULL)) return FALSE;
        if (available) return TRUE;
        Sleep(5);
    }
    return FALSE;
}

static BOOL positive_fragmented(const wchar_t *self)
{
    WRIT_POLICY_PIPE pipe = {0};
    BOOL ok = start_fake(&pipe, self, L"fragmented") &&
        exchange(&pipe, status_request, "WRITFS1\t1\tOK\t0\tSTATUS") && !pipe.failed && pipe.sequence == 1;
    if (!writ_policy_stop(&pipe)) ok = FALSE;
    return ok;
}

static BOOL negative_peer(const wchar_t *self, const wchar_t *mode)
{
    WRIT_POLICY_PIPE pipe = {0};
    BOOL ok = FALSE;
    char reply[512]; /* The protocol bound must hold even with a larger caller buffer. */
    char *large = NULL;
    const char *request = status_request;
    if (!start_fake(&pipe, self, mode)) goto done;
    if (!wcscmp(mode, L"early") && !wait_for_unsolicited_output(&pipe)) goto done;
    if (!wcscmp(mode, L"replay") && !exchange(&pipe, status_request, "WRITFS1\t1\tOK\t0\tSTATUS")) goto done;
    if (!wcscmp(mode, L"write-timeout")) {
        large = large_request();
        if (!large) goto done;
        request = large;
    }
    ULONGLONG before = GetTickCount64();
    if (writ_policy_exchange(&pipe, request, reply, sizeof(reply))) goto done;
    ULONGLONG elapsed = GetTickCount64() - before;
    if ((!wcscmp(mode, L"read-timeout") || !wcscmp(mode, L"write-timeout")) &&
        (elapsed < 14000 || elapsed > 25000)) goto done;
    if (!pipe.failed || reply[0] || WaitForSingleObject(pipe.process, 5000) != WAIT_OBJECT_0 ||
        writ_policy_exchange(&pipe, status_request, reply, sizeof(reply))) goto done;
    ok = TRUE;
done:
    free(large);
    if (!writ_policy_stop(&pipe)) ok = FALSE;
    return ok;
}

int wmain(int argc, wchar_t **argv)
{
    if (argc == 5 && !wcscmp(argv[1], L"--no-addons") &&
        !wcscmp(argv[2], L"--max-old-space-size=128")) {
        const wchar_t *mode = wcsrchr(argv[4], L'\\');
        return mode ? fake_peer(mode + 1) : 118;
    }
    if (argc != 4) {
        fputs("Usage: writfs-transport-probe ABS_NODE ABS_BRIDGE ABS_MOUNT_MODULE\n", stderr);
        return 2;
    }
    setvbuf(stdout, NULL, _IONBF, 0);
    wchar_t self[32768];
    DWORD count = GetModuleFileNameW(NULL, self, ARRAYSIZE(self));
    if (!count || count >= ARRAYSIZE(self)) return 1;
    if (!actual_bend(argv[1], argv[2], argv[3])) {
        fputs("FAIL actual Bend private transport and stripped Node environment\n", stderr);
        return 1;
    }
    puts("PASS native private pipes execute actual Bend admission, read, revocation and cleanup");
    puts("PASS native policy child ignores injected Node environment");
    if (!actual_large_frame(argv[1], argv[2], argv[3])) {
        fputs("FAIL native 64 KiB frame/digest transport\n", stderr);
        return 1;
    }
    puts("PASS native 64 KiB payload traverses private pipes with exact Bend digest");
    if (!positive_fragmented(self)) {
        fputs("FAIL native fragmented-reply positive control\n", stderr);
        return 1;
    }
    puts("PASS native fragmented reply is accepted exactly once");
    static const wchar_t *modes[] = {
        L"early", L"after-lf", L"sequence", L"replay", L"leading-zero", L"sequence-overflow",
        L"value-overflow", L"trailing-field", L"status", L"reason", L"cr", L"non-ascii",
        L"nul", L"oversize", L"partial", L"eof", L"read-timeout", L"write-timeout"
    };
    for (unsigned int i = 0; i < ARRAYSIZE(modes); ++i) {
        if (!negative_peer(self, modes[i])) {
            fprintf(stderr, "FAIL native malformed peer %ls\n", modes[i]);
            return 1;
        }
        printf("PASS native malformed peer %ls poisons the pipe, retires the child and refuses retry\n", modes[i]);
    }
    puts("ALL WINDOWS NATIVE TRANSPORT CHECKS PASSED (22 assertions)");
    return 0;
}
