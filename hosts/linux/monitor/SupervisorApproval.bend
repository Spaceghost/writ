import Base
import ../../../Issuance.bend as Iss
import ../../../Transfer.bend as T

# Body codec for the approvals a provisioned channel role submits through the
# supervisor control channel (`SupervisorOwner` tags 2 and 3).
#
# Authority direction. This module only turns words into the fields of an
# `Iss.SourceApproval` or `Iss.WriteApproval` and back. The decoded `issuer` is
# the record's claim and is never believed here: the owner submits the record
# with the principal attributed from the kernel-reported sender, and
# `Iss.submit_source` / `Iss.submit_write` refuse it unless the claim is that
# principal and the directory, placements, scope, rights, lifetime and replay
# checks all hold. Nothing decoded here is a grant.
#
# Body layout, one U32 word per field, in order:
#   version, serial, issuer, object, object version, domain,
#   scope: stamp graph, stamp policy, stamp authority, invocation,
#          source count N, then N x (object, version),
#          destination object, destination version, code (eight words),
#          kind (1 Copy, 2 Transform, 3 Summarize), output type,
#          write domain, subject,
#   rights, valid until.
# For a source approval `object` is the approved source and `domain` a read
# domain; for a write approval they are the destination and a write domain.
# Every number above 2^32 - 1 is unrepresentable on this channel.
#
# Failure behavior. Too few or too many words, or a manifest shorter than its
# count, is `PartsLength`; an unknown kind is `PartsKind`. Well-formedness
# beyond that (zero ids, empty manifests, stale stamps, expiry) is the issuer's.

# The fields an approval of either kind carries; `domain` is the raw domain id.
type Parts is Data:
  Parts{version: Nat, serial: Nat, issuer: Iss.Principal, object: T.ObjectVersion,
    domain: Nat, scope: Iss.Scope, rights: U32, valid_until: Nat}

type PartsRead is Data:
  PartsRead{parts: Parts}
  PartsLength{}
  PartsKind{}

# The fixed words ahead of the source manifest, kept together so the tail
# decoder stays within the backend's arity limit.
type Head is Data:
  Head{version: U32, serial: U32, issuer: U32, object: T.ObjectVersion, domain: U32,
    stamp: T.Stamp, invocation: U32}

type ObjectsTaken is Data:
  ObjectsTaken{objects: T.Objects, rest: +List<U32>}
  ObjectsShort{}

def object_version(+object: U32, +version: U32) -> T.ObjectVersion:
  T.ObjectVersion{U32.to_nat(object), U32.to_nat(version)}

def objects_then(+object: U32, +version: U32, taken: ObjectsTaken) -> ObjectsTaken:
  match taken:
    case ObjectsTaken{tail, rest}: ObjectsTaken{T.OCons{object_version(object, version), tail}, rest}
    case ObjectsShort{}: ObjectsShort{}

# Reads `count` (object, version) pairs; `done` is `count == 0`.
def take_objects(+words: +List<U32>, done: Bool, +count: U32) -> ObjectsTaken:
  match words done:
    case w True{}: ObjectsTaken{T.OEnd{}, w}
    case +object <> +version <> +rest False{}:
      objects_then(object, version, take_objects(rest, U32.is_eq(count, 1), (count - 1 : U32)))
    case _ False{}: ObjectsShort{}

# The wire kind words, as PlannerPlanMatch.kind_equal reads them.
def kind_of(+word: U32) -> Maybe<&2, T.OpKind>:
  match word:
    case 1: Some{T.Copy{}}
    case 2: Some{T.Transform{}}
    case 3: Some{T.Summarize{}}
    case _: None{}

def kind_word(kind: T.OpKind) -> U32:
  match kind:
    case T.Copy{}: 1
    case T.Transform{}: 2
    case T.Summarize{}: 3

def with_kind(kind: Maybe<&2, T.OpKind>, head: Head, objects: T.Objects, destination: T.ObjectVersion,
    code: T.CodeId, +output: U32, +write_domain: U32, +subject: U32, +rights: U32, +until: U32) -> PartsRead:
  match kind head:
    case None{} _: PartsKind{}
    case Some{k} Head{version, serial, issuer, object, domain, stamp, invocation}:
      PartsRead{Parts{U32.to_nat(version), U32.to_nat(serial), Iss.Principal{U32.to_nat(issuer)},
        object, U32.to_nat(domain),
        Iss.Scope{T.Plan{stamp, U32.to_nat(invocation), objects, destination, code, k, output},
          T.WriteDomain{U32.to_nat(write_domain)}, U32.to_nat(subject)},
        rights, U32.to_nat(until)}}

# The words after the manifest must be exactly the sixteen fixed fields.
def tail_parts(head: Head, objects: T.Objects, +rest: +List<U32>) -> PartsRead:
  match rest:
    case +dobj <> +dver <> a <> b <> c <> d <> e <> f <> g <> h <> +kind <> +output <> +wdomain <> +subject <> +rights <> +until <> []:
      with_kind(kind_of(kind), head, objects, object_version(dobj, dver), T.CodeId{a, b, c, d, e, f, g, h},
        output, wdomain, subject, rights, until)
    case _: PartsLength{}

def after_objects(head: Head, taken: ObjectsTaken) -> PartsRead:
  match taken:
    case ObjectsTaken{objects, rest}: tail_parts(head, objects, rest)
    case ObjectsShort{}: PartsLength{}

# Public entry point: decode one approval body (see the layout above).
def decode_parts(+body: +List<U32>) -> PartsRead:
  match body:
    case +version <> +serial <> +issuer <> +object <> +over <> +domain <> +graph <> +policy <> +authority <> +invocation <> +count <> +rest:
      after_objects(Head{version, serial, issuer, object_version(object, over), domain,
        T.Stamp{U32.to_nat(graph), U32.to_nat(policy), U32.to_nat(authority)}, invocation},
        take_objects(rest, U32.is_eq(count, 0), count))
    case _: PartsLength{}

# --- Test writer ---------------------------------------------------------------

def objects_words(objects: T.Objects) -> +List<U32>:
  match objects:
    case T.OEnd{}: []
    case T.OCons{T.ObjectVersion{object, version}, tail}:
      U32.from_nat(object) <> U32.from_nat(version) <> objects_words(tail)

def objects_count(objects: T.Objects) -> U32:
  match objects:
    case T.OEnd{}: 0
    case T.OCons{_, tail}: (1 + objects_count(tail) : U32)

def plan_words(plan: T.Plan, +write_domain: Nat, +subject: Nat) -> +List<U32>:
  match plan:
    case T.Plan{T.Stamp{graph, policy, authority}, invocation, +sources, T.ObjectVersion{dobj, dver},
        T.CodeId{a, b, c, d, e, f, g, h}, kind, output}:
      List.append(&2, U32,
        [U32.from_nat(graph), U32.from_nat(policy), U32.from_nat(authority), U32.from_nat(invocation),
          objects_count(sources)],
        List.append(&2, U32, objects_words(sources),
          [U32.from_nat(dobj), U32.from_nat(dver), a, b, c, d, e, f, g, h, kind_word(kind), output,
            U32.from_nat(write_domain), U32.from_nat(subject)]))

def scope_words(scope: Iss.Scope) -> +List<U32>:
  match scope:
    case Iss.Scope{plan, T.WriteDomain{write_domain}, subject}: plan_words(plan, write_domain, subject)

# Public entry point: the body words a trusted test sender writes for `parts`.
def encode_parts(parts: Parts) -> +List<U32>:
  match parts:
    case Parts{version, serial, Iss.Principal{issuer}, T.ObjectVersion{object, over}, domain, scope, rights, until}:
      List.append(&2, U32,
        [U32.from_nat(version), U32.from_nat(serial), U32.from_nat(issuer), U32.from_nat(object),
          U32.from_nat(over), U32.from_nat(domain)],
        List.append(&2, U32, scope_words(scope), [rights, U32.from_nat(until)]))

def source_parts(approval: Iss.SourceApproval) -> Parts:
  match approval:
    case Iss.SourceApproval{version, serial, issuer, source, T.ReadDomain{domain}, scope, rights, until}:
      Parts{version, serial, issuer, source, domain, scope, rights, until}

def write_parts(approval: Iss.WriteApproval) -> Parts:
  match approval:
    case Iss.WriteApproval{version, serial, issuer, destination, T.WriteDomain{domain}, scope, rights, until}:
      Parts{version, serial, issuer, destination, domain, scope, rights, until}

# Public entry points: the decoded parts as each approval kind.
def as_source(parts: Parts) -> Iss.SourceApproval:
  match parts:
    case Parts{version, serial, issuer, object, domain, scope, rights, until}:
      Iss.SourceApproval{version, serial, issuer, object, T.ReadDomain{domain}, scope, rights, until}

def as_write(parts: Parts) -> Iss.WriteApproval:
  match parts:
    case Parts{version, serial, issuer, object, domain, scope, rights, until}:
      Iss.WriteApproval{version, serial, issuer, object, T.WriteDomain{domain}, scope, rights, until}
