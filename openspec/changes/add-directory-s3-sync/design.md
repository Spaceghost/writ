# User-owned directory and conditional remote storage

The first S3 profile synchronizes ordinary, fully hydrated files in a dedicated
local directory. This gives offline access without claiming a completed remote
Cloud Files placeholder provider. The original public placeholder preview and
its native acceptance remain available separately.

One private Bend monitor binds to one retained native relative path for each
transaction. Its observed base, streamed local bytes and remote metadata select
adoption, upload, download or conflict. Kind/size/digest describe content;
revision prevents implicit rebase after an ABA change. Byte verification is
bounded to 64 KiB messages and 1 GiB per file. No native conflict rule replaces
that decision.

S3 stores immutable content objects and a bounded versioned directory manifest
under an explicit prefix. Publication conditionally replaces the exact observed
manifest ETag (or uses If-None-Match for creation). Conditional failure retains
local edits and rereads remote state; unconditional overwrite is forbidden.
Deleted entries retain tombstones and old content remains recoverable.

Native apply retains an exclusion handle through exact local recheck and the
effect. Existing files move by retained handle into recovery; a verified remote
file moves to the vacant target without replacement. A recreated target is
preserved alongside recovery and reported as a conflict. Parent handles prevent
directory replacement during the effect. These are native acceptance conditions,
not consequences of model tests.

Connections use HTTPS, AWS Signature Version 4, bounded responses/timeouts and
no cross-origin redirects. Endpoint/bucket/prefix/region are ordinary settings;
secret keys and optional session tokens stay in Windows Credential Manager.
Secrets never enter process arguments, configuration text or activity logs.

The operator and OS own this ordinary-file profile. This does not qualify
protected desktop transformations, implement confidentiality labels on arbitrary
host files, prove crash/power-loss safety, or provide OneDrive OAuth before its
application configuration is supplied.
