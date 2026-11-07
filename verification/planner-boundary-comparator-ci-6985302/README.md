# Planner boundary and comparator CI at 6985302

These explicitly dispatched runs tested exact source
`6985302b7bbbd6ffaf2afcd7790c42f3a564f4c0`:

- [Windows Node](windows-42335756355/README.md): 2,223 core and 78 WritFS
  model checks passed.
- [Genode base-hw QEMU](genode-42335756177/README.md): 2,223 core, 69 mount
  and 24 allocator checks plus scoped public canaries passed; the guest's
  missing real-time clock warning is retained.
- [Linux public canary](linux-42335756190/README.md): 2,223 core and 70 mount
  checks on each of JS and native, plus scoped public canaries. Unsupported
  Landlock setup was refused before input or admission; this is not protected
  setup success.

These observations do not authenticate planner input, implement an endpoint,
resolve authority or qualify a protected host. Retained text is normalized;
original raw artifact hashes remain recorded in each run directory.
