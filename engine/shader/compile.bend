# Compile: a graph of nodes (node.bend) into GLSL lines, the way Unity's
# Shader Graph and Unreal's material editor do it.
#
# A graph is written as a tree (node.bend). The compiler walks it from the
# leaves up and gives each node one line with a name:
#
#   vec3 n0 = vec3(1.0, 0.0, 0.0);
#   float n1 = u_time;
#   float n2 = sin(n1);
#   vec3 n3 = mix(n0, n0, n2);
#
# Each node is written after the nodes it uses (topological order), so the
# GPU always has a value ready. A node that appears twice in the tree, the
# same piece written the same way, gets one line and one name: its second
# use only says its name again (n0 above).
#
# Limits now:
# - Two nodes are "the same" when they are written the same way. Finding
#   one compares it with every line already written, so a graph of n nodes
#   costs about n × n comparisons. Fine for hundreds of nodes; thousands
#   would want a hash.
# - Every node of the tree gets a line. A node nobody uses cannot exist in
#   a tree, so there is nothing to drop yet; a graph editor with loose
#   nodes will need to skip them.
# - A Bad graph (node.bend's ty) still compiles to text, with "bad" as a
#   type, and the driver refuses it. Laws on each graph keep that from
#   happening; nothing stops it here.
# - The law checker does not work out F32 comparisons (F32.is_eq(1.0, 1.0)
#   stays unsolved in a proof), so no law can show that two equal numbers
#   or colors share a line. It works when the engine runs; the laws only
#   check sharing of nodes without numbers (time, sin…).
# - Names are n0, n1…: they say nothing about the node. Readable names
#   (n3_fresnel) come with the graph editor.

import Base
import ./node.bend as N

# One line of the graph: a node whose inputs are names of earlier lines
# (their place in the list), and its type.
type Op is Data:
  ONum{value: F32}
  ORgb{r: F32, g: F32, b: F32}
  OTime{}
  OAdd{a: U32, b: U32}
  OMul{a: U32, b: U32}
  OSin{a: U32}
  OMix{a: U32, b: U32, t: U32}
  OParam{name: String, kind: N.Ty}

type Line is Data:
  Line{op: Op, ty: N.Ty}

# The lines so far and how many there are.
type Lines is Data:
  Lines{lines: List<&2, Line>, count: U32}

# What adding a node gives back: the lines, and the name of its line.
type At is Data:
  At{lines: Lines, name: U32}

# Sameness
# ========

def eq2(+a: U32, +b: U32, +c: U32, +d: U32) -> Bool:
  (U32.is_eq(a, c) && U32.is_eq(b, d))

def same_op(a: Op, b: Op) -> Bool:
  match a b:
    case ONum{+x} ONum{+y}:
      F32.is_eq(x, y)
    case ORgb{+r1, +g1, +b1} ORgb{+r2, +g2, +b2}:
      (F32.is_eq(r1, r2) && F32.is_eq(g1, g2) && F32.is_eq(b1, b2))
    case OTime{} OTime{}:
      True{}
    case OAdd{+a1, +b1} OAdd{+a2, +b2}:
      eq2(a1, b1, a2, b2)
    case OMul{+a1, +b1} OMul{+a2, +b2}:
      eq2(a1, b1, a2, b2)
    case OSin{+a1} OSin{+a2}:
      U32.is_eq(a1, a2)
    case OMix{+a1, +b1, +t1} OMix{+a2, +b2, +t2}:
      (eq2(a1, b1, a2, b2) && U32.is_eq(t1, t2))
    case OParam{+n1, +k1} OParam{+n2, +k2}:
      (String.eq(n1, n2) && N.ty_eq(k1, k2))
    case _ _:
      False{}

def pick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# The name of the line that holds op, or `none` when there is none.
def find_go(xs: List<&2, Line>, +op: Op, +i: U32, +none: U32) -> U32:
  match xs:
    case Nil{}:
      none
    case h <> t:
      Line{+hop, _} = h
      pick(same_op(hop, op), i, find_go(t, op, (i + 1 : U32), none))

# Names and lines
# ===============

# The name of node n in lines that already hold it and everything it uses.
# (Bend allows no two functions calling each other, so the name of a node
# is found again from its children's names, not handed back by walk.)
def name_of(+ls: Lines, n: N.Node) -> U32:
  Lines{+xs, +cnt} = ls
  match n:
    case N.Num{v}:
      find_go(xs, ONum{v}, 0, cnt)
    case N.Rgb{r, g, b}:
      find_go(xs, ORgb{r, g, b}, 0, cnt)
    case N.Time{}:
      find_go(xs, OTime{}, 0, cnt)
    case N.Param{nm, k}:
      find_go(xs, OParam{nm, k}, 0, cnt)
    case N.Add{a, b}:
      find_go(xs, OAdd{name_of(ls, a), name_of(ls, b)}, 0, cnt)
    case N.Mul{a, b}:
      find_go(xs, OMul{name_of(ls, a), name_of(ls, b)}, 0, cnt)
    case N.Sin{a}:
      find_go(xs, OSin{name_of(ls, a)}, 0, cnt)
    case N.Mix{a, b, t}:
      find_go(xs, OMix{name_of(ls, a), name_of(ls, b), name_of(ls, t)}, 0, cnt)

# Node n as one line, its inputs named by the lines already there.
def op_of(+ls: Lines, n: N.Node) -> Op:
  match n:
    case N.Num{v}:
      ONum{v}
    case N.Rgb{r, g, b}:
      ORgb{r, g, b}
    case N.Time{}:
      OTime{}
    case N.Param{nm, k}:
      OParam{nm, k}
    case N.Add{a, b}:
      OAdd{name_of(ls, a), name_of(ls, b)}
    case N.Mul{a, b}:
      OMul{name_of(ls, a), name_of(ls, b)}
    case N.Sin{a}:
      OSin{name_of(ls, a)}
    case N.Mix{a, b, t}:
      OMix{name_of(ls, a), name_of(ls, b), name_of(ls, t)}

# Add a line, unless the same one is there already.
def add_found(xs: List<&2, Line>, +n: U32, +op: Op, +ty: N.Ty, fresh: Bool) -> Lines:
  match fresh:
    case True{}:
      Lines{List.append(&2, Line, xs, [Line{op, ty}]), (n + 1 : U32)}
    case False{}:
      Lines{xs, n}

# Add node n's own line; its inputs must be there already.
def push(ls: Lines, +n: N.Node) -> Lines:
  Lines{+xs, +cnt} = ls
  +op = op_of(Lines{xs, cnt}, n)
  add_found(xs, cnt, op, N.ty(n), U32.is_eq(find_go(xs, op, 0, cnt), cnt))

# Walking the tree: every input first, then the node. The node comes first
# among the arguments because it shrinks at each call, which is how Bend
# sees that the walk ends.
def walk(+n: N.Node, ls: Lines) -> Lines:
  match n:
    case N.Add{+a, +b}:
      push(walk(b, walk(a, ls)), N.Add{a, b})
    case N.Mul{+a, +b}:
      push(walk(b, walk(a, ls)), N.Mul{a, b})
    case N.Sin{+a}:
      push(walk(a, ls), N.Sin{a})
    case N.Mix{+a, +b, +t}:
      push(walk(t, walk(b, walk(a, ls))), N.Mix{a, b, t})
    case leaf:
      push(ls, leaf)

def empty() -> Lines:
  Lines{Nil{}, 0}

# The graph as lines, and the name of its output line.
def graph(+n: N.Node) -> At:
  +ls = walk(n, empty())
  At{ls, name_of(ls, n)}

# GLSL text
# =========

def name(+i: U32) -> String:
  String.append("n", U32.show(i))

# The uniform that holds parameter `nm`: p_ and its name.
def uniform(nm: String) -> String:
  String.append("p_", nm)

def type_name(t: N.Ty) -> String:
  match t:
    case N.Float{}:
      "float"
    case N.Vec3{}:
      "vec3"
    case N.Bad{}:
      "bad"

def expr(op: Op) -> String:
  match op:
    case ONum{v}:
      N.number(v)
    case ORgb{r, g, b}:
      String.concat(["vec3(", N.number(r), ", ", N.number(g), ", ", N.number(b), ")"])
    case OTime{}:
      "u_time"
    case OParam{nm, _}:
      uniform(nm)
    case OAdd{a, b}:
      String.concat([name(a), " + ", name(b)])
    case OMul{a, b}:
      String.concat([name(a), " * ", name(b)])
    case OSin{a}:
      String.concat(["sin(", name(a), ")"])
    case OMix{a, b, t}:
      String.concat(["mix(", name(a), ", ", name(b), ", ", name(t), ")"])

def line_text(l: Line, +i: U32) -> String:
  Line{op, ty} = l
  String.concat(["  ", type_name(ty), " ", name(i), " = ", expr(op), ";"])

def texts_go(xs: List<&2, Line>, +i: U32) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      line_text(h, i) <> texts_go(t, (i + 1 : U32))

# The GLSL lines of a graph, in order.
def lines(at: At) -> List<&2, String>:
  At{Lines{xs, _}, _} = at
  texts_go(xs, 0)

# The name of a graph's output, to use after its lines.
def output(at: At) -> String:
  At{_, +o} = at
  name(o)

# How many lines a graph takes, for the laws.
def count(at: At) -> U32:
  At{Lines{_, +n}, _} = at
  n

# The uniform declarations a graph needs, one per parameter, in order.
def decl(l: Line) -> List<&2, String>:
  Line{op, _} = l
  match op:
    case OParam{nm, k}:
      [String.concat(["uniform ", type_name(k), " ", uniform(nm), ";"])]
    case _:
      Nil{}

def decls_go(xs: List<&2, Line>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      List.append(&2, String, decl(h), decls_go(t))

def uniforms(at: At) -> List<&2, String>:
  At{Lines{xs, _}, _} = at
  decls_go(xs)

