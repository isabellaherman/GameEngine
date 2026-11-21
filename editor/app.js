// The editor: the browser side of the engine, shared by every page that
// opens a scene (index.html for the engine's projects, refs/*/index.html
// for reference characters). It only reads the mouse and draws what Bend
// returns: the World (engine/world.bend) and the camera
// (engine/camera.bend) decide every number, the scene (PROJECT.bend opens a project)
// says what is in the World, engine/shader/glsl.bend writes the shaders and
// engine/material.bend gives the values of their parameters.

import { theme } from "bend-ui";
import { mount } from "bend-ui/web";
import { createKeys } from "bend-ui/keys";
import Keys from "../KEYS.bend";
import World from "../engine/world.bend";
import Scene from "../engine/scene.bend";
import Camera from "../engine/camera.bend";
import Glsl from "../engine/shader/glsl.bend";
import Material from "../engine/material.bend";
import Transform from "../engine/transform.bend";
import Figure from "../engine/figure.bend";
import { mountDefaults } from "./defaults/defaults.js";
import Panels from "./panels/view.bend";
import Defaults from "./defaults/defaults.bend";
import Loco from "../engine/locomotion.bend";

// Opens the editor on a scene (a Bend value, engine/scene.bend).
//
// `camera` is where the editor's camera starts (engine/camera.bend; its
// start() when none). `skins` gives, for each figure's skin name, the files to draw it with:
//   { [name]: { info: <skin.json>, bin: <url of skin.bin>, textures: [url per part] } }
// written by tools/gltf.ts. A figure whose skin has no entry is drawn as bones.
export function startEditor(opening, { skins = {}, camera = null } = {}) {
  theme({ mode: "dark", radius: "pill" });   // every button and segmented in the layout is a pill

  // A Bend list arrives as cons cells; the GPU wants a flat array.
  // Limit: this copies every number once; fine at start-up, too slow per frame.
  const flat = (list) => {
    const out = [];
    for (let l = list; l.$ === "Con"; l = l.tail) out.push(l.head);
    return out;
  };

  // GPU setup
  // =========

  const canvas = document.getElementById("scene");
  const gl = canvas.getContext("webgl2", { antialias: true });

  // The shaders are written by Bend (engine/shader/glsl.bend); JS only hands
  // the text to the GPU driver.
  function shader(type, src) {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
    return s;
  }

  function program(vert, frag) {
    const p = gl.createProgram();
    gl.attachShader(p, shader(gl.VERTEX_SHADER, vert));
    gl.attachShader(p, shader(gl.FRAGMENT_SHADER, frag));
    gl.linkProgram(p);
    if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p));
    return p;
  }

  const prog = program(Glsl.line_vert(), Glsl.line_frag());

  const u = {
    vp: gl.getUniformLocation(prog, "u_vp"),
    eye: gl.getUniformLocation(prog, "u_eye"),
    fade: gl.getUniformLocation(prog, "u_fade"),
  };

  // The ground: built once by world.bend, 6 floats per vertex (x y z r g b).
  const lines = new Float32Array(flat(World.lines()));
  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, lines, gl.STATIC_DRAW);
  const pos = gl.getAttribLocation(prog, "a_pos");
  const col = gl.getAttribLocation(prog, "a_col");
  gl.enableVertexAttribArray(pos);
  gl.vertexAttribPointer(pos, 3, gl.FLOAT, false, 24, 0);
  gl.enableVertexAttribArray(col);
  gl.vertexAttribPointer(col, 3, gl.FLOAT, false, 24, 12);

  // A material's values go to their uniforms; material.bend names each one.
  // Setting a value never compiles anything.
  function setValues(p, values) {
    for (let l = values; l.$ === "Con"; l = l.tail) {
      const loc = gl.getUniformLocation(p, Material.uniform(l.head));
      const xs = flat(Material.numbers(l.head));
      if (xs.length === 1) gl.uniform1f(loc, xs[0]);
      else if (xs.length === 3) gl.uniform3fv(loc, xs);
    }
  }

  // The scene (the project PROJECT.bend opens): every thing that is shown gets, once, its
  // shader (from its material), its mesh on the GPU (3 floats per vertex,
  // 3 indices per triangle) and its model matrix (from its place).
  // Limit: built once at start-up; a thing added later is not seen (an edit
  // of place or values is: see edited() below).
  function upload(thing) {
    const look = Scene.look(thing);
    const material = Scene.material(look);
    const shape = Scene.shape(look);
    const p = program(Glsl.mesh_vert(), Material.frag(material));
    gl.useProgram(p);
    setValues(p, Material.values(material));
    const idx = new Uint32Array(flat(shape.indices));
    const vao = gl.createVertexArray();
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(flat(shape.vertices)), gl.STATIC_DRAW);
    const at = gl.getAttribLocation(p, "a_pos");
    gl.enableVertexAttribArray(at);
    gl.vertexAttribPointer(at, 3, gl.FLOAT, false, 12, 0);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, idx, gl.STATIC_DRAW);
    return {
      prog: p, vao, count: idx.length,
      vp: gl.getUniformLocation(p, "u_vp"),
      model: gl.getUniformLocation(p, "u_model"),
      matrix: flat(Transform.flat(Scene.place(thing))),
    };
  }

  let scene = opening;
  // Each shown thing, by its place in the scene's list.
  const shown = new Map();
  flat(Scene.things(scene)).forEach((t, i) => { if (Scene.is_shown(t)) shown.set(i, upload(t)); });

  // After an edit in the Details panel (panels.bend gave the next scene): the
  // GPU gets thing i's new matrix and values. The graph never changes, so no
  // shader is compiled.
  function edited(i) {
    const g = shown.get(i);
    if (g) {
      const thing = Scene.at(scene, i);
      g.matrix = flat(Transform.flat(Scene.place(thing)));
      gl.useProgram(g.prog);
      setValues(g.prog, Material.values(Scene.material(Scene.look(thing))));
    }
    redraw();
  }

  // Characters (things with a figure): their bones as lines, in the same
  // format as the grid, asked from Bend again every frame because a pose
  // changes over time.
  const boneVao = gl.createVertexArray();
  const boneBuf = gl.createBuffer();
  gl.bindVertexArray(boneVao);
  gl.bindBuffer(gl.ARRAY_BUFFER, boneBuf);
  gl.enableVertexAttribArray(pos);
  gl.vertexAttribPointer(pos, 3, gl.FLOAT, false, 24, 0);
  gl.enableVertexAttribArray(col);
  gl.vertexAttribPointer(col, 3, gl.FLOAT, false, 24, 12);

  function boneLines() {
    const out = [];
    for (const t of flat(Scene.things(scene))) {
      if (!Scene.is_rigged(t)) continue;
      const fig = Scene.figure(Scene.look(t));
      if (Figure.shows_bones(fig)) out.push(...flat(Figure.lines(fig, Scene.place(t))));
    }
    return new Float32Array(out);
  }

  // Skinned characters
  // ==================
  // The mesh (positions, normals, UVs, 4 joints and 4 weights per vertex)
  // goes to the GPU once; every frame Bend gives the skinning matrices
  // (Figure.palette), which go into a float texture the vertex shader reads.
  const skinProg = program(Glsl.skinned_vert(), Glsl.skinned_frag());
  const su = {
    vp: gl.getUniformLocation(skinProg, "u_vp"),
    bones: gl.getUniformLocation(skinProg, "u_bones"),
    tex: gl.getUniformLocation(skinProg, "u_tex"),
    textured: gl.getUniformLocation(skinProg, "u_textured"),
    tint: gl.getUniformLocation(skinProg, "u_tint"),
    sun: gl.getUniformLocation(skinProg, "u_sun"),
    eyeDir: gl.getUniformLocation(skinProg, "u_eye_dir"),
  };
  const loaded = new Map();   // skin name → GPU objects, once its files arrive

  function image(url) {
    return new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => ok(null); i.src = url; });
  }

  async function loadSkin(name) {
    const entry = skins[name];
    if (!entry || loaded.has(name)) return;
    loaded.set(name, null);
    const info = entry.info;
    const bytes = await (await fetch(entry.bin)).arrayBuffer();
    const vao = gl.createVertexArray();
    gl.bindVertexArray(vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Uint8Array(bytes, 0, info.indexOffset), gl.STATIC_DRAW);
    const L = info.layout, S = info.stride;
    const at = (n) => gl.getAttribLocation(skinProg, n);
    gl.enableVertexAttribArray(at("a_pos")); gl.vertexAttribPointer(at("a_pos"), 3, gl.FLOAT, false, S, L.position);
    gl.enableVertexAttribArray(at("a_normal")); gl.vertexAttribPointer(at("a_normal"), 3, gl.FLOAT, false, S, L.normal);
    gl.enableVertexAttribArray(at("a_uv")); gl.vertexAttribPointer(at("a_uv"), 2, gl.FLOAT, false, S, L.uv);
    gl.enableVertexAttribArray(at("a_joints")); gl.vertexAttribIPointer(at("a_joints"), 4, gl.UNSIGNED_SHORT, S, L.joints);
    gl.enableVertexAttribArray(at("a_weights")); gl.vertexAttribPointer(at("a_weights"), 4, gl.UNSIGNED_SHORT, true, S, L.weights);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint32Array(bytes, info.indexOffset, info.indices), gl.STATIC_DRAW);
    const boneTex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, boneTex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, 4, info.bones, 0, gl.RGBA, gl.FLOAT, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    const textures = await Promise.all(info.parts.map(async (_, k) => {
      const img = entry.textures?.[k] ? await image(entry.textures[k]) : null;
      if (!img) return null;
      const t = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, t);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
      gl.generateMipmap(gl.TEXTURE_2D);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
      return t;
    }));
    loaded.set(name, { vao, boneTex, textures, info });
    redraw();
  }

  function drawSkins(frame) {
    for (const t of flat(Scene.things(scene))) {
      if (!Scene.is_rigged(t)) continue;
      const fig = Scene.figure(Scene.look(t));
      const g = loaded.get(Figure.skin(fig));
      if (!g) continue;
      const palette = new Float32Array(flat(Figure.palette(fig, Scene.place(t))));
      gl.useProgram(skinProg);
      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(gl.TEXTURE_2D, g.boneTex);
      gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, 4, g.info.bones, gl.RGBA, gl.FLOAT, palette);
      gl.uniform1i(su.bones, 1);
      gl.uniformMatrix4fv(su.vp, false, frame.slice(0, 16));
      gl.uniform3fv(su.sun, flat(Glsl.sun()));
      gl.uniform3fv(su.eyeDir, frame.slice(16, 19).map((x) => -x));
      gl.uniform3fv(su.tint, [0.8, 0.78, 0.74]);
      gl.bindVertexArray(g.vao);
      g.info.parts.forEach((part, k) => {
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, g.textures[k]);
        gl.uniform1i(su.tex, 0);
        gl.uniform1f(su.textured, g.textures[k] ? 1 : 0);
        gl.drawElements(gl.TRIANGLES, part.count, gl.UNSIGNED_INT, part.first * 4);
      });
    }
  }

  for (const t of flat(Scene.things(opening))) {
    if (Scene.is_rigged(t)) loadSkin(Figure.skin(Scene.figure(Scene.look(t))));
  }

  const [skyR, skyG, skyB] = flat(World.sky());

  // Frame
  // =====

  let cam = camera ?? Camera.start();
  let queued = false;

  // The system asking for reduced motion (ACCESSIBILITY.bend decides what it means, through Editor Defaults).
  const still = matchMedia("(prefers-reduced-motion: reduce)");

  const defaults = mountDefaults(document.getElementById("editor-defaults"), {
    getCam: () => cam,
    setCam: (c) => { cam = c; redraw(); },
    orbit: (c, dx, dy) => Camera.orbit(c, dx, dy),
  });

  // The Scene and Details panels (editor/panels/view.bend): the scene's things and the
  // selected one's components. Bend says what they show and what a click or a typed number
  // does; Bend-UI's driver draws it. When an edit made a new scene, it comes back here.
  const panels = mount(document.getElementById("editor-panels"), {
    init: () => Panels.start(scene, still.matches),
    render: Panels.render, on_event: Panels.on_event, on_input: Panels.on_input,
  }, {
    adopt: true,
    changed: (st) => {
      const next = Panels.scene(st);
      if (next === scene) return;   // a thing was picked: the scene is the same
      scene = next;
      edited(Panels.selected(st));
    },
  });
  still.addEventListener("change", () => panels.dispatch(Panels.motion_event(still.matches)));
  // The scene moved on outside the panels (a walk, the clock): they get it, and draw it at their
  // next event, as before (the Details fields are not drawn again every frame).
  const moved = (next) => { scene = next; panels.set(Panels.with_scene(panels.state, scene), { render: false }); };

  // Shortcuts: the keymap and what each view looks from are KEYS.bend.
  {
    const handlers = {};
    for (let l = Keys.keymap(); l.$ === "Con"; l = l.tail) {
      const action = l.head.action;
      handlers[action] = Keys.is_walk(action) ? () => {}
        : Keys.is_home(action) ? () => defaults.home() : () => defaults.look(Keys.view_handle(action));
    }
    createKeys(Keys.keymap(), handlers);
  }

  function draw() {
    queued = false;
    const w = canvas.width, h = canvas.height;
    const frame = flat(Camera.frame(cam, w / Math.max(h, 1)));
    gl.viewport(0, 0, w, h);
    gl.clearColor(skyR, skyG, skyB, 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    // Characters first, with the depth test. Then the scene's material
    // things, in order, without it: the water lies on y = 0 with the grid,
    // so drawing order decides who shows. Then the grid, tested against the
    // characters only.
    gl.enable(gl.DEPTH_TEST);
    drawSkins(frame);
    gl.disable(gl.DEPTH_TEST);
    for (const t of shown.values()) {
      gl.useProgram(t.prog);
      gl.uniformMatrix4fv(t.vp, false, frame.slice(0, 16));
      gl.uniformMatrix4fv(t.model, false, t.matrix);
      gl.bindVertexArray(t.vao);
      gl.drawElements(gl.TRIANGLES, t.count, gl.UNSIGNED_INT, 0);
    }
    // The grid is tested against the characters' depth, so it hides behind
    // them, but writes none of its own.
    gl.enable(gl.DEPTH_TEST);
    gl.depthMask(false);
    gl.useProgram(prog);
    gl.uniformMatrix4fv(u.vp, false, frame.slice(0, 16));
    gl.uniform3fv(u.eye, frame.slice(16, 19));
    gl.uniform2fv(u.fade, flat(World.fade(cam)));
    gl.bindVertexArray(vao);
    gl.drawArrays(gl.LINES, 0, lines.length / 6);
    gl.depthMask(true);
    gl.disable(gl.DEPTH_TEST);
    // Bones last, over everything, so they show through a skin (x-ray).
    const bones = boneLines();
    if (bones.length) {
      gl.bindVertexArray(boneVao);
      gl.bindBuffer(gl.ARRAY_BUFFER, boneBuf);
      gl.bufferData(gl.ARRAY_BUFFER, bones, gl.DYNAMIC_DRAW);
      gl.drawArrays(gl.LINES, 0, bones.length / 6);
    }
    defaults.draw();
  }

  const redraw = () => { if (!queued) { queued = true; requestAnimationFrame(draw); } };

  // The clock: characters' animations move on by themselves only when
  // motion is not reduced (ACCESSIBILITY.bend, through Editor Defaults).
  // With reduce_motion on, a character moves only when its time is typed
  // in the Details panel.
  let last = 0;
  function tick(now) {
    const dt = last ? (now - last) / 1000 : 0;
    last = now;
    if (Scene.animated(scene) && !Defaults.reduce_motion(still.matches)) {
      moved(Scene.advance(Loco.drive(scene, held(), dt, false), dt, false));
      redraw();
    }
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);

  // Walking (engine/locomotion.bend, keys in KEYS.bend). With motion
  // allowed, held keys drive the character every frame (tick above). With
  // reduce_motion on, each press is one step: a key held down does not
  // repeat.
  const walkKeys = new Map();
  for (let l = Keys.keymap(); l.$ === "Con"; l = l.tail) {
    if (Keys.is_walk(l.head.action)) walkKeys.set(l.head.key, l.head.action);
  }
  const down = new Set();
  function held() {
    const acts = [...down].map((k) => walkKeys.get(k));
    const code = (fwd) => acts.reduce((c, a) => { const x = fwd ? Keys.walk_forward(a) : Keys.walk_turn(a); return x === 0 ? c : c === 0 ? x : -1; }, 0);
    const f = code(true), t = code(false);
    return Loco.input(f < 0 ? 0 : f, t < 0 ? 0 : t);   // opposite keys cancel
  }
  const typing = (e) => /^(INPUT|TEXTAREA|SELECT)$/.test(e.target?.tagName ?? "");
  addEventListener("keydown", (e) => {
    const key = e.key.toLowerCase();
    if (!walkKeys.has(key) || typing(e) || e.metaKey || e.ctrlKey || e.altKey) return;
    if (Defaults.reduce_motion(still.matches)) {
      if (e.repeat) return;
      const a = walkKeys.get(key);
      moved(Loco.drive(scene, Loco.input(Keys.walk_forward(a), Keys.walk_turn(a)), 0, true));
      redraw();
    } else down.add(key);
  });
  addEventListener("keyup", (e) => down.delete(e.key.toLowerCase()));
  addEventListener("blur", () => down.clear());

  new ResizeObserver(() => {
    const dpr = devicePixelRatio || 1;
    canvas.width = Math.round(canvas.clientWidth * dpr);
    canvas.height = Math.round(canvas.clientHeight * dpr);
    redraw();
  }).observe(canvas);

  // Input: drag orbits, right-drag or Shift-drag pans, the wheel zooms.
  // =====

  let drag = null;
  canvas.addEventListener("contextmenu", (e) => e.preventDefault());
  canvas.addEventListener("pointerdown", (e) => {
    drag = { x: e.clientX, y: e.clientY, pan: e.button !== 0 || e.shiftKey };
    canvas.setPointerCapture(e.pointerId);
  });
  canvas.addEventListener("pointermove", (e) => {
    if (!drag) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    drag.x = e.clientX; drag.y = e.clientY;
    cam = drag.pan ? Camera.pan(cam, dx, dy, canvas.clientHeight) : Camera.orbit(cam, dx, dy);
    redraw();
  });
  const release = () => { drag = null; };
  canvas.addEventListener("pointerup", release);
  canvas.addEventListener("pointercancel", release);
  canvas.addEventListener("wheel", (e) => {
    e.preventDefault();
    cam = Camera.zoom(cam, e.deltaY);
    redraw();
  }, { passive: false });
}
