import Base

# Vetores de ponto flutuante usados por câmera, raios e iluminação.
type Vec3 is Data:
  Vec3{x: F32, y: F32, z: F32}

def add(a: Vec3, b: Vec3) -> Vec3:
  Vec3{ax, ay, az} = a
  Vec3{bx, by, bz} = b
  Vec3{(ax + bx : F32), (ay + by : F32), (az + bz : F32)}

def sub(a: Vec3, b: Vec3) -> Vec3:
  Vec3{ax, ay, az} = a
  Vec3{bx, by, bz} = b
  Vec3{(ax - bx : F32), (ay - by : F32), (az - bz : F32)}

def scale(v: Vec3, +s: F32) -> Vec3:
  Vec3{x, y, z} = v
  Vec3{(x * s : F32), (y * s : F32), (z * s : F32)}

def dot(a: Vec3, b: Vec3) -> F32:
  Vec3{ax, ay, az} = a
  Vec3{bx, by, bz} = b
  (ax * bx + ay * by + az * bz : F32)

def cross(a: Vec3, b: Vec3) -> Vec3:
  Vec3{+ax, +ay, +az} = a
  Vec3{+bx, +by, +bz} = b
  Vec3{(ay * bz - az * by : F32), (az * bx - ax * bz : F32),
    (ax * by - ay * bx : F32)}

def normalize(+v: Vec3) -> Vec3:
  scale(v, (1.0 / F32.sqrt(F32.max(dot(v, v), 0.00000001)) : F32))
