/*
 * probe_process.c - runtime-row probe (process), build configuration for
 * Genode qualification, not Writ implementation. Genode component lane,
 * Task 3. The Bend program itself also exercises getenv("BENDRTS") and its
 * exit status through writ_bend_rts.run; this probe adds the calls that
 * run cannot show.
 *
 * Prints getenv("BENDRTS") (set by the run script's <env> node),
 * getenv of an unset name, and sysconf(_SC_NPROCESSORS_ONLN), then
 * leaves through exit(3), so the run script can check that the parent
 * reports exit value 3. sched_getaffinity and cgroup cpu.max are Linux-only
 * blocks that the Genode build of the runtime compiles out, so they are
 * not probed.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void)
{
	char const *v = getenv("BENDRTS");
	char const *u = getenv("WRIT_PROBE_UNSET");
	printf("probe_process: BENDRTS=\"%s\"\n", v ? v : "(null)");
	printf("probe_process: WRIT_PROBE_UNSET is %s\n", u ? "set" : "unset");
	printf("probe_process: sysconf(_SC_NPROCESSORS_ONLN)=%ld\n",
	       sysconf(_SC_NPROCESSORS_ONLN));
	printf("probe_process: calling exit(3)\n");
	fflush(stdout);
	exit(3);
}
