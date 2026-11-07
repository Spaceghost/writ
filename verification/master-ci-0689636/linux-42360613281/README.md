# Linux public canary: automatic master CI

[Run 42360613281](https://github.com/Spaceghost/writ/actions/runs/42360613281)
passed its scoped public-canary workflow at source
`0689636350d49aac3a25379ece312e3f5dd2ab35`. JavaScript and native CPU each
reported 2,281 core checks with matching normalized output SHA-256
`b03250033ffabd8297d21375614e7e356a866548a2f0a23512178fc5adeb1248`,
matching the [local combined capture](../../planner-order-binding-combined/bend.log);
each mount model ran 70 checks. Transport, revocation, policy-failure and
broker-crash results are retained in the artifact logs. Ordinary proof output
requests `--verdict` for a separate mathematical check.

The separate [protected setup attempt](artifacts/writfs-linux-native-1/setup-refusal.log)
was refused at step 8 before input loading or Bend admission, explicitly with
no protected-data qualification. Workflow success does not override that
refusal; runner-only generated files were not independently rehashed here.
