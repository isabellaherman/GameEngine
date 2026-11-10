# O editor de cena: toolbar, outline, viewport 3D e inspector numa só imagem.
# A cena e a UI do Bend-UI são calculadas pixel a pixel no mesmo kernel (GPU).
import Base
import ./camera.bend as C
import ./renderer.bend as R
import ./ui.bend as U

def layered(view: Bool, +ui: U.Ui, camera: C.Camera, +x: U32, +y: U32) -> U32:
  match view:
    case True{}:
      R.scene(camera, (x - U.view_x() : U32), (y - U.view_y() : U32))
    case False{}:
      U.pixel(ui, x, y)

def pixel(+ui: U.Ui, camera: C.Camera, +x: U32, +y: U32) -> U32:
  layered(U.in_viewport(x, y), ui, camera, x, y)

# Blocos de 4x4 pixels por tarefa: não criamos uma tarefa de GPU por pixel.
def block2(+ui: U.Ui, +camera: C.Camera, +x: U32, +y: U32) -> Image:
  Qua{Pix{pixel(ui, camera, x, y)}, Pix{pixel(ui, camera, (x + 1 : U32), y)},
    Pix{pixel(ui, camera, x, (y + 1 : U32))},
    Pix{pixel(ui, camera, (x + 1 : U32), (y + 1 : U32))}}

def block4(+ui: U.Ui, +camera: C.Camera, +x: U32, +y: U32) -> Image:
  Qua{block2(ui, camera, x, y), block2(ui, camera, (x + 2 : U32), y),
    block2(ui, camera, x, (y + 2 : U32)),
    block2(ui, camera, (x + 2 : U32), (y + 2 : U32))}

# A imagem é um quadrado de 1024; os blocos abaixo da janela (live = False) não são calculados.
def tiles(+depth: Nat, live: Bool, +ui: U.Ui, +camera: C.Camera, +x: U32, +y: U32,
    +size: U32) -> Image:
  match depth live:
    case _ False{}:
      Pix{0}
    case 0n True{}:
      block4(ui, camera, x, y)
    case 1n+d True{}:
      +half = (size / 2 : U32)
      +low = (y + half : U32)
      +below = U32.is_lt(low, U.height())
      a b c e = tiles(d, True{}, ui, camera, x, y, half)
        tiles(d, True{}, ui, camera, (x + half : U32), y, half)
        tiles(d, below, ui, camera, x, low, half)
        tiles(d, below, ui, camera, (x + half : U32), low, half)
      Qua{a, b, c, e}

def frame(ui: U.Ui, camera: C.Camera) -> Image:
  tiles!(8n, True{}, ui, camera, 0, 0, 1024)
