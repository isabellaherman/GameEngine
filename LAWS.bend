# The engine's laws. `bend PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./node_modules/bend-ui/SPEC.bend as Spec
import ./node_modules/bend-ui/KEYS.bend as K
import ./SPEC.bend as ES
import ./KEYS.bend as Keys
import ./engine/time.bend as Time
import ./engine/mesh.bend as Mesh

# ---------- Shortcuts ----------

# LAW: no two keys clash, the engine's and Bend-UI's together.
law engine_keys_never_clash:
  {Spec.key_clashes(K.with_lib(Keys.keymap())) == 0 : U32}

# LAW: the engine takes no key Bend-UI says the browser keeps (⌘/Ctrl + W, T, N, Q, L, R).
law engine_keys_not_reserved:
  {Spec.reserved_keys(Keys.keymap()) == 0 : U32}

# LAW: the engine takes no ⌘/Ctrl + digit: the browser switches tabs with them.
law engine_keys_not_tab_keys:
  {ES.browser_kept(Keys.keymap()) == 0 : U32}

# ---------- Time ----------

# LAW: with reduce_motion on, time never runs by itself, whatever the frame.
law reduce_motion_freezes_time:
  for c: Time.Clock
  for dt: F32
  {Time.tick(c, dt, True{}) == c : Time.Clock}

# LAW: a paused clock stays where it is.
law paused_clock_stays:
  for s: F32
  for dt: F32
  {Time.tick(Time.Clock{s, False{}}, dt, False{}) == Time.Clock{s, False{}} : Time.Clock}

# LAW: pausing keeps the moment; playing again starts from it.
law pause_keeps_the_moment:
  for s: F32
  for p: Bool
  {Time.play(Time.pause(Time.Clock{s, p})) == Time.Clock{s, True{}} : Time.Clock}

# ---------- Meshes ----------

# LAW: a plane of 3 × 3 cells has 4 × 4 corners and two triangles per cell.
law plane_has_its_corners:
  {Mesh.vertex_count(Mesh.plane(3.0, 3)) == 16n : Nat}

law plane_has_two_triangles_per_cell:
  {Mesh.triangle_count(Mesh.plane(3.0, 3)) == 18n : Nat}

# LAW: every index names a vertex: the largest is the last corner.
law plane_indices_name_vertices:
  {Mesh.max_index(Mesh.indices(Mesh.plane(3.0, 3))) == 15 : U32}

