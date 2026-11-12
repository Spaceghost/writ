# Windows desktop application

Branch: lane/windows-desktop-app

Base integration: `8a86306` joins current master `2755b17` and reviewed desktop
preview foundation `5776da3`; only the generated source manifest conflicted.
Both parent histories and all source changes were retained.

The native shell passed at `77e8fa3` in run 43135254771, including actual
preview.2 upgrade, tray callback and native accessibility controls, local
save/pause/recovery, sign-in preference, repeated packaging and uninstall.
The directory/S3 lane incorporates this history and extends the same app with
cloud connection and folder status. Its complete run 43140516742 at `7664c20`
also passes cloud desktop/offline saves, settings display, recovery races and
competing HTTPS S3 clients. Captured desktop and connection screenshots were
inspected. Publication and the website download update remain pending final
integration; the newer source keeps these passes scoped to their exact commits.
