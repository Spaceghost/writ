# Native Writ host bindings

The user approved this source exception for Windows, Linux, and Genode. Keep
foreign-language code limited to OS/runtime integration and native probes.
Authorization and state machines stay in the shared Bend modules.

Inventory the ABI, native dependencies, resource ownership and failure behavior.
Capture authority facts from the OS or a trusted supervisor, never from a worker
request. Keep native handles local. A numeric PID or a session label alone does
not establish a process lifetime or human identity.

Generated Bend C/JavaScript, build trees, downloaded toolchains and native binaries
belong outside the checkout. Pin upstream versions and verify downloaded assets.
No unbounded wire messages, general shell endpoints, automatic permission
fallbacks, or unchecked casts/indexes. Bound callbacks, queues and retained state.

Use public canaries until a protected profile's actual native tests pass. A real
mount, runtime execution, actor binding, confinement and crash recovery are
separate claims. Preserve failures and missing coverage. Do not complete the
broader host specifications merely because a bounded contribution works.
