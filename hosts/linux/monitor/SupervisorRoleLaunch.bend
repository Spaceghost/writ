import Base
import ./LocalChannel.bend as C

# Which channel role indices the native supervisor driver may launch a process
# for (contrib/native-hosts/linux/supervisor_owner.c, `writ_supervisor_launch_role`).
#
# Authority direction. The role-index-to-principal map is the provisioned one
# (`SupervisorProvision`); this module only says whether the driver may bind
# one new process lifetime to an index of that map. An index is admitted once:
# exactly when the provisioned map attributes it to a principal (so a zero,
# duplicate or unprovisioned index, or an invalid map, is refused) and no
# process has been admitted for it before. The driver launches only after
# admission and registers the launched process's pidfs identity under that
# index; the receiver then reports that process's datagrams as the role. An
# admitted index is never released, so a role whose process exits cannot be
# rebound in this interpreter's lifetime.
#
# This binds a role index to a process the supervisor itself started; it does
# not authenticate the person or program behind that process, and it binds no
# worker session to a principal.

type Bound is Data:
  NoBound{}
  Bound{index: Nat, rest: Bound}

type RoleRefusal is Data:
  RoleUnprovisioned{}
  RoleAlreadyBound{}

type Admission is Data:
  RoleAdmitted{bound: Bound}
  RoleRefused{reason: RoleRefusal}

def is_bound(bound: Bound, +index: Nat) -> Bool:
  match bound:
    case NoBound{}: False{}
    case Bound{i, rest}: Nat.is_eq(i, index) || is_bound(rest, index)

def admit_fresh(again: Bool, +bound: Bound, +index: Nat) -> Admission:
  match again:
    case True{}: RoleRefused{RoleAlreadyBound{}}
    case False{}: RoleAdmitted{Bound{index, bound}}

def admit_attributed(attribution: C.Attribution, +bound: Bound, +index: Nat) -> Admission:
  match attribution:
    case C.Attributed{_}: admit_fresh(is_bound(bound, index), bound, index)
    case C.Denied{_}: RoleRefused{RoleUnprovisioned{}}

# Public entry point: admit one process launch for role `index` under the
# provisioned `roles`, given the indices already bound.
def admit(+roles: C.RoleMap, +bound: Bound, +index: Nat) -> Admission:
  admit_attributed(C.attribute(roles, C.FromRole{index}), bound, index)
