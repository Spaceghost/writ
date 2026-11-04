### Task 1: Trivial component on base-linux

Fetch Genode at the pinned commit into `../writ-genode/genode/`, obtain its toolchain per the 26.08 instructions, and create a `base-linux` build directory. Build and run the upstream `log` or `hello` style run scenario that the 26.08 tree ships for `base-linux` (find it under `repos/base/run/` or `repos/os/run/`; do not write your own yet) and record the command and the log lines in `verification/genode-bringup-base-linux.txt`.

Create a Genode repository `../writ-genode/writ-repo/` with one component `src/app/writ_hello/` whose `main.cc` is the standard minimal `Component::construct` that logs one line, and a run script `run/writ_hello.run` that starts it under `init` on `base-linux`. Build and run it; append the command and the log line to the same evidence file. Copy `target.mk`, `main.cc`, and `writ_hello.run` into `scripts/genode/writ_hello/` with header comments.

Acceptance: the evidence file shows the upstream scenario's log and the `writ_hello` log line; the pins file names Genode commit, toolchain, and host compiler; `scripts/genode/writ_hello/` holds the authored files.

