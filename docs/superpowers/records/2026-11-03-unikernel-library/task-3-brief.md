### Task 3: Repeat for OSv, then write the selection

Install OSv's `capstan` (or build OSv from source if `capstan` is unavailable) under `../writ-unikernel/` for the current user; pin and record versions in `verification/unikernel-pins.txt`. Build and run the hello program under OSv's QEMU target. OSv runs Linux ELF executables, so this is a native-link attempt only if OSv's build can take the C source directly; if it cannot, record that OSv on this program is compat-mode and keep its matrix as a compat observation. Fill `verification/unikernel-matrix-osv.md` the same way as Task 2, within the time-box.

Then append to `docs/UNIKERNELS.md` a section "Selection matrix, 2026-11" with one table combining both candidates, the chosen kernel for the native-link lane with reasons that cite specific cells, and what the next task (effect twins) would need from it. If neither candidate linked, say so and name the single most likely blocker for each.

Check the boxes 1.1 and 1.2 in the change's `tasks.md` only if the matrix is complete for two candidates; check 1.3 only if `linuxu` ran. Leave the rest unchecked.

Acceptance: both matrix files exist; `docs/UNIKERNELS.md` has the selection section; pins recorded; `tasks.md` boxes match the evidence.
