
## Run

Needs Bend (`bend`) and a clone of [bendlang/bend](https://github.com/bendlang/bend) at `../bend` (the loader in `bunfig.toml`).

```sh
bun install
bun run dev      # http://localhost:3100
bun run check    # type-check the engine
bun run build    # bundle to dist/
```

## Files

| File | What it is |
| --- | --- |
| `engine/world.bend` | The World: origin, axes, units, ground grid, sky, grid fade |
| `engine/camera.bend` | The editor camera: orbit, pan, zoom, view and projection |
| `engine/gizmo.bend` | The axis gizmo: handles, hover, click-to-align |
| `editor/defaults/` | Editor Defaults: gizmo + info, only hands on values (see `RULES.txt`) |
| `engine/vec.bend` | Vectors and 4x4 matrices |
| `engine/color.bend` | Bend-UI color tokens read as RGB |
| `KEYS.bend` | The engine's keymap: every shortcut, in one list |
| `SPEC.bend`, `LAWS.bend`, `PROOF.bend` | The engine's laws (no shortcut overlaps, with Bend-UI's keys too) |
| `main.js` | Reads the mouse, draws what Bend returns (WebGL2) |
| `index.html` | The page: a Bend-UI window holding the viewport |
