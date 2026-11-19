# The engine's laws. `bend PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./node_modules/bend-ui/SPEC.bend as Spec
import ./node_modules/bend-ui/KEYS.bend as K
import ./SPEC.bend as ES
import ./KEYS.bend as Keys
import ./engine/time.bend as Time
import ./engine/mesh.bend as Mesh
import ./engine/shader/node.bend as N
import ./engine/shader/compile.bend as G
import ./engine/material.bend as Mat
import ./projects/water/water.bend as Water
import ./engine/scene.bend as S
import ./engine/transform.bend as Tr
import ./projects/water/scene.bend as Content
import ./editor/panels/panels.bend as O
import ./engine/vec.bend as V
import ./PROJECT.bend as P
import ./engine/skeleton.bend as Sk
import ./projects/character/arm.bend as Arm
import ./engine/figure.bend as Fig
import ./engine/skin.bend as Skin
import ./engine/helpers.bend as H
import ./engine/locomotion.bend as Loco

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

# ---------- Material graphs ----------

# LAW: the water's material gives a color (a vec3), as a mesh's color must.
law water_color_is_a_color:
  {N.ty(Mat.graph(Water.material())) == N.Vec3{} : N.Ty}

# LAW: every parameter of the water's material has a value of the right size.
law water_material_is_complete:
  {Mat.complete(Water.material()) == True{} : Bool}

# LAW: a color parameter given one number is not complete.
law color_needs_three_numbers:
  for x: F32
  {Mat.complete(Mat.Material{N.Param{"tone", N.Vec3{}}, [Mat.Value{"tone", [x]}]}) == False{} : Bool}

# LAW: a value under another name does not fill the parameter.
law value_needs_the_parameters_name:
  for x: F32
  {Mat.complete(Mat.Material{N.Param{"tone", N.Vec3{}}, [Mat.Value{"tint", [x, x, x]}]}) == False{} : Bool}

# LAW: an instance keeps the graph; only the values change.
law instance_keeps_the_graph:
  for x: F32
  {Mat.graph(Mat.instance(Water.material(), [Mat.Value{"tone", [x, x, x]}])) == Mat.graph(Water.material()) : N.Node}

# LAW: a parameter used twice is one line and one uniform.
law parameter_used_twice_is_one_uniform:
  {G.count(G.graph(N.Add{N.Param{"k", N.Float{}}, N.Param{"k", N.Float{}}})) == 2 : U32}

# LAW: a color times a number is a color (brighter or darker).
law color_times_number_is_a_color:
  for r: F32
  for k: F32
  {N.ty(N.Mul{N.Rgb{r, r, r}, N.Num{k}}) == N.Vec3{} : N.Ty}

# LAW: a color plus a number does not fit; the graph is Bad, not a shader error.
law color_plus_number_is_bad:
  for r: F32
  for k: F32
  {N.ty(N.Add{N.Rgb{r, r, r}, N.Num{k}}) == N.Bad{} : N.Ty}

# LAW: mix moves between two colors by a number, never by a color.
law mix_by_a_color_is_bad:
  for r: F32
  {N.ty(N.Mix{N.Rgb{r, r, r}, N.Rgb{r, r, r}, N.Rgb{r, r, r}}) == N.Bad{} : N.Ty}

# LAW: a wave of the time is a float, so it can drive a mix.
law mix_by_a_wave_of_time_is_a_color:
  for r: F32
  {N.ty(N.Mix{N.Rgb{r, r, r}, N.Rgb{r, r, r}, N.Sin{N.Time{}}}) == N.Vec3{} : N.Ty}

# LAW: a node used twice gets one line: sin(time) + sin(time) is 3 lines
# (time, sin, +), not 5.
law shared_node_is_written_once:
  {G.count(G.graph(N.Add{N.Sin{N.Time{}}, N.Sin{N.Time{}}})) == 3 : U32}

# LAW: the output is the last line: every node it uses is written before it.
law output_is_the_last_line:
  {G.output(G.graph(N.Sin{N.Add{N.Time{}, N.Sin{N.Time{}}}})) == "n3" : String}

# ---------- Scene ----------

# LAW: every thing drawn in the starting scene has a complete material.
law scene_materials_are_complete:
  {S.complete(Content.start()) == True{} : Bool}

# LAW: a hidden thing needs no material, so it never makes a scene incomplete.
law hidden_thing_is_complete:
  {S.complete(S.Scene{[S.Thing{"empty", Tr.identity(), S.Hidden{}}]}) == True{} : Bool}

# ---------- Scene and Details panels ----------
# Laws that edit use a one-cell plane: the checker works every list out in
# full, and the real water's 1681 vertices overflow its stack.

# LAW: the Scene panel lists the scene's things by name, in order.
law scene_panel_lists_the_scene:
  {O.names(Content.start()) == ["Water"] : List<&2, String>}

# LAW: a shown thing has a Transform section and a Material section.
law details_show_transform_and_material:
  {O.titles(O.sections(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 0)) == ["Transform", "Material"] : List<&2, String>}

# LAW: a hidden thing has only its Transform.
law hidden_thing_shows_only_transform:
  {O.titles(O.sections(S.Scene{[S.Thing{"empty", Tr.identity(), S.Hidden{}}]}, 0)) == ["Transform"] : List<&2, String>}

# LAW: typing 3 in Position X puts the thing at x = 3 and nothing else moves.
law typing_position_x_moves_to_it:
  {Tr.position(S.place(S.at(O.apply(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 0, O.Pos{0}, 3.0), 0))) == V.V3{3.0, 0.0, 0.0} : V.V3}

# LAW: editing never adds or removes things.
law editing_keeps_every_thing:
  for x: F32
  {S.count(O.apply(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 0, O.Size{1}, x)) == S.count(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}) : Nat}

# LAW: editing a material value keeps its graph, so no shader is compiled.
law editing_a_value_keeps_the_graph:
  for x: F32
  {Mat.graph(S.material(S.look(S.at(O.apply(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 0, O.Val{"tone", 1}, x), 0)))) == Mat.graph(Water.material()) : N.Node}

# LAW: an edit past the end of the list changes nothing.
law editing_past_the_end_changes_nothing:
  for x: F32
  {O.apply(S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]}, 7, O.Pos{0}, x) == S.Scene{[S.Thing{"w", Tr.identity(), S.Shown{Mesh.plane(1.0, 1), Water.material()}}]} : S.Scene}


# ---------- Projects ----------

# LAW: every project opens with a complete scene (each drawn thing's
# material has a value for every parameter).
law every_project_opens_complete:
  for p: P.Project
  {S.complete(P.start(p)) == True{} : Bool}

# ---------- Skeletons ----------
# The rig standard's structural laws (engine/skeleton.bend), on the test arm
# and on skeletons that break each one.

# LAW: the test arm keeps every structural law.
law arm_is_valid:
  {Sk.valid(Arm.skeleton()) == True{} : Bool}

# LAW: the test arm has one root, five deform bones (three arm, two
# finger), one twist, one support.
law arm_has_its_roles:
  {Sk.role_counts(Arm.skeleton()) == [1, 5, 1, 1, 0] : List<&2, U32>}

# LAW: the test arm's hand is found by its slot.
law arm_hand_has_a_slot:
  {Sk.find_slot(Arm.skeleton(), "hand.L") == 4 : U32}

# LAW: a bone listed before its parent breaks the order.
law child_before_parent_is_invalid:
  for t: Tr.Transform
  {Sk.valid(Sk.Skeleton{[
     Sk.Bone{"root", "root", Sk.Root{}, 0, t, 0.0},
     Sk.Bone{"a", "", Sk.Deform{}, 2, t, 0.0},
     Sk.Bone{"b", "", Sk.Deform{}, 0, t, 0.0}]}) == False{} : Bool}

# LAW: a second root is not allowed.
law two_roots_are_invalid:
  for t: Tr.Transform
  {Sk.valid(Sk.Skeleton{[
     Sk.Bone{"root", "root", Sk.Root{}, 0, t, 0.0},
     Sk.Bone{"another root", "", Sk.Root{}, 0, t, 0.0}]}) == False{} : Bool}

# LAW: a Deform bone may not hang from a computed bone.
law deform_under_twist_is_invalid:
  for t: Tr.Transform
  {Sk.valid(Sk.Skeleton{[
     Sk.Bone{"root", "root", Sk.Root{}, 0, t, 0.0},
     Sk.Bone{"twist", "", Sk.Twist{}, 0, t, 0.0},
     Sk.Bone{"hand", "", Sk.Deform{}, 1, t, 0.0}]}) == False{} : Bool}

# LAW: helpers may hang from helpers (the reference rig does this).
law support_under_twist_is_valid:
  for t: Tr.Transform
  {Sk.valid(Sk.Skeleton{[
     Sk.Bone{"root", "root", Sk.Root{}, 0, t, 0.0},
     Sk.Bone{"arm", "", Sk.Deform{}, 0, t, 0.0},
     Sk.Bone{"twist", "", Sk.Twist{}, 1, t, 0.0},
     Sk.Bone{"fix", "", Sk.Support{}, 2, t, 0.0}]}) == True{} : Bool}

# ---------- Animation ----------

# LAW: with reduce_motion on, a character's animation never moves by itself.
law reduce_motion_freezes_figures:
  for f: Fig.Figure
  for dt: F32
  {Fig.advance(f, dt, True{}) == f : Fig.Figure}

# LAW: the same for a whole scene.
law reduce_motion_freezes_scenes:
  for s: S.Scene
  for dt: F32
  {S.advance(s, dt, True{}) == s : S.Scene}

# ---------- Skin weights ----------
# The weight rules of engine/skin.bend, on single vertices (the reference
# rig's 4074 vertices are checked by refs/sora/LAWS.bend when present).

# LAW: weights that sum to 65535 over distinct bones are fine.
law weights_that_sum_to_the_whole_hold:
  {Skin.vertex_ok(1, 2, 0, 0, 40000, 25535, 0, 0, 6) == True{} : Bool}

# LAW: weights that miss the whole by 1 do not.
law weights_one_short_fail:
  {Skin.vertex_ok(1, 2, 0, 0, 40000, 25534, 0, 0, 6) == False{} : Bool}

# LAW: a vertex with no weight would fall to the origin, so it fails.
law vertex_without_weight_fails:
  {Skin.vertex_ok(0, 0, 0, 0, 0, 0, 0, 0, 6) == False{} : Bool}

# LAW: the same bone twice in a vertex fails.
law same_bone_twice_fails:
  {Skin.vertex_ok(3, 3, 0, 0, 30000, 35535, 0, 0, 6) == False{} : Bool}

# LAW: a weighted joint past the last bone fails.
law joint_past_the_end_fails:
  {Skin.vertex_ok(6, 0, 0, 0, 65535, 0, 0, 0, 6) == False{} : Bool}

# LAW: empty slots (weight 0) may point anywhere.
law empty_slots_are_ignored:
  {Skin.vertex_ok(2, 9, 9, 9, 65535, 0, 0, 0, 6) == True{} : Bool}

# ---------- Helper bones ----------

# LAW: every Twist and Support bone of the test arm has exactly one rule.
law arm_helpers_are_covered:
  {H.helpers_cover(Arm.skeleton(), Arm.rules()) == True{} : Bool}

# LAW: a helper without a rule is caught.
law missing_helper_rule_is_caught:
  {H.helpers_cover(Arm.skeleton(), [H.Rule{3, 4, H.Roll{}, 0.5}]) == False{} : Bool}

# LAW: a rule on a Deform bone is caught (clips move those, not rules).
law rule_on_deform_bone_is_caught:
  {H.helpers_cover(Arm.skeleton(), [H.Rule{3, 4, H.Roll{}, 0.5}, H.Rule{5, 2, H.Full{}, 0.5}, H.Rule{2, 1, H.Full{}, 0.5}]) == False{} : Bool}

# ---------- Locomotion ----------

# LAW: with reduce_motion on (Step), no key means no change, in any scene.
law no_key_no_step:
  for s: S.Scene
  for dt: F32
  {Loco.drive(s, Loco.still(), dt, True{}) == s : S.Scene}
