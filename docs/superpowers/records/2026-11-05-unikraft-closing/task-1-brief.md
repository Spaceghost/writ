### Task 1: KVM boots (3.1)

Add the accelerator option to `run.sh`. Boot, under KVM, the hello probe, the exit-code probes (success, die, exit, crash: the exit map must hold: 33, 35, 39, 253), the fault probe (overflow: message then 253), and the corpus image with `check-corpus.sh` (782 PASS, program lines equal to the reference); record wall times beside the TCG ones from the evidence files. Write `verification/unikernel-kvm.txt` and check 3.1 citing it.

Acceptance: every KVM boot has its console lines, exit code, and wall time; the exit map and corpus count hold; TCG records untouched.

