#
# writ_bend.tcl - shared Genode run-script procedures (build configuration),
# not Writ implementation. Genode host-layer lane, Task 3; optional
# parameters added in the channel lane's Task 3 final review. Sourced by
# the writ_bend_*.run scripts and scripts/genode/writ_bend_monitor/
# writ_bend_monitor.tcl through
#   source [select_from_repositories run/writ_bend.tcl]
# Live copy: ../writ-genode/writ-repo/run/writ_bend.tcl (byte-identical).
#
# writ_bend_boot NAME RAM CAPS ?STDOUT? ?START? ?CONFIG? ?CHILDREN? ?BUILDS?
#   Builds and boots one Bend component under init, on base-linux or, from
#   a KERNEL=hw BOARD=pc build directory, on base-hw under QEMU (the run
#   tool's boot_dir/hw and power_on/qemu; the boot configuration is the
#   same; Genode base-hw lane, Task 1). Authority:
#   init routes the parent's LOG, PD, CPU, ROM, and RM services and a Timer
#   session from the sibling timer. The component's VFS holds /dev/log and a
#   component-local vfs_pipe file system at /pipe for libc's pipe() (the
#   runtime's event loop); no file system, network, or block access. The
#   runtime options +RTS --threads 1 --gpu off are <arg> nodes (argv[0]
#   names the program); WRIT_MEM_REPORT=1 makes the shim log its RAM report
#   at exit. Optional, all defaulting to the configuration above:
#     STDOUT    libc's stdout, /dev/log (default) or /dev/null; with
#               /dev/null the VFS /dev also holds a null node (written on
#               its own lines: in the one-line form the null node would nest
#               inside log)
#     START     text after the component's <start> line, before its
#               <config> (for example a <provides> node)
#     CONFIG    text appended inside the component's <config>, after the
#               env node (for example the <writ_channel> policies)
#     CHILDREN  further <start> nodes of init (for example channel clients)
#     BUILDS    further build targets
#   The default arguments give byte-for-byte the configuration this
#   procedure installed before the parameters existed.
#
# writ_bend_require_exit0 NAME
#   Fails unless init reported exit value 0 for NAME. The line may end in
#   any number of carriage returns: base-linux's log ends it in "\r\n",
#   the QEMU serial log of base-hw in "\r\r\n" (Genode base-hw lane,
#   Task 1, verification/genode-bend-hello-base-hw.txt).
#
# writ_bend_require_shim_lines NAME
#   Fails unless the shim's start line and its exit report are present.
#
# writ_bend_refuse_reserve_failure
#   Fails if base-linux logged "_reserve_local unexpectedly failed". On
#   base-linux a shim guard is the PROT_NONE re-reservation that
#   Region_map_mmap::detach makes (repos/base-linux/src/lib/base/
#   region_map_mmap.cc:401-405); that line means the re-reservation failed
#   and the range may be free address space instead of a faulting guard.
#
# All procedures read the global $output and exit 1 on failure.
#

proc writ_bend_boot { name ram caps {stdout /dev/log} {start ""} {extra_config ""} {children ""} {builds ""} } {
	build [concat [list core init timer lib/ld lib/libc lib/libm lib/vfs lib/vfs_pipe app/$name] $builds]

	if {$stdout == "/dev/null"} {
		set dev "
      + dir dev
        + log
        + null"
	} else {
		set dev " | + log"
		set dev "
      + dir dev$dev"
	}

	create_boot_directory

	install_config "
config
+ parent-provides
  + service LOG
  + service PD
  + service CPU
  + service ROM
  + service RM
+ default-route
  + any-service
    + parent
    + any-child
+ default | caps: 200 | ram: 1M
+ start timer
  + provides | + service Timer
+ start $name | caps: $caps | ram: $ram$start
  + config
    + vfs$dev
      + dir pipe | + pipe
    + libc | stdout: $stdout | stderr: /dev/log | pipe: /pipe
    + arg | value: $name
    + arg | value: +RTS
    + arg | value: --threads
    + arg | value: 1
    + arg | value: --gpu
    + arg | value: off
    + env | key: WRIT_MEM_REPORT | value: 1$extra_config$children
-
"

	build_boot_image [build_artifacts]
}

proc writ_bend_require_exit0 { name } {
	global output
	if {![regexp "child \"$name\" exited with exit value 0\r*\n" $output]} {
		puts stderr "Error: $name did not exit with value 0"
		exit 1
	}
}

# writ_bend_require_refusal_exit NAME (base-hw only; Genode base-hw lane)
#   The shim's base-hw refusal ends the component with Parent::exit(139)
#   (hosts/genode/shim/writ_mem.cc, "Failure behaviour"). Fails unless init
#   reported exactly exit value 139 for NAME and core logged none of its own
#   fault diagnostics (repos/base/src/core/region_map_component.cc:97-110,
#   base-hw's pager.cc "unresolvable exception"): with the shim's handler
#   registered core reflects the fault without one. Used by
#   writ_bend_overflow.run and writ_probe_reservation_guard.run.
proc writ_bend_require_refusal_exit { name } {
	global output
	if {![regexp "child \"$name\" exited with exit value (\[0-9-\]+)" $output -> value]} {
		set value "none"
	}
	if {$value ne "139"} {
		puts stderr "Error: on base-hw init must report exit value 139 for $name (got $value)"
		exit 1
	}
	if {[regexp {illegal (READ|WRITE|EXEC)|unresolvable exception|violation at address|giving up on unexpectedly deep} $output]} {
		puts stderr "Error: on base-hw core logged a fault line; the shim's handler did not take the fault"
		exit 1
	}
}

proc writ_bend_require_shim_lines { name } {
	global output
	foreach {re what} [list \
		"\\\[init -> $name\\\] writ_mem: libc mmap="                      "shim start line" \
		"\\\[init -> $name\\\] writ_mem: \\\[exit\\\] ram used=\[0-9\]+ " "shim exit report" ] {
		if {![regexp $re $output]} {
			puts stderr "Error: missing $what"
			exit 1
		}
	}
}

proc writ_bend_refuse_reserve_failure { } {
	global output
	if {[regexp {_reserve_local unexpectedly failed} $output]} {
		puts stderr "Error: base-linux could not re-reserve a detached range (_reserve_local unexpectedly failed)"
		exit 1
	}
}
