
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
| `engine/vec.bend` | Vectors and 4x4 matrices |
| `engine/color.bend` | Bend-UI color tokens read as RGB |
| `main.js` | Reads the mouse, draws what Bend returns (WebGL2) |
| `index.html` | The page: a Bend-UI window holding the viewport |
