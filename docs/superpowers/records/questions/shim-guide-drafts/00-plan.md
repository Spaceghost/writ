# Reading plan: hosts/genode/shim/writ_mem.cc for GB-006 (task 2.2)

File: 1,919 lines, sha256 9d9d32d2402bd947c96a4632ae945c6825d1291a3ce97e5ac45b7d0349f71b5d
(matches INVENTORY.md:643). Every line of the file is covered by exactly one
page except blank lines and banner comments. The header comment (1-239) is
split across the pages whose code it explains.

| # | Page | Lines | What it does | GB-006 claim it bears on | Est. |
|---|------|-------|--------------|--------------------------|------|
| 1 | 01-overview-and-entry.html | 1-74, 241-302, 438-486, 1845-1919 | Self-description, build-time front-end choice, static bounds, process-lifetime state, component entry | Bounds are fixed constants, not caller- or config-driven; construct opens only inventoried sessions | 25 min |
| 2 | 02-posix-entry-points.html | 907-914, 1031-1137 | mmap/munmap/mprotect: shape filter, forwarding to libc, guard creation | Refusals mean "cannot do this exactly", never "this caller may not" | 15 min |
| 3 | 03-reservations.html | 378-435, 916-1028 | Reservation table, create (region map, hint placement), release | Fixed capacity bounds (1 TiB, 32 slots) and Linux hint semantics, not choices about the caller | 15 min |
| 4 | 04-population-and-charging.html | 153-189, 543-673 | Charging a 2 MiB chunk from the PD, RM-session upgrades, attach pieces around guards | Genode quota accounting with fixed margins; no Writ budget accounting; never a parent resource request | 20 min |
| 5 | 05-fault-base-linux.html | 76-94, 213-239, 305-375, 487-541, 680-776 | The shared _resolve_fault decision; base-linux raw SIGSEGV handler; retry table | MAX_RETRIES is a bounded mechanical limit; refusal kills, never redirects | 20 min |
| 6 | 06-fault-base-hw.html | 95-151, 190-211, 778-900 | base-hw Region_map fault handler on the writ_fault entrypoint; Parent::exit(139) | Refusal is mechanical; exit 139 is a reporting convention (a GB-003 evidence limit, not a decision) | 25 min |
| 7 | 07-console-and-time.html | 1140-1287 | Genode.log/now/sleep host functions; Timer route probe; fail-stop on a bad clock | The effects move bytes or read a clock; Bend decides what and when; exit 1 is host failure handling | 15 min |
| 8 | 08-channel-sessions-and-identity.html | 1289-1333, 1402-1476, 1521-1667 | Writ_channel service, per-session buckets, the label-to-subject lookup, session admission and close | The highest-risk page: does the identity-binding rule (label/label_prefix only) count as policy? | 25 min |
| 9 | 09-channel-take-put-refusal.html | 1334-1400, 1478-1519, 1669-1842 | Ring queue, take (copy once), put (copy back unread), fixed transport refusal, close event, report | The one shim-authored result is a fixed transport refusal outside the monitor's decision words | 20 min |
| 10 | 10-verdict.html | (whole file) | Inventory summary: exported symbols, sessions, where each effect is admitted | Asks for the GB-006 verdict | 10 min |

Estimated total: about 3 hours 10 minutes (two sittings are reasonable: pages 1-5, then 6-10).
