### Task 4: Profile check, inventory, and task boxes

Run `scripts/runtime-profile/check-binary.sh` on the non-stripped image ELFs (static link: effect rows only) and record the output in `verification/unikernel-binary-check.txt`. Write `hosts/unikraft/INVENTORY.md`. Check `tasks.md` 2.1 (effect twins and inventory, if the hook and any Bend effect defs exist and the binary check ran), 2.2 (corpus parity, if Task 3 matched), and 2.3 (fault handler, only if the crash path yields a distinct exit code; otherwise leave unchecked and say why). Leave 2.4 and section 3 unchecked.

Acceptance: evidence files exist, inventory complete, boxes match evidence.
