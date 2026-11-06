import Base
import ./DurableIntent.bend as E
import ./Backplane.bend as B
import ./BackplaneTests.bend as BT
import ./Transfer.bend as T
import ./TransferTests.bend as TT
import ./Dlm.bend as D
import ./Test.bend as Test

# All values here are synthetic; an equal record does not authenticate a
# durable store, a sink, artifact bytes, or any caller.
def origin() -> T.OriginRule:
  T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 2}, T.Bits64{4, 8}, 3,
    T.CCons{TT.code(), T.CCons{TT.other_code(), T.CEnd{}}}, T.Charge{47n, 5}}

def output() -> T.OutputPolicy:
  T.OutputPolicy{2, T.Bits64{1, 2}, T.Bits64{4, 8}, 3, T.RCons{origin(), T.REnd{}}}

def label() -> D.Label:
  D.Label{D.Join{D.Rule{D.Named{11}, D.Named{13}}, D.Rule{D.Top{}, D.Bottom{}}},
    D.Meet{D.Rule{D.Named{17}, D.Named{19}}, D.Rule{D.Bottom{}, D.Top{}}}}

def intent() -> B.WriteIntent:
  B.WriteIntent{TT.plan(), output(), label(), B.Storage{}, BT.artifact()}

def with_output(intent: B.WriteIntent, output: T.OutputPolicy) -> B.WriteIntent:
  match intent:
    case B.WriteIntent{p, _, l, b, a}:
      B.WriteIntent{p, output, l, b, a}

def with_plan(intent: B.WriteIntent, plan: T.Plan) -> B.WriteIntent:
  match intent:
    case B.WriteIntent{_, o, l, b, a}:
      B.WriteIntent{plan, o, l, b, a}

def with_label(intent: B.WriteIntent, label: D.Label) -> B.WriteIntent:
  match intent:
    case B.WriteIntent{p, o, _, b, a}:
      B.WriteIntent{p, o, label, b, a}

def with_backend(intent: B.WriteIntent, backend: B.Backend) -> B.WriteIntent:
  match intent:
    case B.WriteIntent{p, o, l, _, a}:
      B.WriteIntent{p, o, l, backend, a}

def with_artifact(intent: B.WriteIntent, artifact: B.ArtifactId) -> B.WriteIntent:
  match intent:
    case B.WriteIntent{p, o, l, b, _}:
      B.WriteIntent{p, o, l, b, artifact}

def with_origins(origins: T.Origins) -> T.OutputPolicy:
  T.OutputPolicy{2, T.Bits64{1, 2}, T.Bits64{4, 8}, 3, origins}

def changed_origin(origin: T.OriginRule) -> T.OutputPolicy:
  with_origins(T.RCons{origin, T.REnd{}})

def different(output: T.OutputPolicy) -> Bool:
  Bool.not(E.intent_equal(intent(), with_output(intent(), output)))

def main() -> IO(Unit):
  do IO<Unit>:
    Test.check(E.intent_equal(intent(), intent()), "durable intent compares every retained field on an identical record")
    Test.check(Bool.not(E.intent_equal(intent(), with_plan(intent(), TT.plan_destination(TT.plan(), T.ObjectVersion{71n, 73n})))),
      "durable intent detects a changed destination")
    Test.check(Bool.not(E.intent_equal(intent(), with_backend(intent(), B.Network{}))), "durable intent detects a backend substitution")
    Test.check(Bool.not(E.intent_equal(intent(), with_artifact(intent(), BT.other_artifact()))), "durable intent detects an artifact substitution")
    Test.check(Bool.not(E.intent_equal(intent(), with_label(intent(), D.Label{D.Rule{D.Top{}, D.Bottom{}},
      D.Rule{D.Bottom{}, D.Top{}}}))), "durable intent detects a changed label tree")
    Test.check(different(T.OutputPolicy{4, T.Bits64{1, 2}, T.Bits64{4, 8}, 3, T.RCons{origin(), T.REnd{}}}),
      "durable intent detects a changed output schema")
    Test.check(different(T.OutputPolicy{2, T.Bits64{1, 3}, T.Bits64{4, 8}, 3, T.RCons{origin(), T.REnd{}}}),
      "durable intent detects a changed secrecy high word")
    Test.check(different(T.OutputPolicy{2, T.Bits64{1, 2}, T.Bits64{4, 9}, 3, T.RCons{origin(), T.REnd{}}}),
      "durable intent detects a changed integrity high word")
    Test.check(different(T.OutputPolicy{2, T.Bits64{1, 2}, T.Bits64{4, 8}, 7, T.RCons{origin(), T.REnd{}}}),
      "durable intent detects changed allowed operations")
    Test.check(different(with_origins(T.REnd{})), "durable intent detects a removed origin")
    Test.check(different(with_origins(T.RCons{origin(), T.RCons{origin(), T.REnd{}}})),
      "durable intent detects a repeated origin")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 44n}, T.Bits64{1, 2}, T.Bits64{4, 8}, 3,
      T.CCons{TT.code(), T.CCons{TT.other_code(), T.CEnd{}}}, T.Charge{47n, 5}})),
      "durable intent detects a changed origin version")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 2}, T.Bits64{4, 8}, 3,
      T.CCons{TT.other_code(), T.CCons{TT.code(), T.CEnd{}}}, T.Charge{47n, 5}})),
      "durable intent detects reordered approved codes")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 2}, T.Bits64{4, 8}, 3,
      T.CCons{TT.code(), T.CCons{TT.other_code(), T.CEnd{}}}, T.Charge{48n, 5}})),
      "durable intent detects changed origin payment terms")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 3}, T.Bits64{4, 8}, 3,
      T.CCons{TT.code(), T.CCons{TT.other_code(), T.CEnd{}}}, T.Charge{47n, 5}})),
      "durable intent detects changed origin secrecy")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 2}, T.Bits64{4, 9}, 3,
      T.CCons{TT.code(), T.CCons{TT.other_code(), T.CEnd{}}}, T.Charge{47n, 5}})),
      "durable intent detects changed origin integrity")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 2}, T.Bits64{4, 8}, 7,
      T.CCons{TT.code(), T.CCons{TT.other_code(), T.CEnd{}}}, T.Charge{47n, 5}})),
      "durable intent detects changed origin operation rights")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 2}, T.Bits64{4, 8}, 3,
      T.CCons{TT.code(), T.CEnd{}}, T.Charge{47n, 5}})),
      "durable intent detects a removed approved code")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 2}, T.Bits64{4, 8}, 3,
      T.CCons{TT.code(), T.CCons{TT.other_code(), T.CEnd{}}}, T.Free{}})),
      "durable intent detects removal of an origin charge")
    Test.check(different(changed_origin(T.OriginRule{T.ObjectVersion{41n, 43n}, T.Bits64{1, 2}, T.Bits64{4, 8}, 3,
      T.CCons{TT.code(), T.CCons{TT.other_code(), T.CEnd{}}}, T.Charge{47n, 4}})),
      "durable intent detects changed charge operation scope")
    Test.check(Bool.not(E.intent_equal(intent(), with_label(intent(), D.Label{
      D.Join{D.Rule{D.Named{11}, D.Named{14}}, D.Rule{D.Top{}, D.Bottom{}}},
      D.Meet{D.Rule{D.Named{17}, D.Named{19}}, D.Rule{D.Bottom{}, D.Top{}}}}))),
      "durable intent detects a changed confidentiality delegate")
    Test.check(Bool.not(E.intent_equal(intent(), with_label(intent(), D.Label{
      D.Join{D.Rule{D.Named{12}, D.Named{13}}, D.Rule{D.Top{}, D.Bottom{}}},
      D.Meet{D.Rule{D.Named{17}, D.Named{19}}, D.Rule{D.Bottom{}, D.Top{}}}}))),
      "durable intent detects a changed policy owner")
    Test.check(Bool.not(E.intent_equal(intent(), with_label(intent(), D.Label{
      D.Join{D.Rule{D.Named{11}, D.Named{13}}, D.Rule{D.Top{}, D.Bottom{}}},
      D.Meet{D.Rule{D.Named{17}, D.Named{20}}, D.Rule{D.Bottom{}, D.Top{}}}}))),
      "durable intent detects a changed integrity delegate")
    Test.check(Bool.not(E.intent_equal(intent(), with_label(intent(), D.Label{
      D.Join{D.Rule{D.Named{11}, D.Named{13}}, D.Rule{D.Top{}, D.Named{29}}},
      D.Meet{D.Rule{D.Named{17}, D.Named{19}}, D.Rule{D.Bottom{}, D.Top{}}}}))),
      "durable intent detects a changed confidentiality right branch")
    Test.check(Bool.not(E.intent_equal(intent(), with_label(intent(), D.Label{
      D.Join{D.Rule{D.Named{11}, D.Named{13}}, D.Rule{D.Top{}, D.Bottom{}}},
      D.Meet{D.Rule{D.Named{17}, D.Named{19}}, D.Rule{D.Bottom{}, D.Named{31}}}}))),
      "durable intent detects a changed integrity right branch")
