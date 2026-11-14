/* SHA-256 (FIPS 180-4) for the supervisor driver's role program digests.
   A native fact only: the driver reports the digest of the bytes it will
   execute; Bend compares it with the provisioned pin. */
#ifndef WRIT_SHA256_H
#define WRIT_SHA256_H

#include <stddef.h>
#include <stdint.h>

struct writ_sha256 {
    uint32_t state[8];
    uint64_t length;            /* bytes absorbed */
    unsigned char block[64];
    size_t used;                /* bytes in `block` */
};

void writ_sha256_init(struct writ_sha256 *h);
void writ_sha256_update(struct writ_sha256 *h, const void *data, size_t length);
void writ_sha256_final(struct writ_sha256 *h, unsigned char digest[32]);

#endif
