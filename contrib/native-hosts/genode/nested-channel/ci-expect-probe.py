#!/usr/bin/env python3
"""Native-harness checks against real Expect/PTY and owned synthetic output."""
import itertools
import os
from pathlib import Path
import subprocess
import sys
import tempfile

here = Path(__file__).resolve().parent
expect = os.environ.get('WRIT_TEST_EXPECT', 'expect')
monitor = '[init -> writ_bend_monitor] writ_channel: service announced'
authority = '[init -> writ_bend_monitor] monitor: SYNTHETIC authority'
warning = '[init -> clients] \x1b[34mWarning: writ_client_r: no route to service "Writ_channel" (label="writ_client_r -> channel")\x1b[0m'
client = '[init -> clients -> writ_client_r] \x1b[31mError: stop because parent denied Writ_channel-session: args\x1b[0m'
markers = [monitor, authority, warning, client]

# Same Expect -re and append-output semantics as pinned Genode's
# tool/run/run wait_for_output. The only child is the synthetic Python writer.
HARNESS = r'''proc source {args} {}
proc select_from_repositories {args} {return unused}
proc writ_bend_boot {args} {}
proc output_spawn_id {} {global output_spawn_id; return $output_spawn_id}
proc run_genode_until {pattern timeout {running_spawn_id -1}} {
  global output output_spawn_id env
  if {$running_spawn_id == -1} {
    spawn python3 $env(TEST_WRITER)
    set output_spawn_id $spawn_id
    set running_spawn_id $spawn_id
  }
  expect {
    -i $running_spawn_id -re $pattern { }
    -i $running_spawn_id eof {puts stderr "synthetic writer EOF"; exit 1}
    -i $running_spawn_id timeout {puts stderr "synthetic wait timeout"; exit 1}
  }
  append output $expect_out(buffer)
}
proc writ_bend_monitor_require {items} {
  global output
  foreach {pattern description} $items {
    if {![regexp -- $pattern $output]} {puts stderr "missing $description"; exit 1}
  }
}
set output ""
set f [open [lindex $argv 0] r]; set body [read $f]; close $f
if {[catch {eval $body} err]} {puts stderr $err; exit 1}
'''


def run_case(root, name, lines, expected, split):
    writer = root / 'writer.py'
    # The child sleeps briefly after output and exits by itself; no process
    # discovery, group signalling or Genode process is involved.
    writer.write_text('import os,time\nlines='+repr(lines)+'\n'+
        'for line in lines:\n b=(line+"\\n").encode(); n=len(b)//2\n'+
        (' os.write(1,b[:n]); time.sleep(.005); os.write(1,b[n:])\n' if split else ' os.write(1,b)\n')+
        ' time.sleep(.01)\ntime.sleep(' + ('5' if name == 'no-output-timeout' else '.2') + ')\n')
    env = dict(os.environ, TEST_WRITER=str(writer))
    result = subprocess.run([expect, str(root/'harness.exp'), str(root/'fixture.run')],
                            env=env, capture_output=True, timeout=8)
    if (result.returncode == 0) != expected:
        raise AssertionError(f'{name}: status {result.returncode}, stdout={result.stdout!r}, stderr={result.stderr!r}')
    if name == 'no-output-timeout' and b'synthetic wait timeout' not in result.stderr:
        raise AssertionError('no-output case did not exercise the Expect timeout')
    print(f'{name}: {"matched" if expected else "incomplete"}')


with tempfile.TemporaryDirectory(prefix='writ-expect-probe-') as name:
    root = Path(name)
    result = subprocess.run([sys.executable, str(here/'ci-route-fixture.py'), 'prepare', 'negative',
                             str(here/'writ_bend_monitor_nested_accept.run'), str(root/'fixture.run')],
                            capture_output=True, timeout=10)
    if result.returncode: raise RuntimeError(result.stderr.decode())
    # Shorten only the synthetic test deadline; production remains 122 seconds.
    p = root/'fixture.run'; s=p.read_text()
    assert s.count('+ 122000') == 1 and s.count('run_genode_until $client_pattern 122') == 1
    p.write_text(s.replace('+ 122000', '+ 4000').replace('run_genode_until $client_pattern 122', 'run_genode_until $client_pattern 4'))
    (root/'harness.exp').write_text(HARNESS)
    for i, order in enumerate(itertools.permutations(markers)):
        run_case(root, f'order-{i}', list(order), True, True)
    for i in range(len(markers)):
        run_case(root, f'missing-{i}', [m for j,m in enumerate(markers) if j != i], False, True)
    for name, altered in [('wrong-warning-color', warning.replace('\x1b[34m','\x1b[31m')),
                          ('wrong-label', warning.replace('writ_client_r -> channel','other -> channel')),
                          ('wrong-child', warning.replace('Warning: writ_client_r','Warning: other')),
                          ('wrong-client-color', client.replace('\x1b[31m','\x1b[34m')),
                          ('wrong-client-origin', client.replace('clients -> writ_client_r]','clients -> other]'))]:
        source = client if name.startswith('wrong-client') else warning
        run_case(root, name, [altered if m==source else m for m in markers], False, True)
    run_case(root, 'no-output-timeout', [], False, False)
print('real Expect/PTY controls only; no Genode executed')
