# Directory and S3 sync

Branch: lane/directory-sync

User scope: native Windows app, multiple-file/folder syncing, S3/R2 first,
OneDrive later once application credentials are available.

Integrated Windows desktop lane through `77e8fa3`. Native shell, actual preview.2
upgrade, accessibility controls, pause/resume, startup and uninstall passed in
run 43135254771. The shared streaming and directory modules have 86 focused
checks passing in Bend's JavaScript execution and in emitted C compiled with
GCC 16.2.1 at `-O0`, single CPU thread, GPU disabled. The complete unchanged core
passes 3,072 checks in JavaScript and ordinary PROOF.bend passes.

S3/native folder acceptance passed at `4a437a0` in run 43138918975: multichunk
binary and Unicode paths, nested/empty folders, offline changes, rename/delete,
recovery, conflicting edits, corrupt bodies, failed publication, open-writer
exclusion and competing HTTPS If-Match publishers. Actual R2 execution is unrun;
the connected account could not provision scoped S3 credentials.

Run 43139839742 at `3e3ab33` exposed intermittent ERROR_INVALID_NAME while moving
an exact retained local file to recovery. `7664c20` adds the Win32 path terminator
and direct native writer/rename/recreated-target exclusion probes. It also
persists an observed-remote marker and explicitly requires one NTFS volume for
the root and staging/recovery. Run 43140516742 passed those changes and the cloud
desktop, root and missing-manifest tests. Captured screenshots were inspected.

Still required: verify credential entry/submission through the real native form,
finalize independent review and packaging on the merged source, revalidate/source-hash,
push master, publish the immutable preview and update the project website.

Full monolithic native C core compilation was attempted but not credited: the
local Zig/Clang frontend used excessive memory and was stopped, a bounded O0
retry hit an LLVM registration error, and GCC attempts hit memory/time bounds.
The 86 new focused C tests do pass. No independent Lean kernel or GPU result is
claimed in this lane. Generated C, binaries and complete build logs remain
outside the checkout in `/var/home/jack/build/writ-windows-desktop`.

Master `c36a740` was integrated at `55b9994` with only the source manifest
conflicting. The merged 3,136-check core passed the output checker and ordinary
PROOF.bend passed. Named desktop and directory acceptance maps now live under
`openspec/traceability/`; the release generator also checks the complete core
output count before accepting the generated policy package.
