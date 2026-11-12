# Native desktop shell

`Writ.exe` owns a hidden-console `writ-cloud.exe start` process and its output
pipe. A kill-on-close job owns its process tree if the app crashes. Normal
pause/quit asks the existing provider to stop and waits asynchronously for its
actual exit. A second app launch activates the existing window. Window close
keeps the notification-area app running; explicit Quit stops it.

The app presents bounded provider event history and operational state. A
confirmed save is a past provider observation; readiness is not proof that all
edits are committed. Failures remain visible. No UI setting changes Bend
authority or conflict handling. Native standard controls supply keyboard and
accessibility behavior; the taskbar icon handles keyboard activation and shell
restart. Sign-in startup is an explicit per-user preference.

The installer adds the GUI alongside the CLI and shuts the app down before
cleanup. Tests drive actual Windows controls and run real provider I/O on the
same packaged bytes. Automated shell evidence remains distinct from a human
interactive editor check, power-loss qualification and protected hosts.
