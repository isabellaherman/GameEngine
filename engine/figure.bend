# Figure: the component that makes a thing a character.
#
# A figure has a skeleton (engine/skeleton.bend), the skin drawn over it
# (the path of a mesh file the browser loads, or "" for bones only), its
# clips (an idle and a walk, engine/gait.bend), and its animation
# parameters: named numbers the editor shows in the Details panel, stored
# like a material's values so the same panel code shows and edits them.
#
#   time   seconds since the animation started (moved by the clock, or by
#          hand when reduce_motion is on)
#   speed  how fast the character moves, in m/s: 0 stands (idle), the
#          walk's own speed (1.3) walks; in between the two blend
#
# The pose a figure takes is a pure function of the figure: nothing about
# animation is hidden in state. That is what lets a networked game rebuild
# any character's pose from a few numbers.
#
# Limits now:
# - The skin is a path, read by the browser; the mesh itself never passes
#   through Bend (too many numbers). Its laws are checked when it is made
#   (tools/gltf.ts).
# - Changing speed changes the walk's playback rate, so the step's phase
#   jumps when speed is edited by hand. The animator (a phase that
#   accumulates) fixes this.

import Base
import ./skeleton.bend as Sk
import ./pose.bend as P
import ./clip.bend as C
import ./gait.bend as G
import ./blend.bend as B
import ./material.bend as Mat
import ./transform.bend as Tr

type Figure is Data:
  Figure{skeleton: Sk.Skeleton, skin: String, params: List<&2, Mat.Value>, idle: C.Clip, walk: C.Clip}

# A figure for a skeleton, standing at time 0, with the code-made clips.
def make(+s: Sk.Skeleton, +skin: String) -> Figure:
  Figure{s, skin, [Mat.Value{"time", [0.0]}, Mat.Value{"speed", [0.0]}], G.idle(s), G.walk(s)}

def empty() -> Figure:
  make(Sk.Skeleton{Nil{}}, "")

def skeleton(f: Figure) -> Sk.Skeleton:
  Figure{s, _, _, _, _} = f
  s

def skin(f: Figure) -> String:
  Figure{_, k, _, _, _} = f
  k

def params(f: Figure) -> List<&2, Mat.Value>:
  Figure{_, _, ps, _, _} = f
  ps

def idle(f: Figure) -> C.Clip:
  Figure{_, _, _, i, _} = f
  i

def walk(f: Figure) -> C.Clip:
  Figure{_, _, _, _, w} = f
  w

def with_params(f: Figure, ps: List<&2, Mat.Value>) -> Figure:
  Figure{s, k, _, i, w} = f
  Figure{s, k, ps, i, w}

def pick_f(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def first(xs: List<&2, F32>) -> F32:
  match xs:
    case Nil{}:
      0.0
    case h <> _:
      h

# The value of a named parameter (0 when the figure has none).
def param_go(ps: List<&2, Mat.Value>, +want: String) -> F32:
  match ps:
    case Nil{}:
      0.0
    case h <> t:
      Mat.Value{+n, xs} = h
      pick_f(String.eq(n, want), first(xs), param_go(t, want))

def param(+f: Figure, +want: String) -> F32:
  param_go(params(f), want)

# How much of the walk is in the pose, from 0 (standing) to 1 (walking).
def walk_weight(+f: Figure) -> F32:
  F32.clamp((param(f, "speed") / F32.max(C.speed(walk(f)), 0.001) : F32), 0.0, 1.0)

# The walk's own clock: it plays faster or slower to match the speed, and
# never slower than half its rate while it shows.
def walk_time(+f: Figure) -> F32:
  (param(f, "time") * F32.max(walk_weight(f), 0.5) : F32)

# The pose the figure takes now: the idle and the walk, sampled and mixed
# by speed.
def pose(+f: Figure) -> P.Pose:
  +rest = P.rest(skeleton(f))
  B.mix(C.sample(idle(f), rest, param(f, "time")), C.sample(walk(f), rest, walk_time(f)), walk_weight(f))

# The figure's bones as lines in the World (6 floats per end), standing
# where `place` puts it.
def lines(+f: Figure, +place: Tr.Transform) -> List<&2, F32>:
  P.lines(skeleton(f), pose(f), place)

# Time
# ====

def set_first(xs: List<&2, F32>, +x: F32) -> List<&2, F32>:
  match xs:
    case Nil{}:
      [x]
    case _ <> t:
      x <> t

def pick_vs(c: Bool, a: List<&2, Mat.Value>, b: List<&2, Mat.Value>) -> List<&2, Mat.Value>:
  match c:
    case True{}:
      a
    case False{}:
      b

def set_param_go(ps: List<&2, Mat.Value>, +want: String, +x: F32) -> List<&2, Mat.Value>:
  match ps:
    case Nil{}:
      Nil{}
    case h <> +t:
      Mat.Value{+n, +xs} = h
      pick_vs(String.eq(n, want), Mat.Value{n, set_first(xs, x)} <> t, Mat.Value{n, xs} <> set_param_go(t, want, x))

def set_param(+f: Figure, +want: String, +x: F32) -> Figure:
  with_params(f, set_param_go(params(f), want, x))

# The figure dt seconds later. With reduce_motion on, nothing moves by
# itself: time changes only when someone types it.
def advance(+f: Figure, +dt: F32, reduce: Bool) -> Figure:
  match reduce:
    case True{}:
      f
    case False{}:
      set_param(f, "time", (param(f, "time") + F32.clamp(dt, 0.0, 0.1) : F32))
