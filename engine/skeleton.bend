# Skeleton: the bones of a character, at rest.
#
# The engine's rig standard. Its structure comes from the reference rig
# (refs/, never shipped): a few bones that clips animate, and many more
# that the engine computes from them.
#
# Every bone has a role, which says who moves it:
# - Root     on the ground, under everything. Moving it moves the whole
#            character. Carries no weight.
# - Deform   body and fingers: the bones a clip animates.
# - Twist    in the middle of an arm or leg segment: spreads a turn along
#            it, so wrists and ankles do not collapse.
# - Support  at a joint: holds the volume when the joint bends (elbow,
#            knee, armpit, hip), or holds a chain.
# - Chain    hair, cloth, accessories: moved by springs, after animation.
#
# A slot names the bone's place in a humanoid body ("hips",
# "upper_arm.L", "index_2.R"), in the vocabulary Unity and VRM use. It is
# how clips and retargeting find bones without knowing their names. Bones
# without a place (helpers, chains) have the slot "".
#
# Bones are a list. A bone's parent is an index into that list, and the
# laws below keep the list in an order that makes every pass simple:
# - one root, at index 0, of kind Root, which is its own parent;
# - every other bone comes after its parent (parent < index), so the
#   world pose is one pass from the top, and no bone can be its own
#   ancestor;
# - a Deform bone hangs only from Deform bones or the root, so "play the
#   clip, then compute the helpers" always works.
#
# Limits now:
# - The rest pose is a Transform per bone, relative to the parent. No bone
#   length is used yet except to draw the bones.
# - A slot is a String, not a type with a case per place: a mistyped slot
#   is not caught by the compiler, only by the laws that look for slots.
# - The laws here look at integers and kinds only. Positions and rotations
#   are floats, which the law checker does not compute; tests check those.

import Base
import ./vec.bend as V
import ./quat.bend as Q
import ./transform.bend as Tr

type Role is Data:
  Root{}
  Deform{}
  Twist{}
  Support{}
  Chain{}

type Bone is Data:
  Bone{name: String, slot: String, role: Role, parent: U32, rest: Tr.Transform, length: F32}

type Skeleton is Data:
  Skeleton{bones: List<&2, Bone>}

def bones(s: Skeleton) -> List<&2, Bone>:
  Skeleton{xs} = s
  xs

def name(b: Bone) -> String:
  Bone{n, _, _, _, _, _} = b
  n

def slot(b: Bone) -> String:
  Bone{_, s, _, _, _, _} = b
  s

def role(b: Bone) -> Role:
  Bone{_, _, k, _, _, _} = b
  k

def parent(b: Bone) -> U32:
  Bone{_, _, _, p, _, _} = b
  p

def rest(b: Bone) -> Tr.Transform:
  Bone{_, _, _, _, r, _} = b
  r

def length(b: Bone) -> F32:
  Bone{_, _, _, _, _, l} = b
  l

def count(s: Skeleton) -> U32:
  Skeleton{xs} = s
  U32.from_nat(List.length(&2, Bone, xs))

# Roles
# =====

def is_root(k: Role) -> Bool:
  match k:
    case Root{}:
      True{}
    case _:
      False{}

def is_deform(k: Role) -> Bool:
  match k:
    case Deform{}:
      True{}
    case _:
      False{}

# Clips animate it: the root (it carries the character) and Deform bones.
def is_animated(k: Role) -> Bool:
  match k:
    case Root{}:
      True{}
    case Deform{}:
      True{}
    case _:
      False{}

# The engine computes it after the clip: Twist, Support and Chain bones.
def is_computed(k: Role) -> Bool:
  match k:
    case Twist{}:
      True{}
    case Support{}:
      True{}
    case Chain{}:
      True{}
    case _:
      False{}

def role_code(k: Role) -> U32:
  match k:
    case Root{}:
      0
    case Deform{}:
      1
    case Twist{}:
      2
    case Support{}:
      3
    case Chain{}:
      4

# Lookups
# =======

def pick_bone(c: Bool, a: Bone, b: Bone) -> Bone:
  match c:
    case True{}:
      a
    case False{}:
      b

def pick_u32(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# Bone i (the first is 0). Past the end: a root at the origin, so a wrong
# index never breaks a frame.
def at_go(xs: List<&2, Bone>, +i: U32) -> Bone:
  match xs:
    case Nil{}:
      Bone{"", "", Root{}, 0, Tr.identity(), 0.0}
    case +h <> +t:
      pick_bone(U32.is_eq(i, 0), h, at_go(t, (i - 1 : U32)))

def at(s: Skeleton, +i: U32) -> Bone:
  Skeleton{xs} = s
  at_go(xs, i)

def role_of(+s: Skeleton, +i: U32) -> Role:
  role(at(s, i))

def parent_of(+s: Skeleton, +i: U32) -> U32:
  parent(at(s, i))

# The index of the bone in this slot, or the bone count when no bone has it.
def find_slot_go(xs: List<&2, Bone>, +want: String, +i: U32) -> U32:
  match xs:
    case Nil{}:
      i
    case h <> t:
      pick_u32(String.eq(slot(h), want), i, find_slot_go(t, want, (i + 1 : U32)))

def find_slot(s: Skeleton, +want: String) -> U32:
  Skeleton{xs} = s
  find_slot_go(xs, want, 0)

# How many bones have this slot.
def slot_count_go(xs: List<&2, Bone>, +want: String) -> U32:
  match xs:
    case Nil{}:
      0
    case h <> t:
      (pick_u32(String.eq(slot(h), want), 1, 0) + slot_count_go(t, want) : U32)

def slot_count(s: Skeleton, +want: String) -> U32:
  Skeleton{xs} = s
  slot_count_go(xs, want)

# How many bones have each role (by role_code).
def role_count_go(xs: List<&2, Bone>, +code: U32) -> U32:
  match xs:
    case Nil{}:
      0
    case h <> t:
      (pick_u32(U32.is_eq(role_code(role(h)), code), 1, 0) + role_count_go(t, code) : U32)

# [root, deform, twist, support, chain]
def role_counts(+s: Skeleton) -> List<&2, U32>:
  +xs = bones(s)
  [role_count_go(xs, 0), role_count_go(xs, 1), role_count_go(xs, 2), role_count_go(xs, 3), role_count_go(xs, 4)]

# The laws' checks
# ================

def not(b: Bool) -> Bool:
  match b:
    case True{}:
      False{}
    case False{}:
      True{}

def no_root(xs: List<&2, Bone>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      (not(is_root(role(h))) && no_root(t))

# Bone 0 is a Root and its own parent, and no other bone is a Root.
def first_is_root(xs: List<&2, Bone>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case +h <> t:
      (is_root(role(h)) && U32.is_eq(parent(h), 0) && no_root(t))

def one_root(s: Skeleton) -> Bool:
  Skeleton{xs} = s
  first_is_root(xs)

# Every bone after the first comes after its parent.
def parents_go(xs: List<&2, Bone>, +i: U32) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +h <> t:
      (U32.is_lt(parent(h), i) && parents_go(t, (i + 1 : U32)))

def parents_before(s: Skeleton) -> Bool:
  Skeleton{xs} = s
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      parents_go(t, 1)

# A Deform bone's parent is animated too (Deform or the root).
def deform_ok(+s: Skeleton, +b: Bone) -> Bool:
  (not(is_deform(role(b))) || is_animated(role_of(s, parent(b))))

# A Deform bone hangs only from Deform bones or the root.
def deform_go(+s: Skeleton, xs: List<&2, Bone>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +h <> t:
      (deform_ok(s, h) && deform_go(s, t))


def deform_under_deform(+s: Skeleton) -> Bool:
  deform_go(s, bones(s))

# All the structural laws at once.
def valid(+s: Skeleton) -> Bool:
  (one_root(s) && parents_before(s) && deform_under_deform(s))
