# Blend: two poses mixed into one.
#
# mix(a, b, w) gives a when w = 0, b when w = 1, and in between moves each
# bone part of the way: positions and scales along a straight line,
# rotations along the shortest arc (Q.nlerp, close to slerp for nearby
# poses and cheaper). This is stage 2 of Gregory's animation pipeline
# ("blend the poses"), and what Unity's Blend Tree and Unreal's Blend Space
# do for one parameter.
#
# Limits now:
# - The whole body mixes by one weight. Mixing by body part (a hand pose
#   over a walk) comes with masks.
# - The two poses must come from the same skeleton (same bone count and
#   order); nothing checks it.

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr
import ./pose.bend as P

def lerp3(a: V.V3, b: V.V3, +t: F32) -> V.V3:
  V.V3{ax, ay, az} = a
  V.V3{bx, by, bz} = b
  V.V3{F32.lerp(ax, bx, t), F32.lerp(ay, by, t), F32.lerp(az, bz, t)}

def mix_one(a: Tr.Transform, b: Tr.Transform, +w: F32) -> Tr.Transform:
  Tr.Transform{ap, ar, as} = a
  Tr.Transform{bp, br, bs} = b
  Tr.Transform{lerp3(ap, bp, w), Q.nlerp(ar, br, w), lerp3(as, bs, w)}

def mix_go(xs: List<&2, Tr.Transform>, ys: List<&2, Tr.Transform>, +w: F32) -> List<&2, Tr.Transform>:
  match xs:
    case Nil{}:
      Nil{}
    case x <> xt:
      match ys:
        case Nil{}:
          Nil{}
        case y <> yt:
          mix_one(x, y, w) <> mix_go(xt, yt, w)

def mix(a: P.Pose, b: P.Pose, +w: F32) -> P.Pose:
  P.Pose{mix_go(P.locals(a), P.locals(b), F32.clamp(w, 0.0, 1.0))}
