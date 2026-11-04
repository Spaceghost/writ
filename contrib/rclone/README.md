# Writ remote for rclone

An optional **Bend service with a small Go adapter** for rclone. Use it to exercise
private ingress, policy-preserving managed copies, and metadata inspection through
real rclone commands. The service owns the bytes, versions, SHA-256 identities,
policy, and authorization decisions.

**This is a bounded, memory-only reference remote.** Restarting the server loses
every object and receipt. Its fixed local authority profile is an integration
example, not durable backup storage or a production issuer.

## Layout

| Location | Responsibility |
| --- | --- |
| `bend/Authority.bend`, `bend/Model.bend` | Fixed service-owned authority, immutable versions, exact replay, Writ commit path |
| `bend/Digest.bend`, `../../lib/Sha256.bend` | Stable adapter entry points to shared pure Bend SHA-256 over the actual payload |
| `bend/Wire.bend`, `bend/Transport.bend` | Bounded canonical protocol and native loopback TCP |
| `bend/Application.bend`, `bend/Presenter.bend`, `bend/Server.bend` | Authentication, metadata views, and serialized service loop |
| `go/` | Independent Go module: rclone interfaces, bounded transport, and a small CLI entry point |

The root library and its tests have no dependency on this contribution. Policy
logic stays in Bend; Go carries requests and checks transport structure.

## Build

Use **Bend 2.0.39**, **Go 1.26.0**, and a native C compiler supported by Bend.
The Go module pins **rclone v1.75.2** and includes its dependency checksums.
See Writ's [Bend installation instructions](../../docs/INSTALL.md).

From the repository root:

```bash
mkdir -p ../writ-rclone-build
bend contrib/rclone/bend/Server.bend -o ../writ-rclone-build/writ-server
(
  cd contrib/rclone/go
  go mod verify
  go build -buildvcs=false -trimpath \
    -o ../../../../writ-rclone-build/rclone-writ ./cmd/rclone-writ
)
```

Use the resulting `rclone-writ` binary for these examples. It registers the
`local` and `writ` backends and the included CLI commands. For a full rclone
build, import this Go package alongside the other backend registrations and add
a `writ` entry to rclone's embedded backend overview data.

The standalone build currently emits rclone's harmless startup message
`internal error: no overview data found for "writ"`: the upstream embedded
overview catalog has no entry for this out-of-tree backend. Registration and
operations work; their exit codes and other errors remain meaningful. The
contribution leaves upstream logging and module sources intact.

## Run a local instance

The following Bash session shares one fresh token between server and client.
Use a trusted local host: the reference transport is unencrypted loopback TCP,
and possession of this token grants the reference audience's metadata access.

```bash
export WRIT_RCLONE_TOKEN="$(openssl rand -hex 32)"
export RCLONE_CONFIG_WRIT_TYPE=writ
export RCLONE_CONFIG_WRIT_ADDRESS=127.0.0.1:8787
export WRIT_RCLONE_CLI="$PWD/../writ-rclone-build/rclone-writ"

../writ-rclone-build/writ-server +RTS --threads 4 --gpu off &
WRIT_SERVER_PID=$!
```

Wait for the server's `Writ reference ready` message, then:

```bash
printf 'Restricted incident report.\n' |
  "$WRIT_RCLONE_CLI" rcat writ:private/report.txt

"$WRIT_RCLONE_CLI" copyto writ:private/report.txt writ:archive/report.txt --checksum
"$WRIT_RCLONE_CLI" lsf writ:archive
"$WRIT_RCLONE_CLI" backend policy writ: archive/report.txt
"$WRIT_RCLONE_CLI" backend status writ:
```

The archive object retains the source's secrecy, origin, and SHA-256. `policy`
takes the object path as a separate argument after the remote root.

These commands intentionally fail:

```bash
"$WRIT_RCLONE_CLI" cat writ:private/report.txt
"$WRIT_RCLONE_CLI" copyto writ:private/report.txt writ:public/report.txt --checksum
"$WRIT_RCLONE_CLI" copyto writ:private/report.txt writ:archive/manual.txt --disable Copy
```

The first would release plaintext. The second has an unacceptable destination.
The third forces rclone to try a generic read instead of the managed Copy hook;
that read is denied too. A policy error never becomes rclone's `ErrorCantCopy`
fallback signal.

Stop the instance with `kill "$WRIT_SERVER_PID"`. Generate a new token before
starting another instance. Its object IDs, versions, and replay journal start
again from empty state.

An ordinary rclone configuration can use `[writ]`, `type = writ`, and
`address = 127.0.0.1:8787`. The `WRIT_RCLONE_TOKEN` environment variable takes
precedence over the optional `token` configuration value. To change the port,
set both `WRIT_RCLONE_PORT` on the server and the client's address.

## What the remote supports

| Operation | Behavior |
| --- | --- |
| `rcat`, local-to-Writ `copy` / `copyto` | Import into `private/`; Bend assigns a protected origin and computes the digest |
| Writ-to-Writ `copy` / `copyto` | Same configured remote and service; exact source/destination versions pass through `DataOS.commit_from_capability` |
| `ls`, `lsf`, `lsd`, `lsjson`, `mkdir` | Authenticated metadata; new logical directories beneath `private/` or `archive/` |
| `backend policy`, `backend receipt`, `backend status` | Policy, request outcome, and instance information, without payload or credentials |
| `Open`, download, generic fallback, delete, rmdir, modification-time updates | Terminal failure in this reference profile |

Only `private`, `archive`, and `public` exist at the root. New plaintext ingress
is restricted to `private/`; managed copies may stay private or enter `archive/`.
The public destination has insufficient clearance for this profile's objects.
There is no working plaintext mount, restore, general-purpose `sync`, or move
workflow: those require operations this contribution deliberately denies.

### Content comparison and policy

Use **`--checksum`** for content synchronization. Modification times are
unsupported, so rclone's default comparison can miss same-size content edits.
The backend exposes the service-computed SHA-256 to support that comparison.

Even with `--checksum`, rclone can skip byte-identical objects whose policies or
origins differ. A skipped transfer creates no new commit or receipt. Use
**`--ignore-times`** when you intend a fresh managed copy and provenance decision:

```bash
"$WRIT_RCLONE_CLI" copyto writ:private/report.txt writ:archive/report.txt --ignore-times
```

This forces a request; Bend still decides whether it is authorized. A checksum
is content identity, not proof that two objects have equivalent authority.

### Versions and uncertain outcomes

Every successful upload or copy creates an immutable version. An overwrite keeps
the object ID and appends a new version; its prior versions remain in memory and
count toward the limits. The adapter sends the source version and expected
destination version, so concurrent changes fail instead of silently changing the
operation's scope. The single server worker serializes accepted transitions.

The service records exact successful upload/copy requests without retaining their
bearer tokens. Repeating the identical request ID and fields in the same instance
returns the original outcome; changed fields fail. The Go client avoids automatic
retries after an uncertain write and includes its request ID in the error:

```bash
"$WRIT_RCLONE_CLI" backend receipt writ: REQUEST_ID_FROM_ERROR
```

A new command gets a new ID. This is an in-process receipt mechanism, not crash
recovery. Failed writes create no receipt or version. Directory creation is
idempotent by path and does not enter the object-version receipt journal.

## Limits and authority assumptions

Objects are limited to **64 KiB**, with **256 retained versions**, **1 MiB total
retained payload**, and **256 explicit directories**. Names are case-sensitive,
canonical printable ASCII paths up to 512 characters. The protocol bounds
requests, responses, receive/send time, fragmentation, and instance lifetime;
see [PROTOCOL.md](PROTOCOL.md) for the exact contract.

The service uses a single trusted local principal, standing free Copy grants,
fixed secrecy/integrity restrictions, and transaction-local logical time. It
constructs that profile itself; wire clients cannot provide grants, origin
approvals, policy bits, or solver candidates. Managed copies exercise the real
capability, negotiation, independent verification, and final commit path. The
returned intent's plan and digest must match the object being registered.

This does not supply an external authenticated issuer, live revocation feed,
payment settlement, encrypted storage, durable publication, or confinement of
arbitrary workers. The source of an upload already possesses its bytes. The
reference demonstrates authority over the objects it manages, not control over
all other processes or copies on the host. Authorized metadata includes names,
sizes, hashes, origins, and policy; it is not a metadata-hiding protocol.

## Verification

The [verification record](VERIFICATION.md) separates pure Bend checks, Go
transport checks, and the real CLI integration run. From the repository root:

```bash
bend contrib/rclone/bend/Tests.bend
bend contrib/rclone/bend/WireTests.bend
bend contrib/rclone/bend/WireBoundaryTests.bend
bend contrib/rclone/bend/ApplicationTests.bend
bend contrib/rclone/bend/DigestTests.bend
(
  cd contrib/rclone/go
  go test -count=1 ./...
)
```

Compile each Bend test file to an executable outside the checkout and run it
with `+RTS --threads 4 --gpu off` for the native lane. These checks are separate
from the root library suite.

For the real CLI test, start a **fresh empty instance** using the environment
above, then run:

```bash
bend contrib/rclone/bend/Integration.bend
bend contrib/rclone/bend/Integration.bend -o ../writ-rclone-build/integration
```

Restart with another fresh instance and token before running the compiled
integration executable. The test performs real CLI operations, including exact
64 KiB ingress, same-size content changes, public-destination denial, forced
manual fallback denial, and unsupported deletion. It requires no protected
payload to be returned to the CLI.
