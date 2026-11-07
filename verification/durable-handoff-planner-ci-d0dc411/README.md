# Durable, handoff and planner preview CI at d0dc411

The following explicitly dispatched runs tested exact source
`d0dc4118757e2673ac1404df1456425a1bee5962`:

- [Windows Node](windows-42333437065/README.md): 2,382 core and 78 WritFS
  model checks passed.
- [Genode base-hw QEMU](genode-42333437047/README.md): 2,382 core, 69 mount
  and 24 allocator checks plus scoped public canaries passed; the missing
  real-time clock warning is retained.
- [Linux public canary](linux-42333437094/README.md): 2,382 core and 70 mount
  checks on each of JS and native, plus scoped public canaries. Unsupported
  Landlock setup was refused before input or admission; this is not protected
  setup success.

These are scoped model and public-canary observations. They do not establish
an authenticated planner endpoint, native protected-worker qualification, a
durable service or independent human security review.
