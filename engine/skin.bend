# Skin: what the GPU needs to bend a mesh with a skeleton.
#
# Every vertex of a skinned mesh follows up to 4 bones, each with a weight.
# For each bone the GPU gets one "skinning matrix":
#
#   skin(bone) = world(bone) · inverse(rest(bone))
#
# The inverse of the rest matrix takes a vertex from where the mesh was
# modeled to the bone's own space; the bone's matrix now takes it back out,
# wherever the bone went. At rest the two cancel and the mesh stays as
# modeled. The vertex shader (engine/shader/glsl.bend, skinned_vert) mixes
# its bones' matrices by weight: linear blend skinning. This is stage 6 of
# Gregory's pipeline ("the matrix palette"), and the same matrix as Blender's
# chan_mat after BKE_pose_bone_done and glTF's joint matrix.
#
# Weights are whole numbers from 0 to 65535 that sum to exactly 65535 per
# vertex (tools/gltf.ts writes them so). As integers, "they sum to the
# whole" is an exact law the checker can compute; the GPU reads them as
# normalized 16-bit values, so it divides by 65535 on its own.
#
# Limits now:
# - Rest matrices are inverted as rotation + translation, which needs a
#   rest pose with scale 1 (the importer refuses others).
# - Linear blending only: a joint twisted far loses volume (the "candy
#   wrapper"). Twist bones (engine/helpers.bend) spread the twist instead of
#   switching to dual quaternions.

import Base
import ./vec.bend as V
import ./transform.bend as Tr
import ./skeleton.bend as Sk
import ./pose.bend as P

# The inverse of a rotation + translation matrix: Rᵀ and −Rᵀ·t.
def rigid_inverse(m: V.M4) -> V.M4:
  V.M4{c0, c1, c2, c3} = m
  V.V4{+a, +b, +c, _} = c0
  V.V4{+d, +e, +f, _} = c1
  V.V4{+g, +h, +i, _} = c2
  V.V4{+x, +y, +z, _} = c3
  V.M4{
    V.V4{a, d, g, 0.0},
    V.V4{b, e, h, 0.0},
    V.V4{c, f, i, 0.0},
    V.V4{(0.0 - (a * x + b * y + c * z) : F32), (0.0 - (d * x + e * y + f * z) : F32), (0.0 - (g * x + h * y + i * z) : F32), 1.0}}

def inverses_go(ms: List<&2, V.M4>) -> List<&2, V.M4>:
  match ms:
    case Nil{}:
      Nil{}
    case h <> t:
      rigid_inverse(h) <> inverses_go(t)

# Every bone's inverse rest matrix (glTF's inverseBindMatrices).
def inverse_rest(+s: Sk.Skeleton) -> List<&2, V.M4>:
  inverses_go(P.model(s, P.rest(s)))

# The 16 numbers of a matrix, column by column.
def numbers(m: V.M4) -> List<&2, F32>:
  V.M4{c0, c1, c2, c3} = m
  V.V4{ax, ay, az, aw} = c0
  V.V4{bx, by, bz, bw} = c1
  V.V4{cx, cy, cz, cw} = c2
  V.V4{dx, dy, dz, dw} = c3
  [ax, ay, az, aw, bx, by, bz, bw, cx, cy, cz, cw, dx, dy, dz, dw]

def palette_go(ws: List<&2, V.M4>, vs: List<&2, V.M4>) -> List<&2, F32>:
  match ws:
    case Nil{}:
      Nil{}
    case w <> wt:
      match vs:
        case Nil{}:
          Nil{}
        case i <> it:
          List.append(&2, F32, numbers(V.mul(w, i)), palette_go(wt, it))

# The skinning matrices of a pose, 16 floats per bone in the skeleton's
# order, with the character standing where `place` puts it. `inverse` is
# inverse_rest(s), computed once per skeleton (engine/figure.bend keeps it).
def palette(+s: Sk.Skeleton, p: P.Pose, +place: Tr.Transform, inverse: List<&2, V.M4>) -> List<&2, F32>:
  palette_go(P.world(s, p, place), inverse)

# Weights
# =======

def whole() -> U32: 65535

def pick_b(c: Bool, a: Bool, b: Bool) -> Bool:
  match c:
    case True{}:
      a
    case False{}:
      b

# One vertex: 4 joints and 4 weights. The weights sum to the whole, at
# least one is above 0, every joint with weight is a bone of the skeleton,
# and no bone appears twice with weight.
def vertex_ok(+j0: U32, +j1: U32, +j2: U32, +j3: U32, +w0: U32, +w1: U32, +w2: U32, +w3: U32, +bones: U32) -> Bool:
  (U32.is_eq((w0 + w1 + w2 + w3 : U32), whole())
   && U32.is_gt(U32.max(U32.max(w0, w1), U32.max(w2, w3)), 0)
   && pick_b(U32.is_gt(w0, 0), U32.is_lt(j0, bones), True{})
   && pick_b(U32.is_gt(w1, 0), U32.is_lt(j1, bones), True{})
   && pick_b(U32.is_gt(w2, 0), U32.is_lt(j2, bones), True{})
   && pick_b(U32.is_gt(w3, 0), U32.is_lt(j3, bones), True{})
   && pick_b((U32.is_gt(w0, 0) && U32.is_gt(w1, 0)), U32.is_ne(j0, j1), True{})
   && pick_b((U32.is_gt(w0, 0) && U32.is_gt(w2, 0)), U32.is_ne(j0, j2), True{})
   && pick_b((U32.is_gt(w0, 0) && U32.is_gt(w3, 0)), U32.is_ne(j0, j3), True{})
   && pick_b((U32.is_gt(w1, 0) && U32.is_gt(w2, 0)), U32.is_ne(j1, j2), True{})
   && pick_b((U32.is_gt(w1, 0) && U32.is_gt(w3, 0)), U32.is_ne(j1, j3), True{})
   && pick_b((U32.is_gt(w2, 0) && U32.is_gt(w3, 0)), U32.is_ne(j2, j3), True{}))

# Every vertex of a skin: 8 numbers each, joints then weights, in a row.
def weights_ok(xs: List<&2, U32>, +bones: U32) -> Bool:
  match xs:
    case j0 <> j1 <> j2 <> j3 <> w0 <> w1 <> w2 <> w3 <> rest:
      (vertex_ok(j0, j1, j2, j3, w0, w1, w2, w3, bones) && weights_ok(rest, bones))
    case _:
      True{}
