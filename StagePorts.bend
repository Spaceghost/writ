import Base
import ./StageGraph.bend as G

# A bounded SYNTHETIC description, never stage admission or authenticated schema
# evidence. Every ID is an opaque U32 value, not an index, native capability,
# registry credential or authority fact. One output schema per stage and at
# most four mandatory ordered input ports are supported; external inputs,
# optional/variadic ports, multiple outputs and typed schema compatibility are
# outside this profile. Exact schema ID equality is the only comparison here.
#
# Public observe describes three independent observations; none is authority.
# same_graph compares descriptions only against a separately supplied input.
# All defs are exported by Bend; implementation helpers are not host APIs.
# Every list-consuming helper below uses finite exact patterns, including Nil;
# there is no caller-selected fuel, clipping or unbounded traversal.

type Port is Data:
  Port{id: U32, schema: U32}
type Stage is Data:
  Stage{id: U32, output_schema: U32, inputs: +List<Port>}
type Edge is Data:
  Edge{from: U32, to: U32, port: U32}
type Graph is Data:
  Graph{stages: +List<Stage>, edges: +List<Edge>}
type Hit is Data:
  NoHit{}
  OneHit{position: U32}
  ManyHits{}
type CycleObservation is Data:
  NoProjection{}
  Checked{outcome: G.Outcome}
type Observation is Data:
  Observation{bindings_match: Bool, projection_matches: Bool, cycle: CycleObservation}

def stage_id(stage: Stage) -> U32:
  match stage:
    case Stage{id, _, _}: id

def port_id(port: Port) -> U32:
  match port:
    case Port{id, _}: id

def port_equal(a: Port, b: Port) -> Bool:
  match a b:
    case Port{ai, as} Port{bi, bs}: U32.is_eq(ai, bi) && U32.is_eq(as, bs)

def edge_equal(a: Edge, b: Edge) -> Bool:
  match a b:
    case Edge{af, at, ap} Edge{bf, bt, bp}:
      U32.is_eq(af, bf) && U32.is_eq(at, bt) && U32.is_eq(ap, bp)

def edge_targets(edge: Edge, stage: U32, port: U32) -> Bool:
  match edge:
    case Edge{_, to, slot}: U32.is_eq(to, stage) && U32.is_eq(slot, port)

def hit_step(yes: Bool, position: U32, state: Hit) -> Hit:
  match yes state:
    case False{} _: state
    case True{} NoHit{}: OneHit{position}
    case True{} OneHit{_}: ManyHits{}
    case True{} ManyHits{}: ManyHits{}

def one_hit(hit: Hit) -> Bool:
  match hit:
    case OneHit{_}: True{}
    case _: False{}

def ordered_hits(a: Hit, b: Hit) -> Bool:
  match a b:
    case OneHit{left} OneHit{right}: U32.is_lt(left, right)
    case _ _: False{}

def edge_shape(edges: +List<Edge>) -> Bool:
  match edges:
    case Nil{}: True{}
    case Con{e0, Nil{}}: True{}
    case Con{e0, Con{e1, Nil{}}}: True{}
    case Con{e0, Con{e1, Con{e2, Nil{}}}}: True{}
    case Con{e0, Con{e1, Con{e2, Con{e3, Nil{}}}}}: True{}
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Nil{}}}}}}: True{}
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Nil{}}}}}}}: True{}
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Con{e6, Nil{}}}}}}}}: True{}
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Con{e6, Con{e7, Nil{}}}}}}}}}: True{}
    case _: False{}

# Returns a position only when exactly one original edge binds that port.
# At most eight edges are inspected even by a direct helper call.
def locate(+stage: U32, +port: U32, edges: +List<Edge>) -> Hit:
  match edges:
    case Nil{}: NoHit{}
    case Con{e0, Nil{}}: hit_step(edge_targets(e0, stage, port), 0, NoHit{})
    case Con{e0, Con{e1, Nil{}}}: hit_step(edge_targets(e1, stage, port), 1, hit_step(edge_targets(e0, stage, port), 0, NoHit{}))
    case Con{e0, Con{e1, Con{e2, Nil{}}}}: hit_step(edge_targets(e2, stage, port), 2, hit_step(edge_targets(e1, stage, port), 1, hit_step(edge_targets(e0, stage, port), 0, NoHit{})))
    case Con{e0, Con{e1, Con{e2, Con{e3, Nil{}}}}}: hit_step(edge_targets(e3, stage, port), 3, hit_step(edge_targets(e2, stage, port), 2, hit_step(edge_targets(e1, stage, port), 1, hit_step(edge_targets(e0, stage, port), 0, NoHit{}))))
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Nil{}}}}}}: hit_step(edge_targets(e4, stage, port), 4, hit_step(edge_targets(e3, stage, port), 3, hit_step(edge_targets(e2, stage, port), 2, hit_step(edge_targets(e1, stage, port), 1, hit_step(edge_targets(e0, stage, port), 0, NoHit{})))))
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Nil{}}}}}}}: hit_step(edge_targets(e5, stage, port), 5, hit_step(edge_targets(e4, stage, port), 4, hit_step(edge_targets(e3, stage, port), 3, hit_step(edge_targets(e2, stage, port), 2, hit_step(edge_targets(e1, stage, port), 1, hit_step(edge_targets(e0, stage, port), 0, NoHit{}))))))
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Con{e6, Nil{}}}}}}}}: hit_step(edge_targets(e6, stage, port), 6, hit_step(edge_targets(e5, stage, port), 5, hit_step(edge_targets(e4, stage, port), 4, hit_step(edge_targets(e3, stage, port), 3, hit_step(edge_targets(e2, stage, port), 2, hit_step(edge_targets(e1, stage, port), 1, hit_step(edge_targets(e0, stage, port), 0, NoHit{})))))))
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Con{e6, Con{e7, Nil{}}}}}}}}}: hit_step(edge_targets(e7, stage, port), 7, hit_step(edge_targets(e6, stage, port), 6, hit_step(edge_targets(e5, stage, port), 5, hit_step(edge_targets(e4, stage, port), 4, hit_step(edge_targets(e3, stage, port), 3, hit_step(edge_targets(e2, stage, port), 2, hit_step(edge_targets(e1, stage, port), 1, hit_step(edge_targets(e0, stage, port), 0, NoHit{}))))))))
    case _: ManyHits{}

# Exact port shape and original-edge subsequence order. Duplicate port IDs,
# missing edges, duplicate bindings and over-limit edge lists refuse.
def ports_ok(+stage: U32, ports: +List<Port>, +edges: +List<Edge>) -> Bool:
  match ports:
    case Nil{}:
      edge_shape(edges)
    case Con{+p0, Nil{}}:
      edge_shape(edges) &&
      one_hit(locate(stage, port_id(p0), edges))
    case Con{+p0, Con{+p1, Nil{}}}:
      edge_shape(edges) &&
      one_hit(locate(stage, port_id(p0), edges)) &&
      one_hit(locate(stage, port_id(p1), edges)) &&
      ordered_hits(locate(stage, port_id(p0), edges), locate(stage, port_id(p1), edges))
    case Con{+p0, Con{+p1, Con{+p2, Nil{}}}}:
      edge_shape(edges) &&
      one_hit(locate(stage, port_id(p0), edges)) &&
      one_hit(locate(stage, port_id(p1), edges)) &&
      one_hit(locate(stage, port_id(p2), edges)) &&
      ordered_hits(locate(stage, port_id(p0), edges), locate(stage, port_id(p1), edges)) &&
      ordered_hits(locate(stage, port_id(p1), edges), locate(stage, port_id(p2), edges))
    case Con{+p0, Con{+p1, Con{+p2, Con{+p3, Nil{}}}}}:
      edge_shape(edges) &&
      one_hit(locate(stage, port_id(p0), edges)) &&
      one_hit(locate(stage, port_id(p1), edges)) &&
      one_hit(locate(stage, port_id(p2), edges)) &&
      one_hit(locate(stage, port_id(p3), edges)) &&
      ordered_hits(locate(stage, port_id(p0), edges), locate(stage, port_id(p1), edges)) &&
      ordered_hits(locate(stage, port_id(p1), edges), locate(stage, port_id(p2), edges)) &&
      ordered_hits(locate(stage, port_id(p2), edges), locate(stage, port_id(p3), edges))
    case _: False{}

def stage_ok(stage: Stage, edges: +List<Edge>) -> Bool:
  match stage:
    case Stage{id, _, ports}: ports_ok(id, ports, edges)

def stages_ok(stages: +List<Stage>, +edges: +List<Edge>) -> Bool:
  match stages:
    case Nil{}: False{}
    case Con{+s0, Nil{}}:
      stage_ok(s0, edges)
    case Con{+s0, Con{+s1, Nil{}}}:
      U32.is_ne(stage_id(s0), stage_id(s1)) &&
      stage_ok(s0, edges) &&
      stage_ok(s1, edges)
    case Con{+s0, Con{+s1, Con{+s2, Nil{}}}}:
      U32.is_ne(stage_id(s0), stage_id(s1)) &&
      U32.is_ne(stage_id(s0), stage_id(s2)) &&
      U32.is_ne(stage_id(s1), stage_id(s2)) &&
      stage_ok(s0, edges) &&
      stage_ok(s1, edges) &&
      stage_ok(s2, edges)
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Nil{}}}}}:
      U32.is_ne(stage_id(s0), stage_id(s1)) &&
      U32.is_ne(stage_id(s0), stage_id(s2)) &&
      U32.is_ne(stage_id(s0), stage_id(s3)) &&
      U32.is_ne(stage_id(s1), stage_id(s2)) &&
      U32.is_ne(stage_id(s1), stage_id(s3)) &&
      U32.is_ne(stage_id(s2), stage_id(s3)) &&
      stage_ok(s0, edges) &&
      stage_ok(s1, edges) &&
      stage_ok(s2, edges) &&
      stage_ok(s3, edges)
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Con{+s4, Nil{}}}}}}:
      U32.is_ne(stage_id(s0), stage_id(s1)) &&
      U32.is_ne(stage_id(s0), stage_id(s2)) &&
      U32.is_ne(stage_id(s0), stage_id(s3)) &&
      U32.is_ne(stage_id(s0), stage_id(s4)) &&
      U32.is_ne(stage_id(s1), stage_id(s2)) &&
      U32.is_ne(stage_id(s1), stage_id(s3)) &&
      U32.is_ne(stage_id(s1), stage_id(s4)) &&
      U32.is_ne(stage_id(s2), stage_id(s3)) &&
      U32.is_ne(stage_id(s2), stage_id(s4)) &&
      U32.is_ne(stage_id(s3), stage_id(s4)) &&
      stage_ok(s0, edges) &&
      stage_ok(s1, edges) &&
      stage_ok(s2, edges) &&
      stage_ok(s3, edges) &&
      stage_ok(s4, edges)
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Con{+s4, Con{+s5, Nil{}}}}}}}:
      U32.is_ne(stage_id(s0), stage_id(s1)) &&
      U32.is_ne(stage_id(s0), stage_id(s2)) &&
      U32.is_ne(stage_id(s0), stage_id(s3)) &&
      U32.is_ne(stage_id(s0), stage_id(s4)) &&
      U32.is_ne(stage_id(s0), stage_id(s5)) &&
      U32.is_ne(stage_id(s1), stage_id(s2)) &&
      U32.is_ne(stage_id(s1), stage_id(s3)) &&
      U32.is_ne(stage_id(s1), stage_id(s4)) &&
      U32.is_ne(stage_id(s1), stage_id(s5)) &&
      U32.is_ne(stage_id(s2), stage_id(s3)) &&
      U32.is_ne(stage_id(s2), stage_id(s4)) &&
      U32.is_ne(stage_id(s2), stage_id(s5)) &&
      U32.is_ne(stage_id(s3), stage_id(s4)) &&
      U32.is_ne(stage_id(s3), stage_id(s5)) &&
      U32.is_ne(stage_id(s4), stage_id(s5)) &&
      stage_ok(s0, edges) &&
      stage_ok(s1, edges) &&
      stage_ok(s2, edges) &&
      stage_ok(s3, edges) &&
      stage_ok(s4, edges) &&
      stage_ok(s5, edges)
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Con{+s4, Con{+s5, Con{+s6, Nil{}}}}}}}}:
      U32.is_ne(stage_id(s0), stage_id(s1)) &&
      U32.is_ne(stage_id(s0), stage_id(s2)) &&
      U32.is_ne(stage_id(s0), stage_id(s3)) &&
      U32.is_ne(stage_id(s0), stage_id(s4)) &&
      U32.is_ne(stage_id(s0), stage_id(s5)) &&
      U32.is_ne(stage_id(s0), stage_id(s6)) &&
      U32.is_ne(stage_id(s1), stage_id(s2)) &&
      U32.is_ne(stage_id(s1), stage_id(s3)) &&
      U32.is_ne(stage_id(s1), stage_id(s4)) &&
      U32.is_ne(stage_id(s1), stage_id(s5)) &&
      U32.is_ne(stage_id(s1), stage_id(s6)) &&
      U32.is_ne(stage_id(s2), stage_id(s3)) &&
      U32.is_ne(stage_id(s2), stage_id(s4)) &&
      U32.is_ne(stage_id(s2), stage_id(s5)) &&
      U32.is_ne(stage_id(s2), stage_id(s6)) &&
      U32.is_ne(stage_id(s3), stage_id(s4)) &&
      U32.is_ne(stage_id(s3), stage_id(s5)) &&
      U32.is_ne(stage_id(s3), stage_id(s6)) &&
      U32.is_ne(stage_id(s4), stage_id(s5)) &&
      U32.is_ne(stage_id(s4), stage_id(s6)) &&
      U32.is_ne(stage_id(s5), stage_id(s6)) &&
      stage_ok(s0, edges) &&
      stage_ok(s1, edges) &&
      stage_ok(s2, edges) &&
      stage_ok(s3, edges) &&
      stage_ok(s4, edges) &&
      stage_ok(s5, edges) &&
      stage_ok(s6, edges)
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Con{+s4, Con{+s5, Con{+s6, Con{+s7, Nil{}}}}}}}}}:
      U32.is_ne(stage_id(s0), stage_id(s1)) &&
      U32.is_ne(stage_id(s0), stage_id(s2)) &&
      U32.is_ne(stage_id(s0), stage_id(s3)) &&
      U32.is_ne(stage_id(s0), stage_id(s4)) &&
      U32.is_ne(stage_id(s0), stage_id(s5)) &&
      U32.is_ne(stage_id(s0), stage_id(s6)) &&
      U32.is_ne(stage_id(s0), stage_id(s7)) &&
      U32.is_ne(stage_id(s1), stage_id(s2)) &&
      U32.is_ne(stage_id(s1), stage_id(s3)) &&
      U32.is_ne(stage_id(s1), stage_id(s4)) &&
      U32.is_ne(stage_id(s1), stage_id(s5)) &&
      U32.is_ne(stage_id(s1), stage_id(s6)) &&
      U32.is_ne(stage_id(s1), stage_id(s7)) &&
      U32.is_ne(stage_id(s2), stage_id(s3)) &&
      U32.is_ne(stage_id(s2), stage_id(s4)) &&
      U32.is_ne(stage_id(s2), stage_id(s5)) &&
      U32.is_ne(stage_id(s2), stage_id(s6)) &&
      U32.is_ne(stage_id(s2), stage_id(s7)) &&
      U32.is_ne(stage_id(s3), stage_id(s4)) &&
      U32.is_ne(stage_id(s3), stage_id(s5)) &&
      U32.is_ne(stage_id(s3), stage_id(s6)) &&
      U32.is_ne(stage_id(s3), stage_id(s7)) &&
      U32.is_ne(stage_id(s4), stage_id(s5)) &&
      U32.is_ne(stage_id(s4), stage_id(s6)) &&
      U32.is_ne(stage_id(s4), stage_id(s7)) &&
      U32.is_ne(stage_id(s5), stage_id(s6)) &&
      U32.is_ne(stage_id(s5), stage_id(s7)) &&
      U32.is_ne(stage_id(s6), stage_id(s7)) &&
      stage_ok(s0, edges) &&
      stage_ok(s1, edges) &&
      stage_ok(s2, edges) &&
      stage_ok(s3, edges) &&
      stage_ok(s4, edges) &&
      stage_ok(s5, edges) &&
      stage_ok(s6, edges) &&
      stage_ok(s7, edges)
    case _: False{}

def choose_stage(ok: Bool, stage: Stage, other: Maybe<&2, Stage>) -> Maybe<&2, Stage>:
  match ok:
    case True{}: Some{stage}
    case False{}: other

def lookup_stage(+id: U32, stages: +List<Stage>) -> Maybe<&2, Stage>:
  match stages:
    case Nil{}: None{}
    case Con{+s0, Nil{}}: choose_stage(U32.is_eq(id, stage_id(s0)), s0, None{})
    case Con{+s0, Con{+s1, Nil{}}}: choose_stage(U32.is_eq(id, stage_id(s0)), s0, choose_stage(U32.is_eq(id, stage_id(s1)), s1, None{}))
    case Con{+s0, Con{+s1, Con{+s2, Nil{}}}}: choose_stage(U32.is_eq(id, stage_id(s0)), s0, choose_stage(U32.is_eq(id, stage_id(s1)), s1, choose_stage(U32.is_eq(id, stage_id(s2)), s2, None{})))
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Nil{}}}}}: choose_stage(U32.is_eq(id, stage_id(s0)), s0, choose_stage(U32.is_eq(id, stage_id(s1)), s1, choose_stage(U32.is_eq(id, stage_id(s2)), s2, choose_stage(U32.is_eq(id, stage_id(s3)), s3, None{}))))
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Con{+s4, Nil{}}}}}}: choose_stage(U32.is_eq(id, stage_id(s0)), s0, choose_stage(U32.is_eq(id, stage_id(s1)), s1, choose_stage(U32.is_eq(id, stage_id(s2)), s2, choose_stage(U32.is_eq(id, stage_id(s3)), s3, choose_stage(U32.is_eq(id, stage_id(s4)), s4, None{})))))
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Con{+s4, Con{+s5, Nil{}}}}}}}: choose_stage(U32.is_eq(id, stage_id(s0)), s0, choose_stage(U32.is_eq(id, stage_id(s1)), s1, choose_stage(U32.is_eq(id, stage_id(s2)), s2, choose_stage(U32.is_eq(id, stage_id(s3)), s3, choose_stage(U32.is_eq(id, stage_id(s4)), s4, choose_stage(U32.is_eq(id, stage_id(s5)), s5, None{}))))))
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Con{+s4, Con{+s5, Con{+s6, Nil{}}}}}}}}: choose_stage(U32.is_eq(id, stage_id(s0)), s0, choose_stage(U32.is_eq(id, stage_id(s1)), s1, choose_stage(U32.is_eq(id, stage_id(s2)), s2, choose_stage(U32.is_eq(id, stage_id(s3)), s3, choose_stage(U32.is_eq(id, stage_id(s4)), s4, choose_stage(U32.is_eq(id, stage_id(s5)), s5, choose_stage(U32.is_eq(id, stage_id(s6)), s6, None{})))))))
    case Con{+s0, Con{+s1, Con{+s2, Con{+s3, Con{+s4, Con{+s5, Con{+s6, Con{+s7, Nil{}}}}}}}}}: choose_stage(U32.is_eq(id, stage_id(s0)), s0, choose_stage(U32.is_eq(id, stage_id(s1)), s1, choose_stage(U32.is_eq(id, stage_id(s2)), s2, choose_stage(U32.is_eq(id, stage_id(s3)), s3, choose_stage(U32.is_eq(id, stage_id(s4)), s4, choose_stage(U32.is_eq(id, stage_id(s5)), s5, choose_stage(U32.is_eq(id, stage_id(s6)), s6, choose_stage(U32.is_eq(id, stage_id(s7)), s7, None{}))))))))
    case _: None{}

def choose_port(ok: Bool, port: Port, other: Maybe<&2, Port>) -> Maybe<&2, Port>:
  match ok:
    case True{}: Some{port}
    case False{}: other

def lookup_port(+id: U32, ports: +List<Port>) -> Maybe<&2, Port>:
  match ports:
    case Nil{}: None{}
    case Con{+p0, Nil{}}: choose_port(U32.is_eq(id, port_id(p0)), p0, None{})
    case Con{+p0, Con{+p1, Nil{}}}: choose_port(U32.is_eq(id, port_id(p0)), p0, choose_port(U32.is_eq(id, port_id(p1)), p1, None{}))
    case Con{+p0, Con{+p1, Con{+p2, Nil{}}}}: choose_port(U32.is_eq(id, port_id(p0)), p0, choose_port(U32.is_eq(id, port_id(p1)), p1, choose_port(U32.is_eq(id, port_id(p2)), p2, None{})))
    case Con{+p0, Con{+p1, Con{+p2, Con{+p3, Nil{}}}}}: choose_port(U32.is_eq(id, port_id(p0)), p0, choose_port(U32.is_eq(id, port_id(p1)), p1, choose_port(U32.is_eq(id, port_id(p2)), p2, choose_port(U32.is_eq(id, port_id(p3)), p3, None{}))))
    case _: None{}

def schema_matches(expected: U32, port: Maybe<&2, Port>) -> Bool:
  match port:
    case Some{Port{_, actual}}: U32.is_eq(expected, actual)
    case None{}: False{}

def edge_stages(source: Maybe<&2, Stage>, target: Maybe<&2, Stage>, port: U32) -> Bool:
  match source target:
    case Some{Stage{_, output, _}} Some{Stage{_, _, inputs}}:
      schema_matches(output, lookup_port(port, inputs))
    case _ _: False{}

def edge_ok(edge: Edge, +stages: +List<Stage>) -> Bool:
  match edge:
    case Edge{from, to, port}:
      edge_stages(lookup_stage(from, stages), lookup_stage(to, stages), port)

def edges_ok(edges: +List<Edge>, +stages: +List<Stage>) -> Bool:
  match edges:
    case Nil{}:
      True{}
    case Con{+e0, Nil{}}:
      edge_ok(e0, stages)
    case Con{+e0, Con{+e1, Nil{}}}:
      edge_ok(e0, stages) &&
      edge_ok(e1, stages)
    case Con{+e0, Con{+e1, Con{+e2, Nil{}}}}:
      edge_ok(e0, stages) &&
      edge_ok(e1, stages) &&
      edge_ok(e2, stages)
    case Con{+e0, Con{+e1, Con{+e2, Con{+e3, Nil{}}}}}:
      edge_ok(e0, stages) &&
      edge_ok(e1, stages) &&
      edge_ok(e2, stages) &&
      edge_ok(e3, stages)
    case Con{+e0, Con{+e1, Con{+e2, Con{+e3, Con{+e4, Nil{}}}}}}:
      edge_ok(e0, stages) &&
      edge_ok(e1, stages) &&
      edge_ok(e2, stages) &&
      edge_ok(e3, stages) &&
      edge_ok(e4, stages)
    case Con{+e0, Con{+e1, Con{+e2, Con{+e3, Con{+e4, Con{+e5, Nil{}}}}}}}:
      edge_ok(e0, stages) &&
      edge_ok(e1, stages) &&
      edge_ok(e2, stages) &&
      edge_ok(e3, stages) &&
      edge_ok(e4, stages) &&
      edge_ok(e5, stages)
    case Con{+e0, Con{+e1, Con{+e2, Con{+e3, Con{+e4, Con{+e5, Con{+e6, Nil{}}}}}}}}:
      edge_ok(e0, stages) &&
      edge_ok(e1, stages) &&
      edge_ok(e2, stages) &&
      edge_ok(e3, stages) &&
      edge_ok(e4, stages) &&
      edge_ok(e5, stages) &&
      edge_ok(e6, stages)
    case Con{+e0, Con{+e1, Con{+e2, Con{+e3, Con{+e4, Con{+e5, Con{+e6, Con{+e7, Nil{}}}}}}}}}:
      edge_ok(e0, stages) &&
      edge_ok(e1, stages) &&
      edge_ok(e2, stages) &&
      edge_ok(e3, stages) &&
      edge_ok(e4, stages) &&
      edge_ok(e5, stages) &&
      edge_ok(e6, stages) &&
      edge_ok(e7, stages)
    case _: False{}

def bindings_match(graph: Graph) -> Bool:
  match graph:
    case Graph{+stages, +edges}:
      stages_ok(stages, edges) && edges_ok(edges, stages)

# Producer projection is separate from exact original-to-projection checking.
def plain_edge(edge: Edge) -> G.Edge:
  match edge:
    case Edge{from, to, _}: G.Edge{from, to}

def project_stages(stages: +List<Stage>) -> Maybe<&2, +List<U32>>:
  match stages:
    case Con{s0, Nil{}}: Some{[stage_id(s0)]}
    case Con{s0, Con{s1, Nil{}}}: Some{[stage_id(s0), stage_id(s1)]}
    case Con{s0, Con{s1, Con{s2, Nil{}}}}: Some{[stage_id(s0), stage_id(s1), stage_id(s2)]}
    case Con{s0, Con{s1, Con{s2, Con{s3, Nil{}}}}}: Some{[stage_id(s0), stage_id(s1), stage_id(s2), stage_id(s3)]}
    case Con{s0, Con{s1, Con{s2, Con{s3, Con{s4, Nil{}}}}}}: Some{[stage_id(s0), stage_id(s1), stage_id(s2), stage_id(s3), stage_id(s4)]}
    case Con{s0, Con{s1, Con{s2, Con{s3, Con{s4, Con{s5, Nil{}}}}}}}: Some{[stage_id(s0), stage_id(s1), stage_id(s2), stage_id(s3), stage_id(s4), stage_id(s5)]}
    case Con{s0, Con{s1, Con{s2, Con{s3, Con{s4, Con{s5, Con{s6, Nil{}}}}}}}}: Some{[stage_id(s0), stage_id(s1), stage_id(s2), stage_id(s3), stage_id(s4), stage_id(s5), stage_id(s6)]}
    case Con{s0, Con{s1, Con{s2, Con{s3, Con{s4, Con{s5, Con{s6, Con{s7, Nil{}}}}}}}}}: Some{[stage_id(s0), stage_id(s1), stage_id(s2), stage_id(s3), stage_id(s4), stage_id(s5), stage_id(s6), stage_id(s7)]}
    case _: None{}

def project_edges(edges: +List<Edge>) -> Maybe<&2, +List<G.Edge>>:
  match edges:
    case Nil{}: Some{[]}
    case Con{e0, Nil{}}: Some{[plain_edge(e0)]}
    case Con{e0, Con{e1, Nil{}}}: Some{[plain_edge(e0), plain_edge(e1)]}
    case Con{e0, Con{e1, Con{e2, Nil{}}}}: Some{[plain_edge(e0), plain_edge(e1), plain_edge(e2)]}
    case Con{e0, Con{e1, Con{e2, Con{e3, Nil{}}}}}: Some{[plain_edge(e0), plain_edge(e1), plain_edge(e2), plain_edge(e3)]}
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Nil{}}}}}}: Some{[plain_edge(e0), plain_edge(e1), plain_edge(e2), plain_edge(e3), plain_edge(e4)]}
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Nil{}}}}}}}: Some{[plain_edge(e0), plain_edge(e1), plain_edge(e2), plain_edge(e3), plain_edge(e4), plain_edge(e5)]}
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Con{e6, Nil{}}}}}}}}: Some{[plain_edge(e0), plain_edge(e1), plain_edge(e2), plain_edge(e3), plain_edge(e4), plain_edge(e5), plain_edge(e6)]}
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Con{e6, Con{e7, Nil{}}}}}}}}}: Some{[plain_edge(e0), plain_edge(e1), plain_edge(e2), plain_edge(e3), plain_edge(e4), plain_edge(e5), plain_edge(e6), plain_edge(e7)]}
    case _: None{}

def projected(stages: Maybe<&2, +List<U32>>, edges: Maybe<&2, +List<G.Edge>>) -> Maybe<&2, G.Graph>:
  match stages edges:
    case Some{ss} Some{es}: Some{G.Graph{ss, es}}
    case _ _: None{}

def project(graph: Graph) -> Maybe<&2, G.Graph>:
  match graph:
    case Graph{stages, edges}: projected(project_stages(stages), project_edges(edges))

def projected_edge_equal(a: Edge, b: G.Edge) -> Bool:
  match a b:
    case Edge{af, at, _} G.Edge{bf, bt}: U32.is_eq(af, bf) && U32.is_eq(at, bt)

def projected_stages_equal(stages: +List<Stage>, plain: +List<U32>) -> Bool:
  match stages plain:
    case Nil{} Nil{}: True{}
    case Con{s0, Nil{}} Con{p0, Nil{}}: U32.is_eq(stage_id(s0), p0)
    case Con{s0, Con{s1, Nil{}}} Con{p0, Con{p1, Nil{}}}: U32.is_eq(stage_id(s0), p0) &&
      U32.is_eq(stage_id(s1), p1)
    case Con{s0, Con{s1, Con{s2, Nil{}}}} Con{p0, Con{p1, Con{p2, Nil{}}}}: U32.is_eq(stage_id(s0), p0) &&
      U32.is_eq(stage_id(s1), p1) &&
      U32.is_eq(stage_id(s2), p2)
    case Con{s0, Con{s1, Con{s2, Con{s3, Nil{}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Nil{}}}}}: U32.is_eq(stage_id(s0), p0) &&
      U32.is_eq(stage_id(s1), p1) &&
      U32.is_eq(stage_id(s2), p2) &&
      U32.is_eq(stage_id(s3), p3)
    case Con{s0, Con{s1, Con{s2, Con{s3, Con{s4, Nil{}}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Con{p4, Nil{}}}}}}: U32.is_eq(stage_id(s0), p0) &&
      U32.is_eq(stage_id(s1), p1) &&
      U32.is_eq(stage_id(s2), p2) &&
      U32.is_eq(stage_id(s3), p3) &&
      U32.is_eq(stage_id(s4), p4)
    case Con{s0, Con{s1, Con{s2, Con{s3, Con{s4, Con{s5, Nil{}}}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Con{p4, Con{p5, Nil{}}}}}}}: U32.is_eq(stage_id(s0), p0) &&
      U32.is_eq(stage_id(s1), p1) &&
      U32.is_eq(stage_id(s2), p2) &&
      U32.is_eq(stage_id(s3), p3) &&
      U32.is_eq(stage_id(s4), p4) &&
      U32.is_eq(stage_id(s5), p5)
    case Con{s0, Con{s1, Con{s2, Con{s3, Con{s4, Con{s5, Con{s6, Nil{}}}}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Con{p4, Con{p5, Con{p6, Nil{}}}}}}}}: U32.is_eq(stage_id(s0), p0) &&
      U32.is_eq(stage_id(s1), p1) &&
      U32.is_eq(stage_id(s2), p2) &&
      U32.is_eq(stage_id(s3), p3) &&
      U32.is_eq(stage_id(s4), p4) &&
      U32.is_eq(stage_id(s5), p5) &&
      U32.is_eq(stage_id(s6), p6)
    case Con{s0, Con{s1, Con{s2, Con{s3, Con{s4, Con{s5, Con{s6, Con{s7, Nil{}}}}}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Con{p4, Con{p5, Con{p6, Con{p7, Nil{}}}}}}}}}: U32.is_eq(stage_id(s0), p0) &&
      U32.is_eq(stage_id(s1), p1) &&
      U32.is_eq(stage_id(s2), p2) &&
      U32.is_eq(stage_id(s3), p3) &&
      U32.is_eq(stage_id(s4), p4) &&
      U32.is_eq(stage_id(s5), p5) &&
      U32.is_eq(stage_id(s6), p6) &&
      U32.is_eq(stage_id(s7), p7)
    case _ _: False{}

def projected_edges_equal(edges: +List<Edge>, plain: +List<G.Edge>) -> Bool:
  match edges plain:
    case Nil{} Nil{}: True{}
    case Con{e0, Nil{}} Con{p0, Nil{}}: projected_edge_equal(e0, p0)
    case Con{e0, Con{e1, Nil{}}} Con{p0, Con{p1, Nil{}}}: projected_edge_equal(e0, p0) &&
      projected_edge_equal(e1, p1)
    case Con{e0, Con{e1, Con{e2, Nil{}}}} Con{p0, Con{p1, Con{p2, Nil{}}}}: projected_edge_equal(e0, p0) &&
      projected_edge_equal(e1, p1) &&
      projected_edge_equal(e2, p2)
    case Con{e0, Con{e1, Con{e2, Con{e3, Nil{}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Nil{}}}}}: projected_edge_equal(e0, p0) &&
      projected_edge_equal(e1, p1) &&
      projected_edge_equal(e2, p2) &&
      projected_edge_equal(e3, p3)
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Nil{}}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Con{p4, Nil{}}}}}}: projected_edge_equal(e0, p0) &&
      projected_edge_equal(e1, p1) &&
      projected_edge_equal(e2, p2) &&
      projected_edge_equal(e3, p3) &&
      projected_edge_equal(e4, p4)
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Nil{}}}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Con{p4, Con{p5, Nil{}}}}}}}: projected_edge_equal(e0, p0) &&
      projected_edge_equal(e1, p1) &&
      projected_edge_equal(e2, p2) &&
      projected_edge_equal(e3, p3) &&
      projected_edge_equal(e4, p4) &&
      projected_edge_equal(e5, p5)
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Con{e6, Nil{}}}}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Con{p4, Con{p5, Con{p6, Nil{}}}}}}}}: projected_edge_equal(e0, p0) &&
      projected_edge_equal(e1, p1) &&
      projected_edge_equal(e2, p2) &&
      projected_edge_equal(e3, p3) &&
      projected_edge_equal(e4, p4) &&
      projected_edge_equal(e5, p5) &&
      projected_edge_equal(e6, p6)
    case Con{e0, Con{e1, Con{e2, Con{e3, Con{e4, Con{e5, Con{e6, Con{e7, Nil{}}}}}}}}} Con{p0, Con{p1, Con{p2, Con{p3, Con{p4, Con{p5, Con{p6, Con{p7, Nil{}}}}}}}}}: projected_edge_equal(e0, p0) &&
      projected_edge_equal(e1, p1) &&
      projected_edge_equal(e2, p2) &&
      projected_edge_equal(e3, p3) &&
      projected_edge_equal(e4, p4) &&
      projected_edge_equal(e5, p5) &&
      projected_edge_equal(e6, p6) &&
      projected_edge_equal(e7, p7)
    case _ _: False{}

# This exact comparison independently scans every original supplied occurrence
# and compares its direction, order and multiplicity to the candidate graph.
def projection_matches(original: Graph, candidate: G.Graph) -> Bool:
  match original candidate:
    case Graph{stages, edges} G.Graph{plain_stages, plain_edges}:
      projected_stages_equal(stages, plain_stages) && projected_edges_equal(edges, plain_edges)

def observe_projection(+original: Graph, +candidate: G.Graph) -> Observation:
  Observation{bindings_match(original), projection_matches(original, candidate), Checked{G.check(candidate)}}

def observe_projected(+original: Graph, candidate: Maybe<&2, G.Graph>) -> Observation:
  match candidate:
    case None{}: Observation{bindings_match(original), False{}, NoProjection{}}
    case Some{graph}: observe_projection(original, graph)

def observe(+graph: Graph) -> Observation:
  observe_projected(graph, project(graph))

# Exact comparison is descriptive; it does not authenticate a pinned record.
def ports_equal(a: +List<Port>, b: +List<Port>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{a0, Nil{}} Con{b0, Nil{}}: port_equal(a0, b0)
    case Con{a0, Con{a1, Nil{}}} Con{b0, Con{b1, Nil{}}}: port_equal(a0, b0) &&
      port_equal(a1, b1)
    case Con{a0, Con{a1, Con{a2, Nil{}}}} Con{b0, Con{b1, Con{b2, Nil{}}}}: port_equal(a0, b0) &&
      port_equal(a1, b1) &&
      port_equal(a2, b2)
    case Con{a0, Con{a1, Con{a2, Con{a3, Nil{}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Nil{}}}}}: port_equal(a0, b0) &&
      port_equal(a1, b1) &&
      port_equal(a2, b2) &&
      port_equal(a3, b3)
    case _ _: False{}

def stage_equal(a: Stage, b: Stage) -> Bool:
  match a b:
    case Stage{ai, ao, ap} Stage{bi, bo, bp}:
      U32.is_eq(ai, bi) && U32.is_eq(ao, bo) && ports_equal(ap, bp)

def stages_equal(a: +List<Stage>, b: +List<Stage>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{a0, Nil{}} Con{b0, Nil{}}: stage_equal(a0, b0)
    case Con{a0, Con{a1, Nil{}}} Con{b0, Con{b1, Nil{}}}: stage_equal(a0, b0) &&
      stage_equal(a1, b1)
    case Con{a0, Con{a1, Con{a2, Nil{}}}} Con{b0, Con{b1, Con{b2, Nil{}}}}: stage_equal(a0, b0) &&
      stage_equal(a1, b1) &&
      stage_equal(a2, b2)
    case Con{a0, Con{a1, Con{a2, Con{a3, Nil{}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Nil{}}}}}: stage_equal(a0, b0) &&
      stage_equal(a1, b1) &&
      stage_equal(a2, b2) &&
      stage_equal(a3, b3)
    case Con{a0, Con{a1, Con{a2, Con{a3, Con{a4, Nil{}}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Con{b4, Nil{}}}}}}: stage_equal(a0, b0) &&
      stage_equal(a1, b1) &&
      stage_equal(a2, b2) &&
      stage_equal(a3, b3) &&
      stage_equal(a4, b4)
    case Con{a0, Con{a1, Con{a2, Con{a3, Con{a4, Con{a5, Nil{}}}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Con{b4, Con{b5, Nil{}}}}}}}: stage_equal(a0, b0) &&
      stage_equal(a1, b1) &&
      stage_equal(a2, b2) &&
      stage_equal(a3, b3) &&
      stage_equal(a4, b4) &&
      stage_equal(a5, b5)
    case Con{a0, Con{a1, Con{a2, Con{a3, Con{a4, Con{a5, Con{a6, Nil{}}}}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Con{b4, Con{b5, Con{b6, Nil{}}}}}}}}: stage_equal(a0, b0) &&
      stage_equal(a1, b1) &&
      stage_equal(a2, b2) &&
      stage_equal(a3, b3) &&
      stage_equal(a4, b4) &&
      stage_equal(a5, b5) &&
      stage_equal(a6, b6)
    case Con{a0, Con{a1, Con{a2, Con{a3, Con{a4, Con{a5, Con{a6, Con{a7, Nil{}}}}}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Con{b4, Con{b5, Con{b6, Con{b7, Nil{}}}}}}}}}: stage_equal(a0, b0) &&
      stage_equal(a1, b1) &&
      stage_equal(a2, b2) &&
      stage_equal(a3, b3) &&
      stage_equal(a4, b4) &&
      stage_equal(a5, b5) &&
      stage_equal(a6, b6) &&
      stage_equal(a7, b7)
    case _ _: False{}

def edges_equal(a: +List<Edge>, b: +List<Edge>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{a0, Nil{}} Con{b0, Nil{}}: edge_equal(a0, b0)
    case Con{a0, Con{a1, Nil{}}} Con{b0, Con{b1, Nil{}}}: edge_equal(a0, b0) &&
      edge_equal(a1, b1)
    case Con{a0, Con{a1, Con{a2, Nil{}}}} Con{b0, Con{b1, Con{b2, Nil{}}}}: edge_equal(a0, b0) &&
      edge_equal(a1, b1) &&
      edge_equal(a2, b2)
    case Con{a0, Con{a1, Con{a2, Con{a3, Nil{}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Nil{}}}}}: edge_equal(a0, b0) &&
      edge_equal(a1, b1) &&
      edge_equal(a2, b2) &&
      edge_equal(a3, b3)
    case Con{a0, Con{a1, Con{a2, Con{a3, Con{a4, Nil{}}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Con{b4, Nil{}}}}}}: edge_equal(a0, b0) &&
      edge_equal(a1, b1) &&
      edge_equal(a2, b2) &&
      edge_equal(a3, b3) &&
      edge_equal(a4, b4)
    case Con{a0, Con{a1, Con{a2, Con{a3, Con{a4, Con{a5, Nil{}}}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Con{b4, Con{b5, Nil{}}}}}}}: edge_equal(a0, b0) &&
      edge_equal(a1, b1) &&
      edge_equal(a2, b2) &&
      edge_equal(a3, b3) &&
      edge_equal(a4, b4) &&
      edge_equal(a5, b5)
    case Con{a0, Con{a1, Con{a2, Con{a3, Con{a4, Con{a5, Con{a6, Nil{}}}}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Con{b4, Con{b5, Con{b6, Nil{}}}}}}}}: edge_equal(a0, b0) &&
      edge_equal(a1, b1) &&
      edge_equal(a2, b2) &&
      edge_equal(a3, b3) &&
      edge_equal(a4, b4) &&
      edge_equal(a5, b5) &&
      edge_equal(a6, b6)
    case Con{a0, Con{a1, Con{a2, Con{a3, Con{a4, Con{a5, Con{a6, Con{a7, Nil{}}}}}}}}} Con{b0, Con{b1, Con{b2, Con{b3, Con{b4, Con{b5, Con{b6, Con{b7, Nil{}}}}}}}}}: edge_equal(a0, b0) &&
      edge_equal(a1, b1) &&
      edge_equal(a2, b2) &&
      edge_equal(a3, b3) &&
      edge_equal(a4, b4) &&
      edge_equal(a5, b5) &&
      edge_equal(a6, b6) &&
      edge_equal(a7, b7)
    case _ _: False{}

def same_graph(a: Graph, b: Graph) -> Bool:
  match a b:
    case Graph{as, ae} Graph{bs, be}: stages_equal(as, bs) && edges_equal(ae, be)
