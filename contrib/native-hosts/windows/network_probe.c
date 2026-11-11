/* Native effect observations only. No Writ policy or worker-profile changes. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include "network_probe.h"

static BOOL network_denied(int family, int type, unsigned short port,
    unsigned int *stage, DWORD *error)
{
    *stage = WRIT_NETWORK_SOCKET;
    SOCKET socket_handle = socket(family, type, type == SOCK_STREAM ? IPPROTO_TCP : IPPROTO_UDP);
    if (socket_handle == INVALID_SOCKET) {
        *error = WSAGetLastError();
        return *error == WSAEACCES;
    }
    BOOL denied = FALSE;
    SOCKADDR_STORAGE destination;
    int length;
    ZeroMemory(&destination, sizeof(destination));
    if (family == AF_INET) {
        SOCKADDR_IN *address = (SOCKADDR_IN *)&destination;
        address->sin_family = AF_INET; address->sin_port = htons(port);
        address->sin_addr.s_addr = htonl(INADDR_LOOPBACK); length = sizeof(*address);
    } else {
        SOCKADDR_IN6 *address = (SOCKADDR_IN6 *)&destination;
        address->sin6_family = AF_INET6; address->sin6_port = htons(port);
        address->sin6_addr = in6addr_loopback; length = sizeof(*address);
    }
    static const char canary[] = "writ-public-egress-canary";
    int result;
    u_long nonblocking = 1;
    *stage = WRIT_NETWORK_NONBLOCKING;
    if (ioctlsocket(socket_handle, FIONBIO, &nonblocking) == SOCKET_ERROR) {
        *error = WSAGetLastError();
        goto done;
    }
    if (type == SOCK_DGRAM) {
        *stage = WRIT_NETWORK_SENDTO;
        result = sendto(socket_handle, canary, sizeof(canary), 0, (SOCKADDR *)&destination, length);
        *error = result == SOCKET_ERROR ? WSAGetLastError() : 0;
    } else {
        *stage = WRIT_NETWORK_CONNECT;
        result = connect(socket_handle, (SOCKADDR *)&destination, length);
        *error = result == SOCKET_ERROR ? WSAGetLastError() : 0;
        if (*error == WSAEWOULDBLOCK || *error == WSAEINPROGRESS) {
            fd_set writable, exceptional;
            TIMEVAL timeout = { 2, 0 };
            FD_ZERO(&writable); FD_ZERO(&exceptional);
            FD_SET(socket_handle, &writable); FD_SET(socket_handle, &exceptional);
            *stage = WRIT_NETWORK_SELECT;
            result = select(0, NULL, &writable, &exceptional, &timeout);
            if (result <= 0) {
                *error = result == 0 ? WSAETIMEDOUT : WSAGetLastError();
                goto done;
            }
            int value = 0, size = sizeof(value);
            *stage = WRIT_NETWORK_STATUS_QUERY;
            if (getsockopt(socket_handle, SOL_SOCKET, SO_ERROR, (char *)&value, &size) == SOCKET_ERROR) {
                *error = WSAGetLastError();
                goto done;
            }
            if (size != (int)sizeof(value)) {
                *error = WSAEFAULT;
                goto done;
            }
            *stage = WRIT_NETWORK_CONNECT_RESULT;
            *error = (DWORD)value;
        }
        /* An established connection never earns denial credit, even if this
         * optional fixed-canary send fails. The receiver is a positive control. */
        if (!*error) send(socket_handle, canary, sizeof(canary), 0);
    }
    /* Only an operation's result earns denial credit. Failed setup, readiness
     * inspection or SO_ERROR retrieval exits above with denied still false. */
    denied = *error == WSAEACCES;
done:
    closesocket(socket_handle);
    return denied;
}

void writ_network_checks(WRIT_PROBE_REPORT *report, const unsigned short ports[4])
{
    WSADATA data;
    int initialized = WSAStartup(MAKEWORD(2,2), &data);
    const int families[4] = { AF_INET, AF_INET6, AF_INET, AF_INET6 };
    const int types[4] = { SOCK_STREAM, SOCK_STREAM, SOCK_DGRAM, SOCK_DGRAM };
    const unsigned int bits[4] = { WRIT_PROBE_TCP4, WRIT_PROBE_TCP6, WRIT_PROBE_UDP4, WRIT_PROBE_UDP6 };
    report->network_startup_error = (unsigned int)initialized;
    report->passed &= ~WRIT_PROBE_NETWORK_MASK;
    report->failed &= ~WRIT_PROBE_NETWORK_MASK;
    for (unsigned int i = 0; i < 4; ++i) {
        DWORD error = 0;
        report->network_stage[i] = WRIT_NETWORK_STARTUP;
        BOOL denied = initialized == 0 &&
            network_denied(families[i], types[i], ports[i], &report->network_stage[i], &error);
        /* A startup failure is reported once. No endpoint API ran, so its
         * operation error stays zero; the stage and failed bit mark incomplete. */
        report->errors[7 + i] = error;
        if (denied) report->passed |= bits[i]; else report->failed |= bits[i];
    }
    if (!initialized) WSACleanup();
}
