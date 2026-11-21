# The Scene and Details panels on screen, as a page written in Bend (Bend-UI's Web.bend and UI.bend).
# panels.bend says what the panels hold (the names, the sections and their fields) and what typing
# does; this file says what is drawn for it, piece by piece, and what each click and keystroke means.
# Nothing of the panels is written in JS any more: Bend-UI's driver draws what `render` returns.
#
#   start(scene, still)      the panels on a scene; `still` is the system asking for reduced motion
#   render(state)            both panels, as the children of the editor's <aside>
#   on_input(msg, got)       a keystroke in a field: the message with the text typed
#   on_event(event, state)   a thing picked, a number typed, the motion setting changed
#
# The scene belongs to the editor (editor/app.js draws it every frame): it hands the panels the
# current scene with `with_scene`, and reads back the one an edit made with `scene`.
#
# Limits now:
# - The selected thing is shown as a pressed toggle button: Bend-UI has no selectable list or tree
#   yet (a request for Bend-UI).
# - The field being typed in keeps its text while you type; Bend's own reading of the value shows
#   when you leave the field.
# - A number is shown with `fixed`, which rounds in F32. The browser's own toFixed rounds the exact
#   decimal, so a value that sits on a half (2.675 with two decimals) can show its last digit one off.
# - `fixed` shows at most 4 decimals.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/scene.bend as S
import ../defaults/defaults.bend as D
import ./panels.bend as O

# What the panels show: the scene, which thing is selected, and whether the system asks for less motion.
type St is Data:
  View{scene: S.Scene, selected: U32, still: Bool}

type Ev is Data:
  pick_thing{i: U32}                       # a thing was clicked in the Scene panel
  field_typed{edit: O.Edit, text: String}  # a keystroke in a field of Details
  field_left{}                             # the field was committed or left
  motion_set{still: Bool}                  # the system's reduced motion changed

def start(+scene: S.Scene, +still: Bool) -> Web.Update<St, Ev>:
  Web.update{View{scene, 0, still}, Web.none{}}

def scene(+st: St) -> S.Scene:
  match st:
    case View{s, _, _}:
      s

def selected(+st: St) -> U32:
  match st:
    case View{_, i, _}:
      i

def with_scene(+st: St, +s: S.Scene) -> St:
  match st:
    case View{_, i, still}:
      View{s, i, still}

def motion_event(+still: Bool) -> Ev:
  motion_set{still}

# ---------- A number as text ----------

def pow10(+d: U32) -> F32:
  match d:
    case 0:
      1.0
    case 1:
      10.0
    case 2:
      100.0
    case 3:
      1000.0
    case _:
      10000.0

# The last d digits of n, with their zeros.
def digits(d: Nat, +n: U32) -> String:
  match d:
    case 0n:
      ""
    case 1n+p:
      digits(p, (n / 10 : U32)) ++ U32.show((n % 10 : U32))

def sign_text(negative: Bool) -> String:
  match negative:
    case True{}:
      "-"
    case False{}:
      ""

def after_dot(none: Bool, +ds: String) -> String:
  match none:
    case True{}:
      ""
    case False{}:
      "." ++ ds

# x with exactly d decimals: fixed(2.5, 2) is "2.50".
def fixed(+x: F32, +d: U32) -> String:
  +scale = pow10(d)
  +unit = F32.to_u32(scale)
  +n = F32.to_u32(F32.round((F32.abs(x) * scale : F32)))
  sign_text(F32.is_lt(x, 0.0)) ++ U32.show((n / unit : U32)) ++ after_dot(U32.is_eq(d, 0), digits(U32.to_nat(d), (n % unit : U32)))

# ---------- Scene panel ----------

def things(+names: List<&2, String>, +i: U32, +sel: U32) -> List<&2, Web.HTML<Ev>>:
  match names:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Ui.toggle(Ev, [Ui.btn_ghost{}, Ui.btn_toggle{}], "editor-panels__item", h, U32.is_eq(i, sel), pick_thing{i}) <> things(t, (i + 1 : U32), sel)

# The rows, or a sentence when there are none.
def or_say(none: Bool, +rows: List<&2, Web.HTML<Ev>>, +say: String) -> List<&2, Web.HTML<Ev>>:
  match none:
    case True{}:
      [Ui.says(Ev, "p", "meta", say)]
    case False{}:
      rows

def scene_panel(+names: List<&2, String>, +sel: U32) -> Web.HTML<Ev>:
  Ui.panel_as(Ev, "section", "editor-panels__scene", [Web.attr{"aria-labelledby", "scene-panel-title"}], [
    Ui.panel_header(Ev, [
      Web.node{"span", [Web.attr{"id", "scene-panel-title"}], [Web.text{"Scene"}]},
      Ui.says(Ev, "span", "meta", Nat.show(List.length(&2, String, names)))]),
    Ui.panel_body_with(Ev, "editor-panels__list", [], or_say(List.is_empty(&2, String, names), things(names, 0, sel), "The scene is empty."))])

# ---------- Details panel ----------

# A field's id: its section, row and place, so a label finds its field.
def field_id(+s: U32, +r: U32, +k: U32) -> String:
  "details-field-" ++ U32.show(s) ++ "-" ++ U32.show(r) ++ "-" ++ U32.show(k)

def field(+f: O.Field, +id: String) -> Web.HTML<Ev>:
  match f:
    case O.Field{edit, label, value, step, decimals}:
      Ui.field_with(Ev, "editor-panels__field", [Web.attr{"for", id}], [
        Ui.field_label(Ev, label),
        Ui.input_with(Ev, [Ui.input_sm{}], "", [
          Web.attr{"id", id}, Web.attr{"type", "number"}, Web.attr{"step", F32.show(step)},
          Web.attr{"value", fixed(value, decimals)}, Web.attr{"aria-label", label},
          Web.on{Web.input{field_typed{edit, ""}}}, Web.on{Web.change{field_left{}}}])])

def fields(+fs: List<&2, O.Field>, +s: U32, +r: U32, +k: U32) -> List<&2, Web.HTML<Ev>>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      field(h, field_id(s, r, k)) <> fields(t, s, r, (k + 1 : U32))

def row(+x: O.Row, +s: U32, +r: U32) -> Web.HTML<Ev>:
  match x:
    case O.Row{label, fs}:
      Ui.box(Ev, "fieldset", "form__section editor-panels__row", [], [
        Ui.says(Ev, "legend", "field__label", label),
        Ui.box(Ev, "div", "editor-panels__fields", [], fields(fs, s, r, 0))])

def rows(+xs: List<&2, O.Row>, +s: U32, +r: U32) -> List<&2, Web.HTML<Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      row(h, s, r) <> rows(t, s, (r + 1 : U32))

# Accessibility (ACCESSIBILITY.bend): with motion reduced, the chevron turns without a transition.
def chevron(reduced: Bool) -> List<&2, Web.Attr<Ev>>:
  match reduced:
    case True{}:
      [Web.style{"transition", "none"}]
    case False{}:
      Nil{}

def section(+x: O.Section, +s: U32, +still: Bool) -> Web.HTML<Ev>:
  match x:
    case O.Section{title, rs}:
      Ui.disclosure_with(Ev, "", [Web.attr{"open", ""}], chevron(D.reduce_motion(still)), [Ui.disclosure_title(Ev, title)], rows(rs, s, 0))

def sections(+xs: List<&2, O.Section>, +s: U32, +still: Bool) -> List<&2, Web.HTML<Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      section(h, s, still) <> sections(t, (s + 1 : U32), still)

# The name at place i, or nothing.
def name_at(+names: List<&2, String>, +i: U32) -> String:
  match names:
    case Nil{}:
      ""
    case Con{h, t}:
      match i:
        case 0:
          h
        case _:
          name_at(t, (i - 1 : U32))

def details_body(none: Bool, +scene: S.Scene, +sel: U32, +still: Bool) -> List<&2, Web.HTML<Ev>>:
  match none:
    case True{}:
      [Ui.says(Ev, "p", "meta", "Nothing selected.")]
    case False{}:
      sections(O.sections(scene, sel), 0, still)

def details_panel(+scene: S.Scene, +sel: U32, +still: Bool) -> Web.HTML<Ev>:
  Ui.panel_as(Ev, "section", "editor-panels__details", [Web.attr{"aria-labelledby", "details-title"}], [
    Ui.panel_header(Ev, [
      Web.node{"span", [Web.attr{"id", "details-title"}], [Web.text{"Details"}]},
      Ui.says(Ev, "span", "meta", name_at(O.names(scene), sel))]),
    Ui.panel_body_with(Ev, "editor-panels__body", [], details_body(Bool.not(U32.is_lt(sel, U32.from_nat(S.count(scene)))), scene, sel, still))])

# ---------- The page ----------

# Both panels, as the children of the editor's <aside id="editor-panels">.
def render(+st: St) -> Web.HTML<Ev>:
  match st:
    case View{s, i, still}:
      Web.node{"aside", [], [scene_panel(O.names(s), i), details_panel(s, i, still)]}

# A keystroke carries the text typed: the message comes back holding it.
def on_input(+msg: Ev, +got: Web.Input) -> Ev:
  match msg got:
    case field_typed{e, _} Web.typed{v}:
      field_typed{e, v}
    case _ _:
      msg

# The scene after a number was typed; a text that is not a number changes nothing.
def write(+st: St, got: Maybe<&2, F32>, e: O.Edit) -> St:
  match st got:
    case View{s, i, still} Some{x}:
      View{O.apply(s, i, e, x), i, still}
    case View{s, i, still} None{}:
      View{s, i, still}

def on_event(+ev: Ev, +st: St) -> Web.Update<St, Ev>:
  match ev st:
    case pick_thing{i} View{s, _, still}:
      Web.update{View{s, i, still}, Web.none{}}
    case field_typed{e, text} View{s, i, still}:
      Web.update{write(View{s, i, still}, F32.read(text), e), Web.none{}}
    case field_left{} View{s, i, still}:
      Web.update{View{s, i, still}, Web.none{}}
    case motion_set{b} View{s, i, _}:
      Web.update{View{s, i, b}, Web.none{}}
