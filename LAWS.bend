# The engine's laws. `bend PROOF.bend` must print ALL PROOFS CHECK.

import Base
import ./node_modules/bend-ui/SPEC.bend as Spec
import ./node_modules/bend-ui/KEYS.bend as K
import ./SPEC.bend as ES
import ./KEYS.bend as Keys

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
