# Board answer body limit, 2026-11-07

The development board's answer route now counts actual wire bytes before
parsing a form or JSON, including requests without `Content-Length`. The cap
remains 16 KiB. It accepts exactly that many bytes and returns 413 after the
first byte over the limit without appending an answer or waiting for the rest
of the request. This is development-tool behavior, not Writ policy evidence.

Command, in the isolated worktree with Bun 1.1.8 and the pinned `marked`
dependency, with `TMPDIR` under `/home/jadams/tmp/writ-codex-20261107`:

```sh
bun utils/board/smoke.ts
```

The new synthetic-question checks send real HTTP/1.1 chunked bodies over a
local socket and test exact and over-limit boundaries, an unfinished oversized
body, declared-length rejection, a UTF-8 character split across chunks,
multibyte byte counting, JSON, and multipart repeated fields and ignored files.
They write only to the smoke fixture, not the user's questions.

The [first smoke run](initial.log) passed all new body-limit checks but failed
the existing startup reconciliation timing assertion; it exited 1. The next
[rerun](rerun.log) passed and exited 0. After adding the declared-length
regression, the [final run](final.log) also passed and exited 0. The initial
failure is retained and is not attributed to a known cause.
