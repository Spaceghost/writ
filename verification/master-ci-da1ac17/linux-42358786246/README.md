# Linux public canary: automatic master CI

[Run 42358786246](https://github.com/Spaceghost/writ/actions/runs/42358786246)
passed its scoped public-canary workflow at exact source
`da1ac178b9bca9f92a51d2797483ccfef50a9686`. JavaScript and native CPU each
reported 2,273 core checks with matching normalized output, SHA-256
`1290d7761819f3e9af56ebd72401c3e13886d13722fa77e21dac8e6dc826db7a`,
which also matches the local suite capture; each mount model ran 70 checks.
The transport, revocation, policy-failure and broker-crash canaries reported
their scoped successes. Ordinary proof output requests `--verdict` for a
separate mathematical check.

The separate [protected setup attempt](artifacts/writfs-linux-native-1/setup-refusal.log)
was refused at step 8 before input loading or Bend admission, explicitly with
no protected-data qualification. Workflow success does not override that
refusal. Eight tracked source hashes in its source/build inventory match this
commit; two runner-only outputs were unavailable for independent rehashing.
The original artifact ZIP hash matches GitHub metadata. The index explains
the exact-text repack and normalized presentation files.
