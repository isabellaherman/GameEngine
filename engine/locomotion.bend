# Locomotion: the character walks through the World.
#
# Input moves the character's place (its thing's Transform), and the
# figure's speed follows, so the animator blends idle and walk by itself.
# Clips stay in place (they do not move the character); code moves it, as
# a pure step(state, input, dt) a server can run again to check a player
# (the study's decision: in-place clips, movement by code).
#
# Two ways to drive, chosen by ACCESSIBILITY.bend:
# - Run (motion allowed): while a key is held, the character speeds up to
#   the walk's speed, turns at a steady rate, and slows down when let go.
# - Step (reduce_motion on): one key press is one step. The character moves
#   a step ahead (or turns 22.5°) and stands again: no continuous motion,
#   nothing moves between presses.
#
# Input is whole numbers so the laws can check it: forward 0 none, 1 ahead,
# 2 back; turn 0 none, 1 left, 2 right. The character faces its own +Z;
# turning left turns it toward its +X.
#
# Limits now:
# - Flat ground: the character's height never changes.
# - Nothing blocks it: no collision.
# - Turning in Run turns the whole body at once (no turn-in-place clip).

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr
import ./figure.bend as Fig
import ./clip.bend as C
import ./scene.bend as S

type Input is Data:
  Input{forward: U32, turn: U32}

def still() -> Input:
  Input{0, 0}

def accel() -> F32: 3.0             # m/s², speeding up and slowing down
def turn_rate() -> F32: 2.0         # rad/s while turning in Run
def step_length() -> F32: 0.65      # m, one step in Step
def step_turn() -> F32: 0.3926991   # rad (22.5°), one turn in Step

# −1, 0 or 1 from an input code (1 is +1, 2 is −1).
def sign(+code: U32) -> F32:
  match code:
    case 0:
      0.0
    case 1:
      1.0
    case _:
      (0.0 - 1.0 : F32)

def is_still(i: Input) -> Bool:
  Input{f, t} = i
  (U32.is_eq(f, 0) && U32.is_eq(t, 0))

# The heading (radians around Y) of a place's rotation, and back.
def y_part(q: Q.Q) -> F32:
  Q.Q{_, y, _, _} = q
  y

def heading(+p: Tr.Transform) -> F32:
  +q = Tr.rotation(p)
  (2.0 * Q.atan2(y_part(q), Q.w_part(q)) : F32)

def facing(+h: F32) -> Q.Q:
  Q.axis_angle(V.V3{0.0, 1.0, 0.0}, h)

def ahead(+h: F32) -> V.V3:
  V.V3{F32.sin(h), 0.0, F32.cos(h)}

def toward(+v: F32, +target: F32, +by: F32) -> F32:
  F32.clamp(target, (v - by : F32), (v + by : F32))

# Run: one frame of held keys.
def run(+t: S.Thing, i: Input, +dt: F32) -> S.Thing:
  S.Thing{+n, +p, +l} = t
  Input{+f, +tn} = i
  +fig = S.figure(l)
  +top = C.speed(Fig.walk(fig))
  +v = toward(Fig.param(fig, "speed"), (sign(f) * top : F32), (accel() * dt : F32))
  +h = (heading(p) + sign(tn) * turn_rate() * dt : F32)
  +pos = V.add(Tr.position(p), V.scale(ahead(h), (v * dt : F32)))
  S.Thing{n, Tr.with_rotation(Tr.with_position(p, pos), facing(h)), S.Rigged{Fig.set_param(fig, "speed", F32.abs(v))}}

# Step: one key press.
def step(+t: S.Thing, i: Input) -> S.Thing:
  S.Thing{+n, +p, +l} = t
  Input{+f, +tn} = i
  +h = (heading(p) + sign(tn) * step_turn() : F32)
  +pos = V.add(Tr.position(p), V.scale(ahead(h), (sign(f) * step_length() : F32)))
  S.Thing{n, Tr.with_rotation(Tr.with_position(p, pos), facing(h)), l}

def not(b: Bool) -> Bool:
  match b:
    case True{}:
      False{}
    case False{}:
      True{}

def pick_thing(c: Bool, a: S.Thing, b: S.Thing) -> S.Thing:
  match c:
    case True{}:
      a
    case False{}:
      b

# One thing, driven: characters move, anything else stays.
def drive_thing(+t: S.Thing, +i: Input, +dt: F32, stepping: Bool) -> S.Thing:
  match stepping:
    case True{}:
      pick_thing((not(is_still(i)) && S.is_rigged(t)), step(t, i), t)
    case False{}:
      pick_thing(S.is_rigged(t), run(t, i, dt), t)

def drive_go(xs: List<&2, S.Thing>, +i: Input, +dt: F32, +stepping: Bool) -> List<&2, S.Thing>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      drive_thing(h, i, dt, stepping) <> drive_go(t, i, dt, stepping)

# Every character in the scene, driven by the same input.
def drive(s: S.Scene, +i: Input, +dt: F32, +stepping: Bool) -> S.Scene:
  S.Scene{xs} = s
  S.Scene{drive_go(xs, i, dt, stepping)}

# An input from its two codes (for main.js, which reads the keys).
def input(+forward: U32, +turn: U32) -> Input:
  Input{forward, turn}
