import Base
import ./engine/vec3.bend as V
import ./engine/camera.bend as C
import ./engine/sphere.bend as S
import ./engine/renderer.bend as R
import ./engine/editor.bend as E
import ./engine/ui.bend as U

def expect(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS: " ++ label)
    case False{}:
      IO.die(Unit, 1, "FAIL: " ++ label)

def near(a: F32, b: F32) -> Bool:
  F32.is_lt(F32.abs((a - b : F32)), 0.0001)

# Consulta a imagem realmente construída na GPU, inclusive os limites de blocos.
def sample(+depth: Nat, image: Image, +x: U32, +y: U32) -> U32:
  match depth image:
    case _ Pix{color}:
      color
    case 0n Qua{tl, _, _, _}:
      0
    case 1n+d Qua{tl, tr, bl, br}:
      +half = (1 << d : U32)
      row = Bool.pick(Image, U32.is_lt(x, half), tl, tr)
      other = Bool.pick(Image, U32.is_lt(x, half), bl, br)
      chosen = Bool.pick(Image, U32.is_lt(y, half), row, other)
      sample(d, chosen, (x % half : U32), (y % half : U32))

def byte_near(+a: U32, +b: U32) -> Bool:
  near(U32.to_f32(a), U32.to_f32(b)) || U32.is_eq((a + 1 : U32), b)
    || U32.is_eq((b + 1 : U32), a)

def color_near(+a: U32, +b: U32) -> Bool:
  byte_near((a .&. 255 : U32), (b .&. 255 : U32))
    && byte_near(((a >> 8n) .&. 255 : U32), ((b >> 8n) .&. 255 : U32))
    && byte_near(((a >> 16n) .&. 255 : U32), ((b >> 16n) .&. 255 : U32))

def ui(+hover: U32) -> U.Ui:
  U.Ui{U.palette(), True{}, hover, 2, 0.45}

def check_pixel(image: Image, +x: U32, +y: U32) -> IO(Unit):
  expect(color_near(sample(10n, image, x, y), E.pixel(ui(0), C.orbit(0.45), x, y)),
    "frame / reference pixel " ++ U32.show(x) ++ "," ++ U32.show(y))

def same(+a: U32, +b: U32, label: String) -> IO(Unit):
  expect(U32.is_eq(a, b), label ++ " (" ++ U32.show(a) ++ ")")

def main() -> IO(Unit):
  do IO<Unit>:
    expect(near(S.intersect(S.unit(), V.Vec3{0.0, 0.0, 3.0},
      V.Vec3{0.0, 0.0, F32.neg(1.0)}), 2.0), "sphere: nearest hit")
    expect(near(S.intersect(S.unit(), V.Vec3{1.0, 0.0, 3.0},
      V.Vec3{0.0, 0.0, F32.neg(1.0)}), 3.0), "sphere: tangent")
    expect(near(S.intersect(S.unit(), V.Vec3{0.0, 0.0, 0.0},
      V.Vec3{1.0, 0.0, 0.0}), 1.0), "sphere: ray from inside")
    expect(F32.is_lt(S.intersect(S.unit(), V.Vec3{0.0, 0.0, 3.0},
      V.Vec3{0.0, 0.0, 1.0}), 0.0), "sphere: behind camera")
    expect(F32.is_lt(S.intersect(S.unit(), V.Vec3{2.0, 0.0, 3.0},
      V.Vec3{0.0, 0.0, F32.neg(1.0)}), 0.0), "sphere: miss")
    expect(U32.is_eq(R.rgb(1.0, 0.0, 0.0), 16711680), "image: RGB packing")
    same(U.hex("#3b5bdb"), 3890139, "ui: hex token")
    same(U.width(), 1024, "ui: window width")
    same(U.height(), 552, "ui: window height")
    same(U.hit(20.0, 20.0), 1, "ui: hit play")
    same(U.hit(100.0, 20.0), 2, "ui: hit reset")
    same(U.hit(92.0, 20.0), 0, "ui: gap between buttons")
    same(U.hit(20.0, 80.0), 10, "ui: hit outline camera")
    same(U.hit(20.0, 147.0), 12, "ui: hit outline sphere")
    same(U.hit(400.0, 300.0), 0, "ui: viewport is not a button")
    same(U.pixel(ui(0), 10, 20), 3890139, "ui: play is accent")
    expect(Bool.not(U32.is_eq(U.pixel(ui(1), 10, 20), 3890139)), "ui: play hover")
    same(U.pixel(ui(0), 500, 10), 1710616, "ui: toolbar surface")
    same(U.pixel(ui(0), 500, 39), 3026218, "ui: toolbar border")
    same(U.pixel(ui(0), 240, 158), 2302753, "ui: selected row")
    same(U.pixel(ui(0), 240, 90), 1710616, "ui: plain row")
    same(U.pixel(ui(10), 240, 90), 2302753, "ui: hovered row")
    same(U.pixel(ui(0), 255, 300), 3026218, "ui: outline border")
    same(U.pixel(ui(0), 768, 300), 3026218, "ui: inspector border")
    same(U.pixel(ui(0), 1000, 500), 1710616, "ui: inspector surface")
    same(U.number_len(F32.neg(1.05)), 5, "ui: number length")
    same(U.number_char(F32.neg(1.05), 0), 45, "ui: number minus")
    same(U.number_char(F32.neg(1.05), 1), 49, "ui: number digit")
    same(U.number_char(F32.neg(1.05), 2), 46, "ui: number dot")
    same(U.number_char(F32.neg(1.05), 4), 53, "ui: number hundredths")
    same(U.number_char(4.2, 3), 48, "ui: number trailing zero")
    same(E.pixel(ui(0), C.orbit(0.45), 266, 50), R.scene(C.orbit(0.45), 10, 10),
      "editor: viewport offset")
    +image : Image = E.frame(ui(0), C.orbit(0.45))
    check_pixel(image, 0, 0)
    check_pixel(image, 20, 20)
    check_pixel(image, 240, 158)
    check_pixel(image, 300, 100)
    check_pixel(image, 511, 295)
    check_pixel(image, 512, 296)
    check_pixel(image, 767, 551)
    check_pixel(image, 800, 200)
    check_pixel(image, 1023, 551)
    IO.print("All engine checks passed.")
