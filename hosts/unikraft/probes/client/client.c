/*
 * HOST-SIDE SCAFFOLDING, NOT WRIT CODE AND NOT AN AUTHORITY.
 *
 * Writ channel client probe for the Unikraft monitor image (Unikraft
 * effect-twins lane, Task 2). It runs on the Linux host, connects to the
 * Unix socket QEMU binds the image's second serial port to
 * (-serial unix:<path>,server=on,wait=off), and writes request frames in the
 * layout of hosts/unikraft/effects/Channel.md: a 16-byte header (length 64,
 * sequence, two reserved words 0) and the 64-byte record. After each frame it
 * reads the 80-byte result frame and prints both as hex with the decoded
 * decision and reason. It decides nothing: the words it sends are the
 * SYNTHETIC examples/Scenario.bend plan, and the route subject is not one of
 * them (the image has it built in). Nothing here is linked into an image.
 *
 * Usage: client SOCKET RECORD...
 *   RECORD is one of
 *     accept  reader R's session 1 at revision 6, the report-to-summary plan
 *     other   the same plan, but the body names subject S's session 2
 *     badver  accept with version word 2 (Bend refuses: bad record)
 *     badlen  accept with header length 65 (host.c refuses: transport refusal)
 * Sequence words count from 1 in argument order. Exit status: 0 when every
 * reply arrived and answered its request's sequence, 1 on a socket error,
 * a short read, or a sequence mismatch, 2 on bad usage.
 */

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define FRAME_BYTES  80
#define RECORD_WORDS 16

static void put_word(unsigned char *p, uint32_t v)
{
	p[0] = v & 0xff; p[1] = (v >> 8) & 0xff; p[2] = (v >> 16) & 0xff; p[3] = v >> 24;
}

static uint32_t get_word(const unsigned char *p)
{
	return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24;
}

/* SYNTHETIC record words (Channel.md, request record): the Scenario plan. */
static int build(const char *name, uint32_t sequence, unsigned char *frame)
{
	uint32_t r[RECORD_WORDS] = {
		1, 1, 1, 6, /* version, kind, session, expected_session */
		1, 2, 3,    /* graph, policy, authority epochs */
		99, 10, 1, 20, 1, /* invocation, source object/version, destination object/version */
		1, 0, 0, 0  /* claimed_subject (untrusted), reserved */
	};
	uint32_t length = 64;
	int i;

	if (!strcmp(name, "accept")) {
	} else if (!strcmp(name, "other")) {
		r[2] = 2; r[3] = 0; r[12] = 2;
	} else if (!strcmp(name, "badver")) {
		r[0] = 2;
	} else if (!strcmp(name, "badlen")) {
		length = 65;
	} else {
		return -1;
	}
	memset(frame, 0, FRAME_BYTES);
	put_word(frame + 0, length);
	put_word(frame + 4, sequence);
	for (i = 0; i < RECORD_WORDS; i++)
		put_word(frame + 16 + 4 * i, r[i]);
	return 0;
}

static void dump(const char *label, const unsigned char *frame)
{
	int i, j;

	printf("%s header        :", label);
	for (i = 0; i < 16; i++)
		printf(" %02x", frame[i]);
	printf("\n");
	for (j = 0; j < 4; j++) {
		printf("%s record +0x%02x :", label, 16 * j);
		for (i = 0; i < 16; i++)
			printf(" %02x", frame[16 + 16 * j + i]);
		printf("\n");
	}
}

static const char *decision_name(uint32_t kind, uint32_t d)
{
	if (kind == 3 && d == 3)
		return "transport refusal (host.c, not a Writ decision)";
	if (kind == 2 && d == 1)
		return "Committed";
	if (kind == 2 && d == 2)
		return "Denied";
	return "unknown";
}

static int full(int fd, unsigned char *buf, size_t n, int writing)
{
	size_t done = 0;

	while (done < n) {
		ssize_t k = writing ? write(fd, buf + done, n - done) : read(fd, buf + done, n - done);

		if (k < 0 && errno == EINTR)
			continue;
		if (k <= 0)
			return -1;
		done += (size_t)k;
	}
	return 0;
}

int main(int argc, char **argv)
{
	struct sockaddr_un a;
	int fd, i;

	if (argc < 3) {
		fprintf(stderr, "usage: client SOCKET RECORD...\n");
		return 2;
	}
	memset(&a, 0, sizeof(a));
	a.sun_family = AF_UNIX;
	if (strlen(argv[1]) >= sizeof(a.sun_path)) {
		fprintf(stderr, "client: socket path too long\n");
		return 2;
	}
	strcpy(a.sun_path, argv[1]);
	for (i = 2; i < argc; i++) {
		unsigned char f[FRAME_BYTES];

		if (build(argv[i], 0, f)) {
			fprintf(stderr, "client: unknown record %s\n", argv[i]);
			return 2;
		}
	}
	fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0 || connect(fd, (struct sockaddr *)&a, sizeof(a))) {
		perror("client: connect");
		return 1;
	}
	for (i = 2; i < argc; i++) {
		unsigned char req[FRAME_BYTES], rep[FRAME_BYTES];
		uint32_t seq = (uint32_t)(i - 1);

		build(argv[i], seq, req);
		printf("request %u (%s)\n", seq, argv[i]);
		dump(" sent", req);
		if (full(fd, req, sizeof(req), 1) || full(fd, rep, sizeof(rep), 0)) {
			fprintf(stderr, "client: socket error or short read at request %u\n", seq);
			return 1;
		}
		dump(" got ", rep);
		printf(" reply: length=%u sequence=%u kind=%u decision=%u (%s) reason=%u\n",
		       get_word(rep), get_word(rep + 4), get_word(rep + 20), get_word(rep + 24),
		       decision_name(get_word(rep + 20), get_word(rep + 24)), get_word(rep + 28));
		if (get_word(rep + 4) != seq || get_word(rep) != 64) {
			fprintf(stderr, "client: reply does not answer request %u\n", seq);
			return 1;
		}
	}
	close(fd);
	return 0;
}
