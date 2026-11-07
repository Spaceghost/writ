# Windows Node: automatic master CI

[Run 42388574240](https://github.com/Spaceghost/writ/actions/runs/42388574240)
passed on exact source `70f05b25eb92581c2f95993151e20ad6b4d71509`. Native
Windows Node ran 2,472 shared library checks and 78 WritFS model checks, both
with exit status 0. Removing the explicitly recorded final Node-exit line from
the normalized library log gives the same bytes as the local
[rendezvous-allocation suite](../../rendezvous-allocation-boundary/bend.log), SHA-256
`249ab6deda8e904a60f064597ad367aaf77c354aadc9261ecc6e3cf1bffa6181`.
This is generated-JavaScript model execution, not native rendezvous or protected
host qualification.

All three downloaded ZIP digests match GitHub metadata. Both generated JS
files were omitted from the source record; their original entry hashes match
the workflow's generated-hash report. See the [index](../README.md) for exact
text repack and normalized presentation scope.
