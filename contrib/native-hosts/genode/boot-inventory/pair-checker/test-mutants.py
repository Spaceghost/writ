#!/usr/bin/env python3
"""Run isolated source mutants; actual assertions remain authored in Bend."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

if len(sys.argv) != 2 or not Path(sys.argv[1]).is_absolute():
    raise SystemExit('usage: test-mutants.py ABSOLUTE_PINNED_BEND')
bend = sys.argv[1]
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
BASE = Path('contrib/native-hosts/genode/boot-inventory/pair-checker')
env = dict(os.environ, BEND_NO_TELEMETRY='1')

def run(command, cwd):
    return subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, timeout=120, check=False)

def run_both(scratch, source, expected_failure=None):
    result = run([bend, str(source)], scratch)
    output = result.stdout + result.stderr
    if expected_failure is None:
        assert result.returncode == 0, output.decode(errors='replace')
    else:
        assert result.returncode != 0 and expected_failure.encode() in output, (result.returncode, expected_failure)
    js = scratch / 'mutant.js'
    built = run([bend, str(source), '-o', str(js)], scratch)
    assert built.returncode == 0, built.stderr.decode(errors='replace')
    node = run(['node', str(js)], scratch)
    output = node.stdout + node.stderr
    if expected_failure is None:
        assert node.returncode == 0, output.decode(errors='replace')
    else:
        assert node.returncode != 0 and expected_failure.encode() in output, (node.returncode, expected_failure)

with tempfile.TemporaryDirectory(prefix='writ-pair-mutants-', dir='/tmp') as directory:
    scratch = Path(directory)
    # Preserve relative imports without symlinking writable test inputs.
    for source in ROOT.glob('*.bend'): shutil.copyfile(source, scratch / source.name)
    (scratch / 'lib').mkdir()
    for source in (ROOT / 'lib').glob('*.bend'): shutil.copyfile(source, scratch / 'lib' / source.name)
    dest = scratch / BASE
    dest.mkdir(parents=True)
    for name in ('PairBytes.bend', 'PairSyntax.bend', 'Feasibility.bend', 'Fixtures.bend', 'PairTests.bend'):
        shutil.copyfile(HERE / name, dest / name)
    shutil.copyfile(HERE / 'StageProbe.bend.txt', dest / 'StageProbe.bend')
    pair = dest / 'PairSyntax.bend'
    byte = dest / 'PairBytes.bend'
    original_pair, original_byte = pair.read_text(), byte.read_text()
    mutants = (
        ('hash binding', pair, 'digest_equal(String.eq(Sha.artifact_hex(artifact), expected))',
         'digest_equal(True{})', 'pair wrong_status_hash', 'PairTests.bend'),
        ('fixed names', pair, 'require(String.eq(name, expected))',
         'require(True{})', 'pair duplicate_name', 'PairTests.bend'),
        ('decimal length', pair, 'U32.is_lt(count, maximum) && U32.is_ge(value, 48)',
         'U32.is_ge(value, 48)', 'pair overlong u64 with matching status', 'PairTests.bend'),
        ('u64 lexical bound', pair, 'String.is_le(s, limit)',
         'True{}', 'pair u64 overflow with matching status', 'PairTests.bend'),
        ('aggregate cap', pair, 'sum_checked(total, value, U32.is_le(total, (1073741824 - value : U32)))',
         'sum_checked(total, value, True{})', 'pair aggregate limit plus one', 'PairTests.bend'),
        ('hex conversion cap', byte, 'hex_cap_checked(bytes, within(bytes, max_manifest(), Some{0}))',
         'hex_cap_checked(bytes, True{})', 'pair 1467-byte over-cap rejected', 'Feasibility.bend'),
    )
    for label, target, before, after, failure, entry in mutants:
        pair.write_text(original_pair); byte.write_text(original_byte)
        text = target.read_text()
        assert text.count(before) == 1, label
        target.write_text(text.replace(before, after))
        run_both(scratch, BASE / entry, failure)
        print('PASS ' + label + ' mutant rejected by named Bend and Node assertion')

    pair.write_text(original_pair); byte.write_text(original_byte)
    original = 'case True{}: manifest_ascii_checked(manifest, status, Bytes.ascii(manifest, True{}))'
    assert original_pair.count(original) == 1
    sentinel = original_pair.replace(original, 'case True{}: PairSyntaxMatch{}')
    pair.write_text(sentinel)
    run_both(scratch, BASE / 'StageProbe.bend')
    print('PASS post-cap sentinel blocked on oversize and reached in-range on Bend and Node')
    for label, before, failure in (
        ('manifest', 'Bytes.within(manifest, 1466, Some{0})', 'stage manifest cap prevents sentinel'),
        ('status', 'Bytes.within(status, 225, Some{0})', 'stage status cap prevents sentinel'),
    ):
        assert sentinel.count(before) == 1
        pair.write_text(sentinel.replace(before, 'True{}'))
        run_both(scratch, BASE / 'StageProbe.bend', failure)
        print('PASS ' + label + ' cap bypass reaches sentinel and is rejected on Bend and Node')
print('ALL PAIR MUTATION AND STAGING CONTROLS PASSED')
