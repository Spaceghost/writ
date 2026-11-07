# Linux public canary: automatic master CI

[Run 42363675039](https://github.com/Spaceghost/writ/actions/runs/42363675039)
passed its scoped public-canary workflow at source
`75e8818cb1c174ee863ba71df2fcd58eb19dec7b`. JavaScript and native CPU each
reported 2,318 core checks with matching normalized output SHA-256
`e87d601d12b49d85bc45d20f2b59ca1d7ece694cc1828b7f21d4713be3f9ad50`,
matching the [local capture](../../locality-conjunction/bend.log); each mount
model ran 70 checks. Transport, revocation, policy-failure and broker-crash
results are retained in the artifact logs. Ordinary proof output requests
`--verdict` for a separate mathematical check.

The separate [protected setup attempt](artifacts/writfs-linux-native-1/setup-refusal.log)
was refused at step 8 before input loading or Bend admission, explicitly with
no protected-data qualification. Workflow success does not override that
refusal; runner-only generated files were not independently rehashed here.
