# Nodes: the pieces of a material graph, the same idea as Unity's Shader
# Graph nodes and Unreal's material expressions.
#
# A node is an expression: a number, a color, the time, a parameter, or a
# math step on other nodes. Each node has a type: a float (one number) or a vec3 (three,
# like a color or a direction). engine/shader/compile.bend turns a graph
# into GLSL lines, one per node. ty() works out a node's type
# and gives Bad when the pieces do not fit, so a wrong graph fails a law in
# `bun run check` instead of failing in the GPU driver.
#
# Limits now:
# - A graph is written as a tree. A node used in two places is written out
#   twice here, and compile.bend finds that the two are the same and gives
#   them one line.
# - Only float and vec3. vec2, vec4 and textures come when a node needs
#   them.
# - Types are checked by laws (ty(graph) == the type its output needs), not
#   by Bend's own type checker. A graph nobody wrote a law for can still
#   be wrong until the driver compiles it.
# - Constants (Num, Rgb) are written into the text, so changing one
#   rebuilds the shader. A value meant to change while you watch is a Param:
#   a uniform, set from engine/material.bend without rebuilding.
# - Time reads 0 for now: main.js does not run the clock yet
#   (engine/time.bend).
# - F32.show writes 1.0 as "1", which GLSL reads as an integer and refuses
#   to mix with floats. number() adds the ".0" back.

import Base

type Ty is Data:
  Float{}
  Vec3{}
  Bad{}

type Node is Data:
  Num{value: F32}                 # a float constant
  Rgb{r: F32, g: F32, b: F32}     # a vec3 constant, 0..1 per channel
  Time{}                          # the engine clock in seconds (u_time)
  Add{a: Node, b: Node}           # a + b, same types
  Mul{a: Node, b: Node}           # a * b, same types, or vec3 * float
  Sin{a: Node}                    # sine, of each channel for a vec3
  Mix{a: Node, b: Node, t: Node}  # from a (t = 0) to b (t = 1); t is a float
  Param{name: String, kind: Ty}   # a named value set by the material (a uniform)

# Types
# =====

def same(a: Ty, b: Ty) -> Ty:
  match a b:
    case Float{} Float{}:
      Float{}
    case Vec3{} Vec3{}:
      Vec3{}
    case _ _:
      Bad{}

# a * b: the same type, or a vec3 scaled by a float (either side).
def scaled(a: Ty, b: Ty) -> Ty:
  match a b:
    case Float{} Float{}:
      Float{}
    case Vec3{} Vec3{}:
      Vec3{}
    case Vec3{} Float{}:
      Vec3{}
    case Float{} Vec3{}:
      Vec3{}
    case _ _:
      Bad{}

def wave(a: Ty) -> Ty:
  match a:
    case Bad{}:
      Bad{}
    case t:
      t

# mix(a, b, t): a and b of one type, t a float.
def blend(ab: Ty, t: Ty) -> Ty:
  match t:
    case Float{}:
      ab
    case _:
      Bad{}

def ty(n: Node) -> Ty:
  match n:
    case Num{_}:
      Float{}
    case Rgb{_, _, _}:
      Vec3{}
    case Time{}:
      Float{}
    case Param{_, k}:
      k
    case Add{a, b}:
      same(ty(a), ty(b))
    case Mul{a, b}:
      scaled(ty(a), ty(b))
    case Sin{a}:
      wave(ty(a))
    case Mix{a, b, t}:
      blend(same(ty(a), ty(b)), ty(t))

# Numbers as GLSL text
# ====================

def has_point(+s: String) -> Bool:
  (String.contains(s, ".") || String.contains(s, "e"))

def with_point(s: String, has: Bool) -> String:
  match has:
    case True{}:
      s
    case False{}:
      String.append(s, ".0")

# A float as GLSL reads it: always with a point (1 → 1.0).
def number(+v: F32) -> String:
  +s = F32.show(v)
  with_point(s, has_point(s))

# Parameters
# ==========

def ty_eq(a: Ty, b: Ty) -> Bool:
  match a b:
    case Float{} Float{}:
      True{}
    case Vec3{} Vec3{}:
      True{}
    case Bad{} Bad{}:
      True{}
    case _ _:
      False{}

# How many numbers a value of this type holds: 1 for a float, 3 for a vec3.
def size(t: Ty) -> Nat:
  match t:
    case Float{}:
      1n
    case Vec3{}:
      3n
    case Bad{}:
      0n

# Every Param in a graph, in the order they appear (a Param used twice is
# listed twice).
def params(n: Node) -> List<&2, Node>:
  match n:
    case Param{name, k}:
      [Param{name, k}]
    case Add{a, b}:
      List.append(&2, Node, params(a), params(b))
    case Mul{a, b}:
      List.append(&2, Node, params(a), params(b))
    case Sin{a}:
      params(a)
    case Mix{a, b, t}:
      List.append(&2, Node, params(a), List.append(&2, Node, params(b), params(t)))
    case _:
      Nil{}

