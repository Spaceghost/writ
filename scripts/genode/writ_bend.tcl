#
# writ_bend.tcl - shared Genode run-script procedures (build configuration),
# not Writ implementation. Genode host-layer lane, Task 3. Sourced by the
# writ_bend_*.run scripts through
#   source [select_from_repositories run/writ_bend.tcl]
# Live copy: ../writ-genode/writ-repo/run/writ_bend.tcl (byte-identical).
#
# writ_bend_boot NAME RAM CAPS
#   Builds and boots one Bend component under init on base-linux. Authority:
#   init routes the parent's LOG, PD, CPU, ROM, and RM services and a Timer
#   session from the sibling timer. The component's VFS holds /dev/log and a
#   component-local vfs_pipe file system at /pipe for libc's pipe() (the
#   runtime's event loop); no file system, network, or block access. The
#   runtime options +RTS --threads 1 --gpu off are <arg> nodes (argv[0]
#   names the program); WRIT_MEM_REPORT=1 makes the shim log its RAM report
#   at exit.
#
# writ_bend_require_exit0 NAME
#   Fails unless init reported exit value 0 for NAME.
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

proc writ_bend_boot { name ram caps } {
	build [list core init timer lib/ld lib/libc lib/libm lib/vfs lib/vfs_pipe app/$name]

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
+ start $name | caps: $caps | ram: $ram
  + config
    + vfs
      + dir dev | + log
      + dir pipe | + pipe
    + libc | stdout: /dev/log | stderr: /dev/log | pipe: /pipe
    + arg | value: $name
    + arg | value: +RTS
    + arg | value: --threads
    + arg | value: 1
    + arg | value: --gpu
    + arg | value: off
    + env | key: WRIT_MEM_REPORT | value: 1
-
"

	build_boot_image [build_artifacts]
}

proc writ_bend_require_exit0 { name } {
	global output
	if {![regexp "child \"$name\" exited with exit value 0\r?\n" $output]} {
		puts stderr "Error: $name did not exit with value 0"
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
