#
# writ_bend_monitor.tcl - shared Genode run-script procedure for the Writ
# channel runs (build configuration), not Writ implementation. Genode
# channel lane, Task 2. Sourced by writ_bend_monitor_accept.run and
# writ_bend_monitor_substitute.run through
#   source [select_from_repositories run/writ_bend_monitor.tcl]
# Live copy: ../writ-genode/writ-repo/run/writ_bend_monitor.tcl (byte-identical).
#
# writ_bend_monitor_run CLIENT SESSION EXPECTED CLAIMED DECISION REASON DELAY
#   Builds and boots, under init on base-linux, the Bend monitor component
#   writ_bend_monitor (hosts/genode/monitor/Monitor.bend linked with the
#   shim) at 256M and the client probe writ_channel_client started under the
#   child name CLIENT. The client's request record names monitor session
#   SESSION with expected revision EXPECTED and carries CLAIMED as its body's
#   claimed subject; it expects decision word DECISION and reason REASON.
#   The client sleeps DELAY ms on its Timer session before it writes (0:
#   none), so with a delay the monitor's Genode.take is parked first.
#   The run ends when the client exits and fails (exit 1) unless the client
#   exited 0, the monitor logged the matching Bend decision line for route
#   subject 1 (the policy below), and both records were dumped.
#
# Authority: init routes the parent-provided LOG, PD, CPU, ROM, and RM
# services and the sibling timer's Timer to both children. The client's
# Writ_channel session is routed to the monitor (<route><service
# name="Writ_channel"><child name="writ_bend_monitor"/>), every other
# service to the parent. init prefixes the client's session label "channel"
# with the child name (repos/base/src/lib/base/child.cc:152-155), so the
# monitor sees "CLIENT -> channel". The monitor's <writ_channel> config
# holds one <policy label_prefix="writ_client_r ->" subject="1"/>: the
# shim gives a channel opened by the child writ_client_r route subject 1,
# which Monitor.bend maps to examples/Scenario.bend's reader. There is no
# <default-policy>. The policy-label syntax follows repos/gems/run/
# depot_deploy.run:96; the route-to-child syntax repos/os/run/
# ahci_block.run:54. The monitor's VFS holds /dev/log and the vfs_pipe file
# system at /pipe for the runtime's event loop; no file system, network, or
# block access. libc stdout and stderr go to /dev/log; the monitor's lines
# come through Genode.log.
#

proc writ_bend_monitor_run { client session expected claimed decision reason delay } {
	global output

	set monitor writ_bend_monitor
	set ram 256M

	build [list core init timer lib/ld lib/libc lib/libm lib/vfs lib/vfs_pipe \
	            app/$monitor app/writ_channel_client]

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
+ start $monitor | caps: 1000 | ram: $ram
  + provides | + service Writ_channel
  + config
    + vfs
      + dir dev | + log
      + dir pipe | + pipe
    + libc | stdout: /dev/log | stderr: /dev/log | pipe: /pipe
    + arg | value: $monitor
    + arg | value: +RTS
    + arg | value: --threads
    + arg | value: 1
    + arg | value: --gpu
    + arg | value: off
    + env | key: WRIT_MEM_REPORT | value: 1
    + writ_channel
      + policy | label_prefix: writ_client_r -> | subject: 1
+ start $client | caps: 200 | ram: 2M
  + binary writ_channel_client
  + route
    + service Writ_channel | + child $monitor
    + any-service
      + parent
      + any-child
  + config | session: $session | expected_session: $expected | claimed_subject: $claimed | expect_decision: $decision | expect_reason: $reason | delay_ms: $delay
-
"

	build_boot_image [build_artifacts]

	run_genode_until "child \"$client\" exited with exit value .*\n" [expr {120 + $delay/1000}]

	if {![regexp "child \"$client\" exited with exit value 0\r?\n" $output]} {
		puts stderr "Error: the client $client did not exit with value 0"
		exit 1
	}
	if {[regexp {_reserve_local unexpectedly failed} $output]} {
		puts stderr "Error: base-linux could not re-reserve a detached range"
		exit 1
	}

	set names [dict create 1 Committed 2 Denied]
	set name [dict get $names $decision]
	foreach {re what} [list \
		"\\\[init -> $monitor\\\] writ_mem: libc mmap="                                       "shim start line" \
		"\\\[init -> $monitor\\\] writ_channel: service announced"                            "service announced" \
		"\\\[init -> $monitor\\\] writ_channel: channel 1 opened for '$client -> channel' route subject 1\r?\n" "channel opened with route subject 1" \
		"\\\[init -> $monitor\\\] monitor: SYNTHETIC authority"                               "synthetic-authority line" \
		"\\\[init -> $monitor\\\] monitor: channel=1 route_subject=1 session=$session body_claimed_subject=$claimed \\(untrusted, not used\\) decision=$name reason=$reason " "Bend decision line" \
		"\\\[init -> $client\\\] client: request record \\+0x0+: "                           "request record dump" \
		"\\\[init -> $client\\\] client: result record \\+0x0+: "                            "result record dump" \
		"\\\[init -> $client\\\] client: PASS decision $decision reason $reason as expected" "client verdict" ] {
		if {![regexp $re $output]} {
			puts stderr "Error: missing $what"
			exit 1
		}
	}
	# With a delay the monitor must have been serving (its first take
	# parked) before the client wrote; the decision then shows the parked
	# take woke on the request signal.
	if {$delay > 0 && ![regexp "\\\[init -> $monitor\\\] monitor: serving \[0-9\]+ records.*\\\[init -> $client\\\] client: request written" $output]} {
		puts stderr "Error: the client wrote before the monitor was serving"
		exit 1
	}
	puts "\n--- $client: route subject 1, session $session, claimed $claimed -> $name reason $reason ---"
}
