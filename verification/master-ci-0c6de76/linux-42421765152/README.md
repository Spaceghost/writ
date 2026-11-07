# Linux public canary: automatic master CI

[Run 42421765152](https://github.com/Spaceghost/writ/actions/runs/42421765152)
passed its scoped workflow at exact source
`0c6de7659d8f59f0a32edcd9802017d9277a8a38`. JavaScript and native CPU each
passed 2,809 shared core checks, with both outputs byte-identical to the local
[reference](../../frontend-binding-snapshot/root-bend.log). The mount model
passed 70 checks on each backend, and the native transport reported ten checks.

The separate protected setup was **refused at step 8**, before input loading or
Bend admission. The retained [setup log](artifacts/writfs-linux-native-1/setup-refusal.log)
states that no protected-data qualification follows. The workflow's public
canary results do not replace that missing confinement evidence.

The source/build inventory has eight tracked paths matching exact source
`0c6de76`; two runner-only generated or native outputs were unavailable for
independent rehashing. The original artifact ZIP hash matches GitHub metadata.
See the [index](../README.md) for exact-text repack and normalized presentation
copies. This run does not establish authenticated frontend cleanup or migration,
protected host qualification, durable recovery or a GPU test.
