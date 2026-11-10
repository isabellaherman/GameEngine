# The editor camera: how we look at the World. It orbits a target point.
# Y is up. yaw turns around Y, pitch tilts up and down, dist is the distance
# to the target in meters. The browser only reads the mouse and passes the
# numbers here; every move is decided in this file.

import Base
import ./vec.bend as V

type Cam is Data:
  Cam{target: V.V3, yaw: F32, pitch: F32, dist: F32}

# Lens: vertical field of view (60°) and the clip planes, in meters.
def fov() -> F32: 1.0471976
def near() -> F32: 0.05
def far() -> F32: 2000.0

# How the mouse maps to motion.
def orbit_speed() -> F32: 0.005    # radians per pixel
def zoom_speed() -> F32: 0.0015    # per wheel unit
def pitch_limit() -> F32: 1.55     # just short of straight up or down
def dist_min() -> F32: 0.5
def dist_max() -> F32: 500.0

# Where the editor starts: looking at the origin from above, at 45°.
def start() -> Cam:
  Cam{V.V3{0.0, 0.0, 0.0}, 0.7853982, 0.4636476, 14.0}

# The point the camera looks at.
def target(cam: Cam) -> V.V3:
  Cam{t, _, _, _} = cam
  t

# The camera's position in the World.
def eye(cam: Cam) -> V.V3:
  Cam{target, +yaw, +pitch, +dist} = cam
  V.add(target, V.V3{(F32.cos(pitch) * F32.sin(yaw) * dist : F32), (F32.sin(pitch) * dist : F32), (F32.cos(pitch) * F32.cos(yaw) * dist : F32)})

# Drag to orbit: the World turns with the mouse.
def orbit(cam: Cam, +dx: F32, +dy: F32) -> Cam:
  Cam{target, yaw, pitch, dist} = cam
  +lim = pitch_limit()
  Cam{target, (yaw - dx * orbit_speed() : F32), F32.clamp((pitch + dy * orbit_speed() : F32), (0.0 - lim : F32), lim), dist}

# Meters the target moves per pixel, so the ground follows the mouse.
def per_pixel(+dist: F32, +height: F32) -> F32:
  (2.0 * dist * F32.tan((fov() / 2.0 : F32)) / F32.max(height, 1.0) : F32)

# Drag to pan: the target slides across the screen plane.
def pan(+cam: Cam, +dx: F32, +dy: F32, +height: F32) -> Cam:
  Cam{+target, +yaw, +pitch, +dist} = cam
  +f = V.norm(V.sub(target, eye(cam)))
  +right = V.norm(V.cross(f, V.V3{0.0, 1.0, 0.0}))
  +up = V.cross(right, f)
  +k = per_pixel(dist, height)
  Cam{V.add(target, V.add(V.scale(right, (0.0 - dx * k : F32)), V.scale(up, (dy * k : F32)))), yaw, pitch, dist}

# Wheel to zoom: closer or farther, never through the target.
def zoom(cam: Cam, +wheel: F32) -> Cam:
  Cam{target, yaw, pitch, dist} = cam
  Cam{target, yaw, pitch, F32.clamp((dist * F32.exp((wheel * zoom_speed() : F32)) : F32), dist_min(), dist_max())}

# World to camera space (a right-handed look-at).
def view(+cam: Cam) -> V.M4:
  Cam{+target, _, _, _} = cam
  +e = eye(cam)
  +f = V.norm(V.sub(target, e))
  +s = V.norm(V.cross(f, V.V3{0.0, 1.0, 0.0}))
  +u = V.cross(s, f)
  V.M4{
    V.V4{V.x(s), V.x(u), (0.0 - V.x(f) : F32), 0.0},
    V.V4{V.y(s), V.y(u), (0.0 - V.y(f) : F32), 0.0},
    V.V4{V.z(s), V.z(u), (0.0 - V.z(f) : F32), 0.0},
    V.V4{(0.0 - V.dot(s, e) : F32), (0.0 - V.dot(u, e) : F32), V.dot(f, e), 1.0}}

# Camera space to the screen (perspective).
def proj(+aspect: F32) -> V.M4:
  +f = (1.0 / F32.tan((fov() / 2.0 : F32)) : F32)
  +n = near()
  +r = far()
  V.M4{
    V.V4{(f / aspect : F32), 0.0, 0.0, 0.0},
    V.V4{0.0, f, 0.0, 0.0},
    V.V4{0.0, 0.0, ((r + n) / (n - r) : F32), (0.0 - 1.0 : F32)},
    V.V4{0.0, 0.0, (2.0 * r * n / (n - r) : F32), 0.0}}

# Everything the GPU needs from the camera, in one list:
# the view-projection matrix (16, column-major), then the eye (3).
def frame(+cam: Cam, +aspect: F32) -> List<F32>:
  +e = eye(cam)
  List.append(&1, F32, V.flat(V.mul(proj(aspect), view(cam))), [V.x(e), V.y(e), V.z(e)])
