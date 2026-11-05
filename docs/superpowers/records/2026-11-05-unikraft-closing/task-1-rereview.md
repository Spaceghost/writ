# Task 1 re-review (fix round 2)

Result: ALL CLOSED. No new defect found.

Method: sourced hosts/unikraft/scripts/env.sh with W=/mnt/MediaVolume/Media/src/github.com/spaceghost/writ-lanes/writ-unikernel
and ran writ_kernel_fragment on constructed captures; reran every KVM capture through the
three check scripts with WRIT_NO_BOOT=1; rebuilt the three negative controls in scratch
files under the W logs dir (removed afterwards). TCG reruns were read from the evidence file only.

## 1. CLOSED: helper drops only a timestamp fragment
Captures run through writ_kernel_fragment (drop/keep):
| Last line | unterminated | terminated |
| --- | --- | --- |
| `[1.5]` | keep | keep |
| `[12` | keep | keep |
| `[` | drop | keep |
| `[    2.27112` | drop | keep |
| pm.c:69 line (with a NUL inside) | drop | keep |
| `done` | keep | keep |
| `[1, 2` | keep | n/a |
| `[    2.271123] ` | drop | n/a |
| `[ 1` | drop (prefix of a valid 5-wide field) | n/a |
No terminated line is ever dropped (condition (a)): `[1.5]`, `[12`, `[`, `done`, the pm.c line
terminated are all kept. An unterminated real program line that is exactly `[` (or `[` plus
spaces, or `[ 1`-style space-then-digits) would be dropped. env.sh's comment states this
as an accepted limit ("[" alone, or "[" and spaces, cannot be told from program text);
the evidence file states it too. The comment's added sentence "condition (a) ... keeps a program
line out" holds for terminated lines only; acceptable. Accepted.

## 2. CLOSED: wording
env.sh, check-image.sh, check-fault.sh comments and the Fix round 2 definition in
verification/unikernel-kvm.txt all say: unterminated trailing fragment that is the start of a
timestamped kernel line after the exit write (cut-off timestamp or the pm.c:69 line),
counted every time. env.sh names the overflow case. The empty-last-line case (old finding 6) is stated.

## 3. CLOSED: TCG reruns
verification/unikernel-kvm.txt "TCG through the tightened scripts": rechecks of tcgnow-hello/die/exit 1-3,
tcgfix-hello1, both corpus runs, and check-fault exhaust and overflow; plus fresh boots of die, exit, hello,
exhaust, overflow and the corpus; all "dropped 0, PASS".

## 4. CLOSED: top table
"== Result (KVM), strict checks before the fragment rule ==" with a line under it pointing to Fix round and Fix round 2.

## 5. CLOSED: KVM counts and negative controls
Reran all 35 KVM captures with the tightened scripts: dropped 1 on exactly 17 (kvm-hello2, 5; kvm-die1,2,4,5,6;
kvm-exit2-6; kvm-tests2-m4096; kvmfix-die1, exit1, tests2-m4096, overflow1), dropped 0 on the other 18; all PASS.
Negative controls rebuilt from run-kvm-die1.raw: fragment not last: dropped 0, FAIL, exit 1; last line
replaced by a pm.c @ 70 line: dropped 0, FAIL, exit 1; second fragment `[    0.2` after the first: dropped 1,
FAIL, exit 1.
