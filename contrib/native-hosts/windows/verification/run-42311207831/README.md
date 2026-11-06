# Failed Windows native canary run 42311207831

[Workflow run](https://github.com/Spaceghost/writ/actions/runs/42311207831)
on source `9c08eb93b86a6025d3b254551557e394f7685f7c` failed the strict LPAC
public-canary confinement gate. The shared Bend mount-policy compilation
passed. In `lpac.txt`, the admitted worker read and revocation observations
passed, but network, clipboard and COM probes were incomplete in the byte
worker; network API errors `10107` received no restriction credit. A separate
no-data diagnostic reported its own observations. The run ended with
`LPAC_OBSERVATIONS mounted_and_revoked=pass byte_worker_confinement=incomplete
no_data_diagnostic=pass` and `FAIL native Windows profile=lpac-canary`. This is
a failed workflow, not protected-host qualification. Its cause remains under
investigation; the diagnostic profile is not a substitute for the byte worker.

Captures normalize terminal escapes, carriage returns, trailing whitespace,
and the installer log's UTF-16 to UTF-8. `artifact-raw-sha256.txt` identifies
the original downloaded files. No generated policy JavaScript or native binary
is retained in the source tree.
