# Unikernel appliance host

## Purpose

Run the Writ monitor as an immutable single-purpose unikernel image with one
authenticated ingress, state kept outside the image, and a measured rebuild
procedure, without presenting the single address space as a worker boundary.

## ADDED Requirements

### Requirement: UA-001 The image contains only the monitor

The appliance image SHALL contain the monitor binary built under the monitor runtime profile, the pinned unikernel, and boot configuration, and SHALL NOT contain a shell, remote login service, debugger, or package tooling.

#### Scenario: Image contents are inventoried

- **GIVEN** a built appliance image
- **WHEN** its contents are listed
- **THEN** only the monitor executable, unikernel, and configuration appear and the monitor passes the runtime profile's binary check.

#### Scenario: A debug shell is added for convenience

- **GIVEN** a build includes an interactive shell
- **WHEN** the image is evaluated
- **THEN** it is not an appliance image and is not promoted.

### Requirement: UA-002 Builds are reproducible and pinned

Two clean builds from the same pinned Writ source, Bend version, unikernel version, and build environment SHALL produce the same image hash, and deployments SHALL name images by that hash.

#### Scenario: Repeated build

- **GIVEN** the pinned inputs
- **WHEN** the image is built twice
- **THEN** both hashes are equal.

#### Scenario: An input changes

- **GIVEN** the unikernel version is bumped
- **WHEN** the image is rebuilt
- **THEN** the hash differs and the new image requires fresh qualification.

### Requirement: UA-003 The corpus runs inside the image

The library corpus and the four examples SHALL execute inside the booted image and SHALL print the same PASS lines and counts as the recorded Linux run, with lane count and execution mode recorded.

#### Scenario: Corpus boots under QEMU

- **GIVEN** the appliance image boots under QEMU with serial output captured
- **WHEN** the corpus finishes
- **THEN** the output ends with the recorded final line and the 638 count matches.

#### Scenario: A primitive is missing

- **GIVEN** the unikernel lacks an alternate signal stack
- **WHEN** the runtime starts
- **THEN** the mismatch is recorded as a failed qualification of that unikernel rather than patched around silently.

### Requirement: UA-004 The address space is not a worker boundary

The appliance SHALL host only the monitor and SHALL deny execution of requester-supplied or transformation code inside the image; worker confinement SHALL be provided by separate domains under the portable host contract.

#### Scenario: Worker execution is requested in the appliance

- **GIVEN** a request asks the appliance to run a summarizer inside the image
- **WHEN** the request is evaluated
- **THEN** it is denied and no sandbox is attempted.

#### Scenario: Worker runs in a separate domain

- **GIVEN** a confined worker domain outside the appliance
- **WHEN** it reaches the monitor
- **THEN** it does so only through the authenticated channel with its subject bound by the host contract.

### Requirement: UA-005 One authenticated ingress

The appliance SHALL expose exactly one service endpoint, the host contract's authenticated session channel, plus its durable store connection, and SHALL NOT expose any other listening service.

#### Scenario: Network scan of the appliance

- **GIVEN** a booted appliance on a test network
- **WHEN** its reachable endpoints are enumerated
- **THEN** only the session channel is found.

#### Scenario: A general socket effect is linked

- **GIVEN** the monitor binary links a general listening effect outside the channel adapter
- **WHEN** the binary check runs
- **THEN** it fails under the monitor runtime profile.

### Requirement: UA-006 State lives outside the image

Session, ledger, authority epochs, and sealed artifacts SHALL persist only through the durable publication store attached at boot, and the image SHALL hold no state that must survive its replacement.

#### Scenario: Boot with an empty store

- **GIVEN** a fresh image attaches an empty store
- **WHEN** it starts
- **THEN** it serves no protected work and reports no sessions.

#### Scenario: Boot with a populated store

- **GIVEN** the store holds an invocation whose outcome was unknown at shutdown
- **WHEN** the image boots and attaches it
- **THEN** that invocation is reconciled exactly once under the durable publication rules.

### Requirement: UA-007 Rebuild is drilled and timed

A rebuild drill SHALL destroy the running appliance, boot the pinned image on a fresh virtual machine, attach the store, and record elapsed time and reconciliation results; the drill SHALL be repeated for every image change before promotion.

#### Scenario: Drill after an image change

- **GIVEN** a new image hash
- **WHEN** the drill runs
- **THEN** its log shows elapsed time, every outstanding invocation reconciled once, and service resumed.

#### Scenario: Drill loses an invocation

- **GIVEN** the drill reconciles one invocation twice or not at all
- **WHEN** results are reviewed
- **THEN** the image is not promoted and the discrepancy is recorded.

### Requirement: UA-008 Clock and entropy are checked at boot

The appliance SHALL verify a monotonic clock at boot and deny protected work when it is unavailable, and SHALL deny challenge issuance when no trusted entropy source is present.

#### Scenario: Clock unavailable

- **GIVEN** the virtual clock cannot be read
- **WHEN** a protected request arrives
- **THEN** it is denied and the denial is recorded.

#### Scenario: Entropy source missing

- **GIVEN** no virtual random device or provisioned entropy
- **WHEN** a negotiation challenge is requested
- **THEN** issuance is denied rather than using a fixed nonce.

### Requirement: UA-009 The trusted base is stated

Each appliance qualification SHALL name the hypervisor, host kernel, firmware, and unikernel as trusted components, and SHALL NOT describe the appliance as removing the host from the trust boundary.

#### Scenario: Qualification record is written

- **GIVEN** a passing drill and corpus under KVM on a given host
- **WHEN** the record is published
- **THEN** it lists those four trusted components and the Linux kernel vulnerability claim is scoped to the guest.

#### Scenario: Record overclaims

- **GIVEN** a record says the appliance is immune to host compromise
- **WHEN** it is reviewed
- **THEN** it is rejected as evidence.

### Requirement: UA-010 Evidence is separated by execution environment

QEMU software emulation, hardware-accelerated virtualization, and physical deployment results SHALL be recorded separately and SHALL NOT be substituted for one another.

#### Scenario: Only QEMU results exist

- **GIVEN** the corpus passed under QEMU TCG
- **WHEN** the appliance is described
- **THEN** it is described as emulated-boot evidence only.

#### Scenario: Device execution is requested

- **GIVEN** the appliance has no GPU passthrough
- **WHEN** the parallel example runs
- **THEN** the record states CPU execution for the device-requesting paths.
