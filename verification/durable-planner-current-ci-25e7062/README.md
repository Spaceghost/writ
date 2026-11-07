# Durable and current planner preview CI at 25e7062

These explicitly dispatched runs tested exact source
`25e70622c06b053ba1b8691da2fb6af6f5c73b4a`:

- [Windows Node](windows-42339491701/README.md): 2,444 core and 78 WritFS
  model checks passed.
- [Genode base-hw QEMU](genode-42339490975/README.md): 2,444 core, 69 mount
  and 24 allocator checks plus scoped public canaries passed; the guest's
  missing real-time clock warning is retained.
- [Linux public canary](linux-42339492391/README.md): 2,444 core and 70 mount
  checks on each of JS and native, plus scoped public canaries. Unsupported
  Landlock setup was refused before input or admission; this is not protected
  setup success.

These scoped observations do not establish an authenticated planner endpoint,
protected-host qualification, durable service or independent human security
review. Original extracted artifact hashes remain recorded in each run.
