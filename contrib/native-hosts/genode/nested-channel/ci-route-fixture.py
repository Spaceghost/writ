#!/usr/bin/env python3
"""Prepare and check the fixed public native route-control fixture, offline.

This is test harness input transformation and exact-byte comparison, not Writ
policy. A missing/changed input is an incomplete experiment.
"""
import hashlib
import pathlib
import sys
import zipfile

ROUTE = '  |     + service Writ_channel | + parent\n'
SOURCE_ROUTE = '  |     + service Writ_channel | + parent\n'
TAIL = '# A nested client\'s exit is logged by its parent init.'
NEGATIVE_TAIL = r'''# Source predicts that nested init refuses this absent route. The fixed client
# sleeps after parent denial; its exit or a timeout is not the expected signal.
set esc [format %c 27]
set client_pattern [format {\[init -> clients -> writ_client_r\] %s\[31mError: stop because parent denied Writ_channel-session:} $esc]
set warning_pattern [format {\[init -> clients\] %s\[34mWarning: writ_client_r: no route to service "Writ_channel" \(label="writ_client_r -> channel"\)%s\[0m} $esc $esc]
set service_pattern {\[init -> writ_bend_monitor\] writ_channel: service announced}
set authority_pattern {\[init -> writ_bend_monitor\] monitor: SYNTHETIC authority}
set writ_deadline_ms [expr {[clock clicks -milliseconds] + 122000}]
run_genode_until $client_pattern 122
# Expect returns after its first match. Other required markers may have arrived
# before that match or may arrive later; retain and recheck the same output.
set markers [list $service_pattern "monitor service" $authority_pattern "synthetic authority" \
  $warning_pattern "nested init no route" $client_pattern "client session refusal"]
foreach {pattern description} $markers {
  if {![regexp -- $pattern $output]} {
    set remaining [expr {$writ_deadline_ms - [clock clicks -milliseconds]}]
    if {$remaining <= 0} { puts stderr "Error: marker deadline expired ($description)"; exit 1 }
    set seconds [expr {($remaining + 999) / 1000}]
    run_genode_until $pattern $seconds [output_spawn_id]
  }
}
writ_bend_monitor_require $markers
puts "nested public R route-negative fixture: PASS (synthetic public data; cleanup unverified)"
'''


def expected_config(positive, scenario):
    if positive.count(ROUTE) != 1:
        raise ValueError('reference config must contain the single nested route')
    return positive if scenario == 'positive' else positive.replace(ROUTE, '', 1)


def fixture(source, scenario):
    if source.count(SOURCE_ROUTE) != 1 or source.count(TAIL) != 1:
        raise ValueError('fixture source shape changed')
    if scenario == 'positive':
        return source
    head, _ = source.split(TAIL, 1)
    return head.replace(SOURCE_ROUTE, '', 1) + NEGATIVE_TAIL


def main():
    if len(sys.argv) != 5 or sys.argv[1] not in ('prepare', 'check-config') or sys.argv[2] not in ('positive', 'negative'):
        raise ValueError('usage: ci-route-fixture.py prepare|check-config positive|negative INPUT OUTPUT')
    action, scenario, input_name, output_name = sys.argv[1:]
    if action == 'prepare':
        source = pathlib.Path(input_name).read_text(encoding='utf-8')
        pathlib.Path(output_name).write_text(fixture(source, scenario), encoding='utf-8')
    else:
        # Read one bounded, exact member without extracting any archive paths.
        # Its identity is the independently reviewed historical snapshot.
        with zipfile.ZipFile(input_name) as archive:
            members = [entry for entry in archive.infolist() if entry.filename == 'installed-config.txt']
            if len(members) != 1 or members[0].file_size != 1710 or members[0].file_size > 65536:
                raise ValueError('reference archive member missing, duplicate, or oversized')
            with archive.open(members[0]) as stream:
                reference = stream.read(65537)  # zipfile verifies CRC upon EOF
            if len(reference) != 1710 or hashlib.sha256(reference).hexdigest() != '2255cb427b821bdb8516aef7c0d6fe53bfaa40b4a43f8549f3a97fc774738b22':
                raise ValueError('reference config identity mismatch')
        # Decode strictly; comparing exact bytes also rejects altered quotas,
        # policy, parent routes, fallback routes and unexpected config lines.
        expected = expected_config(reference.decode('utf-8'), scenario).encode('utf-8')
        if pathlib.Path(output_name).read_bytes() != expected:
            raise ValueError('installed config differs from exact scenario reference')


if __name__ == '__main__':
    try:
        main()
    except (OSError, UnicodeError, ValueError, zipfile.BadZipFile, RuntimeError) as exc:
        print('INCOMPLETE:', exc, file=sys.stderr)
        sys.exit(1)
