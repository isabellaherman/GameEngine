# The info button of Editor Defaults on screen, as a page written in Bend (Bend-UI's Web.bend and
# UI.bend): a Bend-UI dropdown that says where the origin is, what each axis means, and whether
# motion is reduced. It creates no value: every text and tone comes from defaults.bend, which hands
# on engine/world.bend and ACCESSIBILITY.bend. The gizmo beside it is a canvas, drawn by defaults.js.
#
#   start(still)             the button; `still` is the system asking for reduced motion
#   render(state)            the dropdown, as a child of the editor's <aside id="editor-defaults">
#   on_event(event, state)   the system's setting changed
#
# Limits now:
# - Reduce motion only shows the state (a segmented Off / On nobody can press): the setting is
#   written in ACCESSIBILITY.bend, and the interface can't change it yet.

import Base
import ../../node_modules/bend-ui/Web.bend as Web
import ../../node_modules/bend-ui/UI.bend as Ui
import ../../engine/vec.bend as V
import ../../engine/world.bend as W
import ./defaults.bend as D

type St is Data:
  Info{still: Bool}

type Ev is Data:
  motion_is{still: Bool}   # the system's reduced motion changed

def start(+still: Bool) -> Web.Update<St, Ev>:
  Web.update{Info{still}, Web.none{}}

def motion_event(+still: Bool) -> Ev:
  motion_is{still}

def about() -> String:
  "About the scene and accessibility"

# "0, 0, 0": the origin as a person reads it.
def point_text(+p: V.V3) -> String:
  F32.show(V.x(p)) ++ ", " ++ F32.show(V.y(p)) ++ ", " ++ F32.show(V.z(p))

def info_row(+left: Web.HTML<Ev>, +right: Web.HTML<Ev>) -> Web.HTML<Ev>:
  Ui.box(Ev, "div", "editor-defaults__row", [], [left, right])

# An axis: its tone as a dot, its name, and where it points.
def axis_row(+a: W.Axis) -> Web.HTML<Ev>:
  match a:
    case W.Axis{name, points, tone}:
      info_row(
        Ui.box(Ev, "span", "outline__row", [], [
          Ui.dot_with(Ev, [], [Web.style{"background", tone}, Web.style{"border-color", tone}]),
          Ui.says(Ev, "span", "item-title", name)]),
        Ui.says(Ev, "span", "detail", points))

def axis_rows(+xs: List<&2, W.Axis>) -> List<&2, Web.HTML<Ev>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      axis_row(h) <> axis_rows(t)

# A choice nobody can press: it shows the state.
def shown(+label: String, on: Bool) -> Web.HTML<Ev>:
  Ui.choice_with(Ev, on, [Web.attr{"type", "button"}, Web.attr{"tabindex", "-1"}], [Web.text{label}])

# Accessibility (ACCESSIBILITY.bend): whether motion is reduced. It springs when the state changes.
def motion_field(+reduced: Bool) -> Web.HTML<Ev>:
  Ui.box(Ev, "div", "field", [], [
    Web.node{"span", [Web.attr{"class", "field__label"}, Web.attr{"id", "editor-defaults-motion"}], [Web.text{"Reduce motion"}]},
    Ui.segmented_with(Ev, [Ui.seg_slide{}], "editor-defaults__readonly",
      [Web.attr{"data-motion", "spring"}, Web.attr{"role", "group"}, Web.attr{"aria-labelledby", "editor-defaults-motion"}],
      [shown("Off", Bool.not(reduced)), shown("On", reduced)])])

def info_menu(+still: Bool) -> Web.HTML<Ev>:
  Ui.menu_with(Ev, [Ui.menu_end{}], "editor-defaults__info", [Web.attr{"role", "dialog"}, Web.attr{"aria-label", about()}],
    info_row(Ui.says(Ev, "span", "item-title", "Origin"), Ui.says(Ev, "span", "mono detail", point_text(D.origin())))
    <> List.append(&2, Web.HTML<Ev>, axis_rows(D.axes()),
      [Ui.separator(Ev), Ui.says(Ev, "h3", "group-title", "Accessibility"), motion_field(D.reduce_motion(still))]))

def info_button() -> Web.HTML<Ev>:
  Ui.trigger_with(Ev, [Ui.btn_plain{}, Ui.btn_neutral{}, Ui.btn_sm{}, Ui.btn_icon{}, Ui.btn_round{}], "", [Web.attr{"aria-label", about()}], [Ui.icon(Ev, "info")])

# The dropdown, as a child of the editor's <aside id="editor-defaults"> (the gizmo's canvas is there already).
def render(+st: St) -> Web.HTML<Ev>:
  match st:
    case Info{still}:
      Web.node{"aside", [], [Ui.dropdown(Ev, info_button(), info_menu(still))]}

def on_event(+ev: Ev, +st: St) -> Web.Update<St, Ev>:
  match ev:
    case motion_is{b}:
      Web.update{Info{b}, Web.none{}}
