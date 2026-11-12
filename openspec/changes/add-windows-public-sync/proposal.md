# Windows public Files On-Demand save

## Why

Opening `Writ\hello.txt` in Notepad and saving an edit should survive provider
termination and a new empty sync root. The existing Windows WinFsp contribution
serves an immutable canary to its admitted reader; it has no desktop Cloud Files
registration or writable backing store.

## What Changes

- Add a separate public-fixture Cloud Files executable and independent NTFS store.
- Add a small Bend entry/list/read/conditional-replacement lifecycle using existing
  object-version, artifact, hashing and framing components.
- Retain failed and conflicting edits and admit in-sync marking only after exact
  persistence and local readback, fenced by a retained exclusive native oplock.
- Ship PowerShell acceptance tests, launch/removal commands and explicit evidence.

## Impact

Only the optional Windows public demo and its Bend module are added. Protected
WinFsp reads, source/destination admission and existing security laws are preserved.
This does not complete protected durable publication or the general namespace.
Native Windows execution remains an explicit open gate.
