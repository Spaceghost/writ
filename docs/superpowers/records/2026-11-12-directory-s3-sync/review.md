# Independent review

Reviewer: existing `site_research` agent, read-only review of the working lane.

- The initial namespace protocol trusted a supplied parent identity. Bend now
  derives the parent from component keys and checks exact equality, with tests
  for unrelated and falsely claimed root parents. Incremental next-revision
  checks also reject a new spelling colliding with an existing folded name.
- Revalidating a full remote catalog for every path caused excessive work. Each
  scan now captures one validated catalog/ETag; Bend CHECK/SET validates each
  proposed mutation. Conditional publication still uses the exact current ETag.
- Credential scratch strings and the native Credential Manager allocation are
  wiped on success and exceptions; no secret is passed on the command line.
- Missing remote revision zero was already rejected against a nonzero base.
  Explicit missing-manifest rejection and a durable observed-remote marker also
  cover interruption before the first baseline is saved.
- Staging and recovery rename effects require the same NTFS volume as the sync
  root. The constructor now compares native volume identities and reports a
  clear failure before any sync effect if they differ.

The reviewer found no further ordinary-path data-loss issue in the revised
per-file reconciliation, but native acceptance remains required. The repeat
native test found the separate Win32 rename-buffer terminator bug; its fix and
the direct recreated-target probe passed in run 43140516742 at `7664c20`.

Final integration review found no code blocker in the public-fixture UIA value
entry or the connection-aware `--open-folder` shortcut. It identified the
expected publication dependency: preview.3 download/evidence links return 404
until the immutable release exists, so the page must not deploy first. Setup
links are now pinned to the preview.3 tag. The final source still requires its
own native CI run; the previous successful source is not substituted for it.
