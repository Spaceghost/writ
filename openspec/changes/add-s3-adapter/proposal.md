# S3 adapter

## Why

Object clients need access to Writ's protected objects through familiar request
shapes. A storage API must preserve the same paired authority and inherited
restrictions as the capability POSIX boundary, including metadata and multipart
operations.

## What Changes

Introduce [s3-adapter](specs/s3-adapter/spec.md) as a new capability after the real
POSIX adapter is accepted. Define an explicit supported subset, map authenticated
requests to immutable plans, and publish results only through durable commit.
This package specifies future behavior; no S3 server is currently implemented.

## Capabilities

### New Capabilities

- `s3-adapter`: Expose a documented object-request subset whose reads, writes,
  copies, multipart completions, and metadata results retain Writ's current
  authorization and provenance semantics.

### Modified Capabilities

None. Existing admission, capability, provenance, and commit contracts continue
to apply; this adapter supplies transport and operation mappings.

## Impact

New Bend protocol dispatch, request-to-plan mapping, version-bound multipart
state, and protected metadata handling around the existing frontend and durable
publication path. HTTP/TLS, cryptographic primitives, and storage remain declared
host dependencies. This work does not introduce a separate C or Rust policy
implementation or claim universal S3 compatibility.

## Dependencies

- [add-capability-posix-adapter](../add-capability-posix-adapter/proposal.md)
- [add-durable-publication](../add-durable-publication/proposal.md)
