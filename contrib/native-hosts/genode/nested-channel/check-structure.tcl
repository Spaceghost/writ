# Portable structural check only: stubs Genode build/boot functions and adapts
# a historical public same-init log into a synthetic nested-shaped sample.
# It does not parse the Genode configuration or run a Genode component.
if {[llength $argv] != 1 || [lindex $argv 0] ni {sample wrong-label wrong-byte missing-exit}} {
  puts stderr "usage: tclsh check-structure.tcl sample|wrong-label|wrong-byte|missing-exit"
  exit 2
}
set mode [lindex $argv 0]
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here ../../../..]]

proc select_from_repositories {name} {
  global repo
  switch -- $name {
    run/writ_bend_monitor.tcl {return [file join $repo scripts/genode/writ_bend_monitor/writ_bend_monitor.tcl]}
    run/writ_bend.tcl {return [file join $repo scripts/genode/writ_bend.tcl]}
    default {error "unexpected repository lookup: $name"}
  }
}
proc build {args} {set ::build_args $args}
proc create_boot_directory {} {}
proc install_config {config} {set ::config $config}
proc build_artifacts {} {return {}}
proc build_boot_image {args} {}
proc run_genode_until {pattern timeout} {
  if {$timeout != 122} {error "unexpected fixture timeout"}
  set ::output $::sample
}

set fd [open [file join $repo verification/genode-channel-base-linux.txt] r]
set history [read $fd]
close $fd
set begin [string first {RUNS (all with the final tree} $history]
set end [string first {  Run 2, make run/writ_bend_monitor_substitute} $history $begin]
if {$begin < 0 || $end < 0} {error "historical R capture not found"}
set sample [string range $history $begin [expr {$end - 1}]]
set sample [string map [list \
  {[init -> writ_client_r]} {[init -> clients -> writ_client_r]} \
  {for 'writ_client_r -> channel'} {for 'clients -> writ_client_r -> channel'}] $sample]
append sample "\n" {[init -> writ_bend_monitor] writ_channel: service announced} "\n" \
  {[init -> writ_bend_monitor] monitor: SYNTHETIC authority} "\n"
switch -- $mode {
  wrong-label {set sample [string map {{clients -> writ_client_r -> channel} {clients -> wrong -> channel}} $sample]}
  wrong-byte {set sample [string map {{2d 00 00 00 02 00 00 00 02 00 00 00} {2e 00 00 00 02 00 00 00 02 00 00 00}} $sample]}
  missing-exit {set sample [string map {{child "writ_client_r" exited with exit value 0} {child "writ_client_r" exited with exit value 1}} $sample]}
}

source [file join $here writ_bend_monitor_nested_accept.run]
if {$mode ne "sample"} {error "negative sample unexpectedly accepted"}
# Check text boundaries that were previously easy to concatenate incorrectly.
# This is not a complete HID parser or evidence that Genode accepts the config.
foreach required [list \
  "\n    + writ_channel\n      + policy | label_prefix: clients -> writ_client_r -> | subject: 1" \
  "\n+ start clients | caps: 1200 | ram: 16M" \
  "\n  | + parent-provides\n" \
  "\n  | + start writ_client_r | caps: 200 | ram: 2M" \
  "\n  |     + service Writ_channel | + parent" \
  "\n    + service Writ_channel | + child writ_bend_monitor"] {
  if {[string first $required $config] < 0} {error "missing config fragment: $required"}
}
puts "structural stub: PASS (no Genode process or nested observation)"
