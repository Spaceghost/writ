# Capability POSIX adapter design

## Context

Frontend models capability mounts and descriptors but does not create real OS handles or mediate syscalls. A character-device interface must preserve those semantics under real process identity and descriptor behavior.

## Goals and boundaries

Implement the requested capability while preserving existing admission and verification. Policy and authority logic stay in Bend. This change does not imply that external dependencies or the entire host OS are implemented in this repository.

## Decisions

### Linux file-style adapter

Target a Linux POSIX character-device control interface with a per-session capability namespace. The capability mount is a logical binding of token and immutable plan; filesystem mounting is not assumed to grant broader OS authority.

Build on the [Linux host](../add-linux-host/design.md) and shared portable host
contract. Genode is the native capability reference; this Linux character device
is not a required foundation for its session services or the native Windows port.
POSIX remains the first file-style compatibility interface, followed by S3.

### Authenticated descriptors

Obtain subject identity from the trusted host channel. Deliver capability tokens in the session protocol, not in public pathnames, process arguments, or logs. The device returns native descriptors backed by current monitor state.

### One authority path

Translate operations to the existing capability resolution and final commit path. Native open/dup/close do not create read or write grants. Unsupported ioctl, mmap, direct-copy, descriptor-passing, and asynchronous routes fail closed.

### Versioned binary protocol

Use a bounded, versioned, length-delimited request format. Reject unknown opcodes and malformed lengths before allocating large buffers. Preserve full 64-bit labels and 256-bit identities.

### Confinement prerequisite

Device access is permitted to protected workers only when their other effects are confined. The adapter does not advertise host-wide protection merely because /dev access is controlled.

## Risks and trade-offs

Native descriptor duplication, process inheritance, and asynchronous IO can create bypasses. Deny unsupported semantics first and add each only with a scope-preservation test. The selected host transport must keep the authority state inaccessible to clients.

## Migration and rollback

Introduce the capability behind explicit versioned registration. Admit no protected work until acceptance evidence exists. On rollback, disable new work, reconcile in-flight records through their original scopes, and preserve consumed receipts and authority epochs. Never fall back to an unchecked output path.
