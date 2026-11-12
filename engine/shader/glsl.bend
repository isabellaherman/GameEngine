# GLSL: the shader programs the GPU runs, written by Bend.
#
# The GPU does not run Bend. WebGL2 takes a shader only as GLSL ES 3.00 text,
# which the GPU driver compiles. So Bend writes that text here, and main.js
# only hands it to the driver. Unity and Unreal do the same with HLSL: their
# material graphs write the text, and nobody types it.
#
# Each shader is a list of lines, joined with a line break. Later the lines
# come from material graphs (engine/shader/node.bend); for now they are the
# two shaders the World's lines need.
#
# Limits now:
# - To Bend this is plain text. `bun run check` cannot see a GLSL mistake;
#   only the GPU driver finds it, in the browser, when main.js compiles it
#   (main.js then stops with the driver's message). Typed nodes
#   (engine/shader/node.bend) will catch most mistakes before that.
# - Bend text is a list of characters, slow to build. Shaders are built
#   once, at start-up, never per frame.
# - The uniform and attribute names (u_vp, a_pos…) are written here and
#   again in main.js. Nothing checks yet that the two match.
# - No light: meshes are one color.

import Base

def program(lines: List<&2, String>) -> String:
  String.join(lines, "\n")

# The lines of the World: each vertex is a position and a color, placed on
# the screen by the camera's view-projection matrix (u_vp).
def line_vert() -> String:
  program([
    "#version 300 es",
    "uniform mat4 u_vp;",
    "in vec3 a_pos;",
    "in vec3 a_col;",
    "out vec3 v_pos;",
    "out vec3 v_col;",
    "void main() {",
    "  v_pos = a_pos;",
    "  v_col = a_col;",
    "  gl_Position = u_vp * vec4(a_pos, 1.0);",
    "}"])

# Each pixel of a line keeps its color and fades with its distance from the
# eye, between u_fade.x and u_fade.y meters (world.bend decides them).
def line_frag() -> String:
  program([
    "#version 300 es",
    "precision highp float;",
    "uniform vec3 u_eye;",
    "uniform vec2 u_fade;",
    "in vec3 v_pos;",
    "in vec3 v_col;",
    "out vec4 color;",
    "void main() {",
    "  float a = 1.0 - smoothstep(u_fade.x, u_fade.y, distance(v_pos, u_eye));",
    "  color = vec4(v_col, a);",
    "}"])

# Meshes (engine/mesh.bend): each vertex is only a position, placed on the
# screen by the same view-projection matrix as the lines.
def mesh_vert() -> String:
  program([
    "#version 300 es",
    "uniform mat4 u_vp;",
    "in vec3 a_pos;",
    "void main() {",
    "  gl_Position = u_vp * vec4(a_pos, 1.0);",
    "}"])

# Every pixel of a mesh in one color (u_color). There is no light yet:
# a material will decide this later.
def mesh_frag() -> String:
  program([
    "#version 300 es",
    "precision highp float;",
    "uniform vec3 u_color;",
    "out vec4 color;",
    "void main() {",
    "  color = vec4(u_color, 1.0);",
    "}"])
