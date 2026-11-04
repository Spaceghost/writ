/*
 * probe_fault.c - runtime-row probe (faults), build configuration for Genode
 * qualification, not Writ implementation. Genode component lane, Task 3.
 * It stands in for a Bend Overflow program, which on base-linux stops at
 * its stack guard (mprotect) before it installs its fault handler.
 *
 * Installs a handler the way the runtime's pool_stack does
 * (sigaltstack, then sigaction for SIGSEGV and SIGBUS with
 * SA_ONSTACK | SA_NODEFER), prints the return values, and then recurses
 * without bound so the machine stack overflows. The handler writes one
 * line and calls _exit(70), so the parent's report distinguishes the
 * outcomes: "handler reached" with exit value 70, or a fault reported by
 * the platform with no handler line. The line after the recursion must
 * never print: it would mean execution resumed past the fault.
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void trap(int sig)
{
	static char const line[] = "probe_fault: handler reached\n";
	(void)sig;
	if (write(1, line, sizeof line - 1)) { }
	_exit(70);
}

/* Non-tail recursion: the volatile frame and the use after the call keep
 * the compiler from turning it into a loop. */
static __attribute__((noinline)) long deep(long n)
{
	volatile char frame[256];
	frame[0] = (char)n;
	return deep(n + 1) + frame[0];
}

int main(void)
{
	size_t alt = 4 * SIGSTKSZ;
	stack_t ss;
	struct sigaction sa;

	memset(&ss, 0, sizeof ss);
	ss.ss_sp = malloc(alt);
	ss.ss_size = alt;
	memset(&sa, 0, sizeof sa);
	sa.sa_handler = trap;
	sa.sa_flags = SA_ONSTACK | SA_NODEFER;
	int r0 = sigaltstack(&ss, NULL);
	int r1 = sigaction(SIGSEGV, &sa, NULL);
	int r2 = sigaction(SIGBUS, &sa, NULL);
	printf("probe_fault: sigaltstack=%d sigaction(SIGSEGV)=%d sigaction(SIGBUS)=%d\n",
	       r0, r1, r2);
	printf("probe_fault: recursing past the stack\n");
	fflush(stdout);
	long v = deep(0);
	printf("probe_fault: resumed after overflow (%ld)\n", v);
	return 0;
}
