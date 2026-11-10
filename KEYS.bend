# The engine's keymap: every shortcut of the engine lives here, in one list.
# LAWS.bend checks it together with Bend-UI's keys, so no two ever overlap.
#
# Views, as in Blender's numpad (top-row digits work too): 1 front, 3 right,
# 7 top. Blender takes Ctrl for the opposite side; the browser keeps ⌘/Ctrl +
# digit for tabs, so the engine takes Alt (⌥).

import Base
import ./node_modules/bend-ui/SPEC.bend as Spec

def keymap() -> List<&2, Spec.Shortcut>:
  [Spec.Shortcut{0, 0, "1", "view.front"},
   Spec.Shortcut{0, 0, "3", "view.right"},
   Spec.Shortcut{0, 0, "7", "view.top"},
   Spec.Shortcut{0, Spec.alt(), "1", "view.back"},
   Spec.Shortcut{0, Spec.alt(), "3", "view.left"},
   Spec.Shortcut{0, Spec.alt(), "7", "view.bottom"}]

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# The gizmo handle each view looks from (engine/gizmo.bend: 0 +X, 1 +Y,
# 2 +Z, 3 -X, 4 -Y, 5 -Z), or 6 for an action that is not a view.
def view_handle(+action: String) -> U32:
  pick(String.eq(action, "view.front"), 2,
  pick(String.eq(action, "view.right"), 0,
  pick(String.eq(action, "view.top"), 1,
  pick(String.eq(action, "view.back"), 5,
  pick(String.eq(action, "view.left"), 3,
  pick(String.eq(action, "view.bottom"), 4, 6))))))
