# Native boundary review record

Review was performed across platform ownership, in addition to executing the
native probes. The shared Bend state/authority path was reviewed under its
documented private-supervisor and fixed-public-profile assumptions. No concrete
authorization bypass was found within that scope. Broader issuer, durable state,
arbitrary-worker and human-attribution requirements remain separate.

| Finding | Correction and evidence boundary |
| --- | --- |
| WinFsp returned invalid-function before the first admitted open because required Create/Overwrite callbacks were absent | Added explicit denied mutation callbacks; later real native runs reach Bend and pass mounted reads/ranges/EOF/listing. This is an ABI requirement, not an alternate authorization path. |
| Windows identity fields and SID storage could be freed while filesystem callbacks still used them | Terminate/wait first, quiesce the dispatcher, then release retained identity resources. Late callback failures are propagated into the final result. |
| A failed Windows image-path format could leave an unowned path eligible for cleanup | Track successful directory and file creation explicitly; cleanup acts only on resources the fixture created. Truncation/failure does not confer ownership. |
| The elevated Windows CI broker initially produced an LPAC token that still reported elevation | Launch from an explicitly reduced primary token and verify its identity and elevation, then check the actual LPAC token and AccessCheck outcomes. The no-elevation requirement remains mandatory. |
| The default WinFsp volume denied the restricted process before any Bend callback | Set and read back the descriptor on the exact newly created volume, then verify the actual LPAC token. Restricted reads reach Bend while a different process with the same token remains denied. No global driver or device-class permissions change. |
| Clipboard, COM and child-process probes originally credited generic API failure | Require functioning positive controls and specific restriction outcomes. Missing DLL/export, class-not-registered or unrelated launch failures remain failures/incomplete evidence, never a confinement PASS. |
| A separate no-data diagnostic could otherwise confuse profile evidence or leave an exceptional child behind | Keep its process and report pipe separate from the admitted actor; verify its exact capability and Win32k configuration. Check receivers after each diagnostic and explicitly retire the owned process even if job readback fails. Its results never replace missing direct byte-worker evidence. |
| Windows pipe code accepted queued future replies and ignored some child-retirement failures | Reject pending unsolicited/trailing output, validate canonical sequence/fields, poison on faults, and report actual retained-process exit. [All 22 native transport assertions passed](../windows/verification/transport-41774496221.log) at the recorded source; that enclosing job still failed separate worker gates. |
| Linux temporary-file flag rejection also rejected directory opens | Mask the temporary-file creation bit independently of `O_DIRECTORY`. Actual native directory listing passes in the retained Linux record. |
| A Linux outsider could fail on inaccessible ancestors without reaching the Writ boundary | Use traversable trusted fixture ancestors and require real actor-0 Bend denial events, repeated after admitted lookup/stat paths are warm. |
| Genode's upstream packet helper computes offset plus size with unsigned wraparound | Validate the descriptor range independently with subtraction before asking the helper for content. Native probes include negative offset and `dataspace_end - 1`, `SIZE_MAX`, length eight; zero bytes and an unchanged buffer are required. |
| Genode names could otherwise accept an embedded-NUL prefix | Require exact native buffer size, terminator and bytes. Native malformed-name probes accompany the check. |
| The complete Genode mount corpus exceeded its 600-second deadline while copied substrings repeatedly allocated and unmapped native RAM | Reuse bounded native allocation reservations, including all cached capacity in the existing 64 MiB ceiling; report only requested usable lengths and release every reservation at interpreter teardown. Independent review covered overflow checks, cache indices, charging, realloc preservation and teardown. The same 69-vector corpus passes in the native guest without modifying generated policy or upstream engine algorithms. |

The Linux record preserves earlier directory/open and harness failures. The
Windows and Genode records preserve their own failed runs and the actual
results for later source revisions. Review and source changes alone are not
reported as native acceptance.

Windows run 41778041710 remains an overall failure. Its mounted-read and
revocation checks pass, but its byte-worker network, clipboard and COM probes
remain incomplete. A separate no-data LPAC helper with registry-read capability
and Win32k enabled passes seven configured diagnostic probes with and without
WFP. The helper's different profile receives no canary input, and its diagnostic
results do not complete the byte worker's confinement qualification.

The common maximum-payload fixtures still contain the exact same bytes after
their test helper changed from repeated prepending to logarithmic doubling.
The 64 KiB success, 64 KiB plus one-byte refusal, and oversized-frame assertions
were retained. The native guest passes the complete boundary corpus; a host
QuickJS pass did not waive that guest gate. Twenty-four allocator assertions
exercise the same runtime wrapper on the host and inside the native guest.
Per-platform evidence distinguishes local sanitizer results from the separate
clean CI run.

Concurrent master work was integrated from
`58cdbfa4c239de048467bd838e636fe2eab490c6`. Its HostBinding model, six laws,
runtime/unikernel evidence, tooling and pending task states were preserved.
The combined 782-core/41-vector output was rerun on both local backends and is
byte-identical; all 41 vectors also match the integrated upstream record.
All six ordinary laws passed; independent Lean kernel verification was not run.
This contribution adds three Bend modules without modifying any of the 67 Bend
files in that integrated revision. Historical native runs retain their actual
638 or 764 counts. Linux run 41776660115 and native Genode run 41776659987
separately pass with the refreshed 782-check core.
