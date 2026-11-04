/*
 * probe_evloop.c - runtime-row probe (event loop), build configuration for
 * Genode qualification, not Writ implementation. Genode component lane,
 * Task 3. It stands in for the Bend runtime's io_loop, which on base-linux
 * stops at its stack guard before it opens its wake pipe.
 *
 * Repeats the runtime's sequence: signal(SIGPIPE, SIG_IGN), pipe, and
 * fcntl(F_SETFL, O_NONBLOCK) on the read end. Then it checks that a read of
 * the empty pipe returns EAGAIN instead of blocking, that select with a zero
 * timeout reports nothing ready, and that select blocks until a helper
 * thread writes one wake byte (the way an IO helper wakes the loop), after
 * which the byte is read back. Exit value 0 only if every step behaves so;
 * otherwise exit value 1 after naming the step.
 */
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <sys/select.h>
#include <time.h>
#include <unistd.h>

static int fd[2];

static int fail(const char *what)
{
	printf("probe_evloop: %s failed (errno %d)\n", what, errno);
	return 1;
}

static void *helper(void *arg)
{
	struct timespec d = { 0, 50 * 1000 * 1000 };
	(void)arg;
	nanosleep(&d, NULL);
	char c = 'w';
	if (write(fd[1], &c, 1) != 1)
		printf("probe_evloop: helper write failed\n");
	return NULL;
}

int main(void)
{
	char c;
	fd_set rd;
	struct timeval zero = { 0, 0 }, wait = { 5, 0 };
	pthread_t t;

	signal(SIGPIPE, SIG_IGN);
	if (pipe(fd) | fcntl(fd[0], F_SETFL, O_NONBLOCK))
		return fail("pipe or fcntl(O_NONBLOCK)");
	errno = 0;
	if (read(fd[0], &c, 1) != -1 || errno != EAGAIN)
		return fail("non-blocking read of the empty pipe (want EAGAIN)");
	printf("probe_evloop: empty non-blocking read gave EAGAIN\n");
	FD_ZERO(&rd); FD_SET(fd[0], &rd);
	if (select(fd[0] + 1, &rd, NULL, NULL, &zero) != 0)
		return fail("select with zero timeout on the empty pipe (want 0)");
	if (pthread_create(&t, NULL, helper, NULL))
		return fail("pthread_create");
	FD_ZERO(&rd); FD_SET(fd[0], &rd);
	if (select(fd[0] + 1, &rd, NULL, NULL, &wait) != 1 || !FD_ISSET(fd[0], &rd))
		return fail("select waiting for the helper's wake byte");
	if (read(fd[0], &c, 1) != 1 || c != 'w')
		return fail("read of the wake byte");
	printf("probe_evloop: select woke on the helper's byte and read it back\n");
	return 0;
}
