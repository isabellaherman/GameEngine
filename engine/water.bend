# Water: the first thing that lives in the World.
#
# It has two parts, like a water body in other engines: a shape (a mesh,
# engine/mesh.bend) and a material (engine/material.bend: a graph and the
# values of its parameters) that says what color each pixel gets. The
# World (world.bend) only holds the rules of space; things in it, like this
# water, have their own files.
#
# Limits now:
# - The engine has no scene or game objects yet, so nothing says *where* a
#   thing is: this water is built already in place, centered at the origin
#   on y = 0. When game objects exist, the water becomes one, with its own
#   position.
# - One flat color and no light, so the 3200 triangles do not show one by
#   one; they will once the material moves its vertices (waves).
# - It lies on y = 0 with the grid, and only the drawing order in main.js
#   keeps the grid on top (no depth test yet).
# - This file is content (this one water), not engine code: it sits in
#   engine/ only because the generic "thing" type (engine/scene.bend, step
#   9) does not exist yet. Then the water becomes data in the scene (a thing
#   named "water" with a plane shape and the water material), this file
#   keeps only the material, and it can move to a content folder beside
#   engine/, the way Unreal keeps a project's Content apart from the engine.
# - The material's graph is a single parameter. It grows into the real
#   water graph (step 10).

import Base
import ./vec.bend as V
import ./color.bend as C
import ./mesh.bend as M
import ./shader/node.bend as N
import ./material.bend as Mat
import ../node_modules/bend-ui/TOKENS.bend as T

# The shape: a 20 m square cut into 40 × 40 cells, half a meter each.
# Waves will move each vertex, so it needs many of them.
def size() -> F32: 20.0
def cells() -> U32: 40

def shape() -> M.Mesh:
  M.plane(size(), cells())

# The material: for now its graph is one parameter, "tone" (a color), and
# its value is Bend-UI's surface tone. Changing the value recolors the water
# without compiling the shader again.
def tone() -> List<&2, F32>:
  +c = C.rgb(T.dark_surface_2())
  [V.x(c), V.y(c), V.z(c)]

def material() -> Mat.Material:
  Mat.Material{N.Param{"tone", N.Vec3{}}, [Mat.Value{"tone", tone()}]}
