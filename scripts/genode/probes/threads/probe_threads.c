/*
 * probe_threads.c - runtime-row probe (threads), build configuration for
 * Genode qualification, not Writ implementation. Genode component lane,
 * Task 3. It stands in for running a Bend program with --threads 2, which
 * cannot reach its worker pool on base-linux until the memory row is fixed
 * (the runtime stops at its stack guard before main's evaluation).
 *
 * Exercises the calls the runtime's pool uses: pthread_create,
 * pthread_detach, a mutex, a condvar (wait, signal, broadcast), and
 * sched_yield. Two lanes start, block on a shared condvar until main
 * broadcasts, each report back under the mutex, and main waits on a second
 * condvar until both have reported. Exit value 0 only if both lanes ran;
 * any failed call exits with value 1 after naming it.
 */
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t  go_cv = PTHREAD_COND_INITIALIZER;
static pthread_cond_t  done_cv = PTHREAD_COND_INITIALIZER;
static int go, started, done;

static void *lane(void *arg)
{
	int id = (int)(long)arg;
	pthread_mutex_lock(&lock);
	started += 1;
	printf("probe_threads: lane %d started\n", id);
	while (!go)
		pthread_cond_wait(&go_cv, &lock);
	done += 1;
	pthread_cond_signal(&done_cv);
	pthread_mutex_unlock(&lock);
	return NULL;
}

int main(void)
{
	for (long i = 1; i <= 2; i++) {
		pthread_t t;
		if (pthread_create(&t, NULL, lane, (void *)i)) {
			printf("probe_threads: pthread_create failed\n");
			exit(1);
		}
		if (pthread_detach(t)) {
			printf("probe_threads: pthread_detach failed\n");
			exit(1);
		}
	}
	/* Yield until both lanes are waiting, as the pool's POOL_WAIT does. */
	for (;;) {
		pthread_mutex_lock(&lock);
		int s = started;
		pthread_mutex_unlock(&lock);
		if (s == 2) break;
		sched_yield();
	}
	pthread_mutex_lock(&lock);
	go = 1;
	pthread_cond_broadcast(&go_cv);
	while (done < 2)
		pthread_cond_wait(&done_cv, &lock);
	pthread_mutex_unlock(&lock);
	printf("probe_threads: both lanes woke by broadcast and reported (done=%d)\n", done);
	return 0;
}
