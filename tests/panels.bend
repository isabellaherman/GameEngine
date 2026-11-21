# Tests of the panels as a page (editor/panels/view.bend): how a number is shown, and what a typed
# text does to the scene.
#
# Limits now:
# - A test is checked at a few chosen values, not for every value as a law
#   is. It catches mistakes; it does not prove there are none.

import Base
import ../node_modules/bend-ui/Web.bend as Web
import ../engine/vec.bend as V
import ../engine/transform.bend as Tr
import ../engine/scene.bend as S
import ../editor/panels/panels.bend as O
import ../editor/panels/view.bend as P

type Check is Data:
  Check{name: String, ok: Bool}

def one() -> S.Scene:
  S.Scene{[S.Thing{"empty", Tr.identity(), S.Hidden{}}]}

def opened() -> P.St:
  P.View{one(), 0, False{}}

def state_of(u: Web.Update<P.St, P.Ev>) -> P.St:
  match u:
    case Web.update{next, _}:
      next

# The state after an event.
def after(+ev: P.Ev, +st: P.St) -> P.St:
  state_of(P.on_event(ev, st))

# Position X of the scene's first thing.
def x_of(+st: P.St) -> F32:
  V.x(Tr.position(S.place(S.at(P.scene(st), 0))))

def close(+a: F32, +b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.0001)

# A keystroke as the driver sends it: the field's message, filled with the text.
def typed(+text: String) -> P.Ev:
  P.on_input(P.field_typed{O.Pos{0}, ""}, Web.typed{text})

def checks() -> List<&2, Check>:
  [Check{"2.5 with two decimals is 2.50",
     String.eq(P.fixed(2.5, 2), "2.50")},
   Check{"0 with two decimals is 0.00",
     String.eq(P.fixed(0.0, 2), "0.00")},
   Check{"1 with one decimal is 1.0",
     String.eq(P.fixed(1.0, 1), "1.0")},
   Check{"-0.75 with two decimals is -0.75",
     String.eq(P.fixed((0.0 - 0.75 : F32), 2), "-0.75")},
   Check{"12.345 with one decimal is 12.3",
     String.eq(P.fixed(12.345, 1), "12.3")},
   Check{"3 with no decimals is 3",
     String.eq(P.fixed(3.0, 0), "3")},
   Check{"0.05 with two decimals keeps its zero: 0.05",
     String.eq(P.fixed(0.05, 2), "0.05")},
   Check{"typing 2.5 in Position X puts the thing at x = 2.5",
     close(x_of(after(typed("2.5"), opened())), 2.5)},
   Check{"a text that is not a number changes nothing",
     close(x_of(after(typed("abc"), opened())), 0.0)},
   Check{"an empty field changes nothing",
     close(x_of(after(typed(""), opened())), 0.0)},
   Check{"picking a thing selects it",
     U32.is_eq(P.selected(after(P.pick_thing{3}, opened())), 3)},
   Check{"leaving a field changes nothing",
     close(x_of(after(P.field_left{}, after(typed("4"), opened()))), 4.0)}]
