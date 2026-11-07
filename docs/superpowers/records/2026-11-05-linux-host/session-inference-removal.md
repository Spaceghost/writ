# Removal of unused Linux session-table inference

The partial broker previously exposed `broker_reply_session`, which selected the
largest session from a diagnostic table even if a Launch was denied or the table
was truncated. No code caller existed and no native exploit was demonstrated.
This WIP mitigation removes the helper and its header promise. It does not add a
session-allocation response: launch-session return and worker binding remain
unsupported until the [typed response design](session-response-design.md) and
its monitor-owned correlation and identity obligations are implemented and
reviewed. No policy, clock, launcher, existing host test or acceptance task
changes. The original risk and withheld-probe records remain historical.

On WIP parent `2b67902de4a3256d5bbf435e09bbbf19ca3f1ef3`, the remaining broker
source and header are byte-for-byte identical after excluding exactly the
removed definition and declaration/comment. A `git grep` over tracked C,
headers, JavaScript and Bend found no remaining use or declaration. No broker
was started and no identity, process, socket, confinement or native host probe
was run.

A local synthetic build check compiled `broker.c` to an external object with
`gcc -std=gnu11 -Wall -Wextra -Werror -c`, exiting
[0](../../../../verification/linux-session-inference-removal/compile.exit) with
[stdout](../../../../verification/linux-session-inference-removal/compile.stdout)
and [stderr](../../../../verification/linux-session-inference-removal/compile.stderr)
retained. Comparing the [defined symbols before](../../../../verification/linux-session-inference-removal/symbols-before.txt)
and [after](../../../../verification/linux-session-inference-removal/symbols-after.txt)
showed only the removed `broker_reply_session` symbol. The object is not a
runnable broker, stays outside the checkout, and had SHA-256
`c224361479b21e2366088ed569692a224a3b65ef9df1cdadb6a5a79da23b36ae` on this host.
This check cannot establish runtime behavior or the safety of other WIP code.

Pinned Bend 2.0.39 ran the unchanged synthetic Linux monitor suite with
[118 passing checks](../../../../verification/linux-session-inference-removal/linux-model.log)
and the full WIP suite with [1,546 passes](../../../../verification/linux-session-inference-removal/bend.log).
The generated [Node output](../../../../verification/linux-session-inference-removal/node.log)
matched the Bend output after removing only Bend's update notice, SHA-256
`f39f04efaba52165546abd78ebf6440ff8ec247b538e7d5784dd8ddd08ac8bd4`.
The existing-law [BendTT verdict](../../../../verification/linux-session-inference-removal/verdict.log)
returned `ALL PROOFS CHECK` with the previously audited kernel; it does not
prove the native helper boundary. OpenSpec validation is structural. No
optimized native suite was run in this mitigation. These synthetic checks do
not replace the withheld identity probe, authenticate Linux facts, establish
confined execution or qualify a protected host.
