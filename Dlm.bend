import Base

# Finite Jif DLM semantic fragment. The registered universe has Bottom, Top,
# and named principals 0..named-1 (at most 30 names, hence at most 32 slots).
# The reference monitor supplies the authoritative epoch and authenticated
# delegations. These Data constructors are NOT cryptographic capabilities.
# Compound/dynamic principals are deliberately unsupported and deny closed.
# Use prepare, acts_for and flows for validated requests, and verify_batch to
# replay batched answers. Bend exports helpers too; readers/writers and the
# *_checked functions assume preconditions established by those entry points.
type Principal is Data:
  Bottom{}
  Top{}
  Named{id: U32}
  Unsupported{}

# Join and Meet are lattice operations. Their meaning is deliberately dual:
# confidentiality Join intersects readers; integrity Join unions writers.
# Meet reverses those set operations. Rule uses delegate as the allowed reader
# in conf, or as a possible writer in integ, under the owner's authority.
type Policy is Data:
  Rule{owner: Principal, delegate: Principal}
  Join{left: Policy, right: Policy}
  Meet{left: Policy, right: Policy}

type Label is Data:
  Label{conf: Policy, integ: Policy}

# Edge(actor, granter) means actor acts for granter: granter delegates.
type Edges is Data:
  NoEdges{}
  Edge{actor: Principal, granter: Principal, rest: Edges}

# Row i has bit j exactly when principal i acts for principal j.
# Slots 0 and 1 are Bottom and Top; Named{id} occupies slot id+2.
type Rows is Data:
  NoRows{}
  Row{bits: U32, rest: Rows}

type Snapshot is Data:
  Snapshot{epoch: Nat, named: U32, delegations: Edges, relation: Rows}

# expected_epoch must come from the caller's live trusted state, not merely
# from the untrusted proposal being checked.
type Query is Data:
  Query{expected_epoch: Nat, source: Label, destination: Label}

type Batch is Data:
  NoQueries{}
  OneQuery{query: Query}
  SplitQueries{left: Batch, right: Batch}

type Answers is Data:
  NoAnswers{}
  OneAnswer{allowed: Bool}
  SplitAnswers{left: Answers, right: Answers}

def word(c: Bool, yes: U32, no: U32) -> U32:
  match c:
    case True{}:
      yes
    case False{}:
      no

def implies(a: Bool, b: Bool) -> Bool:
  Bool.not(a) || b

def principal_valid(p: Principal, named: U32) -> Bool:
  match p:
    case Bottom{}:
      True{}
    case Top{}:
      True{}
    case Named{id}:
      U32.is_lt(id, named)
    case Unsupported{}:
      False{}

# Internal index conversion; all security-facing entry points validate first.
# The unsupported sentinel is outside every permitted universe.
def principal_index(p: Principal) -> Nat:
  match p:
    case Bottom{}:
      0n
    case Top{}:
      1n
    case Named{id}:
      2n+U32.to_nat(id)
    case Unsupported{}:
      32n

def policy_valid(p: Policy, +named: U32) -> Bool:
  match p:
    case Rule{owner, delegate}:
      principal_valid(owner, named) && principal_valid(delegate, named)
    case Join{left, right}:
      policy_valid(left, named) && policy_valid(right, named)
    case Meet{left, right}:
      policy_valid(left, named) && policy_valid(right, named)

def label_valid(label: Label, +named: U32) -> Bool:
  match label:
    case Label{conf, integ}:
      policy_valid(conf, named) && policy_valid(integ, named)

def edges_valid(edges: Edges, +named: U32) -> Bool:
  match edges:
    case NoEdges{}:
      True{}
    case Edge{actor, granter, rest}:
      principal_valid(actor, named) && principal_valid(granter, named)
        && edges_valid(rest, named)

def low_mask(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      (U32.shl(low_mask(p)) .|. 1 : U32)

def bit(i: Nat) -> U32:
  U32.shln(1, i)

def has_bit(bits: U32, i: Nat) -> Bool:
  U32.is_ne((bits .&. bit(i) : U32), 0)

def row_at(i: Nat, rows: Rows) -> U32:
  match i rows:
    case 0n Row{bits, _}:
      bits
    case 1n+p Row{_, rest}:
      row_at(p, rest)
    case _ NoRows{}:
      0

def edge_bits(edges: Edges, +actor_index: Nat) -> U32:
  match edges:
    case NoEdges{}:
      0
    case Edge{actor, granter, rest}:
      own = word(Nat.is_eq(principal_index(actor), actor_index), bit(principal_index(granter)), 0)
      (own .|. edge_bits(rest, actor_index) : U32)

# Seed reflexive edges, everyone acting for Bottom, and Top acting for everyone.
# Transitive closure then adds only the consequences of these and the edges.
def seed_row(+i: Nat, mask: U32) -> U32:
  word(Nat.is_eq(i, 1n), mask, (1 .|. bit(i) : U32))

def seed_rows(fuel: Nat, +i: Nat, +mask: U32, +edges: Edges) -> Rows:
  match fuel:
    case 0n:
      NoRows{}
    case 1n+p:
      Row{(seed_row(i, mask) .|. edge_bits(edges, i) : U32),
        seed_rows(p, 1n+i, mask, edges)}

def through(rows: Rows, +k: Nat, +via: U32) -> Rows:
  match rows:
    case NoRows{}:
      NoRows{}
    case Row{+bits, rest}:
      Row{(bits .|. word(has_bit(bits, k), via, 0) : U32), through(rest, k, via)}

# Floyd-Warshall, with one finite principal as intermediate per round.
# Fuel is the exact universe size, not a caller-selected early-stop limit.
def close(fuel: Nat, +k: Nat, +rows: Rows) -> Rows:
  match fuel:
    case 0n:
      rows
    case 1n+p:
      via = row_at(k, rows)
      close(p, 1n+k, through(rows, k, via))

def relation(+named: U32, edges: Edges) -> Rows:
  +n = {2n+U32.to_nat(named) : Nat}
  close(n, 0n, seed_rows(n, 0n, low_mask(n), edges))

def rows_equal(a: Rows, b: Rows) -> Bool:
  match a b:
    case NoRows{} NoRows{}:
      True{}
    case Row{x, xs} Row{y, ys}:
      U32.is_eq(x, y) && rows_equal(xs, ys)
    case _ _:
      False{}

def prepare_checked(ok: Bool, epoch: Nat, +named: U32, +edges: Edges) -> Maybe<&2, Snapshot>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Snapshot{epoch, named, edges, relation(named, edges)}}

# Call only with the reference monitor's authenticated delegation snapshot.
# This library validates its finite semantics; it does not verify signatures.
# None rejects an oversized universe or an unknown/unsupported principal.
def prepare(epoch: Nat, +named: U32, +edges: Edges) -> Maybe<&2, Snapshot>:
  prepare_checked(U32.is_le(named, 30) && edges_valid(edges, named), epoch, named, edges)

def closure_checked(ok: Bool, +named: U32, edges: Edges, rows: Rows) -> Bool:
  match ok:
    case False{}:
      False{}
    case True{}:
      rows_equal(relation(named, edges), rows)

# Exact closure is checked: missing and invented authority are both rejected.
# Equality with a newly built matrix also checks shape and out-of-range bits.
# This validates consistency with delegations, not their authenticity or age.
def valid(snapshot: Snapshot) -> Bool:
  match snapshot:
    case Snapshot{_, +named, +edges, rows}:
      closure_checked(U32.is_le(named, 30) && edges_valid(edges, named), named, edges, rows)

def epoch(snapshot: Snapshot) -> Nat:
  match snapshot:
    case Snapshot{epoch, _, _, _}:
      epoch

def named(snapshot: Snapshot) -> U32:
  match snapshot:
    case Snapshot{_, named, _, _}:
      named

def acts_checked(ok: Bool, snapshot: Snapshot, actor: Principal, granter: Principal) -> Bool:
  match ok snapshot:
    case True{} Snapshot{_, _, _, rows}:
      has_bit(row_at(principal_index(actor), rows), principal_index(granter))
    case False{} _:
      False{}

# Returns false on invalid snapshots, stale epochs or unsupported principals.
# Direction matters: acts_for(actor, granter) asks who may act for the granter.
def acts_for(+snapshot: Snapshot, expected_epoch: Nat, +actor: Principal, +granter: Principal) -> Bool:
  acts_checked(valid(snapshot) && Nat.is_eq(epoch(snapshot), expected_epoch)
    && principal_valid(actor, named(snapshot)) && principal_valid(granter, named(snapshot)),
    snapshot, actor, granter)

# Transpose a single relation column into a set of candidate actors.
def column(rows: Rows, +target: Nat, +i: Nat) -> U32:
  match rows:
    case NoRows{}:
      0
    case Row{bits, rest}:
      (word(has_bit(bits, target), bit(i), 0) .|. column(rest, target, 1n+i) : U32)

def rule_set_checked(credited: Bool, +rows: Rows, owner: Nat, delegate: Nat, mask: U32) -> U32:
  match credited:
    case False{}:
      mask
    case True{}:
      (column(rows, owner, 0n) .|. column(rows, delegate, 0n) : U32)

# R(p,o->r,q) and W(p,o<-w,q) have the same atomic predicate:
# !acts_for(o,p) || acts_for(q,o) || acts_for(q,r_or_w).
def rule_set(+rows: Rows, observer: Nat, +owner: Nat, delegate: Nat, mask: U32) -> U32:
  rule_set_checked(has_bit(row_at(owner, rows), observer), rows, owner, delegate, mask)

# Internal evaluators require principal-valid policies and a valid relation.
# Public admission below establishes these preconditions before evaluation.
def readers(policy: Policy, +rows: Rows, +observer: Nat, +mask: U32) -> U32:
  match policy:
    case Rule{owner, delegate}:
      rule_set(rows, observer, principal_index(owner), principal_index(delegate), mask)
    case Join{left, right}:
      (readers(left, rows, observer, mask) .&. readers(right, rows, observer, mask) : U32)
    case Meet{left, right}:
      (readers(left, rows, observer, mask) .|. readers(right, rows, observer, mask) : U32)

def writers(policy: Policy, +rows: Rows, +observer: Nat, +mask: U32) -> U32:
  match policy:
    case Rule{owner, delegate}:
      rule_set(rows, observer, principal_index(owner), principal_index(delegate), mask)
    case Join{left, right}:
      (writers(left, rows, observer, mask) .|. writers(right, rows, observer, mask) : U32)
    case Meet{left, right}:
      (writers(left, rows, observer, mask) .&. writers(right, rows, observer, mask) : U32)

def subset(+small: U32, big: U32) -> Bool:
  U32.is_eq((small .&. big : U32), small)

# A destination may admit fewer readers and more possible writers. These are
# opposite subset directions: dst.readers <= src.readers, src.writers <= dst.writers.
# all_observers repeats both checks for every principal, including Top/Bottom.
def observer_flows(rows: Rows, observer: Nat, mask: U32, source: Label, destination: Label) -> Bool:
  match source destination:
    case Label{sc, si} Label{tc, ti}:
      # These fields are shared across four finite policy evaluations.
      +rs = rows
      +p = observer
      +m = mask
      subset(readers(tc, rs, p, m), readers(sc, rs, p, m))
        && subset(writers(si, rs, p, m), writers(ti, rs, p, m))

def all_observers(fuel: Nat, +observer: Nat, +rows: Rows, +mask: U32, +source: Label, +destination: Label) -> Bool:
  match fuel:
    case 0n:
      True{}
    case 1n+p:
      observer_flows(rows, observer, mask, source, destination)
        && all_observers(p, 1n+observer, rows, mask, source, destination)

def flows_checked(ok: Bool, snapshot: Snapshot, source: Label, destination: Label) -> Bool:
  match ok snapshot:
    case False{} _:
      False{}
    case True{} Snapshot{_, named, _, rows}:
      +n = {2n+U32.to_nat(named) : Nat}
      all_observers(n, 0n, rows, low_mask(n), source, destination)

# Complete fail-closed entry point. A true result is an IFC check, never a
# capability, source-owner approval, payment, endorsement, or declassification.
# For example, copying a value into a label that adds a reader is denied unless
# the authenticated acts-for relation already makes the two policies equivalent.
def flows(+snapshot: Snapshot, expected_epoch: Nat, +source: Label, +destination: Label) -> Bool:
  flows_checked(valid(snapshot) && Nat.is_eq(epoch(snapshot), expected_epoch)
    && label_valid(source, named(snapshot)) && label_valid(destination, named(snapshot)),
    snapshot, source, destination)

# These construct label expressions; they neither validate nor authorize them.
# join safely accumulates dependencies. meet can relax a label, so constructing
# it is never evidence that a value may be relabeled to the result.
def join(left: Label, right: Label) -> Label:
  match left right:
    case Label{lc, li} Label{rc, ri}:
      Label{Join{lc, rc}, Join{li, ri}}

def meet(left: Label, right: Label) -> Label:
  match left right:
    case Label{lc, li} Label{rc, ri}:
      Label{Meet{lc, rc}, Meet{li, ri}}

# A dependency joins both data labels and control-flow labels into its result.
def dependency(data: Label, control: Label) -> Label:
  join(data, control)

def query(query: Query, snapshot: Snapshot) -> Bool:
  match query:
    case Query{epoch, source, destination}:
      flows(snapshot, epoch, source, destination)

# Use a balanced tree of requests with similar policy sizes. Each leaf is a
# complete check, including authoritative closure and epoch validation.
def batch(queries: Batch, +snapshot: Snapshot) -> Answers:
  match queries:
    case NoQueries{}:
      NoAnswers{}
    case OneQuery{q}:
      OneAnswer{query(q, snapshot)}
    case SplitQueries{left, right}:
      a b = batch(left, snapshot) batch(right, snapshot)
      SplitAnswers{a, b}

def answers_equal(a: Answers, b: Answers) -> Bool:
  match a b:
    case NoAnswers{} NoAnswers{}:
      True{}
    case OneAnswer{x} OneAnswer{y}:
      Bool.not(Bool.xor(x, y))
    case SplitAnswers{al, ar} SplitAnswers{bl, br}:
      answers_equal(al, bl) && answers_equal(ar, br)
    case _ _:
      False{}

# GPU answers are proposals. A CPU caller can replay the complete request
# tree; shape, denials, epochs, closure and policy semantics must all agree.
# The replay uses the same policy evaluator, not a separate proof algorithm.
# Supply a fresh authenticated snapshot and live expected epochs at admission.
# True means the answer tree agrees, including denials; it does not mean every
# query is allowed. The caller must also inspect each OneAnswer.allowed value.
def verify_batch(queries: Batch, snapshot: Snapshot, candidate: Answers) -> Bool:
  answers_equal(batch(queries, snapshot), candidate)

# Fixture registry: Named{0}=Alice, Named{1}=Bob, Named{2}=Mallory.
# Synthetic example data only; this function does not register real principals.
def fixture(epoch: Nat) -> Snapshot:
  Snapshot{epoch, 3, NoEdges{},
    Row{1, Row{31, Row{5, Row{9, Row{17, NoRows{}}}}}}}

def public_untrusted() -> Label:
  Label{Rule{Bottom{}, Bottom{}}, Rule{Bottom{}, Bottom{}}}

def public_trusted() -> Label:
  Label{Rule{Bottom{}, Bottom{}}, Rule{Top{}, Top{}}}

# Uses fixture's Alice/Bob IDs; callers need both names in their own registry.
def secret_untrusted() -> Label:
  Label{Rule{Named{0}, Named{1}}, Rule{Bottom{}, Bottom{}}}

def maximal_restriction() -> Label:
  Label{Rule{Top{}, Top{}}, Rule{Bottom{}, Bottom{}}}
