These exploratory probes and captured outputs are retained as work records,
not final verification. Some ran against successive scratch source edits, and
the exact inputs and exit statuses of each are not all independently frozen;
their outputs cannot establish final-tree behavior. In particular,
`isolate-unsafe-direct.log` concerns a deliberately unsafe scratch control and
is not a proposed implementation. The separately documented issue-attempt patch
and probe in the parent directory are the reproducible issue experiment.

Trailing whitespace in these exploratory text logs is normalized. Exact bytes
for the two primary Bun aborts are preserved as base64 in the parent directory.
