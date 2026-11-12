# Time: the engine's clock. Everything that moves by itself (water, a clip
# playing, a preview) reads its seconds from here, so there is one place that
# decides when time runs and when it stops.
#
# The browser only measures how long a frame took (dt) and passes it here,
# together with reduce_motion (editor/defaults/ACCESSIBILITY.bend or the
# system's setting). With reduce_motion on, time never runs by itself: it
# changes only when the person seeks to a moment.
#
# Limits now:
# - main.js does not run a frame loop yet: nothing moves by itself, so the
#   clock is not ticked. It joins the frame with the first thing that moves.
# - Seconds are an F32, which loses precision as it grows: after about a
#   day of running, time moves in steps of about 8 ms and waves would
#   stutter. Going back to 0 at a loop point, or keeping seconds as U32 ms,
#   fixes it when it matters.

import Base

type Clock is Data:
  Clock{seconds: F32, playing: Bool}

# A clock at 0 s, playing. It still stays put while reduce_motion is on.
def start() -> Clock:
  Clock{0.0, True{}}

# A frame longer than this (a tab left in the background, a pause in the
# debugger) counts as this long, so time never jumps ahead.
def max_step() -> F32: 0.1

def seconds(c: Clock) -> F32:
  Clock{s, _} = c
  s

def is_playing(c: Clock) -> Bool:
  Clock{_, p} = c
  p

# A playing clock moves dt seconds (at most max_step); a paused one stays.
def run(c: Clock, +dt: F32) -> Clock:
  match c:
    case Clock{s, True{}}:
      Clock{(s + F32.clamp(dt, 0.0, max_step()) : F32), True{}}
    case Clock{s, False{}}:
      Clock{s, False{}}

# One frame of dt seconds.
def tick(c: Clock, +dt: F32, reduce: Bool) -> Clock:
  match reduce:
    case True{}:
      c
    case False{}:
      run(c, dt)

# Go to a moment, as a time field does. Never before 0 s.
def seek(c: Clock, +s: F32) -> Clock:
  Clock{_, p} = c
  Clock{F32.max(s, 0.0), p}

def play(c: Clock) -> Clock:
  Clock{s, _} = c
  Clock{s, True{}}

def pause(c: Clock) -> Clock:
  Clock{s, _} = c
  Clock{s, False{}}
