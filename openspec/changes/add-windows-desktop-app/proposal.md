# Windows desktop application

## Why

Preview.2 makes the user keep a provider console open and interpret log lines.
The user requested a OneDrive-style taskbar applet and desktop application.

## What Changes

Add a native notification-area applet, activity/settings window and packaged
entry point around the existing public Files On-Demand provider. Include
pause/resume, folder/recovery access, opt-in sign-in launch and safe shutdown.

## Impact

Windows native shell and release packaging; a new `windows-desktop-app`
capability. Bend policy, the single-file local-store scope and protected-host
qualification remain governed by their existing contracts.
