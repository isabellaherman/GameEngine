// Editor Defaults on screen: the axis gizmo and the info button.
// It draws what defaults.bend hands on. The gizmo moves only the editor camera
// (how we look); it never changes the World.

import { tokens as T, initSegmented } from "bend-ui";
import D from "./defaults.bend";

const list = (l) => {
  const out = [];
  for (; l.$ === "Con"; l = l.tail) out.push(l.head);
  return out;
};

const el = (tag, cls, text) => {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
};

const css = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
const still = matchMedia("(prefers-reduced-motion: reduce)");

// The info button: a Bend-UI dropdown that says what each axis means.
function info() {
  const dd = el("div", "dropdown");
  const btn = el("button", "btn btn--plain btn--neutral btn--sm btn--icon btn--round");
  btn.setAttribute("aria-haspopup", "menu");
  btn.setAttribute("aria-expanded", "false");
  btn.setAttribute("aria-label", "About the scene and accessibility");
  btn.innerHTML = '<svg class="icon"><use href="#i-info"/></svg>';

  const menu = el("div", "menu menu--end editor-defaults__info");
  menu.setAttribute("role", "dialog");
  menu.setAttribute("aria-label", "About the scene and accessibility");
  menu.hidden = true;

  const { x, y, z } = D.origin();
  const origin = el("div", "editor-defaults__row");
  origin.append(el("span", "item-title", "Origin"), el("span", "mono detail", `${x}, ${y}, ${z}`));
  menu.append(origin);
  for (const a of list(D.axes())) {
    const row = el("div", "editor-defaults__row");
    const dot = el("span", "dot");
    dot.style.background = a.tone;
    dot.style.borderColor = a.tone;
    const name = el("span", "outline__row");
    name.append(dot, el("span", "item-title", a.name));
    row.append(name, el("span", "detail", a.points));
    menu.append(row);
  }

  // Accessibility (ACCESSIBILITY.bend): whether motion is reduced, and why.
  // A Bend-UI field holding a segmented Off/On that only shows the state
  // (data-manual: a click changes nothing); it springs when the state changes.
  const field = el("div", "field");
  const label = el("span", "field__label", "Reduce motion");
  label.id = "editor-defaults-motion";
  const seg = el("div", "segmented segmented--slide editor-defaults__readonly");
  seg.dataset.motion = "spring";
  seg.dataset.manual = "";
  seg.setAttribute("role", "group");
  seg.setAttribute("aria-labelledby", "editor-defaults-motion");
  const off = el("button", "", "Off"), on = el("button", "", "On");
  for (const b of [off, on]) { b.type = "button"; b.tabIndex = -1; }
  seg.append(off, on);
  field.append(label, seg);
  const show = () => {
    const reduced = D.reduce_motion(still.matches);
    const was = on.getAttribute("aria-pressed") === "true";
    on.setAttribute("aria-pressed", reduced);
    off.setAttribute("aria-pressed", !reduced);
    if (was !== reduced) seg.dispatchEvent(new CustomEvent("change", { detail: reduced ? on : off }));
  };
  show();
  still.addEventListener("change", show);
  menu.append(el("hr", "separator"), el("h3", "group-title", "Accessibility"), field);
  queueMicrotask(() => initSegmented(seg));

  dd.append(btn, menu);
  return dd;
}

// The gizmo: drawn on its own canvas at the screen's pixel density.
export function mountDefaults(root, { getCam, setCam, orbit }) {
  const size = D.gizmo_size(), r = D.gizmo_radius(), none = D.gizmo_none();
  const canvas = el("canvas", "editor-defaults__gizmo");
  canvas.style.width = canvas.style.height = size + "px";
  canvas.setAttribute("role", "img");
  canvas.setAttribute("aria-label", "Axis gizmo. Click an axis to look along it; drag to orbit.");
  const g = canvas.getContext("2d");
  root.append(canvas, info());

  let hover = none, inside = false;

  function draw() {
    const dpr = devicePixelRatio || 1;
    if (canvas.width !== Math.round(size * dpr)) canvas.width = canvas.height = Math.round(size * dpr);
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, size, size);
    const c = size / 2;
    if (inside) {   // the gizmo's ground while the mouse is on it
      g.globalAlpha = 1;
      g.fillStyle = css("--surface-2");
      g.beginPath(); g.arc(c, c, c, 0, Math.PI * 2); g.fill();
    }
    g.lineCap = "round";
    g.textAlign = "center";
    g.textBaseline = "middle";
    g.font = `${T.weight_semibold()} ${T.text_xs()}px ${T.font_sans()}`;
    for (const h of list(D.gizmo_handles(getCam()))) {
      const on = h.id === hover;
      if (h.positive) {
        g.globalAlpha = 1;
        g.strokeStyle = h.tone;
        g.lineWidth = T.space_hairline();
        g.beginPath(); g.moveTo(c, c); g.lineTo(h.x, h.y); g.stroke();
        g.fillStyle = h.tone;
        g.beginPath(); g.arc(h.x, h.y, r, 0, Math.PI * 2); g.fill();
        g.fillStyle = css("--bg");
        g.fillText(h.label, h.x, h.y + 0.5);
      } else {
        g.globalAlpha = 0.35;
        g.fillStyle = h.tone;
        g.beginPath(); g.arc(h.x, h.y, r, 0, Math.PI * 2); g.fill();
        g.globalAlpha = 1;
        g.strokeStyle = h.tone;
        g.lineWidth = 1.5;
        g.beginPath(); g.arc(h.x, h.y, r - 0.75, 0, Math.PI * 2); g.stroke();
      }
      if (on) {   // the handle under the mouse: a ring in the text color
        g.globalAlpha = 1;
        g.strokeStyle = css("--text");
        g.lineWidth = 1.5;
        g.beginPath(); g.arc(h.x, h.y, r + 1.5, 0, Math.PI * 2); g.stroke();
      }
    }
    g.globalAlpha = 1;
  }

  // Click a handle: the camera turns to that side. Drag: the camera orbits.
  let press = null, flight = 0;
  const at = (e) => { const b = canvas.getBoundingClientRect(); return [e.clientX - b.left, e.clientY - b.top]; };

  function flyTo(to) {
    cancelAnimationFrame(flight);
    const from = getCam(), start = performance.now(), ms = D.gizmo_duration();
    const step = (now) => {
      const t = D.reduce_motion(still.matches) ? 1 : (now - start) / ms;   // ACCESSIBILITY.bend: a cut
      setCam(D.gizmo_between(from, to, t));
      if (t < 1) flight = requestAnimationFrame(step);
    };
    flight = requestAnimationFrame(step);
  }
  const fly = (id) => flyTo(D.gizmo_snap(getCam(), id));

  canvas.addEventListener("pointerenter", () => { inside = true; draw(); });
  canvas.addEventListener("pointerleave", () => { inside = false; hover = none; draw(); });
  canvas.addEventListener("pointerdown", (e) => {
    press = { x: e.clientX, y: e.clientY, moved: false };
    canvas.setPointerCapture(e.pointerId);
  });
  canvas.addEventListener("pointermove", (e) => {
    if (press) {
      const dx = e.clientX - press.x, dy = e.clientY - press.y;
      if (!press.moved && Math.hypot(dx, dy) < T.space_1()) return;
      press.moved = true;
      press.x = e.clientX; press.y = e.clientY;
      cancelAnimationFrame(flight);
      setCam(orbit(getCam(), dx, dy));
      return;
    }
    const [px, py] = at(e);
    const h = D.gizmo_hit(getCam(), px, py);
    if (h !== hover) { hover = h; canvas.style.cursor = h === none ? "grab" : "pointer"; draw(); }
  });
  const release = (e) => {
    if (press && !press.moved) {
      const [px, py] = at(e);
      const h = D.gizmo_hit(getCam(), px, py);
      if (h !== none) fly(h);
    }
    press = null;
  };
  canvas.addEventListener("pointerup", release);
  canvas.addEventListener("pointercancel", () => { press = null; });

  // look(id): the same turn as clicking handle id; home(): back to the start view (the view shortcuts).
  return { draw, look: fly, home: () => flyTo(D.gizmo_home()) };
}
