/*
 * probe_clock.c - runtime-row probe (clock), build configuration for Genode
 * qualification, not Writ implementation. Genode component lane, Task 3.
 * It stands in for a Bend program printing IO.now() twice around
 * IO.sleep(100), which cannot reach main's evaluation on base-linux until
 * the memory row is fixed.
 *
 * Reads clock_gettime(CLOCK_MONOTONIC), sleeps 100 ms with nanosleep, and
 * reads the clock again. Exit value 0 only if both reads succeed, the
 * second is later than the first, and at least 100 ms elapsed; otherwise
 * exit value 1 after printing which check failed. libc serves both calls
 * from the Timer session that the run script routes to the timer
 * component.
 */
#include <stdio.h>
#include <time.h>

static long long ns(struct timespec t)
{
	return (long long)t.tv_sec * 1000000000LL + t.tv_nsec;
}

int main(void)
{
	struct timespec a, b, d = { 0, 100 * 1000 * 1000 };
	if (clock_gettime(CLOCK_MONOTONIC, &a)) {
		printf("probe_clock: first clock_gettime failed\n");
		return 1;
	}
	if (nanosleep(&d, NULL)) {
		printf("probe_clock: nanosleep failed\n");
		return 1;
	}
	if (clock_gettime(CLOCK_MONOTONIC, &b)) {
		printf("probe_clock: second clock_gettime failed\n");
		return 1;
	}
	long long delta = ns(b) - ns(a);
	printf("probe_clock: t0=%lld ns t1=%lld ns delta=%lld ns\n", ns(a), ns(b), delta);
	if (delta <= 0) {
		printf("probe_clock: not monotonic\n");
		return 1;
	}
	if (delta < 100LL * 1000 * 1000) {
		printf("probe_clock: slept less than 100 ms\n");
		return 1;
	}
	printf("probe_clock: monotonic, slept at least 100 ms\n");
	return 0;
}
