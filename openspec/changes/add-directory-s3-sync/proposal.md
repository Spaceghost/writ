# Directory sync with S3-compatible storage

## Why

The desktop preview syncs one small local fixture. The user requested nested
file/folder syncing and cloud storage, selecting S3/R2 first and OneDrive later.

## What Changes

Add a shared Bend streamed-artifact and three-way reconciliation monitor, a
native Windows directory/S3 binding, and connection settings in the desktop
app. The first remote profile keeps full local file copies. The existing
single-file Cloud Files preview retains its separate acceptance tests.

## Impact

New `directory-s3-sync` capability, native Windows transport/credential/storage
effects and package tests. No new protected-host claim or automatic label change.
