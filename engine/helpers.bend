# Helpers: the rules that move Twist and Support bones.
#
# Clips animate Deform bones only. After the clip (and the blend), every
# helper bone takes part of a Deform bone's motion, by its rule:
#
#   Rule{bone, driver, part, amount}
#     part Roll   the driver's turn around its own length (its local Y),
#                 as forearm and thigh twist bones need
#     part Full   the driver's whole turn, as joint supports need (an
#                 elbow or knee bone that turns half as much as the joint)
#     part Hold   nothing: the bone stays at rest relative to its parent
#   amount        how much of it: 0.5 is half, -0.5 is half the other way
#
# The driver's motion is measured from its rest pose, carried from the
# driver's frame into the helper's (both at rest), scaled by `amount`, and
# applied on top of the helper's rest. This is stage 4 of Gregory's
# pipeline ("post-processing"), what Unity's Twist Correction constraint
# does, and what the reference rig's original game computed at runtime for
# its " spo" bones (the file carries no rules, so these are ours).
#
# The law that comes with it: every Twist and Support bone has exactly one
# rule, so no helper is ever forgotten (helpers_cover in this file).
#
# Limits now:
# - The amounts are set by eye, not measured on the mesh.
# - A Full rule scales the joint's turn as one rotation; joints that bend
#   and twist at once (a shoulder) may need a rule per axis.
# - Rules run in list order, last in the pose (after the clip, the blend,
#   the grip and the IK), and read Deform bones only, so a helper cannot
#   drive another helper.

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr
import ./skeleton.bend as Sk
import ./pose.bend as P

type Part is Data:
  Roll{}
  Full{}
  Hold{}

type Rule is Data:
  Rule{bone: U32, driver: U32, part: Part, amount: F32}

# A rule made ready for a skeleton: the rest rotations it needs, computed
# once (the helper's local rest, the driver's local rest, and `frame`: from
# the driver's rest frame to the helper's parent's rest frame).
type Prepared is Data:
  Prepared{bone: U32, driver: U32, part: Part, amount: F32, rest: Q.Q, driver_rest: Q.Q, frame: Q.Q}

def rule_bone(r: Rule) -> U32:
  Rule{b, _, _, _} = r
  b

def local_rest(+s: Sk.Skeleton, +i: U32) -> Q.Q:
  Tr.rotation(Sk.rest(Sk.at(s, i)))

def prepare_one(+s: Sk.Skeleton, r: Rule) -> Prepared:
  Rule{+b, +d, p, +a} = r
  +gp = P.rest_rotation(s, Sk.parent_of(s, b))
  +gd = P.rest_rotation(s, d)
  Prepared{b, d, p, a, local_rest(s, b), local_rest(s, d), Q.mul(Q.conj(gp), gd)}

def prepare(+s: Sk.Skeleton, rs: List<&2, Rule>) -> List<&2, Prepared>:
  match rs:
    case Nil{}:
      Nil{}
    case h <> t:
      prepare_one(s, h) <> prepare(s, t)

# Turning
# =======

# The turn around the local Y axis inside a rotation (swing-twist).
def twist_y(q: Q.Q) -> Q.Q:
  Q.Q{_, y, _, w} = q
  Q.normalize(Q.Q{0.0, y, 0.0, w})

def pick_q(c: Bool, a: Q.Q, b: Q.Q) -> Q.Q:
  match c:
    case True{}:
      a
    case False{}:
      b

# A rotation scaled: the same axis, `k` times the angle.
def times_far(+q: Q.Q, +k: F32) -> Q.Q:
  +c = Q.near(Q.identity(), q)
  +angle = (2.0 * F32.acos(F32.clamp(Q.w_part(c), (0.0 - 1.0 : F32), 1.0)) : F32)
  Q.axis_angle(Q.axis_part(c), (angle * k : F32))

def times(+q: Q.Q, +k: F32) -> Q.Q:
  pick_q(F32.is_gt(F32.abs(Q.w_part(q)), 0.99999), Q.identity(), times_far(q, k))

def chosen(p: Part, +delta: Q.Q) -> Q.Q:
  match p:
    case Roll{}:
      twist_y(delta)
    case Full{}:
      delta
    case Hold{}:
      Q.identity()

# The helper's local rotation, given its driver's local rotation now.
def turn(r: Prepared, +driver_now: Q.Q) -> Q.Q:
  Prepared{_, _, p, +a, +rest, +drest, +frame} = r
  +part = times(chosen(p, Q.mul(Q.conj(drest), driver_now)), a)
  Q.normalize(Q.mul(Q.mul(frame, Q.mul(part, Q.conj(frame))), rest))

def ready_bone(r: Prepared) -> U32:
  Prepared{b, _, _, _, _, _, _} = r
  b

def ready_driver(r: Prepared) -> U32:
  Prepared{_, d, _, _, _, _, _} = r
  d

def apply_one(+p: P.Pose, +r: Prepared) -> P.Pose:
  +b = ready_bone(r)
  +now = Tr.rotation(P.local_at(p, ready_driver(r)))
  P.set(p, b, Tr.with_rotation(P.local_at(p, b), turn(r, now)))

def apply_go(rs: List<&2, Prepared>, +p: P.Pose) -> P.Pose:
  match rs:
    case Nil{}:
      p
    case h <> t:
      apply_go(t, apply_one(p, h))

# The pose after every helper took its part.
def apply(rs: List<&2, Prepared>, +p: P.Pose) -> P.Pose:
  apply_go(rs, p)

# The law's check
# ===============

def pick_u32(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def rules_for(rs: List<&2, Rule>, +i: U32) -> U32:
  match rs:
    case Nil{}:
      0
    case +h <> t:
      (pick_u32(U32.is_eq(rule_bone(h), i), 1, 0) + rules_for(t, i) : U32)

def is_helper(r: Sk.Role) -> Bool:
  match r:
    case Sk.Twist{}:
      True{}
    case Sk.Support{}:
      True{}
    case _:
      False{}

# Bone i has one rule when it is a helper, none otherwise.
def covered_one(+b: Sk.Bone, +rs: List<&2, Rule>, +i: U32) -> Bool:
  U32.is_eq(rules_for(rs, i), pick_u32(is_helper(Sk.role(b)), 1, 0))

def covers_go(bs: List<&2, Sk.Bone>, +rs: List<&2, Rule>, +i: U32) -> Bool:
  match bs:
    case Nil{}:
      True{}
    case +h <> t:
      (covered_one(h, rs, i) && covers_go(t, rs, (i + 1 : U32)))

# Every Twist and Support bone has exactly one rule, and no other bone has any.
def helpers_cover(+s: Sk.Skeleton, +rs: List<&2, Rule>) -> Bool:
  covers_go(Sk.bones(s), rs, 0)
