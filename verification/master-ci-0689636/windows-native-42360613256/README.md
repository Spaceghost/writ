# Windows native: automatic master CI failure

[Run 42360613256](https://github.com/Spaceghost/writ/actions/runs/42360613256)
**failed** at source `0689636350d49aac3a25379ece312e3f5dd2ab35`. Its
[LPAC output](artifacts/windows-native-evidence-1/lpac.txt) reports strict
byte-worker network, clipboard and COM observations incomplete; four network
probes reported Win32 error 10107 in phases 1 and 2. Those failures receive no
restriction credit. Mounted public-canary reads and revocation reported pass;
a separate no-data diagnostic with a different profile reported pass. Neither
qualifies the byte worker or a protected host. The UTF-16 installer log is
decoded in the presentation copy; the repack retains its exact bytes.
