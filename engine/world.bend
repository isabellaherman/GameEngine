# The World: the 3D space everything in a game lives in.
#
# - The origin (0, 0, 0) is the center of the World.
# - Y points up. The axes are right-handed: X to the right, Z toward the viewer.
# - One unit is one meter.
# - The ground is the plane y = 0, marked by a grid: a line every meter,
#   a stronger one every 10 meters, and the X and Z axes through the origin.
#
# Colors come from Bend-UI's tokens: the sky is the dark ground, the grid uses
# the border tones, X is danger (red), Y is success (green) and Z is accent
# (blue), as in other engines. The ground draws X and Z; Y rises from it.

import Base
import ./vec.bend as V
import ./color.bend as C
import ./camera.bend as Cam
import ../node_modules/bend-ui/TOKENS.bend as T

# An axis of the World: its name, where it points, and its tone (a Bend-UI
# token).
type Axis is Data:
  Axis{name: String, points: String, tone: String}

def origin() -> V.V3:
  V.V3{0.0, 0.0, 0.0}

def x_tone() -> String: T.color_danger()
def y_tone() -> String: T.color_success()
def z_tone() -> String: T.color_accent()

def axis_x() -> Axis: Axis{"X", "right", x_tone()}
def axis_y() -> Axis: Axis{"Y", "up", y_tone()}
def axis_z() -> Axis: Axis{"Z", "toward the viewer", z_tone()}

def half() -> U32: 100           # the grid reaches 100 m from the origin
def major_every() -> U32: 10     # a strong line every 10 m

def sky() -> List<F32>:
  +c = C.rgb(T.dark_bg())
  [V.x(c), V.y(c), V.z(c)]

# One line from a to b in color c: two vertices of x, y, z, r, g, b.
def line(a: V.V3, b: V.V3, +c: V.V3) -> List<F32>:
  V.V3{ax, ay, az} = a
  V.V3{bx, by, bz} = b
  [ax, ay, az, V.x(c), V.y(c), V.z(c), bx, by, bz, V.x(c), V.y(c), V.z(c)]

# The two grid lines at offset i: one along X (at z = i), one along Z (at x = i).
def cross_at(+i: F32, +h: F32, +c: V.V3) -> List<F32>:
  List.append(&1, F32,
    line(V.V3{(0.0 - h : F32), 0.0, i}, V.V3{h, 0.0, i}, c),
    line(V.V3{i, 0.0, (0.0 - h : F32)}, V.V3{i, 0.0, h}, c))

# The axes through the origin.
def axes(+h: F32) -> List<F32>:
  List.append(&1, F32,
    line(V.V3{(0.0 - h : F32), 0.0, 0.0}, V.V3{h, 0.0, 0.0}, C.rgb(x_tone())),
    line(V.V3{0.0, 0.0, (0.0 - h : F32)}, V.V3{0.0, 0.0, h}, C.rgb(z_tone())))

def pick(c: Bool, a: List<F32>, b: List<F32>) -> List<F32>:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_tone(major: Bool) -> V.V3:
  match major:
    case True{}:
      C.rgb(T.dark_border_strong())
    case False{}:
      C.rgb(T.dark_border())

# Grid line k of 0..2·half; the middle one (k = half) is the axes.
def grid_at(+k: U32) -> List<F32>:
  +n = half()
  +h = U32.to_f32(n)
  +i = (U32.to_f32(k) - h : F32)
  +tone = pick_tone(U32.is_eq((k % major_every() : U32), 0))
  pick(U32.is_eq(k, n), axes(h), cross_at(i, h, tone))

# Walks k down from 2·half to 0; fuel is the same count as a Nat, so it ends.
def grid_go(fuel: Nat, +k: U32, acc: List<F32>) -> List<F32>:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      grid_go(p, (k - 1 : U32), List.append(&1, F32, grid_at(k), acc))

# Every line of the ground, ready for the GPU (6 floats per vertex).
def lines() -> List<F32>:
  +top = (half() * 2 : U32)
  grid_go(U32.to_nat((top + 1 : U32)), top, Nil{})

# The grid fades with distance from the eye, scaled to how far the camera is,
# so it never ends in a hard edge: [start, end] in meters.
def fade(+cam: Cam.Cam) -> List<F32>:
  Cam.Cam{_, _, _, +d} = cam
  +h = U32.to_f32(half())
  [F32.min((d * 2.0 : F32), (h * 0.5 : F32)), F32.min((d * 6.0 : F32), h)]
