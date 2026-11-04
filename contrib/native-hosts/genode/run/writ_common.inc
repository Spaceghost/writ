# Shared boot settings for the native public-canary qualification probes.
assert {[have_spec hw] && [have_spec x86_64] && [have_board pc]}
assert {[have_include power_on/qemu] && [have_include image/iso]}

proc writ_parent_services { } { return {
+ parent-provides
  + service CPU
  + service PD
  + service RM
  + service ROM
  + service LOG
+ default-route
  + service CPU | + parent
  + service PD  | + parent
  + service RM  | + parent
  + service LOG | + parent
  + service Timer | + child timer
+ default | caps: 128 | ram: 4M
+ start timer
  + provides | + service Timer
  + route | + any-service | + parent
} }

proc writ_rom_route { binaries } {
    set result ""
    foreach binary $binaries {
        # Initial executable/loader requests can be unscoped. Later component
        # ROM requests carry the parent-owned child prefix; match their exact
        # remaining label as well, without a prefix/suffix wildcard.
        append result "    + service ROM | unscoped_label: $binary | + parent\n"
        append result "    + service ROM | label: $binary | + parent\n"
    }
    append result {
    + service CPU | + parent
    + service PD  | + parent
    + service RM  | + parent
    + service LOG | + parent
    + service Timer | + child timer
}
    return $result
}

proc writ_server { controller } { return [join [list {
+ start writfs | caps: 256 | ram: 128M
  + provides
    + service File_system
    + service Writ_control
  + config | reader: reader -> / | size: 33 | controller: } $controller {
    + libc | stdout: /dev/log | stderr: /dev/log
    + vfs | + dir dev | + log
  + route
} [writ_rom_route { writfs ld.lib.so libc.lib.so libm.lib.so vfs.lib.so mount.mjs canary }] {
} ] ""] }

proc writ_generated { names } {
    global env
    if {![info exists env(WRIT_GENERATED_DIR)]} {
        error "WRIT_GENERATED_DIR must name fresh generated Bend artifacts"
    }
    foreach name $names {
        set source [file join $env(WRIT_GENERATED_DIR) $name]
        if {![file isfile $source]} { error "missing generated artifact: $source" }
        copy_file $source [run_dir]/genode/$name
    }
}

proc writ_canary { } {
    set file [open [run_dir]/genode/canary wb]
    puts -nonewline $file "Writ native Genode public canary\n"
    close $file
}

# Software CPU emulation is intentional: no /dev/kvm permission or silent
# hardware acceleration fallback is required by the acceptance lane.
proc board_qemu_args { } { return "-machine q35 -cpu Skylake-Client" }
append qemu_args " -nographic -accel tcg -m 512 -nic none -no-reboot "
