# Planner codec CI at b4df8a5

These three dispatched workflows tested exact source
`b4df8a54f29c15be6d11b0ea2ece67ae8faab917`:

- [Windows Node](windows-42332032855/README.md): 2,162 core and 78 WritFS
  model checks passed.
- [Genode base-hw QEMU](genode-42332032876/README.md): 2,162 core and 69
  mount model checks plus scoped public canaries passed; the guest's missing
  real-time clock warning is retained.
- [Linux public canary](linux-42332032836/README.md): 2,162 JS/native core
  checks and scoped canaries passed; unsupported Landlock setup was refused
  before input or admission and receives no protected-data qualification.

These are test results for the bounded synthetic codec and the listed public
canaries. They do not authenticate planner inputs, implement an adapter or
admission path, or qualify a protected host.
