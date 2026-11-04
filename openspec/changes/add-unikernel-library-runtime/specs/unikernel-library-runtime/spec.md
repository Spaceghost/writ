# Library-unikernel Bend runtime

## Purpose

Build the Writ monitor as a natively linked library-unikernel application so
the image contains only the monitor, the Bend runtime, and the kernel libraries
the runtime profile needs, with effects bound to kernel primitives and parity
with the recorded Linux results.

## ADDED Requirements

### Requirement: UL-001 The image is a native link

The monitor SHALL be compiled from the generated C against the chosen unikernel's own libc and linked into its image, and SHALL NOT run through the kernel's Linux-ELF compatibility loader.

#### Scenario: Native application build

- **GIVEN** the generated C of the monitor
- **WHEN** it is built as the unikernel's application
- **THEN** the image links without an ELF loader library and boots to the monitor's first output.

#### Scenario: Compatibility loader selected

- **GIVEN** a build configuration enables the ELF loader
- **WHEN** it is evaluated under this capability
- **THEN** it belongs to the appliance change, not this one.

### Requirement: UL-002 Selection is by an executed matrix

The unikernel SHALL be chosen from a published matrix with one cell per runtime inventory row per candidate, each cell established by executing the primitive, and the matrix SHALL name the chosen kernel and the reasons.

#### Scenario: Matrix is complete for two candidates

- **GIVEN** Unikraft and OSv are built with the reference program
- **WHEN** each row is exercised on each
- **THEN** every cell reads supplied, substituted, or missing, and the choice cites the cells.

#### Scenario: A cell is filled from documentation

- **GIVEN** a row is marked supplied because a header exists
- **WHEN** the matrix is reviewed
- **THEN** that cell is marked unverified and cannot support the choice.

### Requirement: UL-003 Only profile libraries are linked

The image SHALL select only the kernel libraries the runtime profile rows require, and SHALL pass the runtime profile's binary check with no effect row outside the monitor profile.

#### Scenario: Minimal configuration

- **GIVEN** the monitor uses console, time, exit, and the ingress channel
- **WHEN** the image's linked libraries and effect rows are listed
- **THEN** no filesystem, general socket, process, audio, or window library or effect appears.

#### Scenario: A convenience library is added

- **GIVEN** a build adds a filesystem library for debugging
- **WHEN** the binary check runs
- **THEN** it fails and the image is not qualified.

### Requirement: UL-004 Effect twins bind to kernel primitives

The monitor-profile effects SHALL be Bend defs whose C twins call the kernel's console, time, and channel primitives. The effect twins and the inventoried boot and termination host layer SHALL be the only kernel-specific code, and SHALL be listed in a trust inventory that names each file, its exported symbols, and what it may touch.

#### Scenario: Console effect

- **GIVEN** `IO.print` in the monitor
- **WHEN** it runs in the image
- **THEN** its twin writes to the kernel console directly and the text appears on serial.

#### Scenario: Twin reaches beyond the profile

- **GIVEN** a twin opens a file
- **WHEN** the inventory and binary check are reviewed
- **THEN** the twin is rejected.

### Requirement: UL-005 Single lane first, with parity

The image SHALL first run one lane with the inline IO helper and SHALL match the Linux single-lane record line for line; additional lanes SHALL be enabled only after that and SHALL preserve the match.

#### Scenario: Single-lane corpus under QEMU

- **GIVEN** the single-lane image boots under QEMU
- **WHEN** the console capture is compared with the Linux record
- **THEN** every PASS line and the 638 count match.

#### Scenario: Multi-lane divergence

- **GIVEN** lanes are enabled and one example line differs
- **WHEN** results are reviewed
- **THEN** the multi-lane configuration is not qualified and the single-lane result stands alone.

### Requirement: UL-006 Faults halt with a distinct code

A page fault or stack overflow in the image SHALL print the runtime's fault message to the console and halt with an exit code distinct from corpus failure and arena exhaustion; the image SHALL NOT resume after a fault.

#### Scenario: Forced overflow

- **GIVEN** a program recurses past the guard
- **WHEN** the trap fires
- **THEN** the console shows the fault message and the harness sees the fault code.

#### Scenario: Handler resumes

- **GIVEN** a trap handler configured to return
- **WHEN** it is reviewed
- **THEN** the configuration fails this capability.

### Requirement: UL-007 Three environments, recorded separately

Results from running the image as a Linux process, under software emulation, and under a hardware-accelerated hypervisor SHALL be recorded separately; only the latter two SHALL count as boots.

#### Scenario: linuxu run passes

- **GIVEN** Unikraft's `linuxu` platform runs the corpus
- **WHEN** the record is written
- **THEN** it is labeled process execution and no boot claim is made.

#### Scenario: Only QEMU boot exists

- **GIVEN** the corpus passed under QEMU software emulation
- **WHEN** the image is described
- **THEN** it is emulated-boot evidence only until an accelerated run is recorded.

### Requirement: UL-008 Appliance rules apply unchanged

The library image SHALL satisfy the appliance host's requirements for image contents, reproducibility, single ingress, external state, clock and entropy checks, the rebuild drill, and the trusted-base statement.

#### Scenario: Rebuild drill on the library image

- **GIVEN** a new library image hash
- **WHEN** the appliance drill runs
- **THEN** elapsed time and exactly-once reconciliation are recorded as for any appliance image.

#### Scenario: Worker code in the image

- **GIVEN** a request to run a summarizer inside the library image
- **WHEN** it is evaluated
- **THEN** it is denied under the appliance rule; the address space is not a worker boundary.
