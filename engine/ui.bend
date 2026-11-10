# Minimal native adapter for Bend-UI: the scene editor's chrome drawn as pixels.
# Values come from Bend-UI/TOKENS.bend (dark theme); nothing here needs a browser.
# Experimental: only the components this editor uses (toolbar, side, buttons, labels).
import Base
import ../../Bend-UI/TOKENS.bend as T
import ./font.bend as Fo
import ./vec3.bend as V
import ./camera.bend as C
import ./sphere.bend as S
import ./renderer.bend as R

# ---------- Palette: the tokens' "#rrggbb" strings parsed once, on the CPU ----------

type Palette is Data:
  Palette{surface: U32, surface_2: U32, border: U32, border_strong: U32,
    text: U32, text_2: U32, accent: U32, accent_fg: U32}

def hex_digit(c: Char) -> U32:
  +x = Char.to_u32(c)
  Bool.pick(U32, U32.is_lt(x, 58), (x - 48 : U32),
    Bool.pick(U32, U32.is_lt(x, 71), (x - 55 : U32), (x - 87 : U32)))

def hex_go(cs: List<&2, Char>, acc: U32) -> U32:
  match cs:
    case Nil{}:
      acc
    case Con{c, rest}:
      hex_go(rest, ((acc << 4n) .|. hex_digit(c) : U32))

# "#3b5bdb" -> 0x3b5bdb
def hex(s: String) -> U32:
  hex_go(String.to_list(String.drop(s, 1n)), 0)

def palette() -> Palette:
  Palette{hex(T.dark_surface()), hex(T.dark_surface_2()), hex(T.dark_border()),
    hex(T.dark_border_strong()), hex(T.dark_text()), hex(T.dark_text_2()),
    hex(T.color_accent()), hex(T.color_accent_fg())}

# ---------- What the editor shows this frame ----------

# hover: what the pointer is on (see hit). selected: the object in the inspector.
# angle: the camera's current orbit angle, shown live.
type Ui is Data:
  Ui{palette: Palette, paused: Bool, hover: U32, selected: U32, angle: F32}

# Scene objects, in the outline's order: 0 Camera, 1 Light, 2 Sphere, 3 Floor.
def objects() -> U32: 4

def object_label(+k: U32) -> U32:
  (k + 2 : U32)

# ---------- Layout (pixels), from the tokens ----------

def scale() -> U32: 2              # 5x7 glyphs drawn 2x: 14px caps, close to text_md
def advance() -> U32: (6 * scale() : U32)
def text_h() -> U32: (7 * scale() : U32)

def text_w(+n: U32) -> U32:
  Bool.pick(U32, U32.is_eq(n, 0), 0, (n * advance() - scale() : U32))

# The viewport is a fixed 512 x 512 square: the camera's rays assume it.
def viewport() -> U32: 512
# Toolbar (.toolbar): one md control plus space_1 above and below.
def toolbar_h() -> U32: (T.control_md() + 2 * T.space_1() : U32)
def side_w() -> U32: T.side_width()
def view_x() -> U32: side_w()
def view_y() -> U32: toolbar_h()
def width() -> U32: (2 * side_w() + viewport() : U32)
def height() -> U32: (toolbar_h() + viewport() : U32)
def inspector_x() -> U32: (side_w() + viewport() : U32)

# Toolbar buttons: both as wide as the longest label (5 letters), so nothing shifts.
def button_w() -> U32: (text_w(5) + 2 * T.btn_padding_x() : U32)
def button_x(+i: U32) -> U32: (T.space_2() + i * (button_w() + T.space_1()) : U32)
def button_y() -> U32: T.space_1()

# Side bars (.side): a label (.side__label) and rows (ghost buttons) under it.
def label_y() -> U32: (view_y() + T.space_1() + T.space_3() : U32)
def rows_y() -> U32: (label_y() + text_h() + T.space_1() : U32)
def row_x(+side: U32) -> U32: (side + T.side_padding() : U32)
def row_w() -> U32: (side_w() - 2 * T.side_padding() : U32)
def row_step() -> U32: (T.control_md() + T.space_hairline() : U32)
def row_y(+k: U32) -> U32: (rows_y() + k * row_step() : U32)
def text_x(+side: U32) -> U32: (row_x(side) + T.space_2() : U32)
def row_text_y(+k: U32) -> U32: (row_y(k) + (T.control_md() - text_h()) / 2 : U32)

def within(+v: F32, +lo: U32, +size: U32) -> Bool:
  F32.is_ge(v, U32.to_f32(lo)) && F32.is_lt(v, U32.to_f32((lo + size : U32)))

def row_hit(+x: F32, +y: F32, k: Nat) -> U32:
  match k:
    case 0n:
      0
    case 1n+(+n):
      +j = U32.from_nat(n)
      Bool.pick(U32, within(x, row_x(0), row_w()) && within(y, row_y(j), T.control_md()),
        (10 + j : U32), row_hit(x, y, n))

# What a point is on: 1 play/pause, 2 reset, 10 + k the outline's row k, 0 nothing.
def hit(+x: F32, +y: F32) -> U32:
  +bar = within(y, button_y(), T.btn_height())
  Bool.pick(U32, bar && within(x, button_x(0), button_w()), 1,
    Bool.pick(U32, bar && within(x, button_x(1), button_w()), 2,
      row_hit(x, y, U32.to_nat(objects()))))

def in_viewport(+x: U32, +y: U32) -> Bool:
  U32.is_ge(x, view_x()) && U32.is_lt(x, (view_x() + viewport() : U32))
    && U32.is_ge(y, view_y())

# ---------- Text ----------

def glyph_on(+c: U32, +col: U32, +row: U32) -> Bool:
  +bits = Bool.pick(U32, U32.is_lt(row, 4),
    ((Fo.glyph_hi(c) >> U32.to_nat((5 * (3 - row) : U32))) .&. 31 : U32),
    ((Fo.glyph_lo(c) >> U32.to_nat((5 * (6 - row) : U32))) .&. 31 : U32))
  U32.is_lt(col, 5) && U32.is_eq(((bits >> U32.to_nat((4 - col : U32))) .&. 1 : U32), 1)

def box_on(+tx: U32, +ty: U32, +n: U32, +x: U32, +y: U32) -> Bool:
  U32.is_ge(x, tx) && U32.is_ge(y, ty) && U32.is_lt(x, (tx + text_w(n) : U32))
    && U32.is_lt(y, (ty + text_h() : U32))

def label_at(inside: Bool, +label: U32, +tx: U32, +ty: U32, +x: U32, +y: U32) -> Bool:
  match inside:
    case False{}:
      False{}
    case True{}:
      +dx = ((x - tx) / scale() : U32)
      glyph_on(Fo.label_char(label, (dx / 6 : U32)), (dx % 6 : U32), ((y - ty) / scale() : U32))

# Is pixel (x, y) ink of the label whose top-left is (tx, ty)?
def label_on(+label: U32, +tx: U32, +ty: U32, +x: U32, +y: U32) -> Bool:
  label_at(box_on(tx, ty, Fo.label_len(label), x, y), label, tx, ty, x, y)

# Numbers: two decimals, "-" when negative ("-1.05", "0.45", "4.20").
def hundredths(+v: F32) -> U32:
  F32.to_u32((F32.abs(v) * 100.0 + 0.5 : F32))

def negative(+v: F32) -> U32:
  Bool.pick(U32, U32.is_eq(hundredths(v), 0) || F32.is_ge(v, 0.0), 0, 1)

def int_digits(+v: F32) -> U32:
  +whole = (hundredths(v) / 100 : U32)
  Bool.pick(U32, U32.is_ge(whole, 100), 3, Bool.pick(U32, U32.is_ge(whole, 10), 2, 1))

def number_len(+v: F32) -> U32:
  (negative(v) + int_digits(v) + 3 : U32)

def pow10(p: U32) -> U32:
  match p:
    case 0:
      1
    case 1:
      10
    case _:
      100

def digit(+d: U32) -> U32:
  (48 + d % 10 : U32)

def number_char(+v: F32, +i: U32) -> U32:
  +neg = negative(v)
  +n = hundredths(v)
  +nd = int_digits(v)
  +j = (i - neg : U32)
  Bool.pick(U32, U32.is_eq(neg, 1) && U32.is_eq(i, 0), 45,
    Bool.pick(U32, U32.is_lt(j, nd), digit(((n / 100) / pow10((nd - 1 - j : U32)) : U32)),
      Bool.pick(U32, U32.is_eq(j, nd), 46,
        Bool.pick(U32, U32.is_eq(j, (nd + 1 : U32)), digit((n / 10 : U32)), digit(n)))))

def number_at(inside: Bool, +v: F32, +tx: U32, +ty: U32, +x: U32, +y: U32) -> Bool:
  match inside:
    case False{}:
      False{}
    case True{}:
      +dx = ((x - tx) / scale() : U32)
      glyph_on(number_char(v, (dx / 6 : U32)), (dx % 6 : U32), ((y - ty) / scale() : U32))

# A number drawn so that it ends at `right`.
def number_on(+v: F32, +right: U32, +ty: U32, +x: U32, +y: U32) -> Bool:
  +tx = (right - text_w(number_len(v)) : U32)
  number_at(box_on(tx, ty, number_len(v), x, y), v, tx, ty, x, y)

# ---------- Paint ----------

def byte(+c: U32, s: Nat) -> F32:
  U32.to_f32(((c >> s) .&. 255 : U32))

def mix_byte(+a: U32, +b: U32, +s: Nat, +t: F32) -> U32:
  F32.to_u32((F32.lerp(byte(a, s), byte(b, s), t) + 0.5 : F32))

# a -> b by t (0..1), per channel.
def mix(+a: U32, +b: U32, +t: F32) -> U32:
  ((mix_byte(a, b, 16n, t) << 16n) .|. (mix_byte(a, b, 8n, t) << 8n)
    .|. mix_byte(a, b, 0n, t) : U32)

# Bend-UI's hover on a filled button: brightness(btn_hover_brightness), i.e. x 1.08.
def brighten(+c: U32) -> U32:
  mix(c, 16777215, 0.08)

# How much of pixel (x, y) a rounded rectangle covers, 0..1, with soft corners.
def cover(+x: U32, +y: U32, +rx: U32, +ry: U32, +w: U32, +h: U32, +r: U32) -> F32:
  +px = (U32.to_f32(x) + 0.5 : F32)
  +py = (U32.to_f32(y) + 0.5 : F32)
  +fr = U32.to_f32(r)
  +x0 = (U32.to_f32(rx) + fr : F32)
  +x1 = (U32.to_f32((rx + w : U32)) - fr : F32)
  +y0 = (U32.to_f32(ry) + fr : F32)
  +y1 = (U32.to_f32((ry + h : U32)) - fr : F32)
  +qx = F32.max(F32.max((x0 - px : F32), (px - x1 : F32)), 0.0)
  +qy = F32.max(F32.max((y0 - py : F32), (py - y1 : F32)), 0.0)
  F32.clamp((fr + 0.5 - F32.sqrt((qx * qx + qy * qy : F32)) : F32), 0.0, 1.0)

# A rounded shape filled with `fill` and a border_width ring of `edge`, over `under`.
def boxed(+under: U32, +fill: U32, +edge: U32, +x: U32, +y: U32, +rx: U32, +ry: U32,
    +w: U32, +h: U32, +r: U32) -> U32:
  +b = T.border_width()
  outer = cover(x, y, rx, ry, w, h, r)
  inner = cover(x, y, (rx + b : U32), (ry + b : U32), (w - 2 * b : U32),
    (h - 2 * b : U32), (r - b : U32))
  mix(under, mix(edge, fill, inner), outer)

def ink(+under: U32, +color: U32, on: Bool) -> U32:
  Bool.pick(U32, on, color, under)

# ---------- Toolbar (.toolbar): play/pause (.btn--primary) and reset (.btn) ----------

def button(+ui: Ui, +i: U32, +under: U32, +x: U32, +y: U32) -> U32:
  Ui{+pal, +paused, +hover, _, _} = ui
  Palette{+surface, +surface_2, _, +border_strong, +text, _, +accent, +accent_fg} = pal
  +primary = U32.is_eq(i, 0)
  +hot = U32.is_eq(hover, (i + 1 : U32))
  +fill = Bool.pick(U32, primary, Bool.pick(U32, hot, brighten(accent), accent),
    Bool.pick(U32, hot, surface_2, surface))
  +edge = Bool.pick(U32, primary, fill, border_strong)
  +fg = Bool.pick(U32, primary, accent_fg, text)
  +label = Bool.pick(U32, primary, Bool.pick(U32, paused, 6, 7), 8)
  +bx = button_x(i)
  +tx = (bx + (button_w() - text_w(Fo.label_len(label))) / 2 : U32)
  +ty = (button_y() + (T.btn_height() - text_h()) / 2 : U32)
  painted = boxed(under, fill, edge, x, y, bx, button_y(), button_w(), T.btn_height(),
    T.btn_radius())
  ink(painted, fg, label_on(label, tx, ty, x, y))

def toolbar(+ui: Ui, +x: U32, +y: U32) -> U32:
  Ui{+pal, _, _, _, _} = ui
  Palette{+surface, _, +border, _, _, _, _, _} = pal
  +ground = Bool.pick(U32, U32.is_ge(y, (toolbar_h() - T.border_width() : U32)), border,
    surface)
  button(ui, 1, button(ui, 0, ground, x, y), x, y)

# ---------- Outline (left .side): the scene's objects as ghost buttons ----------

def outline_row(+ui: Ui, +k: U32, +x: U32, +y: U32) -> U32:
  Ui{+pal, _, +hover, +selected, _} = ui
  Palette{+surface, +surface_2, _, _, +text, +text_2, _, _} = pal
  # Current or hovered: surface_2 and text (.btn--ghost); otherwise plain, in text_2.
  +lit = U32.is_eq(selected, k) || U32.is_eq(hover, (10 + k : U32))
  +fill = Bool.pick(U32, lit, surface_2, surface)
  painted = boxed(surface, fill, fill, x, y, row_x(0), row_y(k), row_w(), T.control_md(),
    T.btn_radius())
  ink(painted, Bool.pick(U32, lit, text, text_2),
    label_on(object_label(k), text_x(0), row_text_y(k), x, y))

def outline_head(+ui: Ui, +x: U32, +y: U32) -> U32:
  Ui{+pal, _, _, _, _} = ui
  Palette{+surface, _, _, _, _, +text_2, _, _} = pal
  ink(surface, text_2, label_on(0, text_x(0), label_y(), x, y))

def outline_body(in_rows: Bool, +ui: Ui, +x: U32, +y: U32) -> U32:
  match in_rows:
    case True{}:
      outline_row(ui, ((y - rows_y()) / row_step() : U32), x, y)
    case False{}:
      outline_head(ui, x, y)

def outline_edge(edge: Bool, +ui: Ui, +x: U32, +y: U32) -> U32:
  match edge:
    case True{}:
      Ui{+pal, _, _, _, _} = ui
      Palette{_, _, +border, _, _, _, _, _} = pal
      border
    case False{}:
      outline_body(U32.is_ge(y, rows_y())
        && U32.is_lt(((y - rows_y()) / row_step() : U32), objects()), ui, x, y)

def outline(+ui: Ui, +x: U32, +y: U32) -> U32:
  outline_edge(U32.is_ge(x, (side_w() - T.border_width() : U32)), ui, x, y)

# ---------- Inspector (right .side): the selected object's values, read from the engine ----------

# How many properties each object shows.
def prop_count(selected: U32) -> U32:
  match selected:
    case 0:
      3
    case 1:
      3
    case 2:
      4
    case _:
      1

def center_of(s: S.Sphere) -> V.Vec3:
  S.Sphere{center, _} = s
  center

def radius_of(s: S.Sphere) -> F32:
  S.Sphere{_, radius} = s
  radius

def sphere_center() -> V.Vec3:
  center_of(S.unit())

def sphere_radius() -> F32:
  radius_of(S.unit())

def axis(+i: U32, v: V.Vec3) -> F32:
  V.Vec3{x, y, z} = v
  Bool.pick(F32, U32.is_eq(i, 0), x, Bool.pick(F32, U32.is_eq(i, 1), y, z))

# Property i of an object: its label (font.bend's ids) and its value.
def prop_label(selected: U32, +i: U32) -> U32:
  match selected:
    case 0:
      (9 + i : U32)    # ORBIT, HEIGHT, ANGLE
    case 1:
      (12 + i : U32)   # DIR X, DIR Y, DIR Z
    case 2:
      (15 + i : U32)   # X, Y, Z, RADIUS
    case _:
      10               # HEIGHT

def camera_value(+i: U32, angle: F32) -> F32:
  match i:
    case 0:
      C.distance()
    case 1:
      C.height()
    case _:
      angle

def sphere_value(i: U32) -> F32:
  match i:
    case 3:
      sphere_radius()
    case _:
      axis(i, sphere_center())

def prop_value(selected: U32, +i: U32, angle: F32) -> F32:
  match selected:
    case 0:
      camera_value(i, angle)
    case 1:
      axis(i, R.light())
    case 2:
      sphere_value(i)
    case _:
      R.floor_y()

def prop_row(+ui: Ui, +i: U32, +x: U32, +y: U32) -> U32:
  Ui{+pal, _, _, +selected, +angle} = ui
  Palette{+surface, _, _, _, +text, +text_2, _, _} = pal
  +ty = row_text_y((i + 1 : U32))
  +right = (width() - T.side_padding() - T.space_2() : U32)
  named = ink(surface, text_2,
    label_on(prop_label(selected, i), text_x(inspector_x()), ty, x, y))
  ink(named, text, number_on(prop_value(selected, i, angle), right, ty, x, y))

def inspector_title(+ui: Ui, +x: U32, +y: U32) -> U32:
  Ui{+pal, _, _, +selected, _} = ui
  Palette{+surface, _, _, _, +text, _, _, _} = pal
  ink(surface, text, label_on(object_label(selected), text_x(inspector_x()), row_text_y(0), x, y))

def inspector_head(+ui: Ui, +x: U32, +y: U32) -> U32:
  Ui{+pal, _, _, _, _} = ui
  Palette{+surface, _, _, _, _, +text_2, _, _} = pal
  ink(surface, text_2, label_on(1, text_x(inspector_x()), label_y(), x, y))

# Row 0 names the object; the rows under it are its properties.
def inspector_row(+k: U32, +ui: Ui, +x: U32, +y: U32) -> U32:
  match k:
    case 0:
      inspector_title(ui, x, y)
    case _:
      prop_row(ui, (k - 1 : U32), x, y)

def inspector_body(in_rows: Bool, +ui: Ui, +x: U32, +y: U32) -> U32:
  match in_rows:
    case True{}:
      inspector_row(((y - rows_y()) / row_step() : U32), ui, x, y)
    case False{}:
      inspector_head(ui, x, y)

def inspector_rows(+ui: Ui) -> U32:
  Ui{_, _, _, selected, _} = ui
  (prop_count(selected) + 1 : U32)

def inspector_edge(edge: Bool, +ui: Ui, +x: U32, +y: U32) -> U32:
  match edge:
    case True{}:
      Ui{+pal, _, _, _, _} = ui
      Palette{_, _, +border, _, _, _, _, _} = pal
      border
    case False{}:
      inspector_body(U32.is_ge(y, rows_y())
        && U32.is_lt(((y - rows_y()) / row_step() : U32), inspector_rows(ui)), ui, x, y)

def inspector(+ui: Ui, +x: U32, +y: U32) -> U32:
  inspector_edge(U32.is_lt(x, (inspector_x() + T.border_width() : U32)), ui, x, y)

# ---------- The editor's chrome at (x, y), outside the viewport ----------

def sides(left: Bool, +ui: Ui, +x: U32, +y: U32) -> U32:
  match left:
    case True{}:
      outline(ui, x, y)
    case False{}:
      inspector(ui, x, y)

def chrome(bar: Bool, +ui: Ui, +x: U32, +y: U32) -> U32:
  match bar:
    case True{}:
      toolbar(ui, x, y)
    case False{}:
      sides(U32.is_lt(x, side_w()), ui, x, y)

def pixel(+ui: Ui, +x: U32, +y: U32) -> U32:
  chrome(U32.is_lt(y, toolbar_h()), ui, x, y)
