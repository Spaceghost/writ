### Task 1: The hello under `linuxu`

Pin 0.16.3 (commit and tarball hash recorded), build the `IO.print` hello as a `linuxu` application with the same single-lane configuration the matrix used, and run it as a process. If the runtime's reservation fails, try in this order and record each: (1) `+RTS` options that shrink the heap and stack reservations if the runtime exposes them (cite `bend guide` or the generated C); (2) the platform's memory configuration (`CONFIG_LINUXUPLAT_*`, heap size) raised; (3) a `MAP_NORESERVE`-style path if `linuxu` has one. Expected: `hi` and exit status 0 from the process, or the exact failing line. Evidence: `verification/unikernel-linuxu.txt` with commands, versions, the process exit status, and the strace-free observation of the mapping that failed if it did.

Acceptance: `hi` as a `linuxu` process with exit 0, or a recorded stall naming the reservation and the three attempts.

