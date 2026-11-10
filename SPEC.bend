# What the engine's own rules mean. It stays fixed beside LAWS.bend, so no one
# changes what a law means by changing a helper. Bend-UI's SPEC.bend still
# holds the shared meanings (clash, scopes, exact modifiers, typing).

import Base
import ./node_modules/bend-ui/SPEC.bend as Spec

def is_digit(+key: String) -> Bool:
  (String.eq(key, "1") || String.eq(key, "2") || String.eq(key, "3") || String.eq(key, "4")
    || String.eq(key, "5") || String.eq(key, "6") || String.eq(key, "7") || String.eq(key, "8")
    || String.eq(key, "9"))

# Keys the browser keeps beyond Bend-UI's list: ⌘/Ctrl + 1..9 switch tabs.
def browser_keeps(k: Spec.Shortcut) -> Bool:
  match k:
    case Spec.Shortcut{_, +m, +key, _}:
      (U32.is_eq((m .&. Spec.mod() : U32), Spec.mod()) && is_digit(key))

def browser_kept(xs: List<&2, Spec.Shortcut>) -> U32:
  match xs:
    case Nil{}:
      0
    case h <> t:
      (Spec.as_count(browser_keeps(h)) + browser_kept(t) : U32)
