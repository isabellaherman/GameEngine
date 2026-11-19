// The editor: the browser side of the engine, shared by every page that
// opens a scene (index.html for the engine's projects, refs/*/index.html
// for reference characters). It only reads the mouse and draws what Bend
// returns: the World (engine/world.bend) and the camera
// (engine/camera.bend) decide every number, the scene (PROJECT.bend opens a project)
// says what is in the World, engine/shader/glsl.bend writes the shaders and
// engine/material.bend gives the values of their parameters.

import { theme } from "bend-ui";
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
import { mountPanels } from "./panels/panels.js";
import Panels from "./panels/panels.bend";
import Defaults from "./defaults/defaults.bend";

// Opens the editor on a scene (a Bend value, engine/scene.bend).
export function startEditor(opening) {
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
  // of place or values is: see edit() below).
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

  // An edit in the Details panel: panels.bend gives the next scene; the GPU
  // gets the thing's new matrix and values. The graph never changes, so no
  // shader is compiled.
  function edit(i, e, value) {
    scene = Panels.apply(scene, i, e, value);
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
      if (Scene.is_rigged(t)) out.push(...flat(Figure.lines(Scene.figure(Scene.look(t)), Scene.place(t))));
    }
    return new Float32Array(out);
  }

  const [skyR, skyG, skyB] = flat(World.sky());

  // Frame
  // =====

  let cam = Camera.start();
  let queued = false;

  const defaults = mountDefaults(document.getElementById("editor-defaults"), {
    getCam: () => cam,
    setCam: (c) => { cam = c; redraw(); },
    orbit: (c, dx, dy) => Camera.orbit(c, dx, dy),
  });

  // The Scene and Details panels (editor/panels/): the scene's things and the
  // selected one's components.
  mountPanels(document.getElementById("editor-panels"), {
    getScene: () => scene,
    edit,
  });

  // Shortcuts: the keymap and what each view looks from are KEYS.bend.
  {
    const handlers = {};
    for (let l = Keys.keymap(); l.$ === "Con"; l = l.tail) {
      const action = l.head.action;
      handlers[action] = Keys.is_home(action) ? () => defaults.home() : () => defaults.look(Keys.view_handle(action));
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
    // The scene's things first, in order, then the grid over them: the water
    // lies on y = 0 with the grid, so drawing order decides who shows (there
    // is no depth test yet).
    for (const t of shown.values()) {
      gl.useProgram(t.prog);
      gl.uniformMatrix4fv(t.vp, false, frame.slice(0, 16));
      gl.uniformMatrix4fv(t.model, false, t.matrix);
      gl.bindVertexArray(t.vao);
      gl.drawElements(gl.TRIANGLES, t.count, gl.UNSIGNED_INT, 0);
    }
    gl.useProgram(prog);
    gl.uniformMatrix4fv(u.vp, false, frame.slice(0, 16));
    gl.uniform3fv(u.eye, frame.slice(16, 19));
    gl.uniform2fv(u.fade, flat(World.fade(cam)));
    gl.bindVertexArray(vao);
    gl.drawArrays(gl.LINES, 0, lines.length / 6);
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
  const still = matchMedia("(prefers-reduced-motion: reduce)");
  let last = 0;
  function tick(now) {
    const dt = last ? (now - last) / 1000 : 0;
    last = now;
    if (Scene.animated(scene) && !Defaults.reduce_motion(still.matches)) {
      scene = Scene.advance(scene, dt, false);
      redraw();
    }
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);

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
