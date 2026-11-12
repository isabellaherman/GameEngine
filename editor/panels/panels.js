// The Scene and Details panels on screen, stacked on the right as in Unreal. It draws
// what panels.bend returns (the names, the sections and their fields) with
// Bend-UI pieces (panel, ghost buttons, disclosure, field, input), and hands
// typed numbers back to panels.bend, which gives the next scene.
//
// Limits now:
// - The selected thing is shown as a pressed toggle button: Bend-UI has no
//   selectable list or tree yet (a request for Bend-UI).
// - Values are not drawn again while you type, so the field you are in
//   keeps its focus; they are drawn again when you leave the field.

import O from "./panels.bend";
import D from "../defaults/defaults.bend";

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

const still = matchMedia("(prefers-reduced-motion: reduce)");

// ui: { getScene(), edit(index, edit, value) }
export function mountPanels(root, ui) {
  let selected = 0;
  let uid = 0;

  const scenePanel = el("section", "panel editor-panels__scene");
  scenePanel.setAttribute("aria-labelledby", "scene-panel-title");
  const oHead = el("div", "panel__header");
  const oTitle = el("span", "", "Scene");
  oTitle.id = "scene-panel-title";
  const oCount = el("span", "meta");
  oHead.append(oTitle, oCount);
  const oBody = el("div", "panel__body editor-panels__list");
  scenePanel.append(oHead, oBody);

  const details = el("section", "panel editor-panels__details");
  details.setAttribute("aria-labelledby", "details-title");
  const dHead = el("div", "panel__header");
  const dTitle = el("span", "", "Details");
  dTitle.id = "details-title";
  const dName = el("span", "meta");
  dHead.append(dTitle, dName);
  const dBody = el("div", "panel__body editor-panels__body");
  details.append(dHead, dBody);

  root.append(scenePanel, details);

  function drawScene() {
    const names = list(O.names(ui.getScene()));
    oCount.textContent = String(names.length);
    oBody.replaceChildren();
    names.forEach((name, i) => {
      const b = el("button", "btn btn--ghost btn--toggle editor-panels__item", name);
      b.type = "button";
      b.setAttribute("aria-pressed", String(i === selected));
      b.addEventListener("click", () => { selected = i; drawScene(); drawDetails(); });
      oBody.append(b);
    });
    if (!names.length) oBody.append(el("p", "meta", "The scene is empty."));
  }

  function field(f) {
    const id = `details-field-${uid++}`;
    const label = el("label", "field editor-panels__field");
    label.htmlFor = id;
    const input = el("input", "input input--sm");
    input.id = id;
    input.type = "number";
    input.step = String(f.step);
    input.value = f.value.toFixed(f.decimals);
    input.setAttribute("aria-label", `${f.label}`);
    label.append(el("span", "field__label", f.label), input);
    // Each change goes to Bend right away; the panel is drawn again when the
    // field is left, so Bend's own reading of the value shows.
    input.addEventListener("input", () => {
      const v = input.valueAsNumber;
      if (Number.isFinite(v)) ui.edit(selected, f.edit, v);
    });
    input.addEventListener("change", () => drawDetails());
    return label;
  }

  function drawDetails() {
    const names = list(O.names(ui.getScene()));
    dName.textContent = names[selected] ?? "";
    dBody.replaceChildren();
    if (selected >= names.length) { dBody.append(el("p", "meta", "Nothing selected.")); return; }
    for (const s of list(O.sections(ui.getScene(), selected))) {
      const sec = el("details", "disclosure");
      sec.open = true;
      const sum = el("summary");
      sum.innerHTML = '<svg class="icon icon--sm disclosure__chevron"><use href="#i-chevron-down"/></svg>';
      sum.append(el("span", "disclosure__title", s.title));
      // Accessibility (ACCESSIBILITY.bend): the chevron turns without motion.
      if (D.reduce_motion(still.matches)) sum.querySelector(".disclosure__chevron").style.transition = "none";
      sec.append(sum);
      for (const r of list(s.rows)) {
        const group = el("fieldset", "form__section editor-panels__row");
        group.append(el("legend", "field__label", r.label));
        const fields = el("div", "editor-panels__fields");
        for (const f of list(r.fields)) fields.append(field(f));
        group.append(fields);
        sec.append(group);
      }
      dBody.append(sec);
    }
  }

  drawScene();
  drawDetails();
}
