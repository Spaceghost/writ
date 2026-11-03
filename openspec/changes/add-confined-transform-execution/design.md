# Confined transformation execution design

## Context

The library validates supplied manifests, identities, and constraints but does not run or isolate a transformation. Actual plaintext execution needs a monitor-owned input boundary and complete output mediation.

## Goals and boundaries

Implement the requested capability while preserving existing admission and verification. Policy and authority logic stay in Bend. This change does not imply that external dependencies or the entire host OS are implemented in this repository.

## Decisions

### Conservative dependency capture

A worker initially inherits every data/control source it can observe, including configuration, cached state, model weights, and tools. Refinement requires a sound compiler or trusted boundary proof; user declarations never erase a source.

### No ambient effects

The host supplies only scoped input and output handles. Inherited descriptors, sockets, logs, environment-based access, shared memory, descriptor passing, device access, and helper processes are denied or mediated by the same policy. Unsupported effects fail closed.

### Immutable execution identity

Pin the code, model, tools, and configuration before challenge/dispatch. A versioned execution envelope binds provider, phase, invocation, complete manifest, destination, epochs, and quote. Any change requires renewed admission.

### Sealed results

Validated output bytes become immutable artifacts with an authenticated execution record and declared schema. Use a versioned, domain-separated binary encoding and a declared collision-resistant content digest; JSON is not the authoritative record format.

### Explicit trust boundary

Bend supplies policy and verification logic. The host isolation mechanism protects monitor state from workers and devices. Where shared hardware timing cannot be bounded, document it as outside the validated guarantee rather than claiming noninterference.

## Risks and trade-offs

A complete graph does not stop an unchecked physical output path, and an identifier does not authenticate execution. Protect monitor memory, bound resources, and deny unimplemented adapters before releasing plaintext. No specific hardware side-channel proof is claimed.

## Migration and rollback

Introduce the capability behind explicit versioned registration. Admit no protected work until acceptance evidence exists. On rollback, disable new work, reconcile in-flight records through their original scopes, and preserve consumed receipts and authority epochs. Never fall back to an unchecked output path.
