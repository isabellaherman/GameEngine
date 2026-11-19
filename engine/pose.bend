# Pose: where every bone of a skeleton is, at one moment.
#
# A pose holds one Transform per bone, in the skeleton's order, each
# relative to the bone's parent (the "local pose"). Clips and blends work
# on local poses. To draw or skin a character, the engine needs each bone
# measured from the character's origin (the "model pose"):
#
#   model(bone) = model(parent) · local(bone)
#
# Because every parent comes before its children (engine/skeleton.bend),
# one pass down the list computes them all. This is stage 3 of Gregory's
# animation pipeline ("generate the global pose"), and the same as
# BKE_pose_where_is_bone in Blender.
#
# Limits now:
# - The model pose is a list of 4×4 matrices; finding a parent's matrix
#   walks the list, so a skeleton of n bones costs about n²/2 steps.
#   Fine for a few hundred bones; an array would make it n.
# - Scale is carried through the matrices but nothing uses it yet.

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr
import ./skeleton.bend as Sk

type Pose is Data:
  Pose{locals: List<&2, Tr.Transform>}

# Choosing between two values (a match must look at a parameter).
def pick_q(c: Bool, a: Q.Q, b: Q.Q) -> Q.Q:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_tr(c: Bool, a: Tr.Transform, b: Tr.Transform) -> Tr.Transform:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_list(c: Bool, a: List<&2, Tr.Transform>, b: List<&2, Tr.Transform>) -> List<&2, Tr.Transform>:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_f(c: Bool, a: List<&2, F32>, b: List<&2, F32>) -> List<&2, F32>:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_m4(c: Bool, a: V.M4, b: V.M4) -> V.M4:
  match c:
    case True{}:
      a
    case False{}:
      b

def locals(p: Pose) -> List<&2, Tr.Transform>:
  Pose{xs} = p
  xs

# The rest pose: every bone where the skeleton puts it.
def rest_go(xs: List<&2, Sk.Bone>) -> List<&2, Tr.Transform>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      Sk.rest(h) <> rest_go(t)

def rest(s: Sk.Skeleton) -> Pose:
  Pose{rest_go(Sk.bones(s))}

# Local transform i of a pose (identity past the end).
def local_at_go(xs: List<&2, Tr.Transform>, +i: U32) -> Tr.Transform:
  match xs:
    case Nil{}:
      Tr.identity()
    case +h <> +t:
      pick_tr(U32.is_eq(i, 0), h, local_at_go(t, (i - 1 : U32)))

def local_at(p: Pose, +i: U32) -> Tr.Transform:
  Pose{xs} = p
  local_at_go(xs, i)

# The pose with bone i's local transform replaced.
def set_go(xs: List<&2, Tr.Transform>, +i: U32, +x: Tr.Transform) -> List<&2, Tr.Transform>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      pick_list(U32.is_eq(i, 0), x <> t, h <> set_go(t, (i - 1 : U32), x))

def set(p: Pose, +i: U32, +x: Tr.Transform) -> Pose:
  Pose{xs} = p
  Pose{set_go(xs, i, x)}

# Model pose
# ==========

def ident4() -> V.M4:
  Tr.to_m4(Tr.identity())

# Matrix k of a list (the first is 0).
def m4_at(xs: List<&2, V.M4>, +k: U32) -> V.M4:
  match xs:
    case Nil{}:
      ident4()
    case +h <> +t:
      pick_m4(U32.is_eq(k, 0), h, m4_at(t, (k - 1 : U32)))

# Walks bones and locals together. `done` holds the matrices computed so
# far, newest first, so bone i's parent p sits at position i − 1 − p.
def model_go(bs: List<&2, Sk.Bone>, ls: List<&2, Tr.Transform>, +base: V.M4, +i: U32, +done: List<&2, V.M4>) -> List<&2, V.M4>:
  match bs:
    case Nil{}:
      List.reverse(&2, V.M4, done)
    case +b <> bt:
      match ls:
        case Nil{}:
          List.reverse(&2, V.M4, done)
        case l <> lt:
          +own = Tr.to_m4(l)
          +m = pick_m4(U32.is_eq(i, 0), V.mul(base, own), V.mul(m4_at(done, ((i - 1 : U32) - Sk.parent(b) : U32)), own))
          model_go(bt, lt, base, (i + 1 : U32), m <> done)

# Every bone's matrix, measured from the character's origin.
def model(s: Sk.Skeleton, p: Pose) -> List<&2, V.M4>:
  model_go(Sk.bones(s), locals(p), ident4(), 0, Nil{})

# The same, measured from the World's origin: the character stands where
# its thing's place (a Transform) puts it.
def world(s: Sk.Skeleton, p: Pose, +place: Tr.Transform) -> List<&2, V.M4>:
  model_go(Sk.bones(s), locals(p), Tr.to_m4(place), 0, Nil{})

# Where a matrix puts the point (x, y, z).
def at_point(+m: V.M4, +x: F32, +y: F32, +z: F32) -> V.V3:
  V.xyz(V.apply(m, V.V4{x, y, z, 1.0}))

# A bone's head (its origin) and tail (length along its own +Y).
def head(+m: V.M4) -> V.V3:
  at_point(m, 0.0, 0.0, 0.0)

def tail(+m: V.M4, +len: F32) -> V.V3:
  at_point(m, 0.0, len, 0.0)

# Drawing
# =======

# A bone's color by role: deform white, twist yellow, support orange,
# chain blue. The root is not drawn.
def color(r: Sk.Role) -> List<&2, F32>:
  match r:
    case Sk.Root{}:
      [0.5, 0.5, 0.5]
    case Sk.Deform{}:
      [0.92, 0.92, 0.92]
    case Sk.Twist{}:
      [0.95, 0.8, 0.25]
    case Sk.Support{}:
      [0.95, 0.5, 0.2]
    case Sk.Chain{}:
      [0.35, 0.6, 0.95]

def v3_list(+v: V.V3) -> List<&2, F32>:
  [V.x(v), V.y(v), V.z(v)]

# One line per bone with a length, from head to tail: 6 floats per end
# (x y z r g b), as the World's grid lines are.
def line(+b: Sk.Bone, +m: V.M4) -> List<&2, F32>:
  +c = color(Sk.role(b))
  List.concat(&2, F32, [v3_list(head(m)), c, v3_list(tail(m, Sk.length(b))), c])

def lines_go(bs: List<&2, Sk.Bone>, ms: List<&2, V.M4>) -> List<&2, F32>:
  match bs:
    case Nil{}:
      Nil{}
    case +b <> bt:
      match ms:
        case Nil{}:
          Nil{}
        case m <> mt:
          List.append(&2, F32, pick_f(F32.is_gt(Sk.length(b), 0.0), line(b, m), Nil{}), lines_go(bt, mt))

# The skeleton in a pose, as lines in the World, placed by `place`.
def lines(+s: Sk.Skeleton, p: Pose, +place: Tr.Transform) -> List<&2, F32>:
  lines_go(Sk.bones(s), world(s, p, place))

# Rest rotations
# ==============

# Bone i's rotation at rest, measured from the character's origin (its
# parents' rotations and its own, composed). `fuel` bounds the climb: no
# skeleton is deeper than 64 bones.
def rest_rotation_go(fuel: Nat, +s: Sk.Skeleton, +i: U32) -> Q.Q:
  match fuel:
    case 0n:
      Q.identity()
    case 1n+f:
      +own = Tr.rotation(Sk.rest(Sk.at(s, i)))
      pick_q(U32.is_eq(i, 0), own, Q.mul(rest_rotation_go(f, s, Sk.parent_of(s, i)), own))

def rest_rotation(+s: Sk.Skeleton, +i: U32) -> Q.Q:
  rest_rotation_go(64n, s, i)

# A turn given in the character's own axes (X to its left, Y up, Z ahead),
# as the local rotation bone i takes: its rest rotation, then the turn,
# measured from where the bone points at rest. This is how code (and the
# walk in engine/gait.bend) says "swing the thigh forward" without knowing
# how each bone's own axes are set.
def turned(+s: Sk.Skeleton, +i: U32, +turn: Q.Q) -> Q.Q:
  +g = rest_rotation(s, i)
  Q.normalize(Q.mul(Tr.rotation(Sk.rest(Sk.at(s, i))), Q.mul(Q.conj(g), Q.mul(turn, g))))
