# Materials: a graph (engine/shader/node.bend) together with the values of
# its parameters. The same idea as a Material and a Material Instance in
# Unreal, or a material using a Shader Graph in Unity.
#
# The graph decides the shader; it is compiled once. The values are
# uniforms: changing one changes what you see without compiling anything.
# An instance is the same graph with other values, so two waters (a sea and
# a lake) can share one shader.
#
# A value is a parameter's name and its numbers: one for a float, three for
# a vec3 (a color). main.js reads each value's uniform name from here and
# hands the numbers to the GPU; it never writes a name itself.
#
# Limits now:
# - Meshes only (the mesh shader in engine/shader/glsl.bend). Lines keep
#   their own fixed shader.
# - A value is a plain list of numbers; its size is checked against the
#   parameter's type by a law (complete), not by Bend's types. A material
#   nobody wrote that law for can carry a wrong size, and the GPU then
#   ignores or misreads it.
# - Nothing in the editor changes values yet: no fields or sliders exist,
#   and none are added until they are asked for.
# - Each instance compiles its own copy of the shader: main.js does not
#   share programs between materials with the same graph yet.

import Base
import ./shader/node.bend as N
import ./shader/compile.bend as G
import ./shader/glsl.bend as Glsl

type Value is Data:
  Value{name: String, numbers: List<&2, F32>}

type Material is Data:
  Material{graph: N.Node, values: List<&2, Value>}

def graph(m: Material) -> N.Node:
  Material{g, _} = m
  g

def values(m: Material) -> List<&2, Value>:
  Material{_, vs} = m
  vs

# The fragment shader of a material, written by Bend.
def frag(m: Material) -> String:
  Glsl.mesh_frag(graph(m))

# The uniform a value goes to, and its numbers (for main.js).
def uniform(v: Value) -> String:
  Value{nm, _} = v
  G.uniform(nm)

def numbers(v: Value) -> List<&2, F32>:
  Value{_, xs} = v
  xs

# An instance: the same graph with other values.
def instance(m: Material, vs: List<&2, Value>) -> Material:
  Material{g, _} = m
  Material{g, vs}

# Completeness
# ============

# Does this value fill parameter p: same name, and as many numbers as its
# type holds?
def fills_param(+pn: String, +k: N.Ty, v: Value) -> Bool:
  Value{+nm, +xs} = v
  (String.eq(pn, nm) && Nat.is_eq(List.length(&2, F32, xs), N.size(k)))

def fills(+p: N.Node, v: Value) -> Bool:
  match p:
    case N.Param{+pn, +k}:
      fills_param(pn, k, v)
    case _:
      False{}

def filled(+p: N.Node, vs: List<&2, Value>) -> Bool:
  match vs:
    case Nil{}:
      False{}
    case h <> t:
      (fills(p, h) || filled(p, t))

def all_filled(ps: List<&2, N.Node>, +vs: List<&2, Value>) -> Bool:
  match ps:
    case Nil{}:
      True{}
    case h <> t:
      (filled(h, vs) && all_filled(t, vs))

# A material is complete when every parameter of its graph has a value of
# the right size. The laws check it for each material.
def complete(+m: Material) -> Bool:
  all_filled(N.params(graph(m)), values(m))
