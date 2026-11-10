# The rule of Editor Defaults: it only receives. Every value it shows is the
# same value as its source of truth. A value made up here, or one that drifts
# from the source, breaks a law and `bend PROOF.bend` fails.

import Base
import ../../engine/vec.bend as V
import ../../engine/world.bend as W
import ../../engine/camera.bend as Cam
import ../../engine/gizmo.bend as G
import ./defaults.bend as D

# LAW: the origin shown is the World's origin.
law origin_is_the_worlds:
  {D.origin() == W.origin() : V.V3}

# LAW: the axes shown are the World's axes, in order.
law axes_are_the_worlds:
  {D.axes() == [W.axis_x(), W.axis_y(), W.axis_z()] : List<&2, W.Axis>}

# LAW: the gizmo's size, handle radius, "no handle" and timing are the gizmo's.
law gizmo_size_is_the_gizmos:
  {D.gizmo_size() == G.size() : F32}

law gizmo_radius_is_the_gizmos:
  {D.gizmo_radius() == G.radius() : F32}

law gizmo_none_is_the_gizmos:
  {D.gizmo_none() == G.none() : U32}

law gizmo_duration_is_the_gizmos:
  {D.gizmo_duration() == G.duration() : F32}

# LAW: for every camera, the handles shown are the gizmo's handles.
law gizmo_handles_are_the_gizmos:
  for cam: Cam.Cam
  {D.gizmo_handles(cam) == G.handles(cam) : List<&2, G.Handle>}

# LAW: for every camera and point, the handle under the mouse is the gizmo's answer.
law gizmo_hit_is_the_gizmos:
  for cam: Cam.Cam
  for px: F32
  for py: F32
  {D.gizmo_hit(cam, px, py) == G.hit(cam, px, py) : U32}

# LAW: for every camera and handle, where a click sends the camera is the gizmo's answer.
law gizmo_snap_is_the_gizmos:
  for cam: Cam.Cam
  for id: U32
  {D.gizmo_snap(cam, id) == G.snap(cam, id) : Cam.Cam}

# LAW: for every two cameras and time, the way between them is the gizmo's.
law gizmo_between_is_the_gizmos:
  for a: Cam.Cam
  for b: Cam.Cam
  for t: F32
  {D.gizmo_between(a, b, t) == G.between(a, b, t) : Cam.Cam}
