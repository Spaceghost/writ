# Public-fixture tooling only. The fixed entry points choose the reference;
# this helper authenticates no actor and must not be used as a policy engine.
# The overlay, reference path and Tcl interpreter are trusted test inputs.
# The byte cap does not bound open/read latency or prevent a substituted FIFO,
# symlink or same-UID path race. Only an independently bounded outer supervisor
# can bound a stall; this helper is not a safe descriptor-based file opener.
proc writ_fixture_config_guard_install {reference expected_length} {
  if {![string is integer -strict $expected_length] || $expected_length < 1 || $expected_length > 16384} {
    error "invalid fixed reference length"
  }
  set f [open $reference rb]
  try {
    fconfigure $f -translation binary -encoding binary
    set expected [read $f 16385]
  } finally {
    close $f
  }
  if {[string length $expected] != $expected_length ||
      ![string is ascii -strict $expected] || [string first "\x00" $expected] >= 0} {
    error "invalid fixed reference"
  }
  if {![llength [info commands ::install_config]] ||
      [llength [info commands ::writ_fixture_original_install_config]]} {
    error "unexpected installer state"
  }
  # This value is populated before the fixture runs; Tcl and this entire
  # checkout/overlay are trusted. It is not protected from same-interpreter
  # mutation, nor intended as a public configuration or authority API.
  set ::writ_fixture_expected_config $expected
  rename ::install_config ::writ_fixture_original_install_config
  proc ::install_config {args} {
    if {[llength $args] != 1} {error "fixture config requires one argument"}
    set config [lindex $args 0]
    if {[string length $config] > 16384} {error "fixture config exceeds cap"}
    if {![string is ascii -strict $config] || [string first "\x00" $config] >= 0} {
      error "fixture config is not non-NUL ASCII"
    }
    if {![string equal $config $::writ_fixture_expected_config]} {
      error "fixture config differs from fixed reference"
    }
    return [::writ_fixture_original_install_config $config]
  }
}
