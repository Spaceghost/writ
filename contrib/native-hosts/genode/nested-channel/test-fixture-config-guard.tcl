# Offline tooling controls. Builds, installers and Genode waits below are stubs;
# no Genode, QEMU, shell command or external process is launched.
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here ../../../..]]
set f [open [file join $repo verification/genode-channel-base-linux.txt] r]
set history [read $f]
close $f
set begin [string first {RUNS (all with the final tree} $history]
set end [string first {  Run 2, make run/writ_bend_monitor_substitute} $history $begin]
if {$begin < 0 || $end < 0} {error "historical synthetic sample unavailable"}
set sample [string range $history $begin [expr {$end - 1}]]
set sample [string map [list \
  {[init -> writ_client_r]} {[init -> clients -> writ_client_r]} \
  {for 'writ_client_r -> channel'} {for 'clients -> writ_client_r -> channel'}] $sample]
append sample "\n" {[init -> writ_bend_monitor] writ_channel: service announced} "\n" \
  {[init -> writ_bend_monitor] monitor: SYNTHETIC authority} "\n"
set passes 0
proc check {ok name} {
  global passes
  if {!$ok} {error "FAIL: $name"}
  incr passes
  puts "PASS: $name"
}
proc make_test_interp {scenario fail_installer} {
  global repo here sample
  set i [interp create]
  interp eval $i [list set ::repo $repo]
  interp eval $i [list set ::here $here]
  interp eval $i [list set ::sample $sample]
  interp eval $i [list set ::scenario $scenario]
  interp eval $i [list set ::fail_installer $fail_installer]
  interp eval $i {
    set ::installs 0
    set ::builds 0
    set ::images 0
    set ::waits 0
    set ::forwarded {}
    proc exit {status} { error "TEST_EXIT:$status" }
    # In one synthetic test only, alter the fixed fixture text in memory; the
    # real writ_bend_boot and original installer remain the same stubs.
    rename source original_source
    proc source {path} {
      if {$::scenario eq "positive_modified" &&
          $path eq [file join $::here writ_bend_monitor_nested_accept.run]} {
        set f [open $path r]
        try {set text [read $f]} finally {close $f}
        set old {+ policy | label_prefix: clients -> writ_client_r -> | subject: 1}
        set new {+ policy | label_prefix: clients -> writ_client_r -> | subject: 2}
        set changed [string map [list $old $new] $text]
        if {$changed eq $text} {error "fixture mutation absent"}
        return [uplevel 1 $changed]
      }
      return [uplevel 1 [list original_source $path]]
    }
    proc select_from_repositories {name} {
      switch -- $name {
        run/writ_bend_monitor.tcl {return [file join $::repo scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl]}
        run/writ_bend.tcl {return [file join $::repo scripts/genode/writ_bend.tcl]}
        run/writ_fixture_config_guard.tcl {return [file join $::here writ_fixture_config_guard.tcl]}
        run/writ_guard_positive.args {return [file join $::here writ_guard_positive.args]}
        run/writ_guard_negative.args {return [file join $::here writ_guard_negative.args]}
        run/writ_bend_monitor_nested_accept.run {return [file join $::here writ_bend_monitor_nested_accept.run]}
        run/writ_bend_monitor_nested_route_negative.run {return [file join $::here writ_bend_monitor_nested_route_negative.run]}
        default {error "unexpected source lookup: $name"}
      }
    }
    proc build {args} {incr ::builds}
    proc create_boot_directory {} {}
    proc install_config {args} {
      incr ::installs
      if {$::fail_installer} {error "synthetic installer failure"}
      lappend ::forwarded [lindex $args 0]
      # Mimic pinned install_boot_module's puts, without opening any file.
      set ::installed "[lindex $args 0]\n"
    }
    proc build_artifacts {} {return {}}
    proc build_boot_image {args} {incr ::images}
    proc output_spawn_id {} {return owned_synthetic_spawn}
    proc run_genode_until {pattern seconds args} {
      incr ::waits
      if {$::scenario eq "positive"} {
        if {$::waits != 1 || $seconds != 122 || [llength $args] != 0} {error "unexpected positive wait"}
        set ::output $::sample
        return
      }
      if {$::waits == 1} {
        if {$seconds != 122 || [llength $args] != 0} {error "unexpected initial wait"}
        set esc [format %c 27]
        set ::output "\[init -> clients -> writ_client_r\] ${esc}\[31mError: stop because parent denied Writ_channel-session:\n"
      } elseif {$::waits == 2} {
        if {[llength $args] != 1 || [lindex $args 0] ne "owned_synthetic_spawn" || $seconds < 1 || $seconds > 122} {
          error "continuation did not preserve spawn or deadline"
        }
        set esc [format %c 27]
        append ::output "\[init -> writ_bend_monitor\] writ_channel: service announced\n" \
          "\[init -> writ_bend_monitor\] monitor: SYNTHETIC authority\n" \
          "\[init -> clients\] ${esc}\[34mWarning: writ_client_r: no route to service \"Writ_channel\" (label=\"writ_client_r -> channel\")${esc}\[0m\n"
      } else {error "unexpected extra wait"}
    }
  }
  return $i
}
proc run_entry {i name} {
  global here
  interp eval $i [list source [file join $here $name]]
}

set pos [make_test_interp positive 0]
run_entry $pos writ_bend_monitor_nested_guarded_positive.run
set positive [$pos eval {set ::writ_fixture_expected_config}]
check [expr {[$pos eval {set ::installs}] == 1 && [$pos eval {set ::images}] == 1 && [$pos eval {set ::waits}] == 1}] positive_exact_and_actual_boot
check [expr {[$pos eval {set ::installed}] eq "${positive}\n"}] positive_stub_puts_lf
check [expr {[$pos eval {lindex $::forwarded 0}] eq $positive}] exact_argument_forwarded

set neg [make_test_interp negative 0]
run_entry $neg writ_bend_monitor_nested_guarded_negative.run
set negative [$neg eval {set ::writ_fixture_expected_config}]
check [expr {[$neg eval {set ::installs}] == 1 && [$neg eval {set ::images}] == 1 && [$neg eval {set ::waits}] == 2}] negative_late_marker_continuation
check [expr {[$neg eval {set ::installed}] eq "${negative}\n"}] negative_stub_puts_lf
check [expr {$positive ne $negative}] distinct_references

# Exercise the real wrapped installer after resetting only the stub call count.
$pos eval {set ::installs 0}
check [expr {[catch {$pos eval [list install_config $positive]}] == 0 && [$pos eval {set ::installs}] == 1}] repeated_valid_forwarded
set before [$pos eval {set ::installs}]
check [expr {[catch {$pos eval [list install_config $negative]}] != 0 && [$pos eval {set ::installs}] == $before}] negative_reference_rejected_by_positive
set before [$neg eval {set ::installs}]
check [expr {[catch {$neg eval [list install_config $positive]}] != 0 && [$neg eval {set ::installs}] == $before}] positive_reference_rejected_by_negative

set replacements [list \
  {extra_policy} "\n      + policy | label_prefix: clients -> writ_client_r -> | subject: 2" \
  {empty_prefix} {} \
  {space_prefix} {   } \
  {sibling_prefix} {clients -> writ_client_r} \
  {changed_subject} 2]
set prefix {clients -> writ_client_r ->}
foreach {name value} $replacements {
  if {$name eq "extra_policy"} {
    set original {      + policy | label_prefix: clients -> writ_client_r -> | subject: 1}
    set changed [string map [list $original "${original}${value}"] $positive]
  } elseif {$name eq "changed_subject"} {
    set changed [string map {{| subject: 1} {| subject: 2}} $positive]
  } else {
    set changed [string map [list $prefix $value] $positive]
  }
  set before [$pos eval {set ::installs}]
  check [expr {$changed ne $positive && [catch {$pos eval [list install_config $changed]}] != 0 && [$pos eval {set ::installs}] == $before}] mutation_$name
}
set first {      + policy | label_prefix: clients -> writ_client_r -> | subject: 1}
set second {      + policy | label_prefix: clients -> writ_client_s -> | subject: 2}
foreach {name pair} [list ordered "${first}\n${second}" reversed "${second}\n${first}"] {
  set changed [string map [list $first $pair] $positive]
  set before [$pos eval {set ::installs}]
  check [expr {$changed ne $positive && [catch {$pos eval [list install_config $changed]}] != 0 && [$pos eval {set ::installs}] == $before}] mutation_policy_$name
}
foreach {name value} [list \
  removed_route $negative \
  missing_final_lf [string range $positive 0 end-1] \
  added_lf "${positive}\n" \
  nul "${positive}\x00" \
  non_ascii "${positive}\u00e9" \
  exact_cap [string repeat x 16384] \
  over_cap [string repeat x 16385]] {
  set before [$pos eval {set ::installs}]
  check [expr {[catch {$pos eval [list install_config $value]}] != 0 && [$pos eval {set ::installs}] == $before}] boundary_$name
}
set before [$pos eval {set ::installs}]
check [expr {[catch {$pos eval {install_config}}] != 0 && [$pos eval {set ::installs}] == $before}] missing_argument
check [expr {[catch {$pos eval [list install_config $positive extra]}] != 0 && [$pos eval {set ::installs}] == $before}] extra_argument

# Run the actual writ_bend_boot a second time with one altered policy. Compilation
# stub may run first; mismatch must prevent original install and image build.
set old_installs [$pos eval {set ::installs}]
set old_images [$pos eval {set ::images}]
set old_waits [$pos eval {set ::waits}]
set boot_call {writ_bend_boot writ_bend_monitor 256M 1000 /dev/log \
  "\n  + provides | + service Writ_channel" \
  "\n    + writ_channel${::policies}\n      + policy | label_prefix: clients -> writ_client_r -> | subject: 2" \
  $::clients [list app/writ_channel_client]}
check [expr {[catch {$pos eval $boot_call}] != 0 && [$pos eval {set ::installs}] == $old_installs && [$pos eval {set ::images}] == $old_images && [$pos eval {set ::waits}] == $old_waits}] actual_boot_mutation_stops_before_install_image

set failed [make_test_interp positive 1]
set status [catch {run_entry $failed writ_bend_monitor_nested_guarded_positive.run} detail]
check [expr {$status != 0 && $detail eq "TEST_EXIT:1" && [$failed eval {set ::installs}] == 1 && [$failed eval {set ::images}] == 0 && [$failed eval {set ::waits}] == 0}] installer_error_no_boot
set modified [make_test_interp positive_modified 0]
set status [catch {run_entry $modified writ_bend_monitor_nested_guarded_positive.run} detail]
check [expr {$status != 0 && $detail eq "TEST_EXIT:1" && [$modified eval {set ::installs}] == 0 && [$modified eval {set ::images}] == 0 && [$modified eval {set ::waits}] == 0}] entrypoint_mutation_exits_before_install_image_launch
interp delete $modified
interp delete $failed
interp delete $pos
interp delete $neg
puts "ALL $passes FIXTURE GUARD CONTROLS PASSED (stubs only; no Genode)"
