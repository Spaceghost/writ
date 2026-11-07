# 42323201217: exploratory zero-capability Win32k observation

[Run 42323201217](https://github.com/Spaceghost/writ/actions/runs/42323201217) was manually dispatched on `lane/windows-win32k-ac` at source `c193857e092d9306f537d79898b5e8edcbf4d9df`; only its dedicated exploratory job ran. MSVC built the fixed targets; the child PE dependency inspection listed WS2_32 and KERNEL32; all five named synthetic table, progress, pipe, Win32k classifier and token tests passed. This does not fault-inject native adapter failure paths.

The ordinary/ACCA/ordinary sequence used one fresh package for four LPAC cases, each with zero actual token capabilities. A requested Win32k system-call disable ON and read back flags `00000005`; C requested OFF and read back `00000004`, with the remaining observed bits matching. Both ordinary controls reported zero Winsock, USER32 and OLE32 status. The A/C/C/A results were:

| Case | Win32k disable bit | Winsock | USER32 | OLE32 | Load-failure bits |
| --- | ---: | ---: | ---: | ---: | ---: |
| A1 | 1 | 10107 | 1114 | 1359 | 3 |
| C1 | 0 | 10107 | 0 | 0 | 0 |
| C2 | 0 | 10107 | 0 | 0 | 0 |
| A2 | 1 | 10107 | 1114 | 1359 | 3 |

Each case had `initial_modules=0`, `after_winsock_modules=0` and `cleanup_failures=0`. Both A cases reported `pre_ole32_modules=0`; both C cases reported `pre_ole32_modules=1`, meaning USER32 was present but OLE32 (bit 2) was absent before its explicit load. Each passed the implemented cold-load gate. These are numeric observations, not proof of a causal mechanism.

Every pre-resume PSS table reported before/captured/walked/after `1/1/1/1`, result 4 (`WRIT_PSS_MATCH`) and a positively compared report pipe. Completion required the same child lifetime, exactly one resume from previous suspend count 1, a framed report and EOF, scoped child/handle retirement and WFP readback; sequence completion additionally required checked shared cleanup. All supervisors recorded no timeout and exit 0, all six held child digests matched the fixed child build and stderr files are empty. The stdout captures preserve actual PIDs, creation times, readbacks and numeric reports.

Selected token facts were compared privately; raw canonical fields are not retained for independent reconstruction. Constructed environment input matched, but the child environment was not independently read. Shared package state, OS/provider state, ordering, drift and PSS perturbation remain possible confounders, and the pre-resume snapshot says nothing about subsequent handles. The C child has no established GUI or ambient-resource confinement, and this no-data sequence does not establish byte-worker confinement or host qualification. It does not change the strict worker failure.

Text captures normalize line endings and trailing whitespace from [artifact 13553233907](https://github.com/Spaceghost/writ/actions/runs/42323201217/artifacts/13553233907), whose GitHub-reported archive SHA-256 is `71193ccb7805f1cdcee6c630158ca0adc2e15752e12d560c585d4d7ec2a7137a`. `raw-sha256.txt` records the original per-file hashes, and `sha256.txt` covers normalized captures and run metadata. No executable is included.
