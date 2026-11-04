#
# writ_bend_monitor.tcl - shared Genode run-script procedure for the Writ
# channel runs (build configuration), not Writ implementation. Genode
# channel lane, Tasks 2 and 3. Sourced by writ_bend_monitor_accept.run,
# writ_bend_monitor_substitute.run, writ_bend_monitor_routed_s.run,
# writ_bend_monitor_claim_ignored.run, writ_bend_monitor_bad_length.run, and
# writ_bend_monitor_liveness.run through
#   source [select_from_repositories run/writ_bend_monitor.tcl]
# Live copy: ../writ-genode/writ-repo/run/writ_bend_monitor.tcl (byte-identical).
#
# writ_bend_monitor_run CLIENT SUBJECT SESSION EXPECTED CLAIMED DECISION REASON DELAY ?POLICIES?
#   Builds and boots, under init on base-linux, the Bend monitor component
#   writ_bend_monitor (hosts/genode/monitor/Monitor.bend linked with the
#   shim) at 256M and the client probe writ_channel_client started under the
#   child name CLIENT. The client's request record names monitor session
#   SESSION with expected revision EXPECTED and carries CLAIMED as its body's
#   claimed subject; it expects decision word DECISION and reason REASON.
#   The client sleeps DELAY ms on its Timer session before it writes (0:
#   none), so with a delay the monitor's Genode.take is parked first.
#   SUBJECT is the route subject the monitor's policies give CLIENT; the
#   run requires the shim to report it for the channel and the Bend
#   decision line to carry it. POLICIES are the <policy> lines under
#   <writ_channel> (default: writ_bend_monitor_policies below).
#   The run ends when the client exits and fails (exit 1) unless the client
#   exited 0, the monitor logged the matching Bend decision line for route
#   subject SUBJECT, and both records were dumped.
#
# writ_bend_monitor_bad_length_run (Task 3, GB-006)
#   One client, writ_client_r (route subject 1), in mode bad_length: a
#   request with header length 65, then one with length 0, then R's valid
#   request on session 1. Fails unless the shim warned for both lengths
#   with bad length counts 1 and 2, the client printed the shim's refusal
#   for each, the monitor logged exactly one decision line (the valid
#   request: Committed, reason 0), and the client exited 0.
#
# writ_bend_monitor_liveness_run (Task 3, GB-008)
#   Two clients under two policies in one run. writ_client_s (route subject
#   2) floods: 12 requests 400 ms apart from its constructor, never reading
#   a reply. writ_client_r (route subject 1) waits 1000 ms, sends R's
#   request once, and must get Committed, reason 0. The monitor's fuel (8
#   takes) runs out while S is still sending. The run ends at the first
#   flood request signalled after init reported the monitor's exit. Fails
#   unless S's channel was decided (Denied, reason 5) before and after R's
#   decision, R passed and exited 0, the monitor logged "fuel exhausted",
#   the shim's exit report (RAM, caps, channel counters) was logged, init
#   reported the monitor's exit value 0, and S signalled again after it.
#   S is not required to exit: on base-linux its next signal to the exited
#   monitor fails in lx_sendmsg (-111, connection refused) and S stays
#   blocked there (observed; host transport behaviour, not checked).
#
# Authority: init routes the parent-provided LOG, PD, CPU, ROM, and RM
# services and the sibling timer's Timer to both children. The client's
# Writ_channel session is routed to the monitor (<route><service
# name="Writ_channel"><child name="writ_bend_monitor"/>), every other
# service to the parent. init prefixes the client's session label "channel"
# with the child name (repos/base/src/lib/base/child.cc:152-155), so the
# monitor sees "CLIENT -> channel". The monitor's <writ_channel> config
# holds by default <policy label_prefix="writ_client_r ->" subject="1"/>
# and <policy label_prefix="writ_client_s ->" subject="2"/>: the shim gives
# a channel opened by the child writ_client_r route subject 1, which
# Monitor.bend maps to examples/Scenario.bend's reader R, and one opened by
# writ_client_s route subject 2, the synthetic subject S. There is no
# <default-policy>. The policy-label syntax follows repos/gems/run/
# depot_deploy.run:96; the route-to-child syntax repos/os/run/
# ahci_block.run:54. The monitor's VFS holds /dev/log and the vfs_pipe file
# system at /pipe for the runtime's event loop; no file system, network, or
# block access. libc stdout and stderr go to /dev/log; the monitor's lines
# come through Genode.log.
#

set writ_bend_monitor_policies {
      + policy | label_prefix: writ_client_r -> | subject: 1
      + policy | label_prefix: writ_client_s -> | subject: 2}

# A client start node: child name CLIENT, its Writ_channel session routed
# to the monitor, and the client's <config> attributes CONFIG.
proc writ_bend_monitor_client { client config } {
	return "
+ start $client | caps: 200 | ram: 2M
  + binary writ_channel_client
  + route
    + service Writ_channel | + child writ_bend_monitor
    + any-service
      + parent
      + any-child
  + config$config"
}

# Builds, installs the configuration (the monitor with POLICIES and the
# client start nodes CLIENTS), and builds the boot image.
proc writ_bend_monitor_boot { policies clients } {
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
    + writ_channel$policies$clients
-
"

	build_boot_image [build_artifacts]
}

# Fails the run unless every regular expression in the list RES (pairs of
# expression and description) matches the log.
proc writ_bend_monitor_require { res } {
	global output
	foreach {re what} $res {
		if {![regexp $re $output]} {
			puts stderr "Error: missing $what"
			exit 1
		}
	}
	if {[regexp {_reserve_local unexpectedly failed} $output]} {
		puts stderr "Error: base-linux could not re-reserve a detached range"
		exit 1
	}
}

proc writ_bend_monitor_run { client subject session expected claimed decision reason delay {policies ""} } {
	global writ_bend_monitor_policies
	if {$policies == ""} { set policies $writ_bend_monitor_policies }
	global output

	set monitor writ_bend_monitor

	writ_bend_monitor_boot $policies [writ_bend_monitor_client $client \
		" | session: $session | expected_session: $expected | claimed_subject: $claimed | expect_decision: $decision | expect_reason: $reason | delay_ms: $delay"]

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
		"\\\[init -> $monitor\\\] writ_channel: channel 1 opened for '$client -> channel' route subject $subject\r?\n" "channel opened with route subject $subject" \
		"\\\[init -> $monitor\\\] monitor: SYNTHETIC authority"                               "synthetic-authority line" \
		"\\\[init -> $monitor\\\] monitor: channel=1 route_subject=$subject session=$session body_claimed_subject=$claimed \\(untrusted, not used\\) decision=$name reason=$reason " "Bend decision line" \
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
	puts "\n--- $client: route subject $subject, session $session, claimed $claimed -> $name reason $reason ---"
}

proc writ_bend_monitor_bad_length_run { } {
	global writ_bend_monitor_policies
	global output

	set monitor writ_bend_monitor
	set client  writ_client_r

	writ_bend_monitor_boot $writ_bend_monitor_policies [writ_bend_monitor_client $client \
		" | mode: bad_length | session: 1 | expected_session: 6 | claimed_subject: 1 | expect_decision: 1 | expect_reason: 0 | delay_ms: 2000"]

	run_genode_until "child \"$client\" exited with exit value .*\n" 122

	if {![regexp "child \"$client\" exited with exit value 0\r?\n" $output]} {
		puts stderr "Error: the client $client did not exit with value 0"
		exit 1
	}
	set m "\\\[init -> $monitor\\\]"
	set c "\\\[init -> $client\\\]"
	writ_bend_monitor_require [list \
		"$m writ_channel: channel 1 opened for '$client -> channel' route subject 1\r?\n" "channel opened" \
		"$m \[^\r\n\]*Warning: writ_channel: channel 1 request length 65 is not 64, refused before Bend \\(bad length count 1\\)" "shim refusal of length 65" \
		"$m \[^\r\n\]*Warning: writ_channel: channel 1 request length 0 is not 64, refused before Bend \\(bad length count 2\\)" "shim refusal of length 0" \
		"$c client: refusal for request length 65 seq 1: kind=3 \\(transport refusal\\) decision=Denied \\(2\\) reason=256 \\(bad length\\)" "client refusal line for 65" \
		"$c client: refusal for request length 0 seq 2: kind=3 \\(transport refusal\\) decision=Denied \\(2\\) reason=256 \\(bad length\\)" "client refusal line for 0" \
		"$m monitor: channel=1 route_subject=1 session=1 body_claimed_subject=1 \\(untrusted, not used\\) decision=Committed reason=0 " "Bend decision line for the valid request" \
		"$c client: decision=Committed \\(1\\) reason=0 route_subject=1 session=1 seq=3" "client decision for seq 3" \
		"$c client: PASS decision 1 reason 0 as expected" "client verdict" ]
	# Neither refused request reached Bend: one decision line in all.
	set decisions [regexp -all "$m monitor: channel=\[0-9\]+ route_subject=\[0-9\]+ session=\[0-9\]+ body_claimed_subject=\[0-9\]+ \\(untrusted, not used\\) decision=" $output]
	if {$decisions != 1} {
		puts stderr "Error: $decisions Bend decision lines, expected 1 (a refused request reached Bend)"
		exit 1
	}
	puts "\n--- $client: lengths 65 and 0 refused by the shim before Bend; valid request Committed ---"
}

proc writ_bend_monitor_liveness_run { } {
	global writ_bend_monitor_policies
	global output

	set monitor writ_bend_monitor
	set flood   writ_client_s
	set served  writ_client_r

	writ_bend_monitor_boot $writ_bend_monitor_policies \
		"[writ_bend_monitor_client $flood " | mode: flood | count: 12 | period_ms: 400 | session: 2 | expected_session: 0 | claimed_subject: 2"][writ_bend_monitor_client $served " | session: 1 | expected_session: 6 | claimed_subject: 1 | expect_decision: 1 | expect_reason: 0 | delay_ms: 1000"]"

	# Another request arrives after the fuel ran out: the end of the run.
	run_genode_until "child \"$monitor\" exited with exit value \[0-9\]+\r?\n.*\\\[init -> $flood\\\] client: flood request \[0-9\]+ of 12 signalled" 130

	set m "\\\[init -> $monitor\\\]"
	set s "monitor: channel=\[0-9\]+ route_subject=2 session=2 body_claimed_subject=2 \\(untrusted, not used\\) decision=Denied reason=5 "
	set r "monitor: channel=\[0-9\]+ route_subject=1 session=1 body_claimed_subject=1 \\(untrusted, not used\\) decision=Committed reason=0 "
	writ_bend_monitor_require [list \
		"$m writ_channel: channel \[0-9\]+ opened for '$flood -> channel' route subject 2\r?\n" "flooding channel opened" \
		"$m writ_channel: channel \[0-9\]+ opened for '$served -> channel' route subject 1\r?\n" "served channel opened" \
		"$m $s.*$m $r" "a flood decision before the served client's decision" \
		"$m $r.*$m $s" "a flood decision after the served client's decision" \
		"\\\[init -> $served\\\] client: PASS decision 1 reason 0 as expected" "served client verdict" \
		"child \"$served\" exited with exit value 0\r?\n" "served client exit value 0" \
		"$m monitor: fuel exhausted, exiting" "fuel exhausted line" \
		"$m writ_mem: \\\[exit\\\] ram used=\[0-9\]+ limit=\[0-9\]+ caps used=\[0-9\]+ limit=\[0-9\]+ " "monitor RAM and caps at exit" \
		"$m writ_mem: \\\[exit\\\] channel signals=\[0-9\]+ coalesced=\[0-9\]+ ring full=0 bad length=0 stale=\[0-9\]+ taken=\[0-9\]+ put=\[0-9\]+ put skipped=\[0-9\]+ closed=\[0-9\]+ open=\[0-9\]+ closing=\[0-9\]+" "shim channel counters at exit" \
		"child \"$monitor\" exited with exit value 0\r?\n" "monitor exit value 0" \
		"$m monitor: fuel exhausted, exiting.*child \"$monitor\" exited with exit value 0\r?\n.*\\\[init -> $flood\\\] client: flood request \[0-9\]+ of 12 signalled" "a flood request after the monitor's exit" ]
	puts "\n--- $flood flooded without reading; $served served Committed; monitor exited 0 at fuel 0 ---"
}
