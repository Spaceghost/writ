# Windows Node policy: automatic master CI

[Run 42358786243](https://github.com/Spaceghost/writ/actions/runs/42358786243)
passed at source `da1ac178b9bca9f92a51d2797483ccfef50a9686`: 2,273
shared-library checks and 78 WritFS model checks. The library log has a final
`Node exit status: 0` line after the success sentinel. The generated library
JavaScript SHA-256 in the artifact is
`6ec554ca59df5a3b0f483af08c6369f62627e0e59026861570152440515c5a1c`,
matching the locally observed generated file. Generated JavaScript is omitted
from this record; the artifact ZIP hashes and entry hashes are retained.
Before the additional exit-status line, the normalized library output is
byte-identical to the [local suite capture](../../host-binding-duplicate-ids/suite.log).
This is Windows Node model evidence, not native worker confinement or protected
host qualification.
