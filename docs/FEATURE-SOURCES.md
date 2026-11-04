# Feature sources and writing conventions

Reviewed for the proposed WritFS, locality, origin-stage, disclosure, matching,
and retirement feature set on 2026-11-03. A source can motivate a design decision;
it does not supply execution evidence for Writ.

## Technical sources

| Source | What it supports | Writ boundary |
| --- | --- | --- |
| [Plan 9: The Use of Name Spaces](https://9p.io/sys/doc/names.html) | Per-process namespaces can present local, remote, and synthetic resources through one naming model | Address-oriented programming still has messages, latency, and partial failures underneath |
| [Genode 26.05: common session interfaces](https://genode.org/documentation/genode-foundations/26.05/components/Common_session_interfaces.html) | Scoped filesystem sessions and pseudo filesystems can expose storage and hierarchical control | A frontend does not replace native capability enforcement or Writ's complete effect boundary |
| [Jif 3.3.0: language features](https://research.cs.cornell.edu/jif/doc/jif-3.3.0/language.html) | Affected-owner authority, confidentiality declassification, separate integrity endorsement, and robustness against untrusted influence | Writ's proposed release profile is not an implementation of Jif's compiler or its proof |
| [RFC 9497](https://www.rfc-editor.org/rfc/rfc9497.html) | OPRF/VOPRF/POPRF evaluation and their cryptographic assumptions | A primitive alone does not authorize a search, prove input ownership, or enforce a result limit |
| [PICS, USENIX Security 2026](https://www.usenix.org/conference/usenixsecurity26/presentation/goel) | Repeated PSI sessions need input-consistency controls; the presented sender guarantee permits a subset of committed inputs | A complete scoped no-match result needs additional corpus-completeness evidence and a declared leakage policy |
| [Private Computation on Common Fuzzy Records, PoPETs 2025](https://petsymposium.org/popets/2025/popets-2025-0031.php) | Explicit fuzzy record matching can be combined with secure computation | This does not qualify arbitrary semantic similarity or an adversarial IP-theft detector |

Cooperative retirement is scoped to managed resources and authenticated participant
receipts. No source here establishes proof that unknown plaintext copies were
erased. New cryptographic or storage-sanitization claims require their own exact
protocol, threat model, implementation, and acceptance evidence.

## Documentation examples reviewed

The user requested the conventions used in knewter's repositories. These public
sources informed the organization, not Writ's security authority or feature
implementation. No external implementation or prose was copied.

| Repository snapshot | Useful convention adopted |
| --- | --- |
| [T-Display-K230 README](https://github.com/knewter/tdisplay-k230/blob/2098cc5baed62053b1187f4004a8ecd3b3df8328/README.md) | State the current goal; put concrete demonstrations and evidence close to the claim; distinguish observed behavior from pending qualification |
| [ESP32 SDR Lab README](https://github.com/knewter/esp-sdr-stuff/blob/4e1a623206533fff6c10c00cb366a90b1d784e04/README.md) | Keep limitations and failed trials visible; provide reproducible entry points and direct source/evidence links |
| [ESP32 SDR proposal](https://github.com/knewter/esp-sdr-stuff/blob/4e1a623206533fff6c10c00cb366a90b1d784e04/openspec/changes/the-spectrum-reveals-controlled-24ghz-signals/proposal.md) | Explain the concrete uncertainty, bounded scope, and acceptance gate before implementation details |
| [TimeTracker README](https://github.com/knewter/time-tracker/blob/1f58031112a24c26a1a54ac33105b4430a04e954/README.md) | Teach with an incremental worked example and point directly to the relevant parts of the repository |

Writ keeps its existing flat capability paths and stable requirement IDs. The
feature guide provides a short route through them. An unchecked task stays
unchecked until its stated evidence exists; structural validation does not turn
a proposed feature into a running system.
