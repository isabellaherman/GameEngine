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
   Spec.Shortcut{0, 0, "4", "view.z"}]

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
