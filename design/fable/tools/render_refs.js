#!/usr/bin/env node
/* Render the Meadow production references from the design data with three.js in headless Chromium.

   Usage:  node design/fable/tools/render_refs.js /path/to/three.min.js
           (three@0.160 classic build; `npm install three@0.160.0` anywhere, then pass node_modules/three/build/three.min.js)

   Outputs (design/fable/mockups/):
     meadow_gameplay_frame.png      1280x720 gameplay view: real meadow.json layout, tuning.json camera, HUD from ui_layout.json
     camera_pitch_comparison.png    the same moment at three camera pitches
     pip_reference_sheet.png        signature creature turnaround + poses, built from data/models/meadow_creatures.json
     cinch_storyboard.png           the capture celebration, five beats

   These are REFERENCE RENDERS made from primitives equivalent to Roblox parts. They are not screenshots of the
   game and prove nothing about how it runs or feels. */
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const J = f => JSON.parse(fs.readFileSync(path.join(ROOT, 'data', f), 'utf8'));
const three = process.argv[2];
if (!three || !fs.existsSync(three)) { console.error('pass the path to three.min.js'); process.exit(1); }
const data = { arena: J('arenas/meadow.json'), tuning: J('tuning.json'), ui: J('ui_layout.json'), models: J('models/meadow_creatures.json'), creatures: J('creatures.json') };

function scene(data) {
  const T = window.THREE, A = data.arena, pal = A.palette, tun = data.tuning;
  const rgb = c => new T.Color(c[0] / 255, c[1] / 255, c[2] / 255);
  const INK = [27, 36, 64], WHITE = [255, 249, 231], GOLD = [255, 217, 90];
  const mats = {};
  const mat = (c, o = {}) => { const k = c.join(',') + JSON.stringify(o); return mats[k] || (mats[k] = new T.MeshStandardMaterial(Object.assign({ color: rgb(c), roughness: 0.82, metalness: 0 }, o))); };
  const lerp = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
  const SPH = new T.SphereGeometry(0.5, 28, 18), BOX = new T.BoxGeometry(1, 1, 1), CYL = new T.CylinderGeometry(0.5, 0.5, 1, 24);

  // ---------- terrain ----------
  const B = A.bounds;
  const segD = (px, pz, a, b) => { const dx = b[0] - a[0], dz = b[1] - a[1], l2 = dx * dx + dz * dz; const u = Math.max(0, Math.min(1, ((px - a[0]) * dx + (pz - a[1]) * dz) / l2)); return Math.hypot(px - a[0] - dx * u, pz - a[1] - dz * u); };
  const inside = (x, z) => { let c = false; for (let i = 0; i < B.length; i++) { const [x1, z1] = B[i], [x2, z2] = B[(i + 1) % B.length]; if ((z1 > z) !== (z2 > z) && x < (x2 - x1) * (z - z1) / (z2 - z1) + x1) c = !c; } return c; };
  const edgeD = (x, z) => { let m = 1e9; for (let i = 0; i < B.length; i++) m = Math.min(m, segD(x, z, B[i], B[(i + 1) % B.length])); return m; };
  const pond = A.features.find(f => f.id === 'mirror_pond'), creek = A.features.find(f => f.id === 'creek');
  const creekD = (x, z) => { let m = 1e9; for (let i = 0; i < creek.points.length - 1; i++) m = Math.min(m, segD(x, z, creek.points[i], creek.points[i + 1])); return m; };
  const pondK = (x, z) => Math.hypot((x - pond.x) / pond.rx, (z - pond.z) / pond.rz);
  const trail = [[0, 70], [0, 58], [8, 49], [2, 34], [0, 16], [0, 1], [2, -14], [-2, -40], [-2, -64]];
  const trailD = (x, z) => { let m = 1e9; for (let i = 0; i < trail.length - 1; i++) m = Math.min(m, segD(x, z, trail[i], trail[i + 1])); return m; };
  const H = (x, z) => {
    let y = 0.45 * Math.sin(x * 0.06) * Math.cos(z * 0.05) + 0.3 * Math.sin((x + z) * 0.11);
    for (const e of A.elevation) { const d = Math.hypot(x - e.x, z - e.z); if (d < e.r) y += e.y * 0.5 * (1 + Math.cos(Math.PI * d / e.r)); }
    const k = pondK(x, z); if (k < 1.15) y -= 1.6 * Math.min(1, (1.15 - k) / 0.3);
    const cd = creekD(x, z); if (cd < 5) y -= 1.3 * Math.min(1, (5 - cd) / 2.5);
    if (!inside(x, z)) y += Math.min(20, Math.max(0, edgeD(x, z) - 3) * 0.3);
    return y;
  };
  const world = new T.Group();
  { const N = 260, S = 640, g = new T.PlaneGeometry(S, S, N, N); g.rotateX(-Math.PI / 2);
    const p = g.attributes.position, col = new Float32Array(p.count * 3);
    for (let i = 0; i < p.count; i++) {
      const x = p.getX(i), z = p.getZ(i); p.setY(i, H(x, z));
      let c = pal.ground.slice();
      const n = 0.5 + 0.5 * Math.sin(x * 0.19 + Math.sin(z * 0.13) * 2) * Math.cos(z * 0.17);
      c = lerp(c, pal.groundDark, 0.22 * n);
      c = lerp(c, [150, 232, 150], 0.18 * (0.5 + 0.5 * Math.sin(x * 0.045 - z * 0.06)));
      const td = trailD(x, z); if (td < 3.2) c = lerp(c, pal.path, Math.min(1, (3.2 - td) / 1.4) * 0.85);
      const k = pondK(x, z); if (k < 1.22) c = lerp(c, [226, 214, 170], Math.min(1, (1.22 - k) / 0.1) * 0.8);
      const cd = creekD(x, z); if (cd < 5.2) c = lerp(c, [226, 214, 170], Math.min(1, (5.2 - cd) / 1.2) * 0.8);
      if (!inside(x, z)) c = lerp(pal.groundDark, [96, 190, 150], Math.min(1, edgeD(x, z) / 120));
      col[i * 3] = c[0] / 255; col[i * 3 + 1] = c[1] / 255; col[i * 3 + 2] = c[2] / 255;
    }
    g.setAttribute('color', new T.BufferAttribute(col, 3)); g.computeVertexNormals();
    const m = new T.Mesh(g, new T.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 })); m.receiveShadow = true; world.add(m); }
  const add = (geo, c, x, y, z, sx, sy, sz, o = {}) => { const m = new T.Mesh(geo, mat(c, o.mat || {})); m.position.set(x, y, z); m.scale.set(sx, sy, sz); if (o.rot) m.rotation.set(o.rot[0], o.rot[1], o.rot[2]); m.castShadow = o.cast !== false; m.receiveShadow = true; (o.parent || world).add(m); return m; };
  let seed = 7; const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };

  // water
  { const w = new T.Mesh(new T.CircleGeometry(1, 48), new T.MeshStandardMaterial({ color: rgb(pal.water), roughness: 0.25, transparent: true, opacity: 0.9 })); w.rotation.x = -Math.PI / 2; w.scale.set(pond.rx, pond.rz, 1); w.position.set(pond.x, -0.25, pond.z); world.add(w);
    for (let i = 0; i < 7; i++) { const a = rnd() * 6.28, r = 0.2 + rnd() * 0.6; add(CYL, [120, 214, 130], pond.x + Math.cos(a) * pond.rx * r, -0.18, pond.z + Math.sin(a) * pond.rz * r, 2.6, 0.12, 2.6, { cast: false }); }
    const pts = creek.points, pos = [], idx = [];
    for (let i = 0; i < pts.length; i++) { const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)]; const dx = b[0] - a[0], dz = b[1] - a[1], l = Math.hypot(dx, dz); const nx = -dz / l * 3, nz = dx / l * 3; pos.push(pts[i][0] + nx, -0.3, pts[i][1] + nz, pts[i][0] - nx, -0.3, pts[i][1] - nz); if (i) { const k = i * 2; idx.push(k - 2, k - 1, k, k - 1, k + 1, k); } }
    const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(pos, 3)); g.setIndex(idx); g.computeVertexNormals();
    const m = new T.Mesh(g, new T.MeshStandardMaterial({ color: rgb(pal.water), roughness: 0.25, side: T.DoubleSide, transparent: true, opacity: 0.9 })); world.add(m); }

  // hedge boundary
  for (let i = 0; i < B.length; i++) { const a = B[i], b = B[(i + 1) % B.length], l = Math.hypot(b[0] - a[0], b[1] - a[1]), n = Math.ceil(l / 5);
    for (let k = 0; k < n; k++) { const t = (k + 0.5) / n, x = a[0] + (b[0] - a[0]) * t, z = a[1] + (b[1] - a[1]) * t, y = H(x, z);
      add(SPH, lerp([52, 150, 100], [80, 184, 116], rnd()), x, y + 1.0, z, 5.4, 3.6 + rnd() * 1.0, 5.4);
      if (rnd() < 0.5) add(SPH, rnd() < 0.5 ? pal.accent2 : WHITE, x + (rnd() - 0.5) * 3, y + 2.5 + rnd() * 0.5, z + (rnd() - 0.5) * 3, 0.8, 0.8, 0.8, { cast: false }); } }

  const feat = id => A.features.find(f => f.id === id);
  // clover tree
  { const f = feat('clover_tree'), y = H(f.x, f.z); const trunk = [156, 108, 92];
    add(new T.CylinderGeometry(1.7, 2.8, 14, 20), trunk, f.x, y + 7, f.z, 1, 1, 1); add(new T.CylinderGeometry(1.2, 1.7, 14, 20), trunk, f.x + 0.6, y + 20.5, f.z, 1, 1, 1, { rot: [0, 0, -0.06] });
    for (let tier = 0; tier < 2; tier++) for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2 + tier * Math.PI / 4, r = tier ? 6.5 : 10.5, yy = y + (tier ? 37 : 30);
      for (const s of [-1, 1]) add(SPH, tier ? [150, 240, 160] : [104, 214, 138], f.x + Math.cos(a) * r + Math.cos(a + 1.57) * s * (tier ? 2.2 : 3.4), yy, f.z + Math.sin(a) * r + Math.sin(a + 1.57) * s * (tier ? 2.2 : 3.4), tier ? 8 : 12.5, tier ? 4.2 : 5.6, tier ? 8 : 12.5); }
    add(SPH, [120, 226, 150], f.x, y + 31, f.z, 13, 6, 13);
    for (let k = 0; k < 10; k++) { const a = k * 0.63, r = 6 + (k % 3) * 3.5; add(SPH, GOLD, f.x + Math.cos(a) * r, y + 25.5 - (k % 2), f.z + Math.sin(a) * r, 1.1, 1.3, 1.1, { cast: false, mat: { emissive: rgb(GOLD), emissiveIntensity: 0.6 } }); } }
  // windmill
  { const f = feat('landmark_windmill') || feat('windmill'), y = H(f.x, f.z);
    add(new T.CylinderGeometry(3.0, 5.0, 26, 20), [255, 244, 222], f.x, y + 13, f.z, 1, 1, 1); add(new T.ConeGeometry(4.2, 7, 20), [255, 150, 186], f.x, y + 29.5, f.z, 1, 1, 1);
    add(BOX, [150, 104, 84], f.x, y + 2.6, f.z + 4.6, 2.6, 5, 0.6);
    const hub = new T.Group(); hub.position.set(f.x - 2.2, y + 24, f.z + 3.4); hub.rotation.y = -0.55; world.add(hub);
    for (let k = 0; k < 4; k++) { const g = new T.Group(); g.rotation.z = k * Math.PI / 2 + 0.5; hub.add(g); add(BOX, [150, 104, 84], 0, 7.5, 0, 0.6, 15, 0.5, { parent: g }); add(BOX, [[255, 214, 72], [150, 232, 220], [255, 150, 186], [255, 249, 231]][k], 1.9, 9, 0, 3.4, 10, 0.25, { parent: g }); }
    add(SPH, GOLD, f.x - 2.2, y + 24, f.z + 3.4, 2, 2, 2); }
  // pens
  for (const id of ['pen_a', 'pen_b']) { const p = feat(id).points; for (let i = 0; i < p.length - 1; i++) { const a = p[i], b = p[i + 1], l = Math.hypot(b[0] - a[0], b[1] - a[1]), n = Math.round(l / 2.4);
    for (let k = 0; k <= n; k++) { const t = k / n, x = a[0] + (b[0] - a[0]) * t, z = a[1] + (b[1] - a[1]) * t, y = H(x, z); for (let r = 0; r < 2; r++) add(BOX, lerp(pal.wall, [186, 172, 160], rnd() * 0.8), x + (rnd() - 0.5) * 0.3, y + 1.15 + r * 2.2, z + (rnd() - 0.5) * 0.3, 2.3, 2.1, 2.1, { rot: [0, rnd() * 0.5, 0] }); add(BOX, [112, 196, 126], x, y + 4.55, z, 2.5, 0.5, 2.3, { cast: false }); } } }
  // mushrooms, buds, perches, bridge, stones
  { const f = feat('mushroom_ring'); for (let k = 0; k < 5; k++) { const a = k * 1.2566, x = f.x + Math.cos(a) * 9, z = f.z + Math.sin(a) * 9, y = H(x, z); add(CYL, WHITE, x, y + 1.5, z, 2.2, 3, 2.2); add(SPH, k % 2 ? pal.accent2 : [255, 120, 110], x, y + 3.4, z, 7, 3.4, 7); } }
  for (const id of ['bud_a', 'bud_b', 'bud_c']) { const f = feat(id), y = H(f.x, f.z); add(CYL, [86, 176, 120], f.x, y + 1.5, f.z, 1.6, 3, 1.6); add(SPH, [255, 150, 186], f.x, y + 6, f.z, 6, 7.5, 6);
    for (let k = 0; k < 6; k++) { const a = k * 1.047; add(SPH, [255, 190, 210], f.x + Math.cos(a) * 2.2, y + 5.2, f.z + Math.sin(a) * 2.2, 2.6, 6, 2.6); } add(SPH, GOLD, f.x, y + 9.6, f.z, 1.6, 1.6, 1.6, { mat: { emissive: rgb(GOLD), emissiveIntensity: 0.5 } }); }
  for (const id of ['perch_1', 'perch_2', 'perch_3']) { const f = feat(id), y = H(f.x, f.z); add(CYL, [86, 176, 120], f.x, y + 3, f.z, 0.5, 6, 0.5); for (let k = 0; k < 5; k++) { const a = k * 1.2566; add(SPH, k % 2 ? [255, 249, 231] : [255, 200, 222], f.x + Math.cos(a) * 1.3, y + 6.1, f.z + Math.sin(a) * 1.3, 1.9, 0.5, 1.9); } add(SPH, GOLD, f.x, y + 6.3, f.z, 1.3, 0.7, 1.3); }
  { const f = feat('log_bridge'); add(CYL, [150, 104, 84], f.x, 0.4, f.z, 2.6, 11, 2.6, { rot: [Math.PI / 2, 0, 0.1] }); const s = feat('stepping_stones'); for (let k = -2; k <= 2; k++) add(CYL, [214, 206, 196], s.x + k * 0.4, -0.05, s.z + k * 1.7, 2.2, 0.5, 2.2); }
  // tall grass + ground dressing (client decor)
  { const f = feat('tall_grass'), cone = new T.ConeGeometry(0.42, 3.4, 5); const im = new T.InstancedMesh(cone, new T.MeshStandardMaterial({ roughness: 0.9 }), 900); const d = new T.Object3D(); const c = new T.Color();
    for (let i = 0; i < 900; i++) { const a = rnd() * 6.28, r = Math.sqrt(rnd()) * f.r; const x = f.x + Math.cos(a) * r, z = f.z + Math.sin(a) * r; d.position.set(x, H(x, z) + 1.5, z); d.rotation.set((rnd() - 0.5) * 0.3, rnd() * 3, (rnd() - 0.5) * 0.3); d.scale.set(1, 0.8 + rnd() * 0.5, 1); d.updateMatrix(); im.setMatrixAt(i, d.matrix); im.setColorAt(i, c.copy(rgb(lerp([70, 176, 118], [140, 226, 140], rnd())))); }
    im.castShadow = true; im.receiveShadow = true; world.add(im);
    const tuft = new T.InstancedMesh(new T.ConeGeometry(0.3, 1.1, 4), new T.MeshStandardMaterial({ roughness: 0.9 }), 2600); let n = 0;
    while (n < 2600) { const x = (rnd() - 0.5) * 180, z = (rnd() - 0.5) * 160; if (!inside(x, z) || pondK(x, z) < 1.2 || creekD(x, z) < 5 || trailD(x, z) < 2.5) continue; d.position.set(x, H(x, z) + 0.45, z); d.rotation.set(0, rnd() * 3, 0); d.scale.set(1, 0.7 + rnd() * 0.8, 1); d.updateMatrix(); tuft.setMatrixAt(n, d.matrix); tuft.setColorAt(n, c.copy(rgb(lerp([84, 190, 126], [150, 232, 150], rnd())))); n++; }
    tuft.receiveShadow = true; world.add(tuft);
    const fl = new T.InstancedMesh(SPH, new T.MeshStandardMaterial({ roughness: 0.8 }), 700); n = 0; const cols = [[255, 249, 231], [255, 214, 72], [255, 150, 186], [200, 170, 255]];
    while (n < 700) { const x = (rnd() - 0.5) * 180, z = (rnd() - 0.5) * 160; if (!inside(x, z) || pondK(x, z) < 1.2 || creekD(x, z) < 5 || trailD(x, z) < 2) continue; d.position.set(x, H(x, z) + 0.35, z); d.rotation.set(0, 0, 0); d.scale.set(0.7, 0.45, 0.7); d.updateMatrix(); fl.setMatrixAt(n, d.matrix); fl.setColorAt(n, c.copy(rgb(cols[n % 4]))); n++; }
    world.add(fl); }
  // bank ring at the south gate
  for (const b of A.bankRings) { const y = H(b.x, b.z); const g = new T.Group(); g.position.set(b.x, y, b.z); world.add(g);
    const ring = new T.Mesh(new T.TorusGeometry(5, 0.55, 14, 40), mat(GOLD, { emissive: rgb(GOLD), emissiveIntensity: 0.35 })); ring.position.y = 6.2; ring.castShadow = true; g.add(ring);
    for (const s of [-1, 1]) add(CYL, WHITE, s * 3.4, 1.0, 0, 1.4, 2.4, 1.4, { parent: g }); }

  // ---------- creatures ----------
  const speciesPal = {}; for (const s of data.creatures.species) speciesPal[s.id] = s.palette;
  function creature(id, pose = {}, detail = true) {
    const def = data.models.species[id], p = speciesPal[id], g = new T.Group();
    const cmap = { body: p.body, accent: p.accent, bodyDark: lerp(p.body, INK, 0.3), ink: INK, white: WHITE, gold: GOLD, blush: [255, 150, 170] };
    const bs = pose.bodyScale || [1, 1, 1];
    for (const part of def.parts.concat(detail ? def.nearDetail : [])) {
      const geo = part.shape === 'block' ? BOX : part.shape === 'cylinder' ? CYL : SPH;
      const isEye = part.name.startsWith('eye'), isEar = part.name.startsWith('ear_');
      const cc = cmap[part.color] || part.color; const m = new T.Mesh(geo, mat(cc, isEye ? { roughness: 0.2 } : { emissive: rgb(cc), emissiveIntensity: 0.22 }));
      const es = isEye ? (pose.eyeScale || 1) : 1;
      m.scale.set(part.size[0] * (part.name === 'body' || part.name === 'feet' ? bs[0] : 1) * es, part.size[1] * (part.name === 'body' ? bs[1] : 1) * es, part.size[2] * (part.name === 'body' || part.name === 'feet' ? bs[2] : 1));
      let py = part.pos[1]; if (part.name !== 'feet') py = part.name === 'body' ? part.pos[1] * bs[1] : part.pos[1] + (bs[1] - 1) * 1.15 * (part.pos[1] > 1.2 ? 2 : 1);
      m.position.set(part.pos[0] * (part.name === 'body' ? 1 : bs[0]), py, part.pos[2] * bs[2]);
      let rz = part.rot[2]; if (isEar && id === 'pip' && pose.earRot !== undefined) rz = Math.sign(rz) * pose.earRot;
      m.rotation.set(part.rot[0] * Math.PI / 180, part.rot[1] * Math.PI / 180, rz * Math.PI / 180);
      if (isEar && id === 'pip' && pose.earRot !== undefined) m.position.x = Math.sign(part.pos[0]) * (0.5 + Math.sin(pose.earRot * Math.PI / 180) * 0.35 - 0.16);
      m.castShadow = part.name === 'body' || isEar; m.receiveShadow = false; g.add(m);
    }
    g.scale.setScalar(tun.creatures.globalScale.value);
    return g;
  }
  const place = (g, x, z, face, lift = 0, parent = world) => { g.position.set(x, H(x, z) + lift, z); g.rotation.y = face; parent.add(g); return g; };

  // ---------- the moment: a ring about to snap shut around the south-lawn Pip pod ----------
  const C = [12, 46], R = 7.6, a0 = 135 * Math.PI / 180, a1 = (360 + 93) * Math.PI / 180;
  const on = a => [C[0] + R * Math.cos(a), C[1] + R * Math.sin(a)];
  const lead = [[-1, 63.5], [0, 60], [1.5, 56.5], [4, 53.5]];
  const path = lead.slice(); for (let a = a0; a <= a1; a += 0.09) path.push(on(a)); path.push(on(a1));
  const head = path[path.length - 1], snapPt = on(a0);
  function strip(pts, width, yOff, color, alphaFn) {
    const pos = [], col = [], idx = []; let acc = 0; const total = pts.reduce((s, p, i) => i ? s + Math.hypot(p[0] - pts[i - 1][0], p[1] - pts[i - 1][1]) : 0, 0);
    for (let i = 0; i < pts.length; i++) { const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)]; const dx = b[0] - a[0], dz = b[1] - a[1], l = Math.hypot(dx, dz) || 1; const nx = -dz / l * width / 2, nz = dx / l * width / 2;
      if (i) acc += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); const al = alphaFn(acc / total);
      for (const s of [1, -1]) { const x = pts[i][0] + nx * s, z = pts[i][1] + nz * s; pos.push(x, (strip.H || H)(x, z) + yOff, z); col.push(color[0] / 255, color[1] / 255, color[2] / 255, al); }
      if (i) { const k = i * 2; idx.push(k - 2, k - 1, k, k - 1, k + 1, k); } }
    const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(pos, 3)); g.setAttribute('color', new T.Float32BufferAttribute(col, 4)); g.setIndex(idx);
    return new T.Mesh(g, new T.MeshBasicMaterial({ vertexColors: true, transparent: true, depthWrite: false, side: T.DoubleSide }));
  }
  const fade = t => 0.3 + 0.7 * t;
  const ribbon = new T.Group(); world.add(ribbon);
  ribbon.add(strip(path, 3.4, 0.16, [255, 243, 107], t => 0.20 * fade(t)));
  ribbon.add(strip(path, tun.ribbon.width.value * 1.25, 0.2, [255, 240, 96], fade));
  ribbon.add(strip(path, 0.42, 0.24, [255, 255, 245], fade));
  { const n = 5; for (let i = 0; i < n; i++) { const t0 = (i + 0.15) / n, t1 = (i + 0.7) / n; ribbon.add(strip([[head[0] + (snapPt[0] - head[0]) * t0, head[1] + (snapPt[1] - head[1]) * t0], [head[0] + (snapPt[0] - head[0]) * t1, head[1] + (snapPt[1] - head[1]) * t1]], 0.5, 0.26, [255, 255, 255], () => 0.95)); }
    const ring = new T.Mesh(new T.RingGeometry(1.1, 1.5, 32), new T.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.95, depthWrite: false })); ring.rotation.x = -Math.PI / 2; ring.position.set(snapPt[0], H(snapPt[0], snapPt[1]) + 0.27, snapPt[1]); ribbon.add(ring); }
  const pips = [[11.0, 45.0, 2.5], [13.4, 46.2, 3.6], [11.9, 47.6, 0.6]];
  for (const [x, z, f] of pips) place(creature('pip', { bodyScale: [0.95, 1.08, 0.95], earRot: 62, eyeScale: 1.15 }), x, z, f);
  // parade of two, earlier catches, following along the ribbon
  for (const a of [a1 - 0.42, a1 - 0.78]) { const p = on(a); place(creature('pip', { earRot: 22 }), p[0] + 0.4, p[1] + 0.3, Math.PI / 2 + 0.2, 0.35); }
  // pods elsewhere, at their habitats
  for (const [x, z] of [[-13, 24], [-16.5, 27], [-11.5, 28.5]]) place(creature('pip'), x, z, rnd() * 6);
  for (const [x, z] of [[-41.2, 16.8], [-38.4, 16.9], [-41.3, 19.4], [-38.5, 19.5]]) place(creature('cubloom'), x, z, 2.6);
  for (const [x, z] of [[49, -35], [51.5, -37]]) place(creature('bunvolt'), x, z, 0.5);
  place(creature('flutter'), 36, 36, 0.4, 6.4);
  // player (blocky avatar, mid-stride, facing along the ring toward the snap point)
  const player = new T.Group(); const skin = [255, 206, 164], shirt = [64, 140, 240], pants = [40, 56, 110];
  const body = new T.Group(); body.rotation.x = -0.22; player.add(body);
  add(BOX, shirt, 0, 3.0, 0, 2, 2, 1, { parent: body });
  add(SPH, skin, 0, 4.7, 0, 1.4, 1.3, 1.4, { parent: body }); add(SPH, [104, 66, 48], 0, 5.0, 0.12, 1.5, 0.95, 1.5, { parent: body });
  add(BOX, skin, -1.45, 3.1, -0.45, 0.9, 1.9, 0.9, { parent: body, rot: [0.9, 0, 0] }); add(BOX, skin, 1.45, 3.1, 0.45, 0.9, 1.9, 0.9, { parent: body, rot: [-0.9, 0, 0] });
  add(BOX, pants, -0.5, 1.05, 0.5, 0.95, 2, 0.95, { parent: player, rot: [-0.6, 0, 0] }); add(BOX, pants, 0.5, 1.05, -0.5, 0.95, 2, 0.95, { parent: player, rot: [0.6, 0, 0] });
  const tangent = [-Math.sin(a1), Math.cos(a1)];
  player.position.set(head[0], H(head[0], head[1]), head[1]); player.rotation.y = Math.atan2(-tangent[0], -tangent[1]); world.add(player);

  // ---------- lights ----------
  const sc = new T.Scene(); sc.add(world);
  sc.add(new T.HemisphereLight(0xeaf6ff, 0x6fbf88, 0.78));
  const sun = new T.DirectionalLight(0xfff0d0, 2.7); sun.position.set(head[0] + 70, 95, head[1] + 45); sun.target.position.set(head[0], 0, head[1] - 20); sc.add(sun, sun.target);
  sun.castShadow = true; sun.shadow.mapSize.set(4096, 4096); Object.assign(sun.shadow.camera, { left: -150, right: 150, top: 150, bottom: -150, near: 1, far: 400 }); sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.6; sun.shadow.radius = 3;
  sc.fog = new T.Fog(0xbfe8f2, 190, 620);
  return { T, sc, world, H, head, tangent, creature, add, mat, rgb, strip, SPH, BOX, CYL, INK, WHITE, GOLD, lerp, speciesPal };
}

const PAGE = fn => `(${fn.toString()})`;

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const out = f => path.join(ROOT, 'mockups', f);

  // ===== 1. gameplay frame + pitch comparison =====
  {
    const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 2 });
    await page.setContent('<html><body style="margin:0;background:linear-gradient(#8fd4ff,#dff5ee);overflow:hidden;font-family:Verdana,Geneva,sans-serif"><canvas id="c" width="2560" height="1440" style="width:1280px;height:720px;display:block"></canvas><div id="hud"></div></body></html>');
    await page.addScriptTag({ path: three });
    await page.evaluate(`window.buildScene = ${PAGE(scene)}`);
    const shoot = async (pitch, file, hud) => {
      await page.evaluate(({ data, pitch, hud }) => {
        const S = window.S || (window.S = window.buildScene(data)); const T = S.T, cam = data.tuning.camera;
        if (!window.R) { window.R = new T.WebGLRenderer({ canvas: document.getElementById('c'), antialias: true, alpha: true }); window.R.shadowMap.enabled = true; window.R.shadowMap.type = T.PCFSoftShadowMap; window.R.setSize(1280, 720, false); window.R.setPixelRatio(2); window.R.outputColorSpace = T.SRGBColorSpace; window.R.toneMapping = T.NoToneMapping; }
        const camera = new T.PerspectiveCamera(cam.fov.value, 1280 / 720, 0.5, 900);
        const p = pitch * Math.PI / 180, dist = cam.distance.value, la = cam.lookAhead.value;
        const tx = S.head[0] + S.tangent[0] * la, tz = S.head[1] + S.tangent[1] * la, ty = S.H(tx, tz) + 2.5;
        const yaw = -0.16;   // the player's yaw: looking north, turned slightly east
        camera.position.set(tx + Math.sin(yaw) * Math.cos(p) * dist * -1, ty + Math.sin(p) * dist, tz + Math.cos(yaw) * Math.cos(p) * dist);
        camera.lookAt(tx, ty, tz); window.R.render(S.sc, camera);
        const h = document.getElementById('hud'); h.innerHTML = '';
        if (!hud) { h.innerHTML = `<div style="position:absolute;left:16px;top:14px;padding:6px 12px;border-radius:10px;background:rgba(27,36,64,.7);color:#fff9e7;font-weight:bold;font-size:20px">pitch ${pitch}°</div>`; return; }
        const r = data.ui.viewports.desktop_1280x684.rects, oy = 36;
        const box = (k, html, extra = '') => `<div style="position:absolute;left:${r[k][0]}px;top:${r[k][1] + oy}px;width:${r[k][2]}px;height:${r[k][3]}px;border-radius:10px;display:flex;align-items:center;justify-content:center;color:#fff9e7;font-weight:bold;${extra}">${html}</div>`;
        const panel = 'background:rgba(27,36,64,.62);';
        let pipsHtml = ''; for (let i = 0; i < 12; i++) pipsHtml += `<span style="display:inline-block;width:11px;height:11px;border-radius:50%;margin-right:3px;border:1.5px solid rgba(255,249,231,.65);background:${i < 2 ? '#ffd241' : 'transparent'}"></span>`;
        h.innerHTML =
          `<div style="position:absolute;left:0;top:0;width:1280px;height:36px;"><span style="position:absolute;left:12px;top:5px;width:26px;height:26px;border-radius:8px;background:rgba(18,18,21,.55)"></span><span style="position:absolute;left:46px;top:5px;width:26px;height:26px;border-radius:8px;background:rgba(18,18,21,.55)"></span></div>` +
          box('timer', '1:38', panel + 'font-size:19px') +
          box('parade', `<span style="flex:1;padding-left:10px;display:flex;align-items:center">${pipsHtml}</span><span style="color:#ffe36b;padding-right:9px;font-size:14px">×1.0</span>`, panel) +
          box('score', '6', panel + 'font-size:17px') + box('menu', '≡', panel + 'font-size:20px') +
          box('hint', 'Run a circle around the Sparks', panel + 'color:#ffe36b;font-weight:normal;font-size:14px') +
          (() => { const [x, y, w, hh] = r.dash; let s = ''; for (let i = 0; i < 2; i++) s += `<span style="position:absolute;left:${x + w * (0.27 + 0.46 * i) - 13}px;top:${y + oy + hh / 2 - 13}px;width:26px;height:26px;transform:rotate(45deg);border-radius:5px;background:#ffe36b;border:2px solid #fff9e7;box-shadow:0 0 0 2px rgba(27,36,64,.5)"></span>`; return s; })();
      }, { data, pitch, hud });
      await page.screenshot({ path: file });
    };
    const pitch = data.tuning.camera.pitchDegrees.value;
    await shoot(pitch, out('meadow_gameplay_frame.png'), true);
    const strips = [];
    for (const p of data.tuning.camera.pitchPresets.value) { const f = path.join(require('os').tmpdir(), `pitch_${p}.png`); await shoot(p, f, false); strips.push(f); }
    const cmp = await browser.newPage({ viewport: { width: 1920, height: 400 }, deviceScaleFactor: 1 });
    await cmp.setContent(`<html><body style="margin:0;background:#1b2440;display:flex;gap:6px;padding:6px;box-sizing:border-box">${strips.map(f => `<img src="data:image/png;base64,${fs.readFileSync(f).toString('base64')}" style="width:632px;height:356px;border-radius:8px">`).join('')}</body></html>`);
    await cmp.screenshot({ path: out('camera_pitch_comparison.png'), clip: { x: 0, y: 0, width: 1920, height: 368 } });
    await cmp.close(); await page.close();
  }

  // ===== 2. reference sheet + cinch storyboard (small studio scenes) =====
  {
    const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1 });
    await page.setContent('<html><body style="margin:0;background:#fbf7ea;font-family:Verdana,Geneva,sans-serif;color:#1b2440"><div id="root"></div></body></html>');
    await page.addScriptTag({ path: three });
    await page.evaluate(`window.buildScene = ${PAGE(scene)}`);
    await page.evaluate((data) => {
      const S = window.buildScene(data), T = S.T;
      const R = new T.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true }); R.shadowMap.enabled = true; R.shadowMap.type = T.PCFSoftShadowMap; R.outputColorSpace = T.SRGBColorSpace;
      window.shot = (w, h, build, camPos, look, fov = 30, ortho = 0) => {
        R.setSize(w, h, false); const sc = new T.Scene();
        sc.add(new T.HemisphereLight(0xffffff, 0xcfd8c8, 1.15)); const sun = new T.DirectionalLight(0xfff2dc, 1.9); sun.position.set(6, 12, 7); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048); Object.assign(sun.shadow.camera, { left: -22, right: 22, top: 22, bottom: -22 }); sun.shadow.radius = 4; sun.shadow.normalBias = 0.3; sc.add(sun);
        const g = new T.Group(); sc.add(g); build(g, sc);
        const cam = ortho ? new T.OrthographicCamera(-ortho * w / h, ortho * w / h, ortho, -ortho, 0.1, 200) : new T.PerspectiveCamera(fov, w / h, 0.1, 400);
        cam.position.set(...camPos); cam.lookAt(...look); R.render(sc, cam); return R.domElement.toDataURL('image/png');
      };
      window.S = S;
      window.floor = (g, r, color = [108, 214, 142]) => { const m = new T.Mesh(new T.CircleGeometry(r, 48), new T.MeshStandardMaterial({ color: S.rgb(color), roughness: 0.95 })); m.rotation.x = -Math.PI / 2; m.receiveShadow = true; g.add(m); };
      window.put = (g, id, pose, x, z, face, lift = 0) => { const c = S.creature(id, pose || {}, true); c.position.set(x, lift, z); c.rotation.y = face || 0; g.add(c); return c; };
    }, data);
    // --- Pip sheet
    const pipHtml = await page.evaluate(() => {
      const views = [['FRONT', [0, 2.0, -14], 0], ['THREE-QUARTER', [8, 4.6, -11], 0], ['SIDE', [14, 2.0, 0], 0], ['TOP', [0, 17, -0.01], 0], ['BACK', [0, 2.2, 14], 0]];
      const poses = [['IDLE', {}, 0], ['ALERT (0.3 s telegraph)', { bodyScale: [0.94, 1.1, 0.94], earRot: 70, eyeScale: 1.15 }, 0], ['FLEE — contact', { bodyScale: [1.12, 0.85, 1.12], earRot: 55 }, 0], ['FLEE — air', { bodyScale: [0.92, 1.14, 0.92], earRot: 55 }, 0.7], ['CINCHED', { bodyScale: [0.9, 1.12, 0.9], earRot: 5, eyeScale: 1.3 }, 0], ['POP squash', { bodyScale: [1.25, 0.7, 1.25], earRot: 80, eyeScale: 1.2 }, 0]];
      const img = (label, url, w, h) => `<div style="text-align:center"><img src="${url}" width="${w}" height="${h}" style="background:#fff;border-radius:14px;border:1px solid rgba(27,36,64,.15)"><div style="font-size:12px;font-weight:bold;margin-top:4px">${label}</div></div>`;
      let a = '', b = '';
      for (const [label, pos] of views) a += img(label, shot(250, 250, g => { floor(g, 3.4, [236, 232, 214]); put(g, 'pip', {}, 0, 0, 0); }, pos, [0, 1.9, 0], 24), 250, 250);
      for (const [label, pose, lift] of poses) b += img(label, shot(205, 230, g => { floor(g, 3.2, [236, 232, 214]); put(g, 'pip', pose, 0, 0, 0, lift); }, [7.6, 4.4, -10.6], [0, 2.1, 0], 25), 205, 230);
      const scale = shot(520, 250, g => { floor(g, 14, [236, 232, 214]); put(g, 'pip', {}, -7.4, 0, 0); put(g, 'bunvolt', {}, -3.6, 0, 0); put(g, 'cubloom', {}, 0.6, 0, 0); put(g, 'flutter', {}, 6.2, 0, 0, 0.4);
        const s = window.S; const p = new s.T.Group(); p.position.set(11.6, 0, 0); g.add(p); s.add(s.BOX, [200, 204, 214], 0, 3.0, 0, 2, 2, 1, { parent: p }); s.add(s.SPH, [200, 204, 214], 0, 4.7, 0, 1.3, 1.3, 1.3, { parent: p }); s.add(s.BOX, [200, 204, 214], -0.5, 1, 0, 0.95, 2, 0.95, { parent: p }); s.add(s.BOX, [200, 204, 214], 0.5, 1, 0, 0.95, 2, 0.95, { parent: p }); }, [2, 5.5, -34], [2, 2.6, 0], 22);
      return `<div style="padding:22px 26px;width:1548px">
        <div style="font-size:26px;font-weight:bold">PIP POP — signature creature reference</div>
        <div style="font-size:13px;margin:4px 0 14px">Rendered from <b>data/models/meadow_creatures.json</b> (6 parts + 4 near-detail parts). Faces −Z. In game: 3.8 studs tall with ears, 3.0 wide (model 2.9 × 2.3 at globalScale 1.3). Reference render from Roblox-equivalent primitives, not an in-game capture.</div>
        <div style="display:flex;gap:12px">${a}</div>
        <div style="font-size:15px;font-weight:bold;margin:16px 0 6px">POSES — squash and stretch is SpecialMesh.Scale on the body; ears rotate at their weld</div>
        <div style="display:flex;gap:10px;align-items:flex-end">${b}<div style="margin-left:6px">${img('MEADOW SET AT ONE SCALE (grey = 5-stud player)', scale, 250, 120)}<div style="font-size:11px;line-height:1.5;margin-top:8px;max-width:250px">Body 255,210,65 · ears 255,244,190 · feet = body 30% toward ink · eyes ink 27,36,64 (glossy) · glints and cheeks only within 35 studs.</div></div></div>
      </div>`;
    });
    await page.evaluate(h => { document.getElementById('root').innerHTML = h; }, pipHtml);
    await page.screenshot({ path: out('pip_reference_sheet.png'), clip: { x: 0, y: 0, width: 1600, height: 690 } });
    // --- cinch storyboard
    const cinchHtml = await page.evaluate(() => {
      const s = window.S, T = s.T;
      const loop = []; for (let i = 0; i < 40; i++) { const a = i / 40 * Math.PI * 2; loop.push([Math.cos(a) * (7.4 + 0.7 * Math.sin(a * 3 + 1)), Math.sin(a) * (6.6 + 0.5 * Math.cos(a * 2))]); } loop.push(loop[0]);
      const flat = (pts, w, y, color, alpha) => { const m = s.strip(pts, w, y, color, () => alpha); return m; };
      const pips = [[-2.3, -1.5, 2.4], [2.1, 0.3, 3.7], [-0.3, 2.5, 0.7]];
      const beats = [
        ['t = −0.2 s · about to snap', 'Ribbon 1.2 wide, head opaque. Dashed preview and snap ring appear inside 9 studs. Pips in ALERT.', 1.0, 'open', {}],
        ['t = 0 · CLOSE', 'One-frame white flash on the loop, width 2.2. Ground disc at 25% opacity. loop_close plays. Pips switch to CINCHED.', 1.0, 'flash', { bodyScale: [0.9, 1.12, 0.9], earRot: 5, eyeScale: 1.3 }],
        ['t = 0.15 s · cinching', 'Ring is 24 Beam segments shrinking toward the centroid (quad-in). Chevron texture scrolls inward.', 0.82, 'ring', { bodyScale: [0.9, 1.12, 0.9], earRot: 5, eyeScale: 1.3 }],
        ['t = 0.30 s · tight (waits here for the server)', 'Ring stops 0.6 studs outside the outermost body. If the result is late it HOLDS; at 0.8 s it slips.', 0.3, 'ring', { bodyScale: [0.9, 1.12, 0.9], earRot: 5, eyeScale: 1.3 }],
        ['result · POP ×3, 0.06 s apart', 'Squash, burst of 12 species-coloured sparks, arc into the parade. Notes climb the pentatonic ladder. Payout tag rises.', 0.3, 'pop', {}]];
      let html = '';
      beats.forEach(([title, text, k, mode, pose], bi) => {
        const url = shot(300, 300, g => {
          floor(g, 16);
          s.strip.H = () => 0;   // flat studio floor for the strip helper
          if (mode === 'open') { const open = loop.slice(0, 37); g.add(flat(open, 3.2, 0.03, [255, 243, 107], 0.2)); g.add(flat(open, 1.5, 0.05, [255, 240, 96], 1)); g.add(flat(open, 0.42, 0.07, [255, 255, 245], 1));
            for (let i = 0; i < 4; i++) { const a = open[36], b = loop[0]; g.add(flat([[a[0] + (b[0] - a[0]) * (i + 0.15) / 4, a[1] + (b[1] - a[1]) * (i + 0.15) / 4], [a[0] + (b[0] - a[0]) * (i + 0.7) / 4, a[1] + (b[1] - a[1]) * (i + 0.7) / 4]], 0.5, 0.08, [255, 255, 255], 0.95)); } }
          if (mode === 'flash') { const d = new T.Mesh(new T.CircleGeometry(7.2, 40), new T.MeshBasicMaterial({ color: 0xfff36b, transparent: true, opacity: 0.28 })); d.rotation.x = -Math.PI / 2; d.position.y = 0.02; g.add(d); g.add(flat(loop, 4.4, 0.04, [255, 255, 255], 0.35)); g.add(flat(loop, 2.2, 0.06, [255, 255, 255], 1)); }
          if (mode === 'ring' || mode === 'pop') { const kk = Math.max(k, 0.62); const pts = loop.map(p => [p[0] * kk, p[1] * kk]); if (mode === 'ring') { g.add(flat(pts, 2.6, 0.04, [255, 243, 107], 0.3)); g.add(flat(pts, 1.1, 0.06, [255, 240, 96], 1)); g.add(flat(pts, 0.36, 0.08, [255, 255, 245], 1));
              for (let i = 0; i < 12; i++) { const a = i / 12 * 6.28; g.add(flat([[Math.cos(a) * (8.4 * kk + 3.4), Math.sin(a) * (7.6 * kk + 3.4)], [Math.cos(a) * (8.4 * kk + 1.3), Math.sin(a) * (7.6 * kk + 1.3)]], 0.3, 0.05, [255, 255, 255], 0.55)); } } }
          s.strip.H = null;
          if (mode === 'pop') {
            put(g, 'pip', { bodyScale: [1.25, 0.7, 1.25], earRot: 80, eyeScale: 1.2 }, pips[2][0] * 0.7, pips[2][1] * 0.7, pips[2][2]);
            put(g, 'pip', { bodyScale: [0.92, 1.14, 0.92], earRot: 40 }, pips[1][0] * 0.7 + 0.8, pips[1][1] * 0.7, pips[1][2], 2.6);
            put(g, 'pip', { earRot: 30 }, 7.5, -4.5, 2.2, 4.4);
            for (const [cx, cz, cy] of [[pips[0][0] * 0.7, pips[0][1] * 0.7, 1.4], [pips[1][0] * 0.7 + 0.8, pips[1][1] * 0.7, 2.2]]) for (let i = 0; i < 12; i++) { const a = i / 12 * 6.28, r = 2.2 + (i % 3) * 0.9; const m = new T.Mesh(s.SPH, new T.MeshBasicMaterial({ color: i % 2 ? 0xffd241 : 0xfff6c0 })); m.position.set(cx + Math.cos(a) * r, cy + Math.sin(a * 2) * 0.9 + 0.6, cz + Math.sin(a) * r); m.scale.setScalar(0.5 - (i % 3) * 0.1); g.add(m); }
          } else pips.forEach(([x, z, f]) => put(g, 'pip', bi === 0 ? { bodyScale: [0.94, 1.1, 0.94], earRot: 70, eyeScale: 1.15 } : pose, x * (mode === 'ring' ? Math.max(0.72, k + 0.3) : 1), z * (mode === 'ring' ? Math.max(0.72, k + 0.3) : 1), f));
        }, [0, 33, 27], [0, 0.8, 0], 30);
        const tag = mode === 'pop' ? `<div style="position:absolute;left:0;right:0;top:34px;text-align:center"><div style="font-size:34px;font-weight:bold;color:#fff9e7;-webkit-text-stroke:5px #1b2440;paint-order:stroke fill">+29</div><div style="font-size:14px;font-weight:bold;color:#ffe36b;-webkit-text-stroke:3.5px #1b2440;paint-order:stroke fill">x2</div></div>` : '';
        html += `<div style="width:300px"><div style="position:relative"><img src="${url}" width="300" height="300" style="border-radius:14px;border:1px solid rgba(27,36,64,.15);background:#fff">${tag}</div><div style="font-size:13px;font-weight:bold;margin-top:6px">${bi + 1}. ${title}</div><div style="font-size:11.5px;line-height:1.45;margin-top:3px">${text}</div></div>`;
      });
      return `<div style="padding:22px 26px;width:1548px"><div style="font-size:26px;font-weight:bold">CINCH — the capture celebration</div>
        <div style="font-size:13px;margin:4px 0 14px">Timeline data: <b>data/models/cinch_effect.json</b>. Textures: <b>assets/textures/</b>. Example: the first Pip pod (3 × 3 points × size 1.6 × chain x2 = 29). Reference render, not an in-game capture.</div>
        <div style="display:flex;gap:11px">${html}</div></div>`;
    });
    await page.evaluate(h => { document.getElementById('root').innerHTML = h; }, cinchHtml);
    await page.screenshot({ path: out('cinch_storyboard.png'), clip: { x: 0, y: 0, width: 1600, height: 470 } });
    await page.close();
  }
  await browser.close();
  console.log('rendered: meadow_gameplay_frame.png, camera_pitch_comparison.png, pip_reference_sheet.png, cinch_storyboard.png');
})().catch(e => { console.error(e); process.exit(1); });
