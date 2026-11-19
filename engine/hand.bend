# Hand: the fingers close by one number, grip (0 open, 1 a fist).
#
# Clips leave the fingers alone (the code-made walk animates none), so a
# hand pose goes on top of whatever the body does: each finger segment
# turns toward the palm by its share of the grip, the base joints less, the
# middle ones most, the thumb about half. Turns are given in the
# character's own axes at rest (engine/pose.bend's turned), where the arms
# are out to the sides (the T-pose) and the palms face down: a finger
# closes by turning around the forward axis (Z), down for the left hand
# and down for the right (the opposite sign).
#
# This is the "fingers from day one" part of the rig standard: every
# character that follows it closes its hands the same way.
#
# Limits now:
# - One grip for both hands, and every finger closes together (no
#   pointing, no holding a cup): those are hand poses still to come.
# - The thumb closes across the palm by a fixed turn; it does not oppose
#   the fingers.
# - Assumes a T-pose rest with palms down, as the reference rig has.

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr
import ./skeleton.bend as Sk
import ./pose.bend as P

def pick_f(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def side_sign(+side: String) -> F32:
  pick_f(String.eq(side, "L"), (0.0 - 1.0 : F32), 1.0)

# How far each segment turns with a full grip, in radians.
def share(+segment: U32) -> F32:
  match segment:
    case 1:
      1.1
    case 2:
      1.4
    case _:
      1.0

def set_if(found: Bool, +s: Sk.Skeleton, +p: P.Pose, +i: U32, +turn: Q.Q) -> P.Pose:
  match found:
    case True{}:
      P.set(p, i, Tr.with_rotation(P.local_at(p, i), P.turned(s, i, turn)))
    case False{}:
      p

def curl_one(+s: Sk.Skeleton, +p: P.Pose, +slot: String, +angle: F32, +axis: V.V3) -> P.Pose:
  +i = Sk.find_slot(s, slot)
  set_if(U32.is_lt(i, Sk.count(s)), s, p, i, Q.axis_angle(axis, angle))

def forward_axis() -> V.V3: V.V3{0.0, 0.0, 1.0}

def up_axis() -> V.V3: V.V3{0.0, 1.0, 0.0}

def slot(+finger: String, +segment: U32, +side: String) -> String:
  String.concat([finger, "_", U32.show(segment), ".", side])

# One finger's three segments.
def finger(+s: Sk.Skeleton, +p: P.Pose, +name: String, +side: String, +grip: F32) -> P.Pose:
  +k = (side_sign(side) * grip : F32)
  curl_one(s, curl_one(s, curl_one(s, p, slot(name, 1, side), (k * share(1) : F32), forward_axis()), slot(name, 2, side), (k * share(2) : F32), forward_axis()), slot(name, 3, side), (k * share(3) : F32), forward_axis())

def thumb(+s: Sk.Skeleton, +p: P.Pose, +side: String, +grip: F32) -> P.Pose:
  +k = (side_sign(side) * grip * 0.6 : F32)
  curl_one(s, curl_one(s, p, slot("thumb", 2, side), k, up_axis()), slot("thumb", 3, side), k, up_axis())

def hand(+s: Sk.Skeleton, +p: P.Pose, +side: String, +g: F32) -> P.Pose:
  thumb(s, finger(s, finger(s, finger(s, finger(s, p, "index", side, g), "middle", side, g), "ring", side, g), "little", side, g), side, g)

# Both hands closed by `grip` (clamped to 0..1).
def grip(+s: Sk.Skeleton, +p: P.Pose, +g: F32) -> P.Pose:
  +c = F32.clamp(g, 0.0, 1.0)
  hand(s, hand(s, p, "L", c), "R", c)
