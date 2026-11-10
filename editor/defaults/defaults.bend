# Editor Defaults: the basic facts of the scene, gathered in one place of the
# interface. It creates no value and writes nothing: every def here only hands
# on a value whose source of truth is elsewhere (engine/world.bend for the
# World, engine/gizmo.bend for the axis gizmo). LAWS.bend holds it to that.

import Base
import ../../engine/vec.bend as V
import ../../engine/world.bend as W
import ../../engine/camera.bend as Cam
import ../../engine/gizmo.bend as G

# The origin of the World.
def origin() -> V.V3:
  W.origin()

# The axes of the World, in order.
def axes() -> List<&2, W.Axis>:
  [W.axis_x(), W.axis_y(), W.axis_z()]

# The axis gizmo.
def gizmo_size() -> F32:
  G.size()

def gizmo_radius() -> F32:
  G.radius()

def gizmo_none() -> U32:
  G.none()

def gizmo_duration() -> F32:
  G.duration()

def gizmo_handles(+cam: Cam.Cam) -> List<&2, G.Handle>:
  G.handles(cam)

def gizmo_hit(+cam: Cam.Cam, +px: F32, +py: F32) -> U32:
  G.hit(cam, px, py)

def gizmo_snap(+cam: Cam.Cam, +id: U32) -> Cam.Cam:
  G.snap(cam, id)

def gizmo_between(+a: Cam.Cam, +b: Cam.Cam, +t: F32) -> Cam.Cam:
  G.between(a, b, t)
