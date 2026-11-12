# Transform: where a thing is, how it is turned and how big it is. The same
# as Unity's Transform and Unreal's FTransform.
#
# Three parts, applied to each point of the thing in this order:
#   1. scale    stretch along the thing's own X, Y, Z (1 = as built)
#   2. rotation turn it (a quaternion, engine/quat.bend)
#   3. position move it, in meters, to its place in the World
#
# As one matrix: M = T · R · S (column-major, like vec.bend). The GPU gets
# this "model" matrix and places every vertex with it, so a mesh is built
# once, around its own origin, and the transform alone says where it goes.
#
# Limits now:
# - No parent and child yet: a transform is always measured from the
#   World's origin. A thing that follows another (a hand on an arm) needs
#   the parent's matrix times the child's; that comes with the scene's tree.
# - Scale of 0 on any axis flattens the thing, and a negative scale mirrors
#   it and turns its triangles inside out (the GPU then sees their back).
#   Nothing stops either yet.
# - The law checker does not compute floats, so tests/transform.bend checks
#   the math numerically.

import Base
import ./vec.bend as V
import ./quat.bend as Q

type Transform is Data:
  Transform{position: V.V3, rotation: Q.Q, scale: V.V3}

# At the origin, not turned, as built.
def identity() -> Transform:
  Transform{V.V3{0.0, 0.0, 0.0}, Q.identity(), V.V3{1.0, 1.0, 1.0}}

# At a place, not turned, as built.
def at(p: V.V3) -> Transform:
  Transform{p, Q.identity(), V.V3{1.0, 1.0, 1.0}}

def position(t: Transform) -> V.V3:
  Transform{p, _, _} = t
  p

def rotation(t: Transform) -> Q.Q:
  Transform{_, r, _} = t
  r

def scale(t: Transform) -> V.V3:
  Transform{_, _, s} = t
  s

def with_position(t: Transform, p: V.V3) -> Transform:
  Transform{_, r, s} = t
  Transform{p, r, s}

def with_rotation(t: Transform, r: Q.Q) -> Transform:
  Transform{p, _, s} = t
  Transform{p, r, s}

def with_scale(t: Transform, s: V.V3) -> Transform:
  Transform{p, r, _} = t
  Transform{p, r, s}

# A point of the thing, in the World: scale, then turn, then move.
def point(+t: Transform, +v: V.V3) -> V.V3:
  Transform{+p, +r, +s} = t
  V.add(Q.rotate(r, V.V3{(V.x(v) * V.x(s) : F32), (V.y(v) * V.y(s) : F32), (V.z(v) * V.z(s) : F32)}), p)

# The model matrix T · R · S: the rotation's columns stretched by the
# scale, and the position as the last column.
def place(rm: V.M4, +p: V.V3, +s: V.V3) -> V.M4:
  V.M4{c0, c1, c2, _} = rm
  V.M4{
    V.scale4(c0, V.x(s)),
    V.scale4(c1, V.y(s)),
    V.scale4(c2, V.z(s)),
    V.V4{V.x(p), V.y(p), V.z(p), 1.0}}

def to_m4(t: Transform) -> V.M4:
  Transform{p, r, s} = t
  place(Q.to_m4(r), p, s)

# The 16 numbers of the model matrix, as the GPU reads them.
def flat(+t: Transform) -> List<F32>:
  V.flat(to_m4(t))
