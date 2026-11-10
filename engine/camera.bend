import Base
import ./vec3.bend as V

type Camera is Data:
  Camera{origin: V.Vec3, forward: V.Vec3, right: V.Vec3, up: V.Vec3}

# Raio e altura da órbita (o Inspector mostra estes mesmos valores).
def distance() -> F32: 4.2
def height() -> F32: 1.8

# Órbita em torno da origem, mirando no centro da esfera.
def orbit(+angle: F32) -> Camera:
  +origin = {V.Vec3{(distance() * F32.sin(angle) : F32), height(),
    (distance() * F32.cos(angle) : F32)} : V.Vec3}
  +forward = V.normalize(V.scale(origin, F32.neg(1.0)))
  +right = V.normalize(V.cross(forward, V.Vec3{0.0, 1.0, 0.0}))
  up = V.cross(right, forward)
  Camera{origin, forward, right, up}

# Centro do pixel, perspectiva de aproximadamente 45 graus, imagem quadrada.
def ray(camera: Camera, x: U32, y: U32) -> V.Vec3 & V.Vec3:
  Camera{origin, forward, right, up} = camera
  sx = (((U32.to_f32(x) + 0.5) / 256.0 - 1.0) * 0.41421356 : F32)
  sy = ((1.0 - (U32.to_f32(y) + 0.5) / 256.0) * 0.41421356 : F32)
  direction = V.normalize(V.add(forward, V.add(V.scale(right, sx), V.scale(up, sy))))
  (origin, direction)
