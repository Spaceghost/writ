/* Synthetic test-only ABI observation; not an endpoint or authority fact. */
#include "../capture.h"
#include <stddef.h>

size_t writ_handoff_test_layout(unsigned selector)
{
    switch (selector) {
    case 0: return sizeof(struct writ_pair_snapshot);
    case 1: return offsetof(struct writ_pair_snapshot, manifest);
    case 2: return offsetof(struct writ_pair_snapshot, status);
    case 3: return offsetof(struct writ_pair_snapshot, manifest_size);
    case 4: return offsetof(struct writ_pair_snapshot, status_size);
    case 5: return sizeof(((struct writ_pair_snapshot *)0)->manifest);
    case 6: return sizeof(((struct writ_pair_snapshot *)0)->status);
    case 7: return sizeof(((struct writ_pair_snapshot *)0)->manifest_size);
    case 8: return sizeof(((struct writ_pair_snapshot *)0)->status_size);
    default: return (size_t)-1;
    }
}
