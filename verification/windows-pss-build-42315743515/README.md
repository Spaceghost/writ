# 42315743515: PSS feasibility build failure

[Run 42315743515](https://github.com/Spaceghost/writ/actions/runs/42315743515) was explicitly dispatched on `lane/windows-pss` at source `4b0ed63d84cb6389e133f6f8c5fafc5d21c52982`. Only the isolated PSS job ran. CMake configuration and C compilation reached the link step, which failed with `LINK : fatal error LNK1181: cannot open input file 'kernelbase.lib'`. The PSS observer and its native synthetic tests did not run; this is not a Windows PSS, handle, environment, or confinement result. The earlier strict byte-worker failure is unchanged.

The four text captures are normalized for line endings and trailing whitespace from [artifact 13550542070](https://github.com/Spaceghost/writ/actions/runs/42315743515/artifacts/13550542070). `raw-sha256.txt` records original artifact file hashes; `sha256.txt` covers normalized files and `ci.json` run/job metadata. No generated binaries are included.
