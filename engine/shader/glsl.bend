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
# - The engine's own uniform and attribute names (u_vp, a_pos…) are written
#   here and again in main.js; nothing checks that the two match. Material
#   parameters do not have this problem: main.js asks material.bend for
#   their names.
# - Material meshes have no light: their color comes straight from the
#   graph. Only the skinned shaders (skinned_frag) are lit, by one sun.

import Base
import ./node.bend as N
import ./compile.bend as G

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

# Meshes (engine/mesh.bend): each vertex is only a position, built around
# the mesh's own origin. The model matrix (u_model, engine/transform.bend)
# puts it in its place in the World; then the camera's view-projection
# (u_vp) puts it on the screen.
def mesh_vert() -> String:
  program([
    "#version 300 es",
    "uniform mat4 u_vp;",
    "uniform mat4 u_model;",
    "in vec3 a_pos;",
    "void main() {",
    "  gl_Position = u_vp * u_model * vec4(a_pos, 1.0);",
    "}"])

# Every pixel of a mesh gets the color a graph gives (engine/shader/node.bend),
# compiled into one named line per node (engine/shader/compile.bend), with a
# uniform declared for each parameter. `base`
# must be a vec3 (a law checks the water's). u_time is declared for graphs
# that use Time; the driver drops it when nothing reads it.
def mesh_frag(+base: N.Node) -> String:
  +g = G.graph(base)
  program(List.concat(&2, String, [
    ["#version 300 es",
     "precision highp float;",
     "uniform float u_time;"],
    G.uniforms(g),
    ["out vec4 color;",
     "void main() {"],
    G.lines(g),
    [String.concat(["  color = vec4(", G.output(g), ", 1.0);"]),
     "}"]]))

# Skinned meshes
# ==============
#
# A character's skin (engine/skin.bend). Each vertex carries 4 bone
# indices and 4 weights (16-bit, read as 0..1). The skinning matrices sit
# in a float texture, one bone per row of 4 texels (one matrix column
# each), because WebGL2 only promises 256 uniform vectors in a vertex
# shader: about 60 bones as uniforms, and the reference rig has 171.

def skinned_vert() -> String:
  program([
    "#version 300 es",
    "precision highp float;",
    "precision highp int;",
    "uniform mat4 u_vp;",
    "uniform highp sampler2D u_bones;",
    "in vec3 a_pos;",
    "in vec3 a_normal;",
    "in vec2 a_uv;",
    "in uvec4 a_joints;",
    "in vec4 a_weights;",
    "out vec3 v_normal;",
    "out vec2 v_uv;",
    "mat4 bone(uint i) {",
    "  int r = int(i);",
    "  return mat4(texelFetch(u_bones, ivec2(0, r), 0), texelFetch(u_bones, ivec2(1, r), 0),",
    "              texelFetch(u_bones, ivec2(2, r), 0), texelFetch(u_bones, ivec2(3, r), 0));",
    "}",
    "void main() {",
    "  mat4 m = a_weights.x * bone(a_joints.x) + a_weights.y * bone(a_joints.y)",
    "         + a_weights.z * bone(a_joints.z) + a_weights.w * bone(a_joints.w);",
    "  v_normal = mat3(m) * a_normal;",
    "  v_uv = a_uv;",
    "  gl_Position = u_vp * (m * vec4(a_pos, 1.0));",
    "}"])

# Light: one sun and the sky. Wrapped diffuse ("half Lambert": the shadow
# side never goes black) keeps a stylized, soft look; a faint rim from the
# sky lifts the outline. Base color from the texture, or u_tint without one.
def skinned_frag() -> String:
  program([
    "#version 300 es",
    "precision highp float;",
    "uniform sampler2D u_tex;",
    "uniform float u_textured;",
    "uniform vec3 u_tint;",
    "uniform vec3 u_sun;",
    "uniform vec3 u_eye_dir;",
    "in vec3 v_normal;",
    "in vec2 v_uv;",
    "out vec4 color;",
    "void main() {",
    "  vec3 n = normalize(v_normal);",
    "  if (!gl_FrontFacing) n = -n;",
    "  vec4 tex = texture(u_tex, v_uv);",
    "  if (u_textured > 0.5 && tex.a < 0.5) discard;",
    "  vec3 base = mix(u_tint, tex.rgb, u_textured);",
    "  float wrap = dot(n, normalize(u_sun)) * 0.5 + 0.5;",
    "  float light = 0.35 + 0.75 * wrap * wrap;",
    "  float rim = pow(1.0 - max(dot(n, -normalize(u_eye_dir)), 0.0), 3.0) * 0.15;",
    "  color = vec4(base * light + rim, 1.0);",
    "}"])

# Where the sun comes from: high, in front and to the left (unit length).
def sun() -> List<&2, F32>:
  [0.42, 0.78, 0.46]
