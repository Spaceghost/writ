import Base

# Pure synthetic structure; IDs, records and witnesses are forgeable. No
# admission, stage identity, terminal, schema, hook or policy is established.
# check is the intended descriptive entry; exported helpers are not host APIs.
type Edge is Data:
  Edge{from: U32, to: U32}

type Graph is Data:
  Graph{stages: +List<U32>, edges: +List<Edge>}

type Outcome is Data:
  TooManyStages{}
  TooManyEdges{}
  EmptyStages{}
  DuplicateStage{}
  DanglingEdge{}
  CyclicOrInvalidWitness{}
  StructurallyAcyclic{}

type Ranked is Data:
  Ranked{id: U32, rank: U32}

type Round is Data:
  Round{entries: +List<Ranked>, added: Bool}

# Public check and verify_original provide fixed cap fuel before any later
# scan. Direct helper callers must supply already-bounded lists and fuel.
def stages_within(fuel: Nat, xs: +List<U32>) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{_, rest}: stages_within(next, rest)

def edges_within(fuel: Nat, xs: +List<Edge>) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{_, rest}: edges_within(next, rest)

def ranks_within(fuel: Nat, xs: +List<Ranked>) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{_, rest}: ranks_within(next, rest)

def has_stage(fuel: Nat, xs: +List<U32>, +id: U32) -> Bool:
  match fuel xs:
    case _ Nil{}: False{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{head, rest}: U32.is_eq(head, id) || has_stage(next, rest, id)

def unique(fuel: Nat, xs: +List<U32>) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{head, +rest}:
      Bool.not(has_stage(8n, rest, head)) && unique(next, rest)

def valid_edges(fuel: Nat, xs: +List<Edge>, +stages: +List<U32>) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{Edge{from, to}, rest}:
      has_stage(8n, stages, from) && has_stage(8n, stages, to) && valid_edges(next, rest, stages)

def choose_rank(found: Bool, rank: U32, other: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match found:
    case True{}: Some{rank}
    case False{}: other

def find_rank(fuel: Nat, xs: +List<Ranked>, +id: U32) -> Maybe<&2, U32>:
  match fuel xs:
    case _ Nil{}: None{}
    case 0n Con{_, _}: None{}
    case 1n+next Con{Ranked{head, rank}, rest}:
      choose_rank(U32.is_eq(head, id), rank, find_rank(next, rest, id))

# Independent verifier revalidates the original graph and witness, then checks
# every original edge. It does not trust the producer's ready/removed lists.
def rank_present(found: Maybe<&2, U32>) -> Bool:
  match found:
    case None{}: False{}
    case Some{_}: True{}

def witness_entries(fuel: Nat, xs: +List<Ranked>, +stages: +List<U32>) -> Bool:
  match fuel xs:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{Ranked{+id, rank}, +rest}:
      has_stage(8n, stages, id) && U32.is_lt(rank, 8) &&
      Bool.not(rank_present(find_rank(8n, rest, id))) && witness_entries(next, rest, stages)

def every_ranked(fuel: Nat, stages: +List<U32>, +witness: +List<Ranked>) -> Bool:
  match fuel stages:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{id, rest}:
      rank_present(find_rank(8n, witness, id)) && every_ranked(next, rest, witness)

def ordered_ranks(left: Maybe<&2, U32>, right: Maybe<&2, U32>) -> Bool:
  match left right:
    case Some{a} Some{b}: U32.is_lt(a, b)
    case _ _: False{}

def original_ordered(fuel: Nat, edges: +List<Edge>, +witness: +List<Ranked>) -> Bool:
  match fuel edges:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{Edge{from, to}, rest}:
      ordered_ranks(find_rank(8n, witness, from), find_rank(8n, witness, to)) &&
      original_ordered(next, rest, witness)

def verify_rank_cap(ok: Bool, +stages: +List<U32>, +edges: +List<Edge>, +witness: +List<Ranked>) -> Bool:
  match ok:
    case False{}: False{}
    case True{}:
      unique(8n, stages) && valid_edges(32n, edges, stages) &&
      witness_entries(8n, witness, stages) && every_ranked(8n, stages, witness) &&
      original_ordered(32n, edges, witness)

def verify_nonempty(+stages: +List<U32>, edges: +List<Edge>, +witness: +List<Ranked>) -> Bool:
  match stages:
    case Nil{}: False{}
    case Con{_, _}: verify_rank_cap(ranks_within(8n, witness), stages, edges, witness)

def verify_edge_cap(ok: Bool, stages: +List<U32>, edges: +List<Edge>, witness: +List<Ranked>) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: verify_nonempty(stages, edges, witness)

def verify_stage_cap(ok: Bool, stages: +List<U32>, +edges: +List<Edge>, +witness: +List<Ranked>) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: verify_edge_cap(edges_within(32n, edges), stages, edges, witness)

def verify_original(graph: Graph, witness: +List<Ranked>) -> Bool:
  match graph:
    case Graph{+stages, edges}: verify_stage_cap(stages_within(8n, stages), stages, edges, witness)

# All nodes in a round consult only the previous witness; producer traversal
# retains the original edges. The independent verifier does not use this list.
def incoming_ready(fuel: Nat, edges: +List<Edge>, +id: U32, +prior: +List<Ranked>) -> Bool:
  match fuel edges:
    case _ Nil{}: True{}
    case 0n Con{_, _}: False{}
    case 1n+next Con{Edge{from, to}, rest}:
      (Bool.not(U32.is_eq(to, id)) || rank_present(find_rank(8n, prior, from))) &&
      incoming_ready(next, rest, id, prior)

def insert_ready(already: Bool, ready: Bool, id: U32, rank: U32, acc: Round) -> Round:
  match already ready acc:
    case False{} True{} Round{entries, _}: Round{Con{Ranked{id, rank}, entries}, True{}}
    case _ _ Round{entries, added}: Round{entries, added}

def round_scan(fuel: Nat, stages: +List<U32>, +edges: +List<Edge>, +prior: +List<Ranked>, +rank: U32, acc: Round) -> Round:
  match fuel stages:
    case _ Nil{}: acc
    case 0n Con{_, _}: acc
    case 1n+next Con{+id, rest}:
      round_scan(next, rest, edges, prior, rank,
        insert_ready(rank_present(find_rank(8n, prior, id)), incoming_ready(32n, edges, id, prior), id, rank, acc))

def finish_round(done: Bool, result: Round) -> Maybe<&2, +List<Ranked>>:
  match done result:
    case True{} Round{entries, _}: Some{entries}
    case False{} Round{entries, True{}}: Some{entries}
    case False{} Round{_, False{}}: None{}

def advance(+stages: +List<U32>, edges: +List<Edge>, +prior: +List<Ranked>, rank: U32) -> Maybe<&2, +List<Ranked>>:
  finish_round(every_ranked(8n, stages, prior), round_scan(8n, stages, edges, prior, rank, Round{prior, False{}}))

def finish_peel(done: Bool, entries: +List<Ranked>) -> Maybe<&2, +List<Ranked>>:
  match done:
    case False{}: None{}
    case True{}: Some{entries}

def peel(fuel: Nat, +stages: +List<U32>, +edges: +List<Edge>, +rank: U32, state: Maybe<&2, +List<Ranked>>) -> Maybe<&2, +List<Ranked>>:
  match fuel state:
    case _ None{}: None{}
    case 0n Some{+entries}: finish_peel(every_ranked(8n, stages, entries), entries)
    case 1n+next Some{entries}: peel(next, stages, edges, (rank + 1 : U32), advance(stages, edges, entries, rank))

def verified(ok: Bool) -> Outcome:
  match ok:
    case False{}: CyclicOrInvalidWitness{}
    case True{}: StructurallyAcyclic{}

def witness_checked(result: Maybe<&2, +List<Ranked>>, graph: Graph) -> Outcome:
  match result:
    case None{}: CyclicOrInvalidWitness{}
    case Some{entries}: verified(verify_original(graph, entries))

def endpoints_checked(ok: Bool, +stages: +List<U32>, +edges: +List<Edge>) -> Outcome:
  match ok:
    case False{}: DanglingEdge{}
    case True{}: witness_checked(peel(8n, stages, edges, 0, Some{Nil{}}), Graph{stages, edges})

def duplicates_checked(ok: Bool, +stages: +List<U32>, +edges: +List<Edge>) -> Outcome:
  match ok:
    case False{}: DuplicateStage{}
    case True{}: endpoints_checked(valid_edges(32n, edges, stages), stages, edges)

def nonempty(+stages: +List<U32>, edges: +List<Edge>) -> Outcome:
  match stages:
    case Nil{}: EmptyStages{}
    case Con{_, _}: duplicates_checked(unique(8n, stages), stages, edges)

def edge_cap_checked(ok: Bool, stages: +List<U32>, edges: +List<Edge>) -> Outcome:
  match ok:
    case False{}: TooManyEdges{}
    case True{}: nonempty(stages, edges)

def stage_cap_checked(ok: Bool, stages: +List<U32>, +edges: +List<Edge>) -> Outcome:
  match ok:
    case False{}: TooManyStages{}
    case True{}: edge_cap_checked(edges_within(32n, edges), stages, edges)

def check(graph: Graph) -> Outcome:
  match graph:
    case Graph{+stages, edges}: stage_cap_checked(stages_within(8n, stages), stages, edges)
