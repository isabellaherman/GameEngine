# Gait: a walk and an idle, written as math and baked into clips.
#
# Until the engine reads clips from glTF files, its first clips are made
# by code: for each humanoid slot (thigh, shin, arm…), a turn in the
# character's own axes as a function of the step's phase, sampled into
# keys. The result is an ordinary Clip (engine/clip.bend), played,
# blended and skinned like any captured clip would be.
#
# Because the turns are given by slot and in the character's axes (X to
# its left, Y up, Z ahead; engine/pose.bend's turned()), the same code
# animates any skeleton that follows the rig standard: the test arm, the
# reference rig, a character of your own.
#
# One cycle is two steps, left then right. At phase 0 both legs pass under
# the hips; at a quarter, the left leg is forward.
#
# Limits now:
# - The shapes are sines, tuned by eye: a stylized walk, not captured
#   motion. Feet can slide a little: engine/ik.bend only lifts a foot that
#   would sink, it does not pin a foot that touches the floor.
# - Only the body's big bones are in these clips. Fingers come from
#   engine/hand.bend, twist and support bones from engine/helpers.bend.
# - The arms come down from the T-pose by a fixed turn (72°), which suits
#   a rig whose rest pose is a T.

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr
import ./skeleton.bend as Sk
import ./pose.bend as P
import ./clip.bend as C

def pi2() -> F32: 6.2831855

# Turns around the character's own axes.
def about_x(+a: F32) -> Q.Q:
  Q.axis_angle(V.V3{1.0, 0.0, 0.0}, a)

def about_y(+a: F32) -> Q.Q:
  Q.axis_angle(V.V3{0.0, 1.0, 0.0}, a)

def about_z(+a: F32) -> Q.Q:
  Q.axis_angle(V.V3{0.0, 0.0, 1.0}, a)

def pick_q(c: Bool, a: Q.Q, b: Q.Q) -> Q.Q:
  match c:
    case True{}:
      a
    case False{}:
      b

# Walk
# ====

def stride() -> F32: 0.35    # how far a thigh swings, in radians
def arm_down() -> F32: 1.25  # from the T-pose to the sides, in radians

def thigh(+f: F32) -> F32:
  (0.0 - stride() * F32.sin(f) : F32)

# The knee bends while the leg swings forward.
def knee(+f: F32) -> F32:
  (0.08 + 0.75 * F32.max(F32.cos(f), 0.0) : F32)

# The foot stays close to flat: it undoes most of the leg's turn.
def ankle(+f: F32) -> F32:
  (0.0 - 0.7 * (thigh(f) + knee(f)) : F32)

# The turn of each slot at phase f (radians, 0 to 2π). The right side is
# the left side half a cycle later (f + π).
def walk_turn(+slot: String, +f: F32) -> Q.Q:
  +r = (f + 3.1415927 : F32)
  +swing = (0.32 * F32.sin(f) : F32)
  pick_q(String.eq(slot, "upper_leg.L"), about_x(thigh(f)),
  pick_q(String.eq(slot, "upper_leg.R"), about_x(thigh(r)),
  pick_q(String.eq(slot, "lower_leg.L"), about_x(knee(f)),
  pick_q(String.eq(slot, "lower_leg.R"), about_x(knee(r)),
  pick_q(String.eq(slot, "foot.L"), about_x(ankle(f)),
  pick_q(String.eq(slot, "foot.R"), about_x(ankle(r)),
  pick_q(String.eq(slot, "upper_arm.L"), Q.mul(about_x(swing), about_z((0.0 - arm_down() : F32))),
  pick_q(String.eq(slot, "upper_arm.R"), Q.mul(about_x((0.0 - swing : F32)), about_z(arm_down())),
  pick_q(String.eq(slot, "lower_arm.L"), about_y((0.0 - 0.35 : F32)),
  pick_q(String.eq(slot, "lower_arm.R"), about_y(0.35),
  pick_q(String.eq(slot, "hips"), about_y((0.1 * F32.sin(f) : F32)),
  pick_q(String.eq(slot, "upper_chest"), about_y((0.0 - 0.18 * F32.sin(f) : F32)),
  Q.identity()))))))))))))

def walk_slots() -> List<&2, String>:
  ["hips", "upper_chest", "upper_leg.L", "upper_leg.R", "lower_leg.L", "lower_leg.R",
   "foot.L", "foot.R", "upper_arm.L", "upper_arm.R", "lower_arm.L", "lower_arm.R"]

# The hips dip at each step, when the legs are apart.
def bob(+f: F32) -> F32:
  (0.02 * F32.cos((2.0 * f : F32)) - 0.02 : F32)

# Idle
# ====

# Standing: arms at the sides, elbows a little bent, a slow breath.
def idle_turn(+slot: String, +f: F32) -> Q.Q:
  pick_q(String.eq(slot, "upper_arm.L"), about_z((0.0 - arm_down() : F32)),
  pick_q(String.eq(slot, "upper_arm.R"), about_z(arm_down()),
  pick_q(String.eq(slot, "lower_arm.L"), about_y((0.0 - 0.15 : F32)),
  pick_q(String.eq(slot, "lower_arm.R"), about_y(0.15),
  pick_q(String.eq(slot, "upper_chest"), about_x((0.02 * F32.sin(f) : F32)),
  Q.identity())))))

def idle_slots() -> List<&2, String>:
  ["upper_chest", "upper_arm.L", "upper_arm.R", "lower_arm.L", "lower_arm.R"]

# Baking
# ======

def keys() -> U32: 16

# Which gait: 0 walk, 1 idle.
def turn_of(+which: U32, +slot: String, +f: F32) -> Q.Q:
  pick_q(U32.is_eq(which, 0), walk_turn(slot, f), idle_turn(slot, f))

def turn_key(+which: U32, +s: Sk.Skeleton, +bone: U32, +slot: String, +seconds: F32, +phase: F32) -> C.Turn:
  C.Turn{(seconds * phase : F32), P.turned(s, bone, turn_of(which, slot, (pi2() * phase : F32)))}

# Keys k = n, n − 1, … 0, built from the last so the list ends in order.
def turns_go(fuel: Nat, +which: U32, +s: Sk.Skeleton, +bone: U32, +slot: String, +seconds: F32, +k: U32, acc: List<&2, C.Turn>) -> List<&2, C.Turn>:
  match fuel:
    case 0n:
      acc
    case 1n+rest:
      +phase = (U32.to_f32(k) / U32.to_f32(keys()) : F32)
      turns_go(rest, which, s, bone, slot, seconds, (k - 1 : U32), turn_key(which, s, bone, slot, seconds, phase) <> acc)

def turns(+which: U32, +s: Sk.Skeleton, +bone: U32, +slot: String, +seconds: F32) -> List<&2, C.Turn>:
  turns_go(U32.to_nat((keys() + 1 : U32)), which, s, bone, slot, seconds, keys(), Nil{})

# A slot's track, or none when the skeleton lacks the slot.
def track_for(found: Bool, +which: U32, +s: Sk.Skeleton, +bone: U32, +slot: String, +seconds: F32) -> List<&2, C.Track>:
  match found:
    case True{}:
      [C.Turns{bone, turns(which, s, bone, slot, seconds)}]
    case False{}:
      Nil{}

# One track per slot the skeleton has; slots it lacks are skipped.
def tracks_go(slots: List<&2, String>, +which: U32, +s: Sk.Skeleton, +seconds: F32) -> List<&2, C.Track>:
  match slots:
    case Nil{}:
      Nil{}
    case +slot <> rest:
      +bone = Sk.find_slot(s, slot)
      List.append(&2, C.Track, track_for(U32.is_lt(bone, Sk.count(s)), which, s, bone, slot, seconds), tracks_go(rest, which, s, seconds))

def bob_key(+base: V.V3, +seconds: F32, +phase: F32) -> C.Shift:
  C.Shift{(seconds * phase : F32), V.add(base, V.V3{0.0, bob((pi2() * phase : F32)), 0.0})}

# The hips' bounce: their rest position, lowered at each step.
def bob_go(fuel: Nat, +base: V.V3, +seconds: F32, +k: U32, acc: List<&2, C.Shift>) -> List<&2, C.Shift>:
  match fuel:
    case 0n:
      acc
    case 1n+rest:
      +phase = (U32.to_f32(k) / U32.to_f32(keys()) : F32)
      bob_go(rest, base, seconds, (k - 1 : U32), bob_key(base, seconds, phase) <> acc)

def bob_for(found: Bool, +bone: U32, +base: V.V3, +seconds: F32) -> List<&2, C.Track>:
  match found:
    case True{}:
      [C.Shifts{bone, bob_go(U32.to_nat((keys() + 1 : U32)), base, seconds, keys(), Nil{})}]
    case False{}:
      Nil{}

def hips_bob(+s: Sk.Skeleton, +seconds: F32) -> List<&2, C.Track>:
  +bone = Sk.find_slot(s, "hips")
  +base = Tr.position(Sk.rest(Sk.at(s, bone)))
  bob_for(U32.is_lt(bone, Sk.count(s)), bone, base, seconds)

# A walk of one cycle in a second, at 1.3 m/s.
def walk(+s: Sk.Skeleton) -> C.Clip:
  C.Clip{"walk", 1.0, 1.3, List.append(&2, C.Track, tracks_go(walk_slots(), 0, s, 1.0), hips_bob(s, 1.0))}

# Standing still: one breath every 3 seconds.
def idle(+s: Sk.Skeleton) -> C.Clip:
  C.Clip{"idle", 3.0, 0.0, tracks_go(idle_slots(), 1, s, 3.0)}
