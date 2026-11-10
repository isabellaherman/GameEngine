# The axis gizmo: the World's axes seen from the editor camera, drawn small in
# a corner. Each axis has two handles, + and -. The browser draws the handles
# this file places, back to front, asks it which handle the mouse is on, and
# asks it where the camera goes when a handle is clicked.
#
# Sizes come from Bend-UI's tokens; tones and names from engine/world.bend.

import Base
import ./vec.bend as V
import ./camera.bend as Cam
import ./world.bend as W
import ../node_modules/bend-ui/TOKENS.bend as T
import ../node_modules/bend-ui/MOTION.bend as M

# A handle: which one (0 +X, 1 +Y, 2 +Z, 3 -X, 4 -Y, 5 -Z), where it sits in
# the gizmo (pixels from its top-left), how much it faces the viewer (-1..1),
# its tone, and its label ("" on the - side).
type Handle is Data:
  Handle{id: U32, x: F32, y: F32, depth: F32, tone: String, label: String, positive: Bool}

# The gizmo's square side and a handle's radius, in pixels.
def size() -> F32: U32.to_f32((T.space_7() * 2 : U32))
def radius() -> F32: U32.to_f32(T.space_2())
def none() -> U32: 6

# Where the camera looks: right, up and toward-the-viewer, from yaw and pitch.
def toward(+cam: Cam.Cam) -> V.V3:
  V.norm(V.sub(Cam.eye(cam), Cam.target(cam)))

def right(+cam: Cam.Cam) -> V.V3:
  V.norm(V.cross(V.V3{0.0, 1.0, 0.0}, toward(cam)))

def up(+cam: Cam.Cam) -> V.V3:
  V.cross(toward(cam), right(cam))

# One handle for direction d.
def handle(+cam: Cam.Cam, id: U32, +d: V.V3, tone: String, label: String, positive: Bool) -> Handle:
  +c = (size() / 2.0 : F32)
  +reach = (c - radius() - 2.0 : F32)
  Handle{id, (c + V.dot(d, right(cam)) * reach : F32), (c - V.dot(d, up(cam)) * reach : F32), V.dot(d, toward(cam)), tone, label, positive}

def depth(h: Handle) -> F32:
  Handle{_, _, _, d, _, _, _} = h
  d

def back_first(a: Handle, b: Handle) -> Bool:
  F32.is_le(depth(a), depth(b))

# The six handles, back to front: draw them in this order.
def handles(+cam: Cam.Cam) -> List<&2, Handle>:
  List.sort(~Handle, ~back_first, [
    handle(cam, 0, V.V3{1.0, 0.0, 0.0}, W.x_tone(), "X", True{}),
    handle(cam, 1, V.V3{0.0, 1.0, 0.0}, W.y_tone(), "Y", True{}),
    handle(cam, 2, V.V3{0.0, 0.0, 1.0}, W.z_tone(), "Z", True{}),
    handle(cam, 3, V.V3{(0.0 - 1.0 : F32), 0.0, 0.0}, W.x_tone(), "", False{}),
    handle(cam, 4, V.V3{0.0, (0.0 - 1.0 : F32), 0.0}, W.y_tone(), "", False{}),
    handle(cam, 5, V.V3{0.0, 0.0, (0.0 - 1.0 : F32)}, W.z_tone(), "", False{})])

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# The front-most handle under (px, py), or none().
def hit_go(hs: List<&2, Handle>, +px: F32, +py: F32, found: U32) -> U32:
  match hs:
    case Nil{}:
      found
    case Con{h, rest}:
      Handle{id, x, y, _, _, _, _} = h
      hit_go(rest, px, py, pick(F32.is_le(F32.hypot((px - x : F32), (py - y : F32)), radius()), id, found))

def hit(+cam: Cam.Cam, +px: F32, +py: F32) -> U32:
  hit_go(handles(cam), px, py, none())

def pick_f(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

# Clicking a handle puts the camera on that side, looking at the target.
# +Y and -Y stop just short of straight up and down.
def snap_yaw(+id: U32) -> F32:
  +hp = (F32.pi() / 2.0 : F32)
  pick_f(U32.is_eq(id, 0), hp, pick_f(U32.is_eq(id, 3), (0.0 - hp : F32), pick_f(U32.is_eq(id, 2), 0.0, pick_f(U32.is_eq(id, 5), F32.pi(), 0.0))))

def snap_pitch(+id: U32) -> F32:
  +lim = Cam.pitch_limit()
  pick_f(U32.is_eq(id, 1), lim, pick_f(U32.is_eq(id, 4), (0.0 - lim : F32), 0.0))

def snap(+cam: Cam.Cam, +id: U32) -> Cam.Cam:
  Cam.Cam{target, _, _, dist} = cam
  Cam.Cam{target, snap_yaw(id), snap_pitch(id), dist}

# Going home: the camera as the editor starts.
def home() -> Cam.Cam:
  Cam.start()

# The way there takes duration_enter (ms) and eases out.
def duration() -> F32: U32.to_f32(T.duration_enter_ms())

# The shortest turn from a to b, in radians (-pi..pi).
def turn(+a: F32, +b: F32) -> F32:
  +tau = (F32.pi() * 2.0 : F32)
  +d = (b - a : F32)
  (d - tau * F32.floor(((d + F32.pi()) / tau : F32)) : F32)

# The camera at time t (0..1) on the way from a to b: it turns the short way
# and glides its target and distance.
def between(+a: Cam.Cam, +b: Cam.Cam, +t: F32) -> Cam.Cam:
  Cam.Cam{+ta, +ya, +pa, +da} = a
  Cam.Cam{+tb, +yb, +pb, +db} = b
  +k = M.ease_out(F32.clamp(t, 0.0, 1.0))
  Cam.Cam{V.add(ta, V.scale(V.sub(tb, ta), k)), (ya + turn(ya, yb) * k : F32), (pa + (pb - pa) * k : F32), (da + (db - da) * k : F32)}

