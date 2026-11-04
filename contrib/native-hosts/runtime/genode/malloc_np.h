/* QuickJS selects this FreeBSD allocator header for Genode's libc. The libc
 * does not expose malloc_usable_size, so the complete allocation boundary is
 * supplied by quickjs_alloc.c and its exact private size records instead. */
#ifndef WRIT_GENODE_MALLOC_NP_H
#define WRIT_GENODE_MALLOC_NP_H
#include "quickjs_alloc.h"
#endif
