# Linux public canary: automatic master CI

[Run 42411873117](https://github.com/Spaceghost/writ/actions/runs/42411873117)
passed its scoped workflow at exact source
`b4e2e97e34cc702557ed9eca56c7b3a0a0e63a09`. JavaScript and native CPU each
passed 2,634 shared core checks, with both outputs byte-identical to the local
[reference](../../frontend-legacy-conversion/root-bend.log). The mount model
passed 70 checks on each backend, and the native transport reported ten checks.

The separate protected setup was **refused at step 8**, before input loading or
Bend admission. The retained [setup log](artifacts/writfs-linux-native-1/setup-refusal.log)
states that no protected-data qualification follows. The workflow's public
canary results do not replace that missing confinement evidence.

The source/build inventory has eight tracked paths matching exact source
`b4e2e97`; two runner-only generated or native outputs were unavailable for
independent rehashing. The original artifact ZIP hash matches GitHub metadata.
See the [index](../README.md) for exact-text repack and normalized presentation
copies. This run does not establish authenticated frontend migration, protected
host qualification, durable recovery or a GPU test.
