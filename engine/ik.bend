# IK: inverse kinematics for a chain of two bones (thigh and shin, upper
# arm and forearm).
#
# Forward kinematics (engine/pose.bend) goes from rotations to positions.
# IK goes back: "put the ankle there", and it finds the rotations. With two
# bones there is an exact answer, the law of cosines, with no iterations:
#
#   1. the knee opens or closes until hip-to-ankle is as long as
#      hip-to-target (the triangle hip, knee, ankle with sides a, b, d);
#   2. the thigh turns so hip-to-ankle points at the target.
#
# The knee bends in the plane it already bends in, so a straight leg keeps
# bending forward (its own X axis). This is Unreal's Two Bone IK and the
# first solver of the study's step 11.
#
# ground() uses it to keep both feet on the floor (y = 0): a foot that
# would sink is lifted to its rest height above the floor.
#
# Limits now:
# - Flat floor only (y = 0): no terrain to read yet.
# - A target out of reach stretches the leg straight toward it, short by
#   0.1 mm; the bones never stretch.
# - No pole target: the knee's direction comes from the pose.
# - The foot keeps its rotation from the clip; it does not tilt to the floor.

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr
import ./skeleton.bend as Sk
import ./pose.bend as P

def len(+v: V.V3) -> F32:
  F32.sqrt(V.dot(v, v))

def pick_q(c: Bool, a: Q.Q, b: Q.Q) -> Q.Q:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_v(c: Bool, a: V.V3, b: V.V3) -> V.V3:
  match c:
    case True{}:
      a
    case False{}:
      b

# The shortest turn taking direction u to direction v.
def from_to(+u: V.V3, +v: V.V3) -> Q.Q:
  +c = V.cross(u, v)
  Q.normalize(Q.Q{V.x(c), V.y(c), V.z(c), (len(u) * len(v) + V.dot(u, v) : F32)})

# The angle at the knee of a triangle with sides a, b and d (d opposite it).
def corner(+a: F32, +b: F32, +d: F32) -> F32:
  F32.acos(F32.clamp(((a * a + b * b - d * d) / F32.max((2.0 * a * b : F32), 0.000001) : F32), (0.0 - 1.0 : F32), 1.0))

# Bone i's rotation in a pose, measured from the character's origin.
def model_rotation_go(fuel: Nat, +s: Sk.Skeleton, +p: P.Pose, +i: U32) -> Q.Q:
  match fuel:
    case 0n:
      Q.identity()
    case 1n+f:
      +own = Tr.rotation(P.local_at(p, i))
      pick_q(U32.is_eq(i, 0), own, Q.mul(model_rotation_go(f, s, p, Sk.parent_of(s, i)), own))

def model_rotation(+s: Sk.Skeleton, +p: P.Pose, +i: U32) -> Q.Q:
  model_rotation_go(64n, s, p, i)

def head_of(+ms: List<&2, V.M4>, +i: U32) -> V.V3:
  P.head(P.m4_at(ms, i))

# Two-bone IK: bones `upper` and `lower` (its child), so that the head of
# `end` (the lower bone's child) reaches `target` (character's space).
def two_bone(+s: Sk.Skeleton, +p: P.Pose, +upper: U32, +lower: U32, +end: U32, +target: V.V3) -> P.Pose:
  +ms = P.model(s, p)
  +hip = head_of(ms, upper)
  +knee = head_of(ms, lower)
  +ankle = head_of(ms, end)
  +a = len(V.sub(knee, hip))
  +b = len(V.sub(ankle, knee))
  +d = F32.min(len(V.sub(target, hip)), (a + b - 0.0001 : F32))
  +bend_now = corner(a, b, len(V.sub(ankle, hip)))
  +bend_want = corner(a, b, d)
  +across = V.cross(V.sub(knee, hip), V.sub(ankle, knee))
  +axis = pick_v(F32.is_lt(len(across), 0.000001), Q.rotate(model_rotation(s, p, upper), V.V3{1.0, 0.0, 0.0}), V.norm(across))
  +gu = model_rotation(s, p, upper)
  +gl = model_rotation(s, p, lower)
  +gparent = model_rotation(s, p, Sk.parent_of(s, upper))
  +ds = Q.axis_angle(axis, (bend_want - bend_now : F32))
  +ankle2 = V.add(knee, Q.rotate(ds, V.sub(ankle, knee)))
  +dt = from_to(V.sub(ankle2, hip), V.sub(target, hip))
  +up_local = Q.normalize(Q.mul(Q.conj(gparent), Q.mul(dt, gu)))
  +low_local = Q.normalize(Q.mul(Q.conj(gu), Q.mul(ds, gl)))
  +p1 = P.set(p, upper, Tr.with_rotation(P.local_at(p, upper), up_local))
  P.set(p1, lower, Tr.with_rotation(P.local_at(p1, lower), low_local))

# Floor
# =====

# Keeps one foot above the floor: if its ankle is lower than at rest, the
# leg reaches for the same spot at the rest height.
def lift(low: Bool, +s: Sk.Skeleton, +p: P.Pose, +upper: U32, +lower: U32, +foot: U32, +ankle: V.V3, +rest_height: F32) -> P.Pose:
  match low:
    case True{}:
      two_bone(s, p, upper, lower, foot, V.V3{V.x(ankle), rest_height, V.z(ankle)})
    case False{}:
      p

def plant(+s: Sk.Skeleton, +p: P.Pose, +upper: U32, +lower: U32, +foot: U32, +rest_height: F32) -> P.Pose:
  +ankle = head_of(P.model(s, p), foot)
  lift(F32.is_lt(V.y(ankle), rest_height), s, p, upper, lower, foot, ankle, rest_height)

def found(+s: Sk.Skeleton, +i: U32) -> Bool:
  U32.is_lt(i, Sk.count(s))

def plant_if(legs: Bool, +s: Sk.Skeleton, +p: P.Pose, +up: U32, +low: U32, +foot: U32, +h: F32) -> P.Pose:
  match legs:
    case True{}:
      plant(s, p, up, low, foot, h)
    case False{}:
      p

def plant_side(+s: Sk.Skeleton, +rest: List<&2, V.M4>, +p: P.Pose, +side: String) -> P.Pose:
  +up = Sk.find_slot(s, String.concat(["upper_leg.", side]))
  +low = Sk.find_slot(s, String.concat(["lower_leg.", side]))
  +foot = Sk.find_slot(s, String.concat(["foot.", side]))
  +h = V.y(head_of(rest, foot))
  plant_if((found(s, up) && found(s, low) && found(s, foot)), s, p, up, low, foot, h)

# Both feet on the floor (a skeleton without legs is left as it is).
# `rest` is the skeleton's rest model pose (P.model(s, P.rest(s))), computed
# once per skeleton: each foot's rest height is read from it.
def ground(+s: Sk.Skeleton, +rest: List<&2, V.M4>, +p: P.Pose) -> P.Pose:
  plant_side(s, rest, plant_side(s, rest, p, "L"), "R")
