# The proofs of LAWS.bend.

import Base
import ./LAWS.bend as Laws
import ./PROJECT.bend as P
import ./engine/scene.bend as S
import ./engine/locomotion.bend as Loco

def Laws.engine_keys_never_clash():
  {==}

def Laws.engine_keys_not_reserved():
  {==}

def Laws.engine_keys_not_tab_keys():
  {==}

def Laws.reduce_motion_freezes_time(c, dt):
  {==}

def Laws.paused_clock_stays(s, dt):
  {==}

def Laws.pause_keeps_the_moment(s, p):
  {==}

def Laws.plane_has_its_corners():
  {==}

def Laws.plane_has_two_triangles_per_cell():
  {==}

def Laws.plane_indices_name_vertices():
  {==}

def Laws.water_color_is_a_color():
  {==}

def Laws.color_times_number_is_a_color(r, k):
  {==}

def Laws.color_plus_number_is_bad(r, k):
  {==}

def Laws.mix_by_a_color_is_bad(r):
  {==}

def Laws.mix_by_a_wave_of_time_is_a_color(r):
  {==}

def Laws.shared_node_is_written_once():
  {==}

def Laws.output_is_the_last_line():
  {==}

def Laws.water_material_is_complete():
  {==}

def Laws.color_needs_three_numbers(x):
  {==}

def Laws.value_needs_the_parameters_name(x):
  {==}

def Laws.instance_keeps_the_graph(x):
  {==}

def Laws.parameter_used_twice_is_one_uniform():
  {==}

def Laws.scene_materials_are_complete():
  {==}

def Laws.hidden_thing_is_complete():
  {==}

def Laws.scene_panel_lists_the_scene():
  {==}

def Laws.details_show_transform_and_material():
  {==}

def Laws.hidden_thing_shows_only_transform():
  {==}

def Laws.typing_position_x_moves_to_it():
  {==}

def Laws.editing_keeps_every_thing(x):
  {==}

def Laws.editing_a_value_keeps_the_graph(x):
  {==}

def Laws.editing_past_the_end_changes_nothing(x):
  {==}

def Laws.every_project_opens_complete(p):
  match p:
    case P.Water{}:
      {==}
    case P.Character{}:
      {==}

def Laws.arm_is_valid():
  {==}

def Laws.arm_has_its_roles():
  {==}

def Laws.arm_hand_has_a_slot():
  {==}

def Laws.child_before_parent_is_invalid(t):
  {==}

def Laws.two_roots_are_invalid(t):
  {==}

def Laws.deform_under_twist_is_invalid(t):
  {==}

def Laws.support_under_twist_is_valid(t):
  {==}

def Laws.reduce_motion_freezes_figures(f, dt):
  {==}

# A scene's things, advanced with reduce_motion on, are the same things:
# by induction on the list, looking at each thing's look.
def frozen_things(xs: List<&2, S.Thing>, dt: F32) -> {xs == S.advance_go(xs, dt, True{}) : List<&2, S.Thing>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      match h:
        case S.Thing{n, p, l}:
          match l:
            case S.Hidden{}:
              %frozen_things(t, dt) : {S.Thing{n, p, S.Hidden{}} <> t == S.Thing{n, p, S.Hidden{}} <> _ : List<&2, S.Thing>}
              {==}
            case S.Shown{sh, m}:
              %frozen_things(t, dt) : {S.Thing{n, p, S.Shown{sh, m}} <> t == S.Thing{n, p, S.Shown{sh, m}} <> _ : List<&2, S.Thing>}
              {==}
            case S.Rigged{f}:
              %frozen_things(t, dt) : {S.Thing{n, p, S.Rigged{f}} <> t == S.Thing{n, p, S.Rigged{f}} <> _ : List<&2, S.Thing>}
              {==}

def Laws.reduce_motion_freezes_scenes(s, dt):
  match s:
    case S.Scene{xs}:
      %frozen_things(xs, dt) : {S.Scene{_} == S.Scene{xs} : S.Scene}
      {==}

def Laws.weights_that_sum_to_the_whole_hold():
  {==}

def Laws.weights_one_short_fail():
  {==}

def Laws.vertex_without_weight_fails():
  {==}

def Laws.same_bone_twice_fails():
  {==}

def Laws.joint_past_the_end_fails():
  {==}

def Laws.empty_slots_are_ignored():
  {==}

def Laws.arm_helpers_are_covered():
  {==}

def Laws.missing_helper_rule_is_caught():
  {==}

def Laws.rule_on_deform_bone_is_caught():
  {==}

# With no key pressed, Step leaves every thing as it was: by induction.
def still_things(xs: List<&2, S.Thing>, dt: F32) -> {xs == Loco.drive_go(xs, Loco.still(), dt, True{}) : List<&2, S.Thing>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %still_things(t, dt) : {h <> t == h <> _ : List<&2, S.Thing>}
      {==}

def Laws.no_key_no_step(s, dt):
  match s:
    case S.Scene{xs}:
      %still_things(xs, dt) : {S.Scene{_} == S.Scene{xs} : S.Scene}
      {==}
