# 5x7 bitmap font and the editor's labels. Generated table: edit with care.
# A glyph is 7 rows of 5 bits (bit 4 is the left column): hi packs rows 0-3, lo rows 4-6.
# Character codes are ASCII; 0 or any code not here draws nothing (a space).
import Base

def glyph_hi(c: U32) -> U32:
  match c:
    case 65:  # A
      476735
    case 66:  # B
      1001022
    case 67:  # C
      476688
    case 68:  # D
      1001009
    case 69:  # E
      1032734
    case 70:  # F
      1032734
    case 71:  # G
      476695
    case 72:  # H
      575039
    case 73:  # I
      462980
    case 74:  # J
      231490
    case 75:  # K
      576152
    case 76:  # L
      541200
    case 77:  # M
      585397
    case 78:  # N
      575285
    case 79:  # O
      476721
    case 80:  # P
      1001022
    case 81:  # Q
      476721
    case 82:  # R
      1001022
    case 83:  # S
      508430
    case 84:  # T
      1020036
    case 85:  # U
      575025
    case 86:  # V
      575025
    case 87:  # W
      575029
    case 88:  # X
      574788
    case 89:  # Y
      574788
    case 90:  # Z
      1016900
    case 48:  # 0
      476789
    case 49:  # 1
      143492
    case 50:  # 2
      476194
    case 51:  # 3
      1017986
    case 52:  # 4
      72018
    case 53:  # 5
      1033153
    case 54:  # 6
      205342
    case 55:  # 7
      1016900
    case 56:  # 8
      476718
    case 57:  # 9
      476719
    case 46:  # .
      0
    case 45:  # -
      31
    case _:
      0

def glyph_lo(c: U32) -> U32:
  match c:
    case 65:  # A
      17969
    case 66:  # B
      17982
    case 67:  # C
      16942
    case 68:  # D
      17982
    case 69:  # E
      16927
    case 70:  # F
      16912
    case 71:  # G
      17967
    case 72:  # H
      17969
    case 73:  # I
      4238
    case 74:  # J
      2636
    case 75:  # K
      21073
    case 76:  # L
      16927
    case 77:  # M
      17969
    case 78:  # N
      20017
    case 79:  # O
      17966
    case 80:  # P
      16912
    case 81:  # Q
      22093
    case 82:  # R
      21073
    case 83:  # S
      1086
    case 84:  # T
      4228
    case 85:  # U
      17966
    case 86:  # V
      17732
    case 87:  # W
      22186
    case 88:  # X
      10801
    case 89:  # Y
      4228
    case 90:  # Z
      8735
    case 48:  # 0
      26158
    case 49:  # 1
      4238
    case 50:  # 2
      4383
    case 51:  # 3
      1582
    case 52:  # 4
      31810
    case 53:  # 5
      1582
    case 54:  # 6
      17966
    case 55:  # 7
      8456
    case 56:  # 8
      17966
    case 57:  # 9
      1100
    case 46:  # .
      396
    case 45:  # -
      0
    case _:
      0

# Labels, by id:
#    0 SCENE
#    1 INSPECTOR
#    2 CAMERA
#    3 LIGHT
#    4 SPHERE
#    5 FLOOR
#    6 PLAY
#    7 PAUSE
#    8 RESET
#    9 ORBIT
#   10 HEIGHT
#   11 ANGLE
#   12 DIR X
#   13 DIR Y
#   14 DIR Z
#   15 X
#   16 Y
#   17 Z
#   18 RADIUS

def label_len(label: U32) -> U32:
  match label:
    case 0:
      5
    case 1:
      9
    case 2:
      6
    case 3:
      5
    case 4:
      6
    case 5:
      5
    case 6:
      4
    case 7:
      5
    case 8:
      5
    case 9:
      5
    case 10:
      6
    case 11:
      5
    case 12:
      5
    case 13:
      5
    case 14:
      5
    case 15:
      1
    case 16:
      1
    case 17:
      1
    case 18:
      6
    case _:
      0

def label_0(i: U32) -> U32:  # SCENE
  match i:
    case 0:
      83
    case 1:
      67
    case 2:
      69
    case 3:
      78
    case 4:
      69
    case _:
      0

def label_1(i: U32) -> U32:  # INSPECTOR
  match i:
    case 0:
      73
    case 1:
      78
    case 2:
      83
    case 3:
      80
    case 4:
      69
    case 5:
      67
    case 6:
      84
    case 7:
      79
    case 8:
      82
    case _:
      0

def label_2(i: U32) -> U32:  # CAMERA
  match i:
    case 0:
      67
    case 1:
      65
    case 2:
      77
    case 3:
      69
    case 4:
      82
    case 5:
      65
    case _:
      0

def label_3(i: U32) -> U32:  # LIGHT
  match i:
    case 0:
      76
    case 1:
      73
    case 2:
      71
    case 3:
      72
    case 4:
      84
    case _:
      0

def label_4(i: U32) -> U32:  # SPHERE
  match i:
    case 0:
      83
    case 1:
      80
    case 2:
      72
    case 3:
      69
    case 4:
      82
    case 5:
      69
    case _:
      0

def label_5(i: U32) -> U32:  # FLOOR
  match i:
    case 0:
      70
    case 1:
      76
    case 2:
      79
    case 3:
      79
    case 4:
      82
    case _:
      0

def label_6(i: U32) -> U32:  # PLAY
  match i:
    case 0:
      80
    case 1:
      76
    case 2:
      65
    case 3:
      89
    case _:
      0

def label_7(i: U32) -> U32:  # PAUSE
  match i:
    case 0:
      80
    case 1:
      65
    case 2:
      85
    case 3:
      83
    case 4:
      69
    case _:
      0

def label_8(i: U32) -> U32:  # RESET
  match i:
    case 0:
      82
    case 1:
      69
    case 2:
      83
    case 3:
      69
    case 4:
      84
    case _:
      0

def label_9(i: U32) -> U32:  # ORBIT
  match i:
    case 0:
      79
    case 1:
      82
    case 2:
      66
    case 3:
      73
    case 4:
      84
    case _:
      0

def label_10(i: U32) -> U32:  # HEIGHT
  match i:
    case 0:
      72
    case 1:
      69
    case 2:
      73
    case 3:
      71
    case 4:
      72
    case 5:
      84
    case _:
      0

def label_11(i: U32) -> U32:  # ANGLE
  match i:
    case 0:
      65
    case 1:
      78
    case 2:
      71
    case 3:
      76
    case 4:
      69
    case _:
      0

def label_12(i: U32) -> U32:  # DIR X
  match i:
    case 0:
      68
    case 1:
      73
    case 2:
      82
    case 3:
      0
    case 4:
      88
    case _:
      0

def label_13(i: U32) -> U32:  # DIR Y
  match i:
    case 0:
      68
    case 1:
      73
    case 2:
      82
    case 3:
      0
    case 4:
      89
    case _:
      0

def label_14(i: U32) -> U32:  # DIR Z
  match i:
    case 0:
      68
    case 1:
      73
    case 2:
      82
    case 3:
      0
    case 4:
      90
    case _:
      0

def label_15(i: U32) -> U32:  # X
  match i:
    case 0:
      88
    case _:
      0

def label_16(i: U32) -> U32:  # Y
  match i:
    case 0:
      89
    case _:
      0

def label_17(i: U32) -> U32:  # Z
  match i:
    case 0:
      90
    case _:
      0

def label_18(i: U32) -> U32:  # RADIUS
  match i:
    case 0:
      82
    case 1:
      65
    case 2:
      68
    case 3:
      73
    case 4:
      85
    case 5:
      83
    case _:
      0

# The letter at index i of a label, 0 past its end.
def label_char(label: U32, i: U32) -> U32:
  match label:
    case 0:
      label_0(i)
    case 1:
      label_1(i)
    case 2:
      label_2(i)
    case 3:
      label_3(i)
    case 4:
      label_4(i)
    case 5:
      label_5(i)
    case 6:
      label_6(i)
    case 7:
      label_7(i)
    case 8:
      label_8(i)
    case 9:
      label_9(i)
    case 10:
      label_10(i)
    case 11:
      label_11(i)
    case 12:
      label_12(i)
    case 13:
      label_13(i)
    case 14:
      label_14(i)
    case 15:
      label_15(i)
    case 16:
      label_16(i)
    case 17:
      label_17(i)
    case 18:
      label_18(i)
    case _:
      0
