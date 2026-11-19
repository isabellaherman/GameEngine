# The engine's keymap: every shortcut of the engine lives here, in one list.
# LAWS.bend checks it together with Bend-UI's keys, so no two ever overlap.
#
# Views: 1 goes back to the start view; 2, 3 and 4 look along Y, X and Z
# (from the + side, like clicking that handle of the gizmo).

import Base
import ./node_modules/bend-ui/SPEC.bend as Spec

def keymap() -> List<&2, Spec.Shortcut>:
  [Spec.Shortcut{0, 0, "1", "view.home"},
   Spec.Shortcut{0, 0, "2", "view.y"},
   Spec.Shortcut{0, 0, "3", "view.x"},
   Spec.Shortcut{0, 0, "4", "view.z"},
   Spec.Shortcut{0, 0, "w", "walk.forward"},
   Spec.Shortcut{0, 0, "s", "walk.back"},
   Spec.Shortcut{0, 0, "a", "turn.left"},
   Spec.Shortcut{0, 0, "d", "turn.right"}]

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# Does this action go back to the start view?
def is_home(+action: String) -> Bool:
  String.eq(action, "view.home")

# The gizmo handle each view looks from (engine/gizmo.bend: 0 +X, 1 +Y,
# 2 +Z), or 6 for an action that is not one.
def view_handle(+action: String) -> U32:
  pick(String.eq(action, "view.y"), 1,
  pick(String.eq(action, "view.x"), 0,
  pick(String.eq(action, "view.z"), 2, 6)))

# Walking keys (engine/locomotion.bend): the input each one gives, as
# whole numbers (forward: 1 ahead, 2 back; turn: 1 left, 2 right).
def is_walk(+action: String) -> Bool:
  (String.eq(action, "walk.forward") || String.eq(action, "walk.back") || String.eq(action, "turn.left") || String.eq(action, "turn.right"))

def walk_forward(+action: String) -> U32:
  pick(String.eq(action, "walk.forward"), 1, pick(String.eq(action, "walk.back"), 2, 0))

def walk_turn(+action: String) -> U32:
  pick(String.eq(action, "turn.left"), 1, pick(String.eq(action, "turn.right"), 2, 0))
