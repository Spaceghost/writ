# Comparator regression platform CI

These explicitly dispatched runs tested exact source `c5a02c7f3027ea45af7a9737fa2e9ed0801195ec`:

- [Windows Node](windows-42337450839/README.md): 2,224 core and 78 model checks passed.
- [Genode base-hw QEMU](genode-42337450847/README.md): 2,224 core, 69 mount and 24 allocator checks plus public canaries passed; the guest's missing real-time clock warning is retained.
- [Linux public canary](linux-42337450706/README.md): 2,224 JS/native core and 70 JS/native mount checks plus scoped public canaries passed. The protected setup probe refused at step 8 before input or admission; its failure text is retained.

These observations do not implement planner admission, authenticate input, or qualify a protected host. Retained text is normalized; original artifact-file and archive hashes are recorded separately.
