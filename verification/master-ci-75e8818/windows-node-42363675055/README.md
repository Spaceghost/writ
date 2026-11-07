# Windows Node policy: automatic master CI

[Run 42363675055](https://github.com/Spaceghost/writ/actions/runs/42363675055)
passed at source `75e8818cb1c174ee863ba71df2fcd58eb19dec7b`: 2,318 shared-library checks
and 78 WritFS model checks. Before its final `Node exit status: 0` line,
normalized library output matches the [local Node capture](../../locality-conjunction/node.log).
The generated library JavaScript SHA-256 is
`b9eeb71b3458b639762b02a238f9eb3945f4844307525e21a66b451e609e154f`,
matching the locally recorded generated file. Generated JavaScript is omitted
while artifact and entry hashes are retained. This is model evidence, not
native worker confinement or protected host qualification.
