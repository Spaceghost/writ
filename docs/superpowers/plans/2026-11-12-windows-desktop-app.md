# Windows desktop and notification-area application

Branch: `lane/windows-desktop-app`, integrating `master` at `2755b17` with the
released public-preview foundation at `5776da3` (preview.2 source `20d39f6`).

## Concrete gap

After trying preview.2, Spaceghost requested a full taskbar applet and desktop
application following OneDrive's approach. The current per-user installer opens
a console provider. Users must read event lines and run commands to stop it.

## Scope

Build a native Windows presentation/process-lifecycle shell under the approved
native contribution: notification-area icon and flyout, accessible desktop
activity and settings, open-folder/recovery actions, pause/resume, explicit
sign-in startup preference, version/help, single instance and graceful quit.
The public single-file sync engine and all Bend save decisions remain shared.
Display observed activity, never infer protected-host qualification or remote
sync from this UI. Pause stops the provider; unopened files require resume.

Use standard Win32 controls and per-monitor DPI support. Keep queues and logs
bounded, child handles explicit, blocking shutdown off the UI message loop,
and provider/interpreter lifetime tied to the owning app. Installation launches
the app and uninstall first shuts it down without deleting user data.

## Acceptance

1. Implement and document the native shell; keep CLI automation available.
2. Exercise real HWND controls and lifecycle on native Windows: readiness,
   hydration/save, pause/edit/resume, second launch, close-to-tray, settings,
   errors, shutdown and installed uninstall. Capture screenshots for review.
3. Preserve complete existing Windows sync/recovery/conflict tests and Linux
   regression/package gates; compare both GUI and provider rebuild bytes.
4. Obtain independent review, resolve findings, validate OpenSpec, refresh and
   verify the source manifest. Push reviewed work to master under the user's
   explicit instruction. Publish a new immutable preview only after native gates
   pass. Record exact source/artifact evidence and verification limits.
5. Finish the requested website download path with the verified release and
   actual desktop behavior, preserving the existing path-based deployment.

References: Microsoft [notification-area contract](https://learn.microsoft.com/en-us/windows/win32/shell/notification-area),
[OneDrive pause/resume](https://support.microsoft.com/en-us/onedrive/how-to-pause-and-resume-onedrive-sync),
and [UI Automation testing](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-usefortesting).
Relevant contracts: verification-evidence, add-windows-public-sync,
add-windows-release, and the bounded desktop-shell proposal.

## User clarification during implementation

The user explicitly expanded the goal to include multiple-file/folder syncing
and remote/cloud syncing. This plan is the first working increment; completing
the shell alone does not complete that request. Continue with a shared Bend
directory/object model, native directory operations, remote transport and
conflict/recovery evidence. The requested first remote provider is being
clarified while independent shell implementation continues.
