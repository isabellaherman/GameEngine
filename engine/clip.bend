# Clip: an animation, as keys in time.
#
# A clip holds tracks. Each track drives one bone:
# - Turns   the bone's local rotation over time (most tracks)
# - Shifts  the bone's local position over time (the hips' bounce, root
#           motion)
# Keys are (time in seconds, value), in order. Between two keys a rotation
# moves along the shortest arc (Q.slerp) and a position along a straight
# line, as glTF's LINEAR sampler does. A clip loops: time past its length
# starts again from 0.
#
# sample() turns a clip and a time into a pose: start from a base pose
# (usually the rest pose) and overwrite what each track drives. Bones
# without a track keep the base. This is stage 1 of Gregory's animation
# pipeline ("extract the poses from the clips").
#
# A clip also says the speed (m/s) at which its feet do not slide; the
# animator plays it faster or slower to match the character's speed.
#
# Limits now:
# - Linear keys only (glTF's STEP and CUBICSPLINE are not read).
# - Finding the keys around a time walks the track from the start.
# - Only rotation and position: no scale tracks.

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr
import ./pose.bend as P

type Turn is Data:
  Turn{time: F32, rotation: Q.Q}

type Shift is Data:
  Shift{time: F32, position: V.V3}

type Track is Data:
  Turns{bone: U32, turns: List<&2, Turn>}
  Shifts{bone: U32, shifts: List<&2, Shift>}

type Clip is Data:
  Clip{name: String, seconds: F32, speed: F32, tracks: List<&2, Track>}

def name(c: Clip) -> String:
  Clip{n, _, _, _} = c
  n

def seconds(c: Clip) -> F32:
  Clip{_, s, _, _} = c
  s

def speed(c: Clip) -> F32:
  Clip{_, _, v, _} = c
  v

def tracks(c: Clip) -> List<&2, Track>:
  Clip{_, _, _, ts} = c
  ts

def turn_time(k: Turn) -> F32:
  Turn{t, _} = k
  t

def turn_rotation(k: Turn) -> Q.Q:
  Turn{_, r} = k
  r

def shift_time(k: Shift) -> F32:
  Shift{t, _} = k
  t

def shift_position(k: Shift) -> V.V3:
  Shift{_, p} = k
  p

# Time inside the loop: 0 ≤ t < seconds.
def wrap(+t: F32, +seconds: F32) -> F32:
  (t - seconds * F32.floor((t / F32.max(seconds, 0.0001) : F32)) : F32)

# How far t is from a to b, from 0 to 1.
def between(+t: F32, +a: F32, +b: F32) -> F32:
  F32.clamp(((t - a) / F32.max((b - a : F32), 0.000001) : F32), 0.0, 1.0)

# Rotations
# =========

def pick_q(c: Bool, a: Q.Q, b: Q.Q) -> Q.Q:
  match c:
    case True{}:
      a
    case False{}:
      b

# The rotation at time t, from key h and the keys after it.
def turn_from(ks: List<&2, Turn>, +h: Turn, +t: F32) -> Q.Q:
  match ks:
    case Nil{}:
      turn_rotation(h)
    case +n <> +rest:
      pick_q(F32.is_lt(t, turn_time(n)),
        Q.slerp(turn_rotation(h), turn_rotation(n), between(t, turn_time(h), turn_time(n))),
        turn_from(rest, n, t))

def turn_at(ks: List<&2, Turn>, +t: F32) -> Q.Q:
  match ks:
    case Nil{}:
      Q.identity()
    case h <> rest:
      turn_from(rest, h, t)

# Positions
# =========

def pick_v(c: Bool, a: V.V3, b: V.V3) -> V.V3:
  match c:
    case True{}:
      a
    case False{}:
      b

def lerp3(a: V.V3, b: V.V3, +t: F32) -> V.V3:
  V.V3{ax, ay, az} = a
  V.V3{bx, by, bz} = b
  V.V3{F32.lerp(ax, bx, t), F32.lerp(ay, by, t), F32.lerp(az, bz, t)}

def shift_from(ks: List<&2, Shift>, +h: Shift, +t: F32) -> V.V3:
  match ks:
    case Nil{}:
      shift_position(h)
    case +n <> +rest:
      pick_v(F32.is_lt(t, shift_time(n)),
        lerp3(shift_position(h), shift_position(n), between(t, shift_time(h), shift_time(n))),
        shift_from(rest, n, t))

def shift_at(ks: List<&2, Shift>, +t: F32) -> V.V3:
  match ks:
    case Nil{}:
      V.V3{0.0, 0.0, 0.0}
    case h <> rest:
      shift_from(rest, h, t)

# Sampling
# ========

def apply_track(+p: P.Pose, tr: Track, +t: F32) -> P.Pose:
  match tr:
    case Turns{+b, ks}:
      +old = P.local_at(p, b)
      P.set(p, b, Tr.with_rotation(old, turn_at(ks, t)))
    case Shifts{+b, ks}:
      +old = P.local_at(p, b)
      P.set(p, b, Tr.with_position(old, shift_at(ks, t)))

def apply_go(ts: List<&2, Track>, p: P.Pose, +t: F32) -> P.Pose:
  match ts:
    case Nil{}:
      p
    case h <> rest:
      apply_go(rest, apply_track(p, h, t), t)

# The pose of a clip at time t (in seconds; the clip loops), on top of a
# base pose.
def sample(+c: Clip, +base: P.Pose, +t: F32) -> P.Pose:
  apply_go(tracks(c), base, wrap(t, seconds(c)))

# How many tracks drive this bone (for the laws: a clip must drive only
# bones that exist and a bone at most once per kind of track).
def track_bone(tr: Track) -> U32:
  match tr:
    case Turns{b, _}:
      b
    case Shifts{b, _}:
      b

def bones_go(ts: List<&2, Track>) -> List<&2, U32>:
  match ts:
    case Nil{}:
      Nil{}
    case h <> rest:
      track_bone(h) <> bones_go(rest)

def bones(c: Clip) -> List<&2, U32>:
  bones_go(tracks(c))
