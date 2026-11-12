# Water: the shape and material of the scene's water (content/scene.bend
# puts it in the World).
#
# This is content, not engine code: one particular water. The engine's
# generic types are in engine/: a mesh (engine/mesh.bend) for the shape and
# a material (engine/material.bend: a graph and the values of its
# parameters) that says what color each pixel gets.
#
# Limits now:
# - One flat color and no light, so the 3200 triangles do not show one by
#   one; they will once the material moves its vertices (waves).
# - It lies on y = 0 with the grid, and only the drawing order in main.js
#   keeps the grid on top (no depth test yet).
# - The material's graph is a single parameter. It grows into the real
#   water graph (step 11).

import Base
import ../engine/vec.bend as V
import ../engine/color.bend as C
import ../engine/mesh.bend as M
import ../engine/shader/node.bend as N
import ../engine/material.bend as Mat
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
