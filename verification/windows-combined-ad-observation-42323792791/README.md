# 42323792791: combined no-data initializer observation

[Run 42323792791](https://github.com/Spaceghost/writ/actions/runs/42323792791) was manually dispatched on `lane/windows-combined-ad` at source `1327ded885c34cca3db9f8a7308ba984faa83416`; only its dedicated exploratory job ran. MSVC built the fixed targets; child PE inspection listed WS2_32 and KERNEL32; all five named synthetic table, progress, pipe, combined classifier and token tests passed. Native adapter failure paths were not fault-injected.

The ordinary/A/D/D/A/ordinary sequence used one fresh package for four LPAC lifetimes. A had zero capabilities and Win32k disable ON; D had one actual derived registryRead SID with exactly enabled attributes and Win32k disable OFF. These two settings differ together. Observer readback reported capability counts `0/1/1/0`, D attributes `00000004`, and Win32k system-call-disable flags `00000005/00000004/00000004/00000005`. Both ordinary controls reported Winsock, USER32 and OLE32 status zero.

| Case | Capabilities | Win32k disable bit | Winsock | USER32 | OLE32 | Load-failure bits |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| A1 | none | 1 | 10107 | 1114 | 1359 | 3 |
| D1 | registryRead | 0 | 0 | 0 | 0 | 0 |
| D2 | registryRead | 0 | 0 | 0 | 0 | 0 |
| A2 | none | 1 | 10107 | 1114 | 1359 | 3 |

The two D reports each observed all three initializer results as zero in the same retained child lifetime. All cases recorded `initial_modules=0`, `after_winsock_modules=0`, and `cleanup_failures=0`. A cases recorded `pre_ole32_modules=0`, D cases `pre_ole32_modules=1`: bit 1 is USER32, while bit 2 is OLE32, which was absent before its explicit load. All passed the implemented cold-load gate. The selected token comparison is an observer assertion, since raw canonical fields are not retained for independent reconstruction.

Each pre-resume PSS table reported before/captured/walked/after `1/1/1/1`, result 4 (`WRIT_PSS_MATCH`) and a positively compared report pipe. Completion required the same child lifetime, exactly one resume from previous suspend count 1, a framed report and EOF, scoped child/handle retirement and WFP readback; sequence completion also required checked shared cleanup. All supervisors recorded no timeout and exit 0; all six held image hashes matched the built child, and stderr captures are empty. Process IDs, creation times and raw numeric results appear in stdout.

This is joint-status evidence from two no-data lifetimes, not a single-factor contrast or proof of cause. The actual child environment was not independently read; package/OS/provider state, ordering, drift and PSS perturbation remain confounders, and PSS does not establish later handle state. The D child has no established GUI or ambient-resource confinement; no socket/traffic probes were added, but `WSAStartup` may cause unobserved provider/OS activity. The result does not establish byte-worker confinement or host qualification and does not change the strict worker failure.

The normalized text captures derive from [artifact 13554500862](https://github.com/Spaceghost/writ/actions/runs/42323792791/artifacts/13554500862), whose GitHub-reported archive SHA-256 is `42cb0590f87f1068d277916c7601d0ffa4cc3c37a02ac4a19de61e57d73fb592`. `raw-sha256.txt` preserves original per-file hashes, and `sha256.txt` covers normalized captures and run metadata. No executable is included.
