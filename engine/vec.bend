# Vectors and 4x4 matrices: the math every other part of the engine stands on.
# Matrices are column-major (like WebGL): M4{c0, c1, c2, c3} holds four columns.

import Base

type V3 is Data:
  V3{x: F32, y: F32, z: F32}

type V4 is Data:
  V4{x: F32, y: F32, z: F32, w: F32}

type M4 is Data:
  M4{c0: V4, c1: V4, c2: V4, c3: V4}

def add(a: V3, b: V3) -> V3:
  V3{ax, ay, az} = a
  V3{bx, by, bz} = b
  V3{(ax + bx : F32), (ay + by : F32), (az + bz : F32)}

def sub(a: V3, b: V3) -> V3:
  V3{ax, ay, az} = a
  V3{bx, by, bz} = b
  V3{(ax - bx : F32), (ay - by : F32), (az - bz : F32)}

def scale(a: V3, +k: F32) -> V3:
  V3{x, y, z} = a
  V3{(x * k : F32), (y * k : F32), (z * k : F32)}

def dot(a: V3, b: V3) -> F32:
  V3{ax, ay, az} = a
  V3{bx, by, bz} = b
  (ax * bx + ay * by + az * bz : F32)

def cross(a: V3, b: V3) -> V3:
  V3{+ax, +ay, +az} = a
  V3{+bx, +by, +bz} = b
  V3{(ay * bz - az * by : F32), (az * bx - ax * bz : F32), (ax * by - ay * bx : F32)}

def norm(+a: V3) -> V3:
  scale(a, (1.0 / F32.max(F32.sqrt(dot(a, a)), 0.000001) : F32))

# A 4-vector scaled, and two added: the pieces of a matrix product.
def scale4(a: V4, +k: F32) -> V4:
  V4{x, y, z, w} = a
  V4{(x * k : F32), (y * k : F32), (z * k : F32), (w * k : F32)}

def add4(a: V4, b: V4) -> V4:
  V4{ax, ay, az, aw} = a
  V4{bx, by, bz, bw} = b
  V4{(ax + bx : F32), (ay + by : F32), (az + bz : F32), (aw + bw : F32)}

# M * v: each column weighted by one component of v.
def apply(m: M4, v: V4) -> V4:
  M4{c0, c1, c2, c3} = m
  V4{x, y, z, w} = v
  add4(add4(scale4(c0, x), scale4(c1, y)), add4(scale4(c2, z), scale4(c3, w)))

# A * B: A applied to each column of B.
def mul(+a: M4, b: M4) -> M4:
  M4{c0, c1, c2, c3} = b
  M4{apply(a, c0), apply(a, c1), apply(a, c2), apply(a, c3)}

# The 16 numbers in column-major order, as WebGL reads them.
def flat(m: M4) -> List<F32>:
  M4{c0, c1, c2, c3} = m
  V4{ax, ay, az, aw} = c0
  V4{bx, by, bz, bw} = c1
  V4{cx, cy, cz, cw} = c2
  V4{dx, dy, dz, dw} = c3
  [ax, ay, az, aw, bx, by, bz, bw, cx, cy, cz, cw, dx, dy, dz, dw]

# One component of a vector.
def x(v: V3) -> F32:
  V3{a, _, _} = v
  a

def y(v: V3) -> F32:
  V3{_, b, _} = v
  b

def z(v: V3) -> F32:
  V3{_, _, c} = v
  c
