# Quaternions: how the engine stores a rotation.
#
# A rotation of θ radians around an axis (a direction of length 1) is four
# numbers: q = (axis · sin(θ/2), cos(θ/2)), written Q{x, y, z, w}. Every
# rotation has length 1.
#
# Why not three angles (yaw, pitch, roll)? Angles lock when two axes line
# up (gimbal lock), and blending two sets of angles takes crooked paths.
# Quaternions do neither, and slerp blends two of them along the shortest
# arc at a steady speed. Unity, Unreal and glTF all store rotations this way.
#
# Rules (the same as the matrices in vec.bend):
# - mul(a, b) means "b first, then a", like matrices.
# - q and -q are the same rotation. Blends flip one of them when needed, so
#   they always take the short way.
# - Angles are in radians and turn counterclockwise around the axis, seen
#   from its tip (the right-hand rule, as in world.bend).
#
# Limits now:
# - The law checker does not compute float arithmetic, so no law can prove
#   that, say, a full turn comes back to the start. tests/quat.bend checks
#   those numerically (within 0.0001) when `bun run check` runs it.
# - Nothing renormalizes on its own: many mul calls in a row slowly drift
#   from length 1. normalize() fixes it; callers that chain rotations every
#   frame must call it.
# - Degrees per axis (from_degrees, to_degrees) are for people, in the
#   editor. Near ±90° around X the other two axes line up (gimbal lock), and
#   to_degrees may split one turn between Y and Z differently from how it
#   was typed; the rotation itself stays right. Unity's inspector has the
#   same behavior.
# - The editor camera keeps its own angles (camera.bend) and does not use
#   this file.

import Base
import ./vec.bend as V

type Q is Data:
  Q{x: F32, y: F32, z: F32, w: F32}

# No rotation.
def identity() -> Q:
  Q{0.0, 0.0, 0.0, 1.0}

# A rotation of `angle` radians around `axis` (any length but zero).
def axis_angle(axis: V.V3, +angle: F32) -> Q:
  +a = V.norm(axis)
  +h = (angle / 2.0 : F32)
  +s = F32.sin(h)
  Q{(V.x(a) * s : F32), (V.y(a) * s : F32), (V.z(a) * s : F32), F32.cos(h)}

# b first, then a (the Hamilton product).
def mul(a: Q, b: Q) -> Q:
  Q{+ax, +ay, +az, +aw} = a
  Q{+bx, +by, +bz, +bw} = b
  Q{(aw * bx + ax * bw + ay * bz - az * by : F32),
    (aw * by - ax * bz + ay * bw + az * bx : F32),
    (aw * bz + ax * by - ay * bx + az * bw : F32),
    (aw * bw - ax * bx - ay * by - az * bz : F32)}

# The opposite rotation (for a quaternion of length 1).
def conj(q: Q) -> Q:
  Q{x, y, z, w} = q
  Q{(0.0 - x : F32), (0.0 - y : F32), (0.0 - z : F32), w}

def dot(a: Q, b: Q) -> F32:
  Q{ax, ay, az, aw} = a
  Q{bx, by, bz, bw} = b
  (ax * bx + ay * by + az * bz + aw * bw : F32)

def length(+q: Q) -> F32:
  F32.sqrt(dot(q, q))

def scale(q: Q, +k: F32) -> Q:
  Q{x, y, z, w} = q
  Q{(x * k : F32), (y * k : F32), (z * k : F32), (w * k : F32)}

def add(a: Q, b: Q) -> Q:
  Q{ax, ay, az, aw} = a
  Q{bx, by, bz, bw} = b
  Q{(ax + bx : F32), (ay + by : F32), (az + bz : F32), (aw + bw : F32)}

# Back to length 1.
def normalize(+q: Q) -> Q:
  scale(q, (1.0 / F32.max(length(q), 0.000001) : F32))

def neg(q: Q) -> Q:
  scale(q, (0.0 - 1.0 : F32))

# The axis part (x, y, z) and the angle part (w).
def axis_part(q: Q) -> V.V3:
  Q{x, y, z, _} = q
  V.V3{x, y, z}

def w_part(q: Q) -> F32:
  Q{_, _, _, w} = q
  w

# Turn a vector: v' = v + 2w (u × v) + 2 u × (u × v), with u = (x, y, z).
def rotate(+q: Q, +v: V.V3) -> V.V3:
  +u = axis_part(q)
  +t = V.scale(V.cross(u, v), 2.0)
  V.add(v, V.add(V.scale(t, w_part(q)), V.cross(u, t)))

# The same rotation as a 4×4 matrix, column-major like vec.bend.
def to_m4(q: Q) -> V.M4:
  Q{+x, +y, +z, +w} = q
  V.M4{
    V.V4{(1.0 - 2.0 * (y * y + z * z) : F32), (2.0 * (x * y + w * z) : F32), (2.0 * (x * z - w * y) : F32), 0.0},
    V.V4{(2.0 * (x * y - w * z) : F32), (1.0 - 2.0 * (x * x + z * z) : F32), (2.0 * (y * z + w * x) : F32), 0.0},
    V.V4{(2.0 * (x * z + w * y) : F32), (2.0 * (y * z - w * x) : F32), (1.0 - 2.0 * (x * x + y * y) : F32), 0.0},
    V.V4{0.0, 0.0, 0.0, 1.0}}

# Blending
# ========

def pick(c: Bool, a: Q, b: Q) -> Q:
  match c:
    case True{}:
      a
    case False{}:
      b

# b, or -b when that is closer to a: the short way round.
def near(+a: Q, +b: Q) -> Q:
  pick(F32.is_lt(dot(a, b), 0.0), neg(b), b)

def lerp4(a: Q, b: Q, +t: F32) -> Q:
  Q{ax, ay, az, aw} = a
  Q{bx, by, bz, bw} = b
  Q{F32.lerp(ax, bx, t), F32.lerp(ay, by, t), F32.lerp(az, bz, t), F32.lerp(aw, bw, t)}

# Straight blend, then back to length 1. Cheap, and close to slerp when
# a and b are near each other (one animation frame to the next).
def nlerp(+a: Q, +b: Q, +t: F32) -> Q:
  normalize(lerp4(a, near(a, b), t))

# The arc itself, th radians long: a weighs sin((1 − t)·th) / sin(th) and
# b weighs sin(t·th) / sin(th).
def arc_far(a: Q, b: Q, +t: F32, +th: F32) -> Q:
  +s = F32.sin(th)
  normalize(add(scale(a, (F32.sin(((1.0 - t) * th : F32)) / s : F32)), scale(b, (F32.sin((t * th : F32)) / s : F32))))

# Along the arc between a and b at a steady speed. When they are almost the
# same rotation, the arc is too short to measure and nlerp takes over.
def arc(+a: Q, +b: Q, +t: F32, +d: F32, close: Bool) -> Q:
  match close:
    case True{}:
      nlerp(a, b, t)
    case False{}:
      arc_far(a, b, t, F32.acos(d))

def slerp(+a: Q, b: Q, +t: F32) -> Q:
  +c = near(a, b)
  +d = dot(a, c)
  arc(a, c, t, d, F32.is_gt(d, 0.9995))

# Degrees per axis
# ================
# How a person reads and types a rotation in the editor: degrees around X,
# Y and Z. Applied in Unity's order: Z first, then X, then Y.

def pi() -> F32: 3.1415927

def to_radians(+d: F32) -> F32:
  (d * 0.017453292 : F32)

def to_deg(+r: F32) -> F32:
  (r * 57.29578 : F32)

def pickf(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

# The angle of the point (x, y) from the X axis, in -π..π, for every
# quadrant (F32.atan alone only knows half of them).
def atan2(+y: F32, +x: F32) -> F32:
  +a = F32.atan((y / x : F32))
  pickf(F32.is_gt(x, 0.0), a,
  pickf((F32.is_lt(x, 0.0) && F32.is_ge(y, 0.0)), (a + pi() : F32),
  pickf(F32.is_lt(x, 0.0), (a - pi() : F32),
  pickf(F32.is_gt(y, 0.0), (pi() / 2.0 : F32),
  pickf(F32.is_lt(y, 0.0), (0.0 - pi() / 2.0 : F32), 0.0)))))

# Degrees around X, Y, Z (each turn applied in the order Z, X, Y).
def from_degrees(+d: V.V3) -> Q:
  +qx = axis_angle(V.V3{1.0, 0.0, 0.0}, to_radians(V.x(d)))
  +qy = axis_angle(V.V3{0.0, 1.0, 0.0}, to_radians(V.y(d)))
  +qz = axis_angle(V.V3{0.0, 0.0, 1.0}, to_radians(V.z(d)))
  mul(qy, mul(qx, qz))

# Back to degrees around X, Y, Z, read from the rotation's matrix.
def to_degrees(q: Q) -> V.V3:
  Q{+x, +y, +z, +w} = q
  +sx = F32.clamp((0.0 - 2.0 * (y * z - w * x) : F32), (0.0 - 1.0 : F32), 1.0)
  V.V3{
    to_deg(F32.asin(sx)),
    to_deg(atan2((2.0 * (x * z + w * y) : F32), (1.0 - 2.0 * (x * x + y * y) : F32))),
    to_deg(atan2((2.0 * (x * y + w * z) : F32), (1.0 - 2.0 * (x * x + z * z) : F32)))}

