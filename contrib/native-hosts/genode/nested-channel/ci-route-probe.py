#!/usr/bin/env python3
"""Offline checks of native fixture preparation and its log assertions."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

here = Path(__file__).resolve().parent
repo = here.parents[3]
source = here / 'writ_bend_monitor_nested_accept.run'
reference = repo / 'verification/genode-nested-ci-7b31cfc/raw/positive.zip'
normalized = repo / 'verification/genode-nested-ci-7b31cfc/positive/installed-config.txt'
program = here / 'ci-route-fixture.py'
route = '  |     + service Writ_channel | + parent\n'
warning = '[init -> clients] Warning: writ_client_r: no route to service "Writ_channel" (label="writ_client_r -> channel")'
monitor = '[init -> writ_bend_monitor] writ_channel: service announced\n[init -> writ_bend_monitor] monitor: SYNTHETIC authority'
client = '[init -> clients -> writ_client_r] Error: stop because parent denied Writ_channel-session: args'


def invoke(*args):
    return subprocess.run([sys.executable, str(program), *map(str, args)], capture_output=True, timeout=10)


def must(condition, message):
    if not condition:
        raise AssertionError(message)


with tempfile.TemporaryDirectory(prefix='writ-route-probe-') as directory:
    root = Path(directory)
    positive, negative = root / 'positive.run', root / 'negative.run'
    for scenario, target in [('positive', positive), ('negative', negative)]:
        must(invoke('prepare', scenario, source, target).returncode == 0, f'{scenario} prepare')
    must(positive.read_bytes() == source.read_bytes(), 'positive must be exact source')
    pos = positive.read_text(); neg = negative.read_text()
    before = "# A nested client's exit is logged by its parent init."
    must(pos.split(before)[0].replace(route, '', 1) == neg.split('# Source predicts')[0], 'negative changes only route before assertions')
    must(pos.count(route) == 1 and neg.count(route) == 0, 'route difference')
    for scenario in ['positive', 'negative']:
        installed = root / f'{scenario}.config'
        with zipfile.ZipFile(reference) as archive:
            original = archive.read('installed-config.txt').decode('utf-8')
        must(original == normalized.read_text() + '\n', 'historical normalization discrepancy')
        installed.write_text(original if scenario == 'positive' else original.replace(route, '', 1))
        must(invoke('check-config', scenario, reference, installed).returncode == 0, f'{scenario} config')
        for mutation in [lambda s: s.replace('ram: 16M', 'ram: 17M'),
                         lambda s: s.replace('subject: 1', 'subject: 2'),
                         lambda s: s.replace('+ service Writ_channel | + child writ_bend_monitor', '+ any-service | + parent'),
                         lambda s: s + '+ default-route | + any-service | + parent\n']:
            altered = root / 'altered.config'; altered.write_text(mutation(installed.read_text()))
            must(invoke('check-config', scenario, reference, altered).returncode != 0, 'changed config accepted')
    must(invoke('check-config', 'positive', reference, normalized).returncode != 0, 'normalized copy accepted as exact raw bytes')
    malformed = root / 'malformed.run'; malformed.write_text(pos.replace(route, '', 1))
    must(invoke('prepare', 'negative', malformed, root / 'bad').returncode != 0, 'missing route accepted')
    # Exercise the actual Tcl assertions with synthetic output. No Genode is run.
    harness = root / 'fixture-harness.tcl'
    harness.write_text(r'''proc source {args} {}
proc select_from_repositories {args} {return unused}
proc writ_bend_boot {args} {}
proc run_genode_until {pattern timeout} {
  global output env
  set output $env(TEST_OUTPUT)
  if {![regexp $pattern $output]} {puts stderr "missing terminal marker"; exit 1}
}
proc writ_bend_monitor_require {items} {
  global output
  foreach {pattern description} $items {
    if {![regexp $pattern $output]} {puts stderr "missing $description"; exit 1}
  }
}
set f [open [lindex $argv 0] r]; set body [read $f]; close $f
if {[catch {eval $body} error]} {puts stderr $error; exit 1}
''')
    samples = [('matched', monitor + '\n' + warning + '\n' + client, True),
               ('wrong label', monitor + '\n' + warning.replace('writ_client_r -> channel', 'other -> channel') + '\n' + client, False),
               ('wrong child', monitor + '\n' + warning.replace('Warning: writ_client_r', 'Warning: other') + '\n' + client, False),
               ('missing warning', monitor + '\n' + client, False), ('missing client', monitor + '\n' + warning, False),
               ('missing monitor', warning + '\n' + client, False),
               ('server policy rejection', "writ_channel: no <policy> with a subject", False)]
    for name, output, match in samples:
        result = subprocess.run(['tclsh', str(harness), str(negative)],
                                env={**os.environ, 'TEST_OUTPUT': output}, capture_output=True, timeout=10)
        must((result.returncode == 0) == match, f'{name}: {result.stderr!r}')
        print(f'{name}: {"matched" if match else "refused"}')
    print('exact-source/config transformations: checked; no Genode executed')
