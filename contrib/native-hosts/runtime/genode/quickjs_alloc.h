#ifndef WRIT_QUICKJS_ALLOC_H
#define WRIT_QUICKJS_ALLOC_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void *writ_qjs_malloc(size_t);
void *writ_qjs_realloc(void *, size_t);
void writ_qjs_free(void *);
size_t writ_qjs_usable_size(void const *);
size_t writ_qjs_live_bytes(void);
size_t writ_qjs_reserved_bytes(void);
size_t writ_qjs_peak_bytes(void);
size_t writ_qjs_peak_reserved_bytes(void);
void writ_qjs_trim(void);
int writ_qjs_reset_peaks(void);

#ifdef __cplusplus
}
#endif
#endif
