# Outliner and Details: the editor's view of the scene, as in Unreal.
#
# The Outliner lists every thing in the scene by name. The Details panel
# shows the selected thing's components as sections of fields: its
# Transform (position, rotation in degrees, scale) and, when it is shown,
# its Material's values. Typing a value gives back a new scene with that
# one value changed (apply); outliner.js only draws what this file returns
# and passes the typed numbers back.
#
# The scene stays data (engine/scene.bend): the panels are a way of seeing
# and editing it, the "thing with parts" view over the ECS-style data.
#
# Limits now:
# - Edits live only while the page is open: nothing writes them back to
#   content/scene.bend, and a reload starts from the file again.
# - Rotation is shown in degrees per axis (engine/quat.bend's to_degrees).
#   Near ±90° around X, the Y and Z fields may show a different split than
#   the one typed; the rotation itself is right.
# - A color is three number fields (R, G, B, from 0 to 1): Bend-UI has no
#   color input yet (a request for Bend-UI).
# - The list is flat: no parent and child yet, so no tree.
# - No undo, no adding, removing, renaming or reordering things.
# - Selecting a thing in the viewport (clicking it) does not exist; only the
#   Outliner selects.

import Base
import ../../engine/vec.bend as V
import ../../engine/quat.bend as Q
import ../../engine/transform.bend as Tr
import ../../engine/material.bend as Mat
import ../../engine/scene.bend as S

# What a field edits: one axis of the position, rotation or scale, or
# number k of the material value with this name.
type Edit is Data:
  Pos{axis: U32}
  Rot{axis: U32}
  Size{axis: U32}
  Val{name: String, k: U32}

# One number field: what it edits, its short label, its value, how much the
# arrows change it, and how many decimals it shows.
type Field is Data:
  Field{edit: Edit, label: String, value: F32, step: F32, decimals: U32}

# A labeled row of fields (Position: X Y Z).
type Row is Data:
  Row{label: String, fields: List<&2, Field>}

# A section of the Details panel (Transform, Material).
type Section is Data:
  Section{title: String, rows: List<&2, Row>}

# Outliner
# ========

def names_go(xs: List<&2, S.Thing>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      S.name(h) <> names_go(t)

# The Outliner's rows: every thing's name, in the scene's order.
def names(s: S.Scene) -> List<&2, String>:
  names_go(S.things(s))

# Details: what it shows
# ======================

# The edit for axis a of part p: 0 position, 1 rotation, 2 scale.
def part_edit(+p: U32, +a: U32) -> Edit:
  match p:
    case 0:
      Pos{a}
    case 1:
      Rot{a}
    case _:
      Size{a}

def xyz(+v: V.V3, +p: U32, +step: F32, +decimals: U32) -> List<&2, Field>:
  [Field{part_edit(p, 0), "X", V.x(v), step, decimals},
   Field{part_edit(p, 1), "Y", V.y(v), step, decimals},
   Field{part_edit(p, 2), "Z", V.z(v), step, decimals}]

def transform_section(+t: Tr.Transform) -> Section:
  Section{"Transform", [
    Row{"Position", xyz(Tr.position(t), 0, 0.1, 2)},
    Row{"Rotation", xyz(Q.to_degrees(Tr.rotation(t)), 1, 1.0, 1)},
    Row{"Scale", xyz(Tr.scale(t), 2, 0.1, 2)}]}

def channel(+k: U32) -> String:
  match k:
    case 0:
      "R"
    case 1:
      "G"
    case 2:
      "B"
    case _:
      "#"

def label_for(three: Bool, +name: String, +k: U32) -> String:
  match three:
    case True{}:
      channel(k)
    case False{}:
      name

# A material value's fields: one number, or R G B for three.
def value_fields_go(xs: List<&2, F32>, +name: String, +k: U32, +three: Bool) -> List<&2, Field>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      Field{Val{name, k}, label_for(three, name, k), h, 0.01, 2} <> value_fields_go(t, name, (k + 1 : U32), three)

def value_row(v: Mat.Value) -> Row:
  Mat.Value{+name, +xs} = v
  Row{name, value_fields_go(xs, name, 0, Nat.is_eq(List.length(&2, F32, xs), 3n))}

def value_rows(vs: List<&2, Mat.Value>) -> List<&2, Row>:
  match vs:
    case Nil{}:
      Nil{}
    case h <> t:
      value_row(h) <> value_rows(t)

def look_sections(l: S.Look) -> List<&2, Section>:
  match l:
    case S.Shown{_, m}:
      [Section{"Material", value_rows(Mat.values(m))}]
    case S.Hidden{}:
      Nil{}

# Every section of the Details panel for thing i.
def sections(s: S.Scene, +i: U32) -> List<&2, Section>:
  +t = S.at(s, i)
  transform_section(S.place(t)) <> look_sections(S.look(t))

# The sections' titles, in order (for the laws).
def titles(xs: List<&2, Section>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      Section{n, _} = h
      n <> titles(t)

# Details: what typing does
# =========================

def set_axis(v: V.V3, +a: U32, +x: F32) -> V.V3:
  V.V3{+vx, +vy, +vz} = v
  match a:
    case 0:
      V.V3{x, vy, vz}
    case 1:
      V.V3{vx, x, vz}
    case _:
      V.V3{vx, vy, x}

def pick_nums(c: Bool, a: List<&2, F32>, b: List<&2, F32>) -> List<&2, F32>:
  match c:
    case True{}:
      a
    case False{}:
      b

# Number k of a list set to x.
def set_at(xs: List<&2, F32>, +k: U32, +x: F32) -> List<&2, F32>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> +t:
      pick_nums(U32.is_eq(k, 0), x <> t, h <> set_at(t, (k - 1 : U32), x))

def pick_value(c: Bool, a: Mat.Value, b: Mat.Value) -> Mat.Value:
  match c:
    case True{}:
      a
    case False{}:
      b

def set_value(v: Mat.Value, +name: String, +k: U32, +x: F32) -> Mat.Value:
  Mat.Value{+n, +xs} = v
  pick_value(String.eq(n, name), Mat.Value{n, set_at(xs, k, x)}, Mat.Value{n, xs})

def set_values(vs: List<&2, Mat.Value>, +name: String, +k: U32, +x: F32) -> List<&2, Mat.Value>:
  match vs:
    case Nil{}:
      Nil{}
    case h <> t:
      set_value(h, name, k, x) <> set_values(t, name, k, x)

# The material keeps its graph (no shader is compiled again); only the
# value changes.
def set_look(l: S.Look, +name: String, +k: U32, +x: F32) -> S.Look:
  match l:
    case S.Shown{shape, +m}:
      S.Shown{shape, Mat.instance(m, set_values(Mat.values(m), name, k, x))}
    case S.Hidden{}:
      S.Hidden{}

def edit_thing(t: S.Thing, e: Edit, +x: F32) -> S.Thing:
  S.Thing{n, +p, l} = t
  match e:
    case Pos{a}:
      S.Thing{n, Tr.with_position(p, set_axis(Tr.position(p), a, x)), l}
    case Rot{a}:
      S.Thing{n, Tr.with_rotation(p, Q.from_degrees(set_axis(Q.to_degrees(Tr.rotation(p)), a, x))), l}
    case Size{a}:
      S.Thing{n, Tr.with_scale(p, set_axis(Tr.scale(p), a, x)), l}
    case Val{name, k}:
      S.Thing{n, p, set_look(l, name, k, x)}

# The scene after typing x into a field of thing i.
def apply(+s: S.Scene, +i: U32, e: Edit, +x: F32) -> S.Scene:
  S.put(s, i, edit_thing(S.at(s, i), e, x))
