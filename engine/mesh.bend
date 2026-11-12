# Meshes: surfaces made of triangles, the shape of everything solid the
# engine draws.
#
# A mesh is a list of vertices and a list of indices. Each vertex is its
# position x, y, z in meters. Every three indices make one triangle, naming
# three vertices by their place in the list (the first is 0). Corners shared
# by several triangles are stored once.
#
# Triangles wind counterclockwise seen from their front, so the right-hand
# rule gives the side they face.
#
# Limits now:
# - A vertex is only a position. No normal (needed for light), no UV
#   (needed for textures), no color. Each comes when something needs it.
# - Nothing checks depth when main.js draws: what is drawn last shows on
#   top. That works while everything lies on the ground; meshes in front of
#   each other will need the GPU's depth test.
# - A mesh is built once, as Bend lists, and main.js copies it into a flat
#   array for the GPU. Building it every frame would be slow, so moving
#   vertices (waves) belongs in the vertex shader, not here.
# - The laws check a small plane (3 × 3 cells), because the checker works
#   it out in full. Bigger planes run the same code.

import Base

type Mesh is Data:
  Mesh{vertices: List<&2, F32>, indices: List<&2, U32>}

def vertices(m: Mesh) -> List<&2, F32>:
  Mesh{v, _} = m
  v

def indices(m: Mesh) -> List<&2, U32>:
  Mesh{_, i} = m
  i

# A flat square on the ground (y = 0), centered at the origin, `size` meters
# on a side and cut into `cells` × `cells` squares of two triangles each.
# Water needs many vertices, because its waves move each vertex.

# Vertex k of the (n + 1) × (n + 1) corners, row by row along X.
def corner(+k: U32, +n1: U32, +h: F32, +step: F32) -> List<&2, F32>:
  +i = U32.to_f32((k % n1 : U32))
  +j = U32.to_f32((k / n1 : U32))
  [(i * step - h : F32), 0.0, (j * step - h : F32)]

def corners_go(fuel: Nat, +k: U32, +n1: U32, +h: F32, +step: F32, acc: List<&2, F32>) -> List<&2, F32>:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      corners_go(p, (k - 1 : U32), n1, h, step, List.append(&2, F32, corner(k, n1, h, step), acc))

# Cell c's two triangles. a is its first corner, b the next one along X,
# d and e the same two one row further along Z.
# Seen from above (+Y) both wind counterclockwise, so the square faces up.
def cell(+c: U32, +n: U32) -> List<&2, U32>:
  +n1 = (n + 1 : U32)
  +a = ((c / n : U32) * n1 + (c % n : U32) : U32)
  +b = (a + 1 : U32)
  +d = (a + n1 : U32)
  +e = (d + 1 : U32)
  [a, d, b, b, d, e]

def cells_go(fuel: Nat, +c: U32, +n: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      cells_go(p, (c - 1 : U32), n, List.append(&2, U32, cell(c, n), acc))

def plane(+size: F32, +cells: U32) -> Mesh:
  +n1 = (cells + 1 : U32)
  +corners = (n1 * n1 : U32)
  +squares = (cells * cells : U32)
  +h = (size / 2.0 : F32)
  +step = (size / U32.to_f32(cells) : F32)
  Mesh{
    corners_go(U32.to_nat(corners), (corners - 1 : U32), n1, h, step, Nil{}),
    cells_go(U32.to_nat(squares), (squares - 1 : U32), cells, Nil{})}

# Counts, for the laws: how many vertices and triangles a mesh has.
def vertex_count(m: Mesh) -> Nat:
  Mesh{v, _} = m
  Nat.div(List.length(&2, F32, v), 3n)

def triangle_count(m: Mesh) -> Nat:
  Mesh{_, i} = m
  Nat.div(List.length(&2, U32, i), 3n)

# The largest index, for the law that every index names a vertex.
def max_index(xs: List<&2, U32>) -> U32:
  match xs:
    case Nil{}:
      0
    case h <> t:
      U32.max(h, max_index(t))
