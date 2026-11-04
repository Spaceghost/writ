#
# writ_bend_monitor.tcl - shared Genode run-script procedure for the Writ
# channel runs (build configuration), not Writ implementation. Genode
# channel lane, Tasks 2 and 3. Sourced by writ_bend_monitor_accept.run,
# writ_bend_monitor_substitute.run, writ_bend_monitor_routed_s.run,
# writ_bend_monitor_claim_ignored.run, writ_bend_monitor_bad_length.run,
# writ_bend_monitor_liveness.run, writ_bend_monitor_queue.run, and
# writ_bend_monitor_dead_client.run through
#   source [select_from_repositories run/writ_bend_monitor.tcl]
# It sources scripts/genode/writ_bend.tcl (run/writ_bend.tcl) and boots
# through its writ_bend_boot.
# Live copy: ../writ-genode/writ-repo/run/writ_bend_monitor.tcl (byte-identical).
#
# base-hw (Genode base-hw lane, Task 3): the same procedures run from a
# KERNEL=hw BOARD=pc build directory under QEMU; every line match accepts
# any number of carriage returns before the newline (QEMU's serial log ends
# lines in "\r\r\n").
#
# writ_bend_monitor_run CLIENT SUBJECT SESSION EXPECTED CLAIMED DECISION REASON DELAY ?POLICIES?
#   Builds and boots, under init (base-linux or base-hw), the Bend monitor component
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
#   One client, writ_client_r (route subject 1), in mode bad_length:
#   requests with header lengths 65, 0, and 4294967295 (0xFFFFFFFF, above
#   the 4 KiB bucket), then R's valid request on session 1. Fails unless
#   the shim warned for the three lengths with bad length counts 1, 2, 3,
#   the client printed the shim's refusal for each, the monitor logged
#   exactly one decision line (the valid request, seq 4: Committed, reason
#   0), and the client exited 0.
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
#   On base-hw the monitor's exit destroys the buckets, so S's next record
#   write faults and core logs "illegal WRITE ... pd='init -> writ_client_s'";
#   that line, after init's report of the monitor's exit, ends the run there
#   (base-hw lane, Task 3).
#
# writ_bend_monitor_queue_run (Task 3, GB-006 queue depth and channels)
#   Nine clients writ_client_q1 .. writ_client_q9, each under its own
#   policy label_prefix "writ_client_qN ->" (route subject 2; the trailing
#   " ->" keeps a prefix from matching a longer child name). The shim admits 8
#   channels (MAX_CHANNELS) and refuses the ninth session. After 2000 ms
#   each admitted client floods S's request (500 times, 2 ms apart, never
#   reading a reply), so requests from several channels arrive while the
#   monitor takes one at a time. The monitor's 8 units of fuel are spent on
#   8 requests (Denied, reason 5) and it exits. Fails unless exactly one
#   session was refused for the channel limit, 8 channels opened, 8 Bend
#   decision lines were logged, the exit counters show ring full=0 and 8
#   taken and put, and init reported the monitor's exit value 0. The
#   ring's high-water mark (ring max=) and the coalesced count are
#   recorded, not required (they depend on timing). A first version with
#   one request per client after the delay never had more than one entry
#   in the ring (ring max=1, arrivals spread out) and spent fuel on close
#   events; it was replaced by this one.
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

source [select_from_repositories run/writ_bend.tcl]

# Boots the monitor through writ_bend_boot: it provides Writ_channel, its
# <config> holds the <writ_channel> POLICIES, and CLIENTS are further
# children of init.
proc writ_bend_monitor_boot { policies clients } {
	writ_bend_boot writ_bend_monitor 256M 1000 /dev/log "
  + provides | + service Writ_channel" "
    + writ_channel$policies" $clients [list app/writ_channel_client]
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
	writ_bend_refuse_reserve_failure
}

proc writ_bend_monitor_run { client subject session expected claimed decision reason delay {policies ""} } {
	global writ_bend_monitor_policies
	if {$policies == ""} { set policies $writ_bend_monitor_policies }
	global output

	set monitor writ_bend_monitor

	writ_bend_monitor_boot $policies [writ_bend_monitor_client $client \
		" | session: $session | expected_session: $expected | claimed_subject: $claimed | expect_decision: $decision | expect_reason: $reason | delay_ms: $delay"]

	run_genode_until "child \"$client\" exited with exit value .*\n" [expr {120 + $delay/1000}]

	if {![regexp "child \"$client\" exited with exit value 0\r*\n" $output]} {
		puts stderr "Error: the client $client did not exit with value 0"
		exit 1
	}
	writ_bend_refuse_reserve_failure

	set names [dict create 1 Committed 2 Denied]
	set name [dict get $names $decision]
	foreach {re what} [list \
		"\\\[init -> $monitor\\\] writ_mem: libc mmap="                                       "shim start line" \
		"\\\[init -> $monitor\\\] writ_channel: service announced"                            "service announced" \
		"\\\[init -> $monitor\\\] writ_channel: channel 1 opened for '$client -> channel' route subject $subject\r*\n" "channel opened with route subject $subject" \
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

	if {![regexp "child \"$client\" exited with exit value 0\r*\n" $output]} {
		puts stderr "Error: the client $client did not exit with value 0"
		exit 1
	}
	set m "\\\[init -> $monitor\\\]"
	set c "\\\[init -> $client\\\]"
	writ_bend_monitor_require [list \
		"$m writ_channel: channel 1 opened for '$client -> channel' route subject 1\r*\n" "channel opened" \
		"$m \[^\r\n\]*Warning: writ_channel: channel 1 request length 65 is not 64, refused before Bend \\(bad length count 1\\)" "shim refusal of length 65" \
		"$m \[^\r\n\]*Warning: writ_channel: channel 1 request length 0 is not 64, refused before Bend \\(bad length count 2\\)" "shim refusal of length 0" \
		"$m \[^\r\n\]*Warning: writ_channel: channel 1 request length 4294967295 is not 64, refused before Bend \\(bad length count 3\\)" "shim refusal of length 0xFFFFFFFF" \
		"$c client: refusal for request length 65 seq 1: kind=3 decision=3 \\(transport refusal\\) reason=256 \\(bad length\\)" "client refusal line for 65" \
		"$c client: refusal for request length 0 seq 2: kind=3 decision=3 \\(transport refusal\\) reason=256 \\(bad length\\)" "client refusal line for 0" \
		"$c client: refusal for request length 4294967295 seq 3: kind=3 decision=3 \\(transport refusal\\) reason=256 \\(bad length\\)" "client refusal line for 0xFFFFFFFF" \
		"$m monitor: channel=1 route_subject=1 session=1 body_claimed_subject=1 \\(untrusted, not used\\) decision=Committed reason=0 " "Bend decision line for the valid request" \
		"$c client: decision=Committed \\(1\\) reason=0 route_subject=1 session=1 seq=4" "client decision for seq 4" \
		"$c client: PASS decision 1 reason 0 as expected" "client verdict" ]
	# No refused request reached Bend: one decision line in all.
	set decisions [regexp -all "$m monitor: channel=\[0-9\]+ route_subject=\[0-9\]+ session=\[0-9\]+ body_claimed_subject=\[0-9\]+ \\(untrusted, not used\\) decision=" $output]
	if {$decisions != 1} {
		puts stderr "Error: $decisions Bend decision lines, expected 1 (a refused request reached Bend)"
		exit 1
	}
	puts "\n--- $client: lengths 65, 0, 0xFFFFFFFF refused by the shim before Bend; valid request Committed ---"
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
	# base-linux: the flooding client signals again. base-hw: the monitor's
	# exit destroys the buckets (its RAM dataspaces), so the flooding
	# client's next record write into its request bucket faults and core
	# logs it (observed: "illegal WRITE at address 0x4010 by pager_object:
	# pd='init -> writ_client_s'", ip in Main::_write, the record copy at
	# bucket offset 0x10; region_map_component.cc:103).
	if {[have_spec hw]} {
		set after_exit "Error: illegal WRITE at address \[^\r\n\]* pd='init -> $flood'"
	} else {
		set after_exit "\\\[init -> $flood\\\] client: flood request \[0-9\]+ of 12 signalled"
	}
	run_genode_until "child \"$monitor\" exited with exit value \[0-9\]+\r*\n.*$after_exit" 130

	set m "\\\[init -> $monitor\\\]"
	set s "monitor: channel=\[0-9\]+ route_subject=2 session=2 body_claimed_subject=2 \\(untrusted, not used\\) decision=Denied reason=5 "
	set r "monitor: channel=\[0-9\]+ route_subject=1 session=1 body_claimed_subject=1 \\(untrusted, not used\\) decision=Committed reason=0 "
	writ_bend_monitor_require [list \
		"$m writ_channel: channel \[0-9\]+ opened for '$flood -> channel' route subject 2\r*\n" "flooding channel opened" \
		"$m writ_channel: channel \[0-9\]+ opened for '$served -> channel' route subject 1\r*\n" "served channel opened" \
		"$m $s.*$m $r" "a flood decision before the served client's decision" \
		"$m $r.*$m $s" "a flood decision after the served client's decision" \
		"\\\[init -> $served\\\] client: PASS decision 1 reason 0 as expected" "served client verdict" \
		"child \"$served\" exited with exit value 0\r*\n" "served client exit value 0" \
		"$m monitor: channel=\[0-9\]+ closed \\(shim close event\\) bindings 1 -> 0" "close event dropping the served client's binding" \
		"$m monitor: fuel exhausted, exiting" "fuel exhausted line" \
		"$m writ_mem: \\\[exit\\\] ram used=\[0-9\]+ limit=\[0-9\]+ caps used=\[0-9\]+ limit=\[0-9\]+ " "monitor RAM and caps at exit" \
		"$m writ_mem: \\\[exit\\\] channel signals=\[0-9\]+ coalesced=\[0-9\]+ ring full=0 ring max=\[0-9\]+ bad length=0 stale=\[0-9\]+ taken=\[0-9\]+ put=\[0-9\]+ put skipped=\[0-9\]+ closed=1 open=\[0-9\]+ closing=\[0-9\]+" "shim channel counters at exit (closed=1)" \
		"child \"$monitor\" exited with exit value 0\r*\n" "monitor exit value 0" \
		"$m monitor: fuel exhausted, exiting.*child \"$monitor\" exited with exit value 0\r*\n.*$after_exit" "a flood request after the monitor's exit" ]
	puts "\n--- $flood flooded without reading; $served served Committed; monitor exited 0 at fuel 0 ---"
}

proc writ_bend_monitor_queue_run { } {
	global output

	set monitor writ_bend_monitor
	set clients ""
	for {set i 1} {$i <= 9} {incr i} {
		append clients [writ_bend_monitor_client writ_client_q$i \
			" | mode: flood | count: 500 | period_ms: 2 | session: 2 | expected_session: 0 | claimed_subject: 2 | delay_ms: 2000"]
	}
	set policies ""
	for {set i 1} {$i <= 9} {incr i} {
		append policies "
      + policy | label_prefix: writ_client_q$i -> | subject: 2"
	}
	writ_bend_monitor_boot $policies $clients

	run_genode_until "child \"$monitor\" exited with exit value .*\n" 130

	set m "\\\[init -> $monitor\\\]"
	writ_bend_monitor_require [list \
		"$m monitor: fuel exhausted, exiting" "fuel exhausted line" \
		"$m writ_mem: \\\[exit\\\] ram used=\[0-9\]+ limit=\[0-9\]+ caps used=\[0-9\]+ limit=\[0-9\]+ " "monitor RAM and caps at exit" \
		"$m writ_mem: \\\[exit\\\] channel signals=\[0-9\]+ coalesced=\[0-9\]+ ring full=0 ring max=\[1-8\] bad length=0 stale=0 taken=8 put=8 put skipped=0 closed=0 open=8 closing=0" "shim channel counters at exit" \
		"child \"$monitor\" exited with exit value 0\r*\n" "monitor exit value 0" ]
	set refused [regexp -all "$m \[^\r\n\]*Warning: writ_channel: 8 channels open or closing, session for 'writ_client_q\[0-9\] -> channel' denied" $output]
	set opened  [regexp -all "$m writ_channel: channel \[0-9\]+ opened for 'writ_client_q\[0-9\] -> channel' route subject 2" $output]
	set decided [regexp -all "$m monitor: channel=\[0-9\]+ route_subject=2 session=2 body_claimed_subject=2 \\(untrusted, not used\\) decision=Denied reason=5 " $output]
	if {$refused != 1 || $opened != 8 || $decided != 8} {
		puts stderr "Error: $opened channels opened, $refused refused, $decided decisions (expected 8, 1, 8)"
		exit 1
	}
	regexp {ring max=([0-9]+)} $output -> ring_max
	regexp {coalesced=([0-9]+)} $output -> coalesced
	puts "\n--- 8 channels, the ninth session refused; ring max=$ring_max of 8, coalesced=$coalesced; monitor exited 0 ---"
}

# writ_bend_monitor_dead_client_run (Task 3 final review, GB-008)
#   Three clients: writ_client_d (route subject 2) sends S's request and
#   exits at once, before any reply; writ_client_f (route subject 2)
#   registers a result signal context, frees it, sends S's request, and
#   stays alive, so the monitor's reply signal goes to a context that no
#   longer exists; writ_client_r (route subject 1) sends R's request after
#   3000 ms and must be Committed. Fails unless the freed-context
#   client's decision is logged before R's, core warns about the freed
#   context (base-linux only: base-hw's kernel drops a signal to an invalid
#   context silently, repos/base-hw/src/core/kernel/thread.cc:395-400, so
#   there is no line to require), R's PASS and exit 0 are logged, and init
#   reported no exit of the monitor (it must still be serving).
proc writ_bend_monitor_dead_client_run { } {
	global output

	set monitor writ_bend_monitor
	set policies {
      + policy | label_prefix: writ_client_r -> | subject: 1
      + policy | label_prefix: writ_client_d -> | subject: 2
      + policy | label_prefix: writ_client_f -> | subject: 2}
	writ_bend_monitor_boot $policies "[writ_bend_monitor_client writ_client_d " | mode: exit_after_signal | session: 2 | expected_session: 0 | claimed_subject: 2"][writ_bend_monitor_client writ_client_f " | mode: freed_sigh | session: 2 | expected_session: 0 | claimed_subject: 2"][writ_bend_monitor_client writ_client_r " | session: 1 | expected_session: 6 | claimed_subject: 1 | expect_decision: 1 | expect_reason: 0 | delay_ms: 3000"]"

	run_genode_until "child \"writ_client_r\" exited with exit value .*\n" 130

	set m "\\\[init -> $monitor\\\]"
	# The freed-context client's channel, from the shim's open line, so
	# its own decision (and so the reply to its freed context) is
	# required, not just any route-subject-2 decision. The dead client's
	# decision is not required: its queued entry may become the close
	# event instead (observed once), so the S count is 1 or 2.
	if {![regexp "$m writ_channel: channel (\[0-9\]+) opened for 'writ_client_f -> channel' route subject 2" $output -> f_channel]} {
		puts stderr "Error: missing freed-context client's channel"
		exit 1
	}
	writ_bend_monitor_require [list \
		"\\\[init -> writ_client_d\\\] client: request sent, exiting before any reply" "dead client sent and exited" \
		"\\\[init -> writ_client_f\\\] client: registered a result signal context and freed it" "freed result context" \
		"\\\[init -> writ_client_f\\\] client: request sent, staying alive with no result handler" "freed-context client sent" \
		"$m monitor: channel=$f_channel route_subject=2 session=2 body_claimed_subject=2 \\(untrusted, not used\\) decision=Denied reason=5 .*$m monitor: channel=\[0-9\]+ route_subject=1 session=1 body_claimed_subject=1 \\(untrusted, not used\\) decision=Committed reason=0 " "R's decision after the freed-context client's decision" \
		[expr {[have_spec hw] ? "client: request sent, staying alive with no result handler" : "Warning: invalid signal-context capability"}] [expr {[have_spec hw] ? "freed-context client still alive (base-hw drops a signal to a freed context silently, kernel/thread.cc:395-400)" : "core warning for the freed context"}] \
		"\\\[init -> writ_client_r\\\] client: PASS decision 1 reason 0 as expected" "R's verdict" \
		"child \"writ_client_r\" exited with exit value 0\r*\n" "R exit value 0" ]
	if {[regexp "child \"$monitor\" exited" $output]} {
		puts stderr "Error: the monitor exited"
		exit 1
	}
	set decided [regexp -all "$m monitor: channel=\[0-9\]+ route_subject=2 session=2 " $output]
	puts "\n--- dead and freed-context clients: $decided S decisions; writ_client_r served Committed; monitor still serving ---"
}
