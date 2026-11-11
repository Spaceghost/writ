/* Deterministic API faults against the production probe. No real restricted
 * process or confinement claim: API replacement exists only in this test TU. */
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "network_probe.h"

_Static_assert(sizeof(WRIT_PROBE_REPORT) == 120, "fixed version-2 report ABI");

static unsigned int assertions;
static void check(int condition, const char *name)
{
    if (!condition) { fprintf(stderr, "FAIL network evidence: %s\n", name); exit(1); }
    ++assertions;
}

static struct {
    int startup_error, socket_error, nonblocking_error, connect_error;
    int wait_result, wait_error, query_error, query_size, connection_error;
    int datagram_error, send_error;
} fault;
static struct {
    unsigned int startup, cleanup, sockets, nonblocking, connect, wait, query;
    unsigned int datagram, send, close;
} calls;
static int last_error;
static const unsigned short receiver_ports[4] = { 41001, 41002, 41003, 41004 };
static unsigned int live_sockets;

static int WSAAPI test_startup(WORD version, LPWSADATA data)
{
    check(version == MAKEWORD(2,2), "fixed Winsock version");
    ++calls.startup;
    ZeroMemory(data, sizeof(*data));
    last_error = WSAEACCES; /* Deliberately different from startup's own result. */
    return fault.startup_error;
}
static int WSAAPI test_cleanup(void) { ++calls.cleanup; return 0; }
static int WSAAPI test_last_error(void) { return last_error; }
static SOCKET WSAAPI test_socket(int family, int type, int protocol)
{
    unsigned int i = calls.sockets++;
    check(i < 4, "at most four fixed endpoints");
    check(family == (i % 2 ? AF_INET6 : AF_INET), "endpoint address family");
    check(type == (i < 2 ? SOCK_STREAM : SOCK_DGRAM), "endpoint socket type");
    check(protocol == (i < 2 ? IPPROTO_TCP : IPPROTO_UDP), "endpoint protocol");
    if (fault.socket_error) { last_error = fault.socket_error; return INVALID_SOCKET; }
    ++live_sockets;
    return (SOCKET)(100 + i);
}
static int WSAAPI test_close(SOCKET socket_handle)
{
    check(socket_handle >= 100 && socket_handle < 104 && live_sockets == 1,
        "close only the current owned socket once");
    --live_sockets; ++calls.close;
    return 0;
}
static int WSAAPI test_nonblocking(SOCKET socket_handle, long command, u_long *enabled)
{
    (void)socket_handle;
    ++calls.nonblocking;
    check(command == (long)FIONBIO && *enabled == 1, "nonblocking mode is required");
    if (fault.nonblocking_error) { last_error = fault.nonblocking_error; return SOCKET_ERROR; }
    return 0;
}
static void destination(SOCKET socket_handle, const struct sockaddr *address, int size)
{
    check(socket_handle >= 100 && socket_handle < 104, "known endpoint handle");
    unsigned int i = (unsigned int)(socket_handle - 100);
    if (i % 2) {
        const SOCKADDR_IN6 *v6 = (const SOCKADDR_IN6 *)address;
        check(size == (int)sizeof(*v6) && v6->sin6_family == AF_INET6 &&
            ntohs(v6->sin6_port) == receiver_ports[i] &&
            !memcmp(&v6->sin6_addr, &in6addr_loopback, sizeof(v6->sin6_addr)), "fixed IPv6 loopback destination");
    } else {
        const SOCKADDR_IN *v4 = (const SOCKADDR_IN *)address;
        check(size == (int)sizeof(*v4) && v4->sin_family == AF_INET &&
            ntohs(v4->sin_port) == receiver_ports[i] && ntohl(v4->sin_addr.s_addr) == INADDR_LOOPBACK,
            "fixed IPv4 loopback destination");
    }
}
static int WSAAPI test_connect(SOCKET socket_handle, const struct sockaddr *address, int size)
{
    ++calls.connect; destination(socket_handle, address, size);
    if (fault.connect_error) { last_error = fault.connect_error; return SOCKET_ERROR; }
    return 0;
}
static int WSAAPI test_select(int count, fd_set *readable, fd_set *writable,
    fd_set *exceptional, const struct timeval *timeout)
{
    (void)count;
    ++calls.wait;
    check(!readable && writable->fd_count == 1 && exceptional->fd_count == 1 &&
        writable->fd_array[0] == exceptional->fd_array[0], "wait only for the owned connection");
    check(timeout->tv_sec == 2 && timeout->tv_usec == 0, "connect wait stays bounded");
    if (fault.wait_result == SOCKET_ERROR) last_error = fault.wait_error;
    return fault.wait_result;
}
static int WSAAPI test_getsockopt(SOCKET socket_handle, int level, int option, char *value, int *size)
{
    (void)socket_handle;
    ++calls.query;
    check(level == SOL_SOCKET && option == SO_ERROR && *size == (int)sizeof(int), "query exact connection status");
    if (fault.query_error) { last_error = fault.query_error; return SOCKET_ERROR; }
    memcpy(value, &fault.connection_error, sizeof(int));
    *size = fault.query_size;
    return 0;
}
static int WSAAPI test_send(SOCKET socket_handle, const char *bytes, int size, int flags)
{
    (void)socket_handle; (void)bytes; (void)flags;
    ++calls.send;
    if (fault.send_error) { last_error = fault.send_error; return SOCKET_ERROR; }
    return size;
}
static int WSAAPI test_sendto(SOCKET socket_handle, const char *bytes, int size, int flags,
    const struct sockaddr *address, int address_size)
{
    (void)bytes; (void)flags;
    ++calls.datagram; destination(socket_handle, address, address_size);
    if (fault.datagram_error) { last_error = fault.datagram_error; return SOCKET_ERROR; }
    return size;
}

/* Do not expose a configurable API table or injection hook in production. */
#define WSAStartup test_startup
#define WSACleanup test_cleanup
#define WSAGetLastError test_last_error
#define socket test_socket
#define closesocket test_close
#define ioctlsocket test_nonblocking
#define connect test_connect
#define select test_select
#define getsockopt test_getsockopt
#define send test_send
#define sendto test_sendto
#include "network_probe.c"
#undef WSAStartup
#undef WSACleanup
#undef WSAGetLastError
#undef socket
#undef closesocket
#undef ioctlsocket
#undef connect
#undef select
#undef getsockopt
#undef send
#undef sendto

static void reset(void)
{
    ZeroMemory(&fault, sizeof(fault)); ZeroMemory(&calls, sizeof(calls));
    check(live_sockets == 0, "previous case released its sockets");
    fault.connect_error = WSAEWOULDBLOCK;
    fault.wait_result = 1;
    fault.query_size = sizeof(int);
}

static WRIT_PROBE_REPORT run(const char *name, unsigned int passed,
    unsigned int tcp_stage, unsigned int tcp_error, unsigned int udp_stage, unsigned int udp_error)
{
    WRIT_PROBE_REPORT report = {0};
    report.magic = WRIT_PROBE_MAGIC; report.phase = 1;
    /* Stale network bits must be replaced without changing unrelated checks. */
    report.passed = WRIT_PROBE_READ | WRIT_PROBE_NETWORK_MASK;
    report.failed = WRIT_PROBE_CHILD | WRIT_PROBE_NETWORK_MASK;
    writ_network_checks(&report, receiver_ports);
    check(report.passed == (WRIT_PROBE_READ | passed), "only observed denials pass");
    check(report.failed == (WRIT_PROBE_CHILD | (WRIT_PROBE_NETWORK_MASK & ~passed)), "incomplete or open routes fail");
    check(report.network_startup_error == (unsigned int)fault.startup_error, "startup owns its error once");
    for (unsigned int i = 0; i < 4; ++i) {
        check(report.network_stage[i] == (i < 2 ? tcp_stage : udp_stage), "terminal operation stage");
        check(report.errors[7 + i] == (i < 2 ? tcp_error : udp_error), "endpoint API error");
    }
    check(writ_network_report_valid(&report, WRIT_PROBE_NETWORK_MASK), "receiver accepts truthful incomplete reports");
    check(calls.startup == 1 && calls.cleanup == (fault.startup_error ? 0u : 1u), "balanced Winsock initialization");
    check(calls.sockets == (fault.startup_error ? 0u : 4u), "no endpoint after failed startup");
    check(calls.close == (fault.startup_error || fault.socket_error ? 0u : 4u) && live_sockets == 0,
        "every created socket closed on success and failure");
    if (fault.startup_error || fault.socket_error || fault.nonblocking_error)
        check(!calls.connect && !calls.wait && !calls.query && !calls.datagram && !calls.send,
            "failed setup never reaches network effect APIs");
    printf("PASS network evidence: %s\n", name);
    return report;
}

int main(void)
{
    const unsigned int tcp = WRIT_PROBE_TCP4 | WRIT_PROBE_TCP6;
    const unsigned int udp = WRIT_PROBE_UDP4 | WRIT_PROBE_UDP6;
    reset(); fault.startup_error = WSASYSCALLFAILURE;
    run("startup failure is not four observed socket errors", 0, WRIT_NETWORK_STARTUP, 0, WRIT_NETWORK_STARTUP, 0);
    reset(); fault.startup_error = WSAEACCES;
    run("startup access error earns no denial credit", 0, WRIT_NETWORK_STARTUP, 0, WRIT_NETWORK_STARTUP, 0);
    reset(); fault.socket_error = WSAEACCES;
    run("socket access denial is explicit", tcp | udp, WRIT_NETWORK_SOCKET, WSAEACCES, WRIT_NETWORK_SOCKET, WSAEACCES);
    reset(); fault.socket_error = WSAEAFNOSUPPORT;
    run("unsupported family is incomplete", 0, WRIT_NETWORK_SOCKET, WSAEAFNOSUPPORT, WRIT_NETWORK_SOCKET, WSAEAFNOSUPPORT);
    reset(); fault.nonblocking_error = WSAEACCES;
    run("nonblocking setup access error is incomplete", 0, WRIT_NETWORK_NONBLOCKING, WSAEACCES, WRIT_NETWORK_NONBLOCKING, WSAEACCES);
    reset(); fault.wait_result = SOCKET_ERROR; fault.wait_error = WSAEACCES;
    run("select access error is not a connection denial", 0, WRIT_NETWORK_SELECT, WSAEACCES, WRIT_NETWORK_SENDTO, 0);
    reset(); fault.wait_result = 0;
    run("timeout is incomplete", 0, WRIT_NETWORK_SELECT, WSAETIMEDOUT, WRIT_NETWORK_SENDTO, 0);
    reset(); fault.query_error = WSAEACCES;
    run("SO_ERROR query access error is not a connection denial", 0, WRIT_NETWORK_STATUS_QUERY, WSAEACCES, WRIT_NETWORK_SENDTO, 0);
    reset(); fault.query_size = 1; fault.connection_error = WSAEACCES;
    run("short SO_ERROR result is incomplete", 0, WRIT_NETWORK_STATUS_QUERY, WSAEFAULT, WRIT_NETWORK_SENDTO, 0);
    reset(); fault.connection_error = WSAEACCES;
    WRIT_PROBE_REPORT valid = run("successful SO_ERROR query can report connection denial", tcp,
        WRIT_NETWORK_CONNECT_RESULT, WSAEACCES, WRIT_NETWORK_SENDTO, 0);
    reset(); fault.connection_error = WSAECONNREFUSED;
    run("connection refusal is not access denial", 0, WRIT_NETWORK_CONNECT_RESULT, WSAECONNREFUSED, WRIT_NETWORK_SENDTO, 0);
    reset(); fault.connect_error = WSAEACCES; fault.datagram_error = WSAEACCES;
    run("direct TCP and UDP access denials", tcp | udp, WRIT_NETWORK_CONNECT, WSAEACCES, WRIT_NETWORK_SENDTO, WSAEACCES);
    check(calls.query == 0 && calls.wait == 0, "direct denial does not inspect a pending connection");
    reset(); fault.connect_error = WSAECONNREFUSED; fault.datagram_error = WSAEACCES;
    run("each endpoint retains its own outcome", udp, WRIT_NETWORK_CONNECT, WSAECONNREFUSED, WRIT_NETWORK_SENDTO, WSAEACCES);
    reset(); fault.connect_error = 0;
    run("successful direct connections never pass denial checks", 0, WRIT_NETWORK_CONNECT, 0, WRIT_NETWORK_SENDTO, 0);
    reset(); fault.connect_error = WSAEINPROGRESS; fault.send_error = WSAEACCES;
    run("send error after connected TCP earns no denial credit", 0, WRIT_NETWORK_CONNECT_RESULT, 0, WRIT_NETWORK_SENDTO, 0);
    reset(); fault.datagram_error = WSAENETUNREACH;
    run("unreachable UDP is incomplete", 0, WRIT_NETWORK_CONNECT_RESULT, 0, WRIT_NETWORK_SENDTO, WSAENETUNREACH);

    WRIT_PROBE_REPORT bad = valid;
    bad.network_stage[0] = WRIT_NETWORK_STATUS_QUERY;
    check(!writ_network_report_valid(&bad, WRIT_PROBE_NETWORK_MASK), "receiver rejects query error marked passed");
    bad = valid; bad.network_stage[0] = 99;
    check(!writ_network_report_valid(&bad, WRIT_PROBE_NETWORK_MASK), "receiver rejects unknown stage");
    bad = valid; bad.network_stage[0] = WRIT_NETWORK_SENDTO;
    check(!writ_network_report_valid(&bad, WRIT_PROBE_NETWORK_MASK), "receiver rejects TCP/datagram stage mismatch");
    bad = valid; bad.network_stage[2] = WRIT_NETWORK_CONNECT_RESULT;
    check(!writ_network_report_valid(&bad, WRIT_PROBE_NETWORK_MASK), "receiver rejects UDP/connection stage mismatch");
    bad = valid; bad.magic = 0x57525031u;
    check(!writ_network_report_valid(&bad, WRIT_PROBE_NETWORK_MASK), "receiver rejects old report version");
    bad = valid; bad.network_startup_error = WSASYSCALLFAILURE;
    check(!writ_network_report_valid(&bad, WRIT_PROBE_NETWORK_MASK), "receiver rejects endpoint claim after failed startup");
    bad = valid; bad.failed |= WRIT_PROBE_TCP4;
    check(!writ_network_report_valid(&bad, WRIT_PROBE_NETWORK_MASK), "receiver rejects overlapping results");
    check(!writ_network_report_valid(&valid, 0), "receiver rejects network stages in a phase without network checks");
    ZeroMemory(&bad, sizeof(bad)); bad.magic = WRIT_PROBE_MAGIC;
    check(writ_network_report_valid(&bad, 0), "phase without network checks remains empty");
    printf("PASS network evidence assertions: %u (synthetic API faults; no LPAC qualification)\n", assertions);
    return 0;
}
