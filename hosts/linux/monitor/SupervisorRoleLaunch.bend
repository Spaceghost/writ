import Base
import ./LocalChannel.bend as C

# Which channel role processes the native supervisor driver may start
# (contrib/native-hosts/linux/supervisor_owner.c, `writ_supervisor_launch_role`).
#
# Authority direction. The role-index-to-principal map and each role's
# program digest come from the protected provisioning record
# (`SupervisorProvision`). The driver opens the program it was asked to run,
# copies it into a sealed memory file, and reports the file's facts
# (`ProgramFacts`) and the SHA-256 of the sealed copy; it judges neither. This
# module decides whether that one copy may be started for an index:
#   1. the provisioned map attributes the index to a principal (so a zero,
#      unmapped or invalid-map index is refused: `RoleUnprovisioned`);
#   2. no process was admitted for the index before (`RoleAlreadyBound`);
#   3. the file was a regular, singly linked file owned by root or the
#      supervisor's user and writable by no group or other user
#      (`ProgramUnprotected`);
#   4. the digest equals the one the record pins for the index
#      (`ProgramMismatch`).
# Only then is the index bound. The driver executes exactly the sealed copy it
# hashed and registers the started process's pidfs identity under the index;
# the receiver then reports that process's datagrams as the role. A bound
# index is never released, so a role whose process exits cannot be rebound in
# this interpreter's lifetime. A refusal binds nothing.
#
# Not established. A digest names bytes, not an author: the record that pins
# it is signed by the operator key SupervisorProvision checks, which says who
# chose each program, not who built it, and an older signed record is accepted
# again. Nothing here binds a worker session to a principal.

# SHA-256, as eight big-endian U32 words in digest order.
type Digest is Data:
  Digest{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

# Each provisioned role's program digest.
type Programs is Data:
  NoPrograms{}
  Program{index: Nat, digest: Digest, rest: Programs}

# What the driver observed about the opened program file: `st_mode`,
# `st_nlink` (saturated), `st_uid`, the supervisor's effective user ID, and
# the digest of the sealed copy it will execute.
type ProgramFacts is Data:
  ProgramFacts{mode: U32, links: U32, owner: U32, euid: U32, digest: Digest}

type Bound is Data:
  NoBound{}
  Bound{index: Nat, rest: Bound}

# The provisioned programs and the indices bound so far.
type Launches is Data:
  Launches{programs: Programs, bound: Bound}

type RoleRefusal is Data:
  RoleUnprovisioned{}
  RoleAlreadyBound{}
  ProgramUnprotected{}
  ProgramMismatch{}

type Admission is Data:
  RoleAdmitted{launches: Launches}
  RoleRefused{reason: RoleRefusal}

# Before provisioning nothing is launchable.
def none() -> Launches:
  Launches{NoPrograms{}, NoBound{}}

def provisioned(programs: Programs) -> Launches:
  Launches{programs, NoBound{}}

def digest_equal(x: Digest, y: Digest) -> Bool:
  match x y:
    case Digest{a1, b1, c1, d1, e1, f1, g1, h1} Digest{a2, b2, c2, d2, e2, f2, g2, h2}:
      U32.is_eq(a1, a2) && U32.is_eq(b1, b2) && U32.is_eq(c1, c2) && U32.is_eq(d1, d2) &&
      U32.is_eq(e1, e2) && U32.is_eq(f1, f2) && U32.is_eq(g1, g2) && U32.is_eq(h1, h2)

# Exported for SupervisorProvision's consistency check: how many entries name
# `index`.
def program_counted(here: Bool, later: Nat) -> Nat:
  match here:
    case True{}: (1n + later : Nat)
    case False{}: later

def program_count(programs: Programs, +index: Nat) -> Nat:
  match programs:
    case NoPrograms{}: 0n
    case Program{i, _, rest}: program_counted(Nat.is_eq(i, index), program_count(rest, index))

def pinned_here(here: Bool, digest: Digest, later: Maybe<&2, Digest>) -> Maybe<&2, Digest>:
  match here:
    case True{}: Some{digest}
    case False{}: later

# The digest pinned for `index`, if any (the first entry; the record allows one).
def pinned(programs: Programs, +index: Nat) -> Maybe<&2, Digest>:
  match programs:
    case NoPrograms{}: None{}
    case Program{i, digest, rest}: pinned_here(Nat.is_eq(i, index), digest, pinned(rest, index))

def is_bound(bound: Bound, +index: Nat) -> Bool:
  match bound:
    case NoBound{}: False{}
    case Bound{i, rest}: Nat.is_eq(i, index) || is_bound(rest, index)

def file_type_mask() -> U32:
  61440

def regular_file() -> U32:
  32768

# Group- or other-write permission (0o022).
def shared_write_bits() -> U32:
  18

# Root or the supervisor's own user may own a role program; nobody else.
def trusted_owner(+owner: U32, +euid: U32) -> Bool:
  U32.is_eq(owner, 0) || U32.is_eq(owner, euid)

# Exported for tests: whether the facts describe a protected program file.
def protected(facts: ProgramFacts) -> Bool:
  match facts:
    case ProgramFacts{+mode, +links, +owner, +euid, _}:
      U32.is_eq(U32.and(mode, file_type_mask()), regular_file()) && U32.is_eq(links, 1) &&
      trusted_owner(owner, euid) && U32.is_eq(U32.and(mode, shared_write_bits()), 0)

def digest_of(facts: ProgramFacts) -> Digest:
  match facts:
    case ProgramFacts{_, _, _, _, digest}: digest

def matches(pin: Maybe<&2, Digest>, +digest: Digest) -> Bool:
  match pin:
    case None{}: False{}
    case Some{want}: digest_equal(want, digest)

def bind(+launches: Launches, +index: Nat) -> Launches:
  match launches:
    case Launches{programs, bound}: Launches{programs, Bound{index, bound}}

def admit_program(matched: Bool, +launches: Launches, +index: Nat) -> Admission:
  match matched:
    case True{}: RoleAdmitted{bind(launches, index)}
    case False{}: RoleRefused{ProgramMismatch{}}

def admit_facts(safe: Bool, +launches: Launches, +facts: ProgramFacts, +index: Nat) -> Admission:
  match safe launches:
    case False{} _: RoleRefused{ProgramUnprotected{}}
    case True{} Launches{+programs, +bound}:
      admit_program(matches(pinned(programs, index), digest_of(facts)), Launches{programs, bound}, index)

def admit_fresh(again: Bool, +launches: Launches, +facts: ProgramFacts, +index: Nat) -> Admission:
  match again:
    case True{}: RoleRefused{RoleAlreadyBound{}}
    case False{}: admit_facts(protected(facts), launches, facts, index)

def bound_of(launches: Launches) -> Bound:
  match launches:
    case Launches{_, bound}: bound

def admit_attributed(attribution: C.Attribution, +launches: Launches, +facts: ProgramFacts, +index: Nat) -> Admission:
  match attribution:
    case C.Attributed{_}: admit_fresh(is_bound(bound_of(launches), index), launches, facts, index)
    case C.Denied{_}: RoleRefused{RoleUnprovisioned{}}

# Public entry point: admit starting the program described by `facts` as role
# `index` under the provisioned `roles` and `launches`.
def admit(+roles: C.RoleMap, +launches: Launches, +facts: ProgramFacts, +index: Nat) -> Admission:
  admit_attributed(C.attribute(roles, C.FromRole{index}), launches, facts, index)

# --- Wire form ----------------------------------------------------------------------

# Exported for SupervisorWire: the ROLE argument's twelve words are mode,
# links, owner, euid, then the digest.
def facts_of_words(+words: +List<U32>) -> Maybe<&2, ProgramFacts>:
  match words:
    case +mode <> +links <> +owner <> +euid <> +a <> +b <> +c <> +d <> +e <> +f <> +g <> +h <> []:
      Some{ProgramFacts{mode, links, owner, euid, Digest{a, b, c, d, e, f, g, h}}}
    case _: None{}

# Exported for SupervisorProvision: a digest's eight words, in order.
def digest_words(digest: Digest) -> +List<U32>:
  match digest:
    case Digest{a, b, c, d, e, f, g, h}: [a, b, c, d, e, f, g, h]
