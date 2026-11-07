# 42322440747: exploratory registryRead ABBA no-data observation

[Run 42322440747](https://github.com/Spaceghost/writ/actions/runs/42322440747) was manually dispatched on `lane/windows-registry-ab` at source `deee3ccbe7622a902284b5666a26cc6e86c04af0`. Only the dedicated exploratory job ran. MSVC built the fixed binaries, child PE imports were WS2_32 and KERNEL32, and all five named synthetic table, progress, pipe, A/B classifier and token tests passed. This does not fault-inject the native adapter's error and cleanup paths.

The fixed sequence ran an ordinary control, four LPAC cases A/B/B/A sharing one fresh package, and another ordinary control. The actual token capability counts were 0/1/1/0; each B's single capability matched the derived registryRead SID and had attributes `00000004` according to the observer. The observer recorded baseline then matches for the selected token facts, but does not retain their raw canonical fields for independent reconstruction. Both ordinary controls reported Winsock, USER32 and OLE32 status 0.

| Case | Capability | Winsock | USER32 | OLE32 |
| --- | --- | ---: | ---: | ---: |
| A1 | none | 10107 | 1114 | 1359 |
| B1 | registryRead | 0 | 1114 | 1359 |
| B2 | registryRead | 0 | 1114 | 1359 |
| A2 | none | 10107 | 1114 | 1359 |

Every case reported `load_failures=3`, `cleanup_failures=0` and no target module loaded at the relevant cold-load snapshots. Each pre-resume PSS observation reported before/captured/walked/after counts `1/1/1/1`, result 4 (`WRIT_PSS_MATCH`) and a positively compared report-pipe object. Each case completion gate included exactly one resume from suspend count 1, the same child exit, one framed report and EOF, scoped child/handle cleanup and WFP readback; sequence completion additionally required checked shared cleanup. Supervisors recorded zero timeouts and exit status 0, all six held child digests matched the built child, and all stderr captures are empty. Actual process IDs, creation times and raw numeric results are retained in the stdout captures.

This observation is exploratory and cannot establish that registryRead caused the Winsock change. The private constructed environment inputs were compared, but the actual child environments were not independently read; selected token equality is an observer assertion, package/OS state and ordering can vary, and PSS may perturb initialization. The pre-resume snapshot does not establish later handle state. These no-data results do not establish byte-worker confinement or host qualification and do not change the failed strict worker gate.

The text captures normalize line endings and trailing whitespace from [artifact 13553227785](https://github.com/Spaceghost/writ/actions/runs/42322440747/artifacts/13553227785). Its GitHub-reported archive SHA-256 is `b5521d5643120813874d9846ba725da2fd16c76c31d08a6955bc40e88f0e00ee`; `raw-sha256.txt` preserves original per-file hashes, and `sha256.txt` covers normalized files and run metadata. No generated executable is included.
