# Planner N48 regression CI at 262a8d4

These three dispatched workflows tested exact source
`262a8d4d683c4c48711e734bd1358bc4b33a3993`:

- [Windows Node](windows-42335497307/README.md): 2,163 core and 78 WritFS
  model checks passed.
- [Genode base-hw QEMU](genode-42335497587/README.md): 2,163 core and 69
  mount model checks plus scoped public canaries passed; the guest's missing
  real-time clock warning is retained.
- [Linux public canary](linux-42335497465/README.md): 2,163 JS/native core
  checks and scoped canaries passed; unsupported Landlock setup was refused
  before input or admission and receives no protected-data qualification.

These results cover the bounded codec tests and listed public canaries, not
every possible numeric value. They do not authenticate planner inputs,
implement an adapter or admission path, or qualify a protected host.
