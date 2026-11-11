/* Ordinary-process positive control using the same production network probe.
 * Only the fixed public canary reaches four owned loopback receivers. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include "network_probe.h"

static int readable(SOCKET handle, ULONGLONG deadline)
{
    ULONGLONG now = GetTickCount64();
    if (now >= deadline) return 0;
    DWORD remaining = (DWORD)(deadline - now);
    fd_set input;
    FD_ZERO(&input); FD_SET(handle, &input);
    TIMEVAL wait = { (long)(remaining / 1000), (long)((remaining % 1000) * 1000) };
    return select(0, &input, NULL, NULL, &wait) > 0;
}

static int receive_canary(SOCKET receiver, int stream)
{
    static const char expected[] = "writ-public-egress-canary";
    char received[sizeof(expected)] = {0};
    SOCKET input = receiver;
    int ok = 0, total = 0;
    ULONGLONG deadline = GetTickCount64() + 2000;
    if (!readable(receiver, deadline)) goto done;
    if (stream) {
        input = accept(receiver, NULL, NULL);
        if (input == INVALID_SOCKET) goto done;
        u_long nonblocking = 1;
        if (ioctlsocket(input, FIONBIO, &nonblocking) == SOCKET_ERROR) goto done;
    }
    do {
        if (!readable(input, deadline)) goto done;
        int count = recv(input, received + total, (int)sizeof(received) - total, 0);
        if (count <= 0) goto done;
        total += count;
        if (!stream) break;
    } while (total < (int)sizeof(received));
    ok = total == (int)sizeof(expected) && !memcmp(received, expected, sizeof(expected));
done:
    if (stream && input != receiver && input != INVALID_SOCKET) closesocket(input);
    return ok;
}

int main(void)
{
    WSADATA data;
    SOCKET receivers[4] = { INVALID_SOCKET, INVALID_SOCKET, INVALID_SOCKET, INVALID_SOCKET };
    unsigned short ports[4] = {0};
    const char *names[4] = { "TCP4", "TCP6", "UDP4", "UDP6" };
    int ok = 0;
    int startup = WSAStartup(MAKEWORD(2,2), &data);
    if (startup) { fprintf(stderr, "FAIL positive-control WSAStartup=%d\n", startup); return 1; }
    for (unsigned int i = 0; i < 4; ++i) {
        int family = i % 2 ? AF_INET6 : AF_INET;
        int type = i < 2 ? SOCK_STREAM : SOCK_DGRAM;
        receivers[i] = socket(family, type, i < 2 ? IPPROTO_TCP : IPPROTO_UDP);
        if (receivers[i] == INVALID_SOCKET) goto done;
        SOCKADDR_STORAGE address;
        ZeroMemory(&address, sizeof(address));
        int length;
        if (family == AF_INET) {
            SOCKADDR_IN *v4 = (SOCKADDR_IN *)&address;
            v4->sin_family = AF_INET; v4->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
            length = sizeof(*v4);
        } else {
            SOCKADDR_IN6 *v6 = (SOCKADDR_IN6 *)&address;
            v6->sin6_family = AF_INET6; v6->sin6_addr = in6addr_loopback;
            length = sizeof(*v6);
        }
        if (bind(receivers[i], (SOCKADDR *)&address, length) == SOCKET_ERROR ||
            getsockname(receivers[i], (SOCKADDR *)&address, &length) == SOCKET_ERROR) goto done;
        ports[i] = family == AF_INET ? ntohs(((SOCKADDR_IN *)&address)->sin_port) :
            ntohs(((SOCKADDR_IN6 *)&address)->sin6_port);
        u_long nonblocking = 1;
        if (!ports[i] || ioctlsocket(receivers[i], FIONBIO, &nonblocking) == SOCKET_ERROR ||
            (i < 2 && listen(receivers[i], 1) == SOCKET_ERROR)) goto done;
    }
    WRIT_PROBE_REPORT report = {0};
    report.magic = WRIT_PROBE_MAGIC;
    writ_network_checks(&report, ports);
    if (report.network_startup_error || report.passed || report.failed != WRIT_PROBE_NETWORK_MASK ||
        !writ_network_report_valid(&report, WRIT_PROBE_NETWORK_MASK)) goto done;
    for (unsigned int i = 0; i < 4; ++i) {
        if (report.errors[7 + i] || !receive_canary(receivers[i], i < 2)) goto done;
        printf("PASS loopback %s: exact public canary received; stage=%u error=%u denial_credit=0\n",
            names[i], report.network_stage[i], report.errors[7 + i]);
    }
    ok = 1;
done:
    if (!ok) fprintf(stderr, "FAIL ordinary loopback positive control; error=%d\n", WSAGetLastError());
    for (unsigned int i = 0; i < 4; ++i)
        if (receivers[i] != INVALID_SOCKET) closesocket(receivers[i]);
    WSACleanup();
    if (ok) puts("PASS network loopback controls: 4 (ordinary Windows process; no LPAC qualification)");
    return ok ? 0 : 1;
}
