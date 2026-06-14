const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];

const storage = {
  get(key, fallback) {
    try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; }
  },
  set(key, value) { localStorage.setItem(key, JSON.stringify(value)); }
};

const state = {
  status: null,
  measurements: storage.get("survey.measurements", []),
  plan: storage.get("survey.plan", { widthM: null, lengthM: null, metersPerPixel: null }),
  image: null,
  selected: null,
  mode: "locate",
  actionPoints: [],
  view: { scale: 1, x: 0, y: 0 },
  pointers: new Map(),
  dragStart: null
};

const floorCanvas = $("#floorCanvas");
const floorCtx = floorCanvas.getContext("2d");
const reportCanvas = $("#reportCanvas");
const reportCtx = reportCanvas.getContext("2d");
let toastTimer;

function toast(message) {
  const el = $("#toast");
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 2400);
}

function api(path, options) {
  return fetch(path, options).then(async (response) => {
    const body = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(body.error || `Request failed (${response.status})`);
    return body;
  });
}

function qualityClass(label) {
  return `quality-${String(label || "unavailable").toLowerCase().replaceAll(" ", "-")}`;
}

function qualityColor(label) {
  return {
    "Excellent": "#087f5b", "Good": "#3a8d32", "Fair": "#d18b00",
    "Weak": "#d05b16", "Very Weak": "#b42318"
  }[label] || "#66727d";
}

function formatUptime(seconds) {
  if (seconds == null) return "--";
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return hours ? `${hours}h ${minutes}m` : `${minutes}m ${seconds % 60}s`;
}

function updateStatus(data) {
  state.status = data;
  $("#rssiValue").textContent = data.rssi ?? "--";
  $("#qualityValue").textContent = data.quality_label || "Unavailable";
  $("#ssidValue").textContent = data.ssid || "Not connected";
  $("#bssidValue").textContent = data.bssid || "--";
  $("#channelValue").textContent = data.channel || "--";
  $("#ipValue").textContent = data.local_ip || data.setup_ip || "--";
  $("#uptimeValue").textContent = formatUptime(data.uptime_seconds);

  $("#signalPanel").className = `signal-panel ${qualityClass(data.quality_label)}`;
  const pill = $("#connectionPill");
  pill.className = `connection-pill ${data.connected ? "connected" : "disconnected"}`;
  pill.querySelector("b").textContent = data.connection_status || "Disconnected";
}

async function refreshStatus() {
  try {
    updateStatus(await api("/api/status"));
  } catch {
    const pill = $("#connectionPill");
    pill.className = "connection-pill disconnected";
    pill.querySelector("b").textContent = "Offline";
  }
}

function showPage(name) {
  $$(".page").forEach((page) => page.classList.toggle("active", page.dataset.page === name));
  $$(".bottom-nav button").forEach((button) => button.classList.toggle("active", button.dataset.target === name));
  if (name === "floor") requestAnimationFrame(() => { resizeFloorCanvas(); drawFloor(); });
  if (name === "report") requestAnimationFrame(renderReport);
}

$$(".bottom-nav button").forEach((button) => button.addEventListener("click", () => showPage(button.dataset.target)));

$("#scanButton").addEventListener("click", async () => {
  const list = $("#networkList");
  list.innerHTML = '<p class="empty">Scanning nearby networks...</p>';
  try {
    const { networks } = await api("/api/scan");
    list.innerHTML = "";
    const unique = [...new Map(networks.sort((a, b) => b.rssi - a.rssi).map((item) => [item.ssid, item])).values()];
    unique.forEach((network) => {
      const button = document.createElement("button");
      button.className = "network";
      button.innerHTML = `<b></b><span></span><span class="network-rssi"></span>`;
      button.querySelector("b").textContent = network.ssid || "(Hidden network)";
      button.querySelector("span").textContent = `Channel ${network.channel} | ${network.secure ? "Secured" : "Open"}`;
      button.querySelector(".network-rssi").textContent = `${network.rssi} dBm`;
      button.addEventListener("click", () => { $("#ssidInput").value = network.ssid; $("#passwordInput").focus(); });
      list.append(button);
    });
    if (!unique.length) list.innerHTML = '<p class="empty">No networks found.</p>';
  } catch (error) {
    list.innerHTML = `<p class="empty">${error.message}</p>`;
  }
});
$("#connectForm").addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await api("/api/connect", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ssid: $("#ssidInput").value, password: $("#passwordInput").value })
    });
    toast("Connection started. Status will update shortly.");
  } catch (error) { toast(error.message); }
});

$("#resetWifiButton").addEventListener("click", async () => {
  if (!confirm("Clear saved Wi-Fi credentials and restart setup mode?")) return;
  try {
    await api("/api/reset-wifi", { method: "POST" });
    toast("Credentials cleared. Reconnect to WiFi-Survey-Setup.");
  } catch (error) { toast(error.message); }
});

function openImageDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open("wifi-survey", 1);
    request.onupgradeneeded = () => request.result.createObjectStore("assets");
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function savePlanImage(blob) {
  const db = await openImageDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction("assets", "readwrite");
    tx.objectStore("assets").put(blob, "floor-plan");
    tx.oncomplete = resolve;
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

async function loadPlanImage() {
  const db = await openImageDb();
  const blob = await new Promise((resolve, reject) => {
    const request = db.transaction("assets").objectStore("assets").get("floor-plan");
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  db.close();
  if (blob) await setImageFromBlob(blob, false);
}

function blobToImage(blob) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    const url = URL.createObjectURL(blob);
    image.onload = () => { URL.revokeObjectURL(url); resolve(image); };
    image.onerror = reject;
    image.src = url;
  });
}

async function setImageFromBlob(blob, persist = true) {
  state.image = await blobToImage(blob);
  state.selected = null;
  state.actionPoints = [];
  fitImage();
  $("#canvasEmpty").hidden = true;
  if (persist) await savePlanImage(blob);
  drawFloor();
  renderReport();
}

$("#floorFileInput").addEventListener("change", async (event) => {
  const file = event.target.files[0];
  if (!file) return;
  try {
    await setImageFromBlob(file);
    toast("Floor plan saved on this phone.");
  } catch { toast("Could not open that image."); }
  event.target.value = "";
});

function resizeFloorCanvas() {
  const rect = floorCanvas.getBoundingClientRect();
  const dpr = devicePixelRatio || 1;
  const width = Math.round(rect.width * dpr);
  const height = Math.round(rect.height * dpr);
  if (floorCanvas.width !== width || floorCanvas.height !== height) {
    floorCanvas.width = width;
    floorCanvas.height = height;
    floorCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (state.image && state.view.scale === 1 && state.view.x === 0) fitImage();
  }
}

function fitImage() {
  if (!state.image) return;
  const rect = floorCanvas.getBoundingClientRect();
  state.view.scale = Math.min(rect.width / state.image.width, rect.height / state.image.height);
  state.view.x = (rect.width - state.image.width * state.view.scale) / 2;
  state.view.y = (rect.height - state.image.height * state.view.scale) / 2;
}

function canvasPoint(event) {
  const rect = floorCanvas.getBoundingClientRect();
  return { x: event.clientX - rect.left, y: event.clientY - rect.top };
}

function imagePoint(point) {
  return { x: (point.x - state.view.x) / state.view.scale, y: (point.y - state.view.y) / state.view.scale };
}

function normalizedPoint(point) {
  return {
    x: Math.max(0, Math.min(1, point.x / state.image.width)),
    y: Math.max(0, Math.min(1, point.y / state.image.height))
  };
}

function screenPoint(normalized) {
  return {
    x: state.view.x + normalized.x * state.image.width * state.view.scale,
    y: state.view.y + normalized.y * state.image.height * state.view.scale
  };
}

function drawMarker(ctx, point, color, label) {
  ctx.save();
  ctx.fillStyle = color;
  ctx.strokeStyle = "#fff";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(point.x, point.y, 7, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  if (label) {
    ctx.font = "700 10px system-ui";
    ctx.fillStyle = "#101820";
    ctx.fillText(label, point.x + 10, point.y + 4);
  }
  ctx.restore();
}

function drawFloor() {
  resizeFloorCanvas();
  const rect = floorCanvas.getBoundingClientRect();
  floorCtx.clearRect(0, 0, rect.width, rect.height);
  if (!state.image) return;
  floorCtx.drawImage(state.image, state.view.x, state.view.y, state.image.width * state.view.scale, state.image.height * state.view.scale);
  state.measurements.forEach((measurement, index) => {
    drawMarker(floorCtx, screenPoint({ x: measurement.floor_plan_x, y: measurement.floor_plan_y }), qualityColor(measurement.quality_label), String(index + 1));
  });
  if (state.selected) drawMarker(floorCtx, screenPoint(state.selected), "#101820", "Current");
  state.actionPoints.forEach((point) => drawMarker(floorCtx, screenPoint(point), "#1479d1", ""));
  if (state.actionPoints.length === 2) {
    const a = screenPoint(state.actionPoints[0]);
    const b = screenPoint(state.actionPoints[1]);
    floorCtx.strokeStyle = "#1479d1";
    floorCtx.lineWidth = 2;
    floorCtx.setLineDash([5, 4]);
    floorCtx.strokeRect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(a.x - b.x), Math.abs(a.y - b.y));
    floorCtx.setLineDash([]);
  }
}

function setMode(mode) {
  state.mode = mode;
  state.actionPoints = [];
  $$(".tool").forEach((tool) => tool.classList.toggle("active", tool.id === `${mode}Tool`));
  $("#floorHint").textContent = {
    locate: "Tap your current location on the plan.",
    pan: "Drag to pan. Pinch or use the mouse wheel to zoom.",
    scale: "Tap two points with a known real-world distance.",
    crop: "Tap two opposite corners of the area to keep."
  }[mode];
  drawFloor();
}

["locate", "pan", "scale", "crop"].forEach((mode) => $(`#${mode}Tool`).addEventListener("click", () => setMode(mode)));

floorCanvas.addEventListener("pointerdown", (event) => {
  floorCanvas.setPointerCapture(event.pointerId);
  state.pointers.set(event.pointerId, canvasPoint(event));
  state.dragStart = { point: canvasPoint(event), view: { ...state.view }, moved: false };
});

floorCanvas.addEventListener("pointermove", (event) => {
  if (!state.pointers.has(event.pointerId)) return;
  const previous = state.pointers.get(event.pointerId);
  const current = canvasPoint(event);
  state.pointers.set(event.pointerId, current);

  if (state.pointers.size === 2) {
    const points = [...state.pointers.values()];
    const other = points[0] === current ? points[1] : points[0];
    const previousDistance = Math.hypot(previous.x - other.x, previous.y - other.y);
    const currentDistance = Math.hypot(current.x - other.x, current.y - other.y);
    if (previousDistance > 0) zoomAt((currentDistance / previousDistance), { x: (current.x + other.x) / 2, y: (current.y + other.y) / 2 });
    state.dragStart.moved = true;
  } else if (state.mode === "pan" && state.dragStart) {
    state.view.x = state.dragStart.view.x + current.x - state.dragStart.point.x;
    state.view.y = state.dragStart.view.y + current.y - state.dragStart.point.y;
    state.dragStart.moved = true;
    drawFloor();
  }
});

floorCanvas.addEventListener("pointerup", (event) => {
  const point = canvasPoint(event);
  state.pointers.delete(event.pointerId);
  if (!state.image || state.dragStart?.moved || state.mode === "pan") return;
  const normalized = normalizedPoint(imagePoint(point));
  if (state.mode === "locate") {
    state.selected = normalized;
    $("#recordHint").textContent = `Location selected at ${(normalized.x * 100).toFixed(1)}%, ${(normalized.y * 100).toFixed(1)}%.`;
  } else {
    state.actionPoints.push(normalized);
    if (state.actionPoints.length === 2 && state.mode === "scale") $("#distanceDialog").showModal();
    if (state.actionPoints.length === 2 && state.mode === "crop") cropImage();
  }
  drawFloor();
});

floorCanvas.addEventListener("wheel", (event) => {
  event.preventDefault();
  zoomAt(event.deltaY < 0 ? 1.12 : 0.89, canvasPoint(event));
}, { passive: false });

function zoomAt(factor, center) {
  const oldScale = state.view.scale;
  const newScale = Math.max(0.05, Math.min(12, oldScale * factor));
  state.view.x = center.x - (center.x - state.view.x) * (newScale / oldScale);
  state.view.y = center.y - (center.y - state.view.y) * (newScale / oldScale);
  state.view.scale = newScale;
  drawFloor();
}

function canvasBlob(canvas) {
  return new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.9));
}

async function cropImage() {
  const [a, b] = state.actionPoints;
  const x = Math.round(Math.min(a.x, b.x) * state.image.width);
  const y = Math.round(Math.min(a.y, b.y) * state.image.height);
  const width = Math.round(Math.abs(a.x - b.x) * state.image.width);
  const height = Math.round(Math.abs(a.y - b.y) * state.image.height);
  if (width < 20 || height < 20) { toast("Crop area is too small."); state.actionPoints = []; return; }
  const canvas = document.createElement("canvas");
  canvas.width = width; canvas.height = height;
  canvas.getContext("2d").drawImage(state.image, x, y, width, height, 0, 0, width, height);
  await setImageFromBlob(await canvasBlob(canvas));
  setMode("locate");
  toast("Floor plan cropped.");
}

$("#rotateButton").addEventListener("click", async () => {
  if (!state.image) return;
  const canvas = document.createElement("canvas");
  canvas.width = state.image.height; canvas.height = state.image.width;
  const ctx = canvas.getContext("2d");
  ctx.translate(canvas.width, 0); ctx.rotate(Math.PI / 2); ctx.drawImage(state.image, 0, 0);
  await setImageFromBlob(await canvasBlob(canvas));
  toast("Floor plan rotated.");
});

$("#distanceForm").addEventListener("submit", (event) => {
  const [a, b] = state.actionPoints;
  if (!a || !b) return;
  const pixelDistance = Math.hypot((a.x - b.x) * state.image.width, (a.y - b.y) * state.image.height);
  state.plan.metersPerPixel = Number($("#distanceInput").value) / pixelDistance;
  storage.set("survey.plan", state.plan);
  updateScaleReadout();
  state.actionPoints = [];
  setMode("locate");
});

function updatePlanDimensions() {
  state.plan.widthM = Number($("#planWidth").value) || null;
  state.plan.lengthM = Number($("#planLength").value) || null;
  storage.set("survey.plan", state.plan);
  updateScaleReadout();
}

function updateScaleReadout() {
  const parts = [];
  if (state.plan.widthM && state.plan.lengthM) parts.push(`${state.plan.widthM} m x ${state.plan.lengthM} m`);
  if (state.plan.metersPerPixel) parts.push(`1 px = ${state.plan.metersPerPixel.toFixed(4)} m`);
  $("#scaleReadout").textContent = parts.join(" | ") || "Scale not calibrated";
}

["planWidth", "planLength"].forEach((id) => $(`#${id}`).addEventListener("change", updatePlanDimensions));

$("#recordButton").addEventListener("click", async () => {
  if (!state.image || !state.selected) {
    showPage("floor");
    toast("Tap your current location on the floor plan first.");
    return;
  }
  try {
    state.status = await api("/api/status");
    if (!state.status.connected || state.status.rssi == null) throw new Error("ESP32 is not connected to the target Wi-Fi.");
    $("#measurementDialog").showModal();
  } catch (error) { toast(error.message); }
});

$("#roomInput").addEventListener("change", () => {
  $("#customRoomLabel").hidden = $("#roomInput").value !== "Custom";
});

$("#measurementForm").addEventListener("submit", (event) => {
  event.preventDefault();
  const room = $("#roomInput").value === "Custom" ? ($("#customRoomInput").value || "Custom") : $("#roomInput").value;
  const measurement = {
    id: crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random()}`,
    timestamp: new Date().toISOString(),
    node_id: state.status.node_id || "ESP32-01",
    room_name: room,
    note: $("#noteInput").value.trim(),
    floor_plan_x: state.selected.x,
    floor_plan_y: state.selected.y,
    rssi: state.status.rssi,
    quality_label: state.status.quality_label,
    ssid: state.status.ssid,
    bssid: state.status.bssid,
    channel: state.status.channel
  };
  state.measurements.push(measurement);
  storage.set("survey.measurements", state.measurements);
  $("#measurementDialog").close();
  $("#noteInput").value = "";
  renderMeasurements();
  drawFloor();
  toast("Measurement point recorded.");
});

function renderMeasurements() {
  const rows = $("#measurementRows");
  rows.innerHTML = "";
  $("#measurementsEmpty").hidden = state.measurements.length > 0;
  state.measurements.slice().reverse().forEach((measurement) => {
    const row = document.createElement("tr");
    row.innerHTML = `<td></td><td><b></b><span class="quality-tag"></span></td><td></td><td></td><td><button class="delete-point" title="Delete point">&times;</button></td>`;
    row.children[0].textContent = measurement.room_name;
    row.querySelector("b").textContent = `${measurement.rssi} dBm`;
    row.querySelector(".quality-tag").textContent = measurement.quality_label;
    row.children[2].textContent = measurement.channel;
    row.children[3].textContent = new Date(measurement.timestamp).toLocaleString();
    row.querySelector("button").addEventListener("click", () => {
      if (!confirm("Delete this measurement point?")) return;
      state.measurements = state.measurements.filter((item) => item.id !== measurement.id);
      storage.set("survey.measurements", state.measurements);
      renderMeasurements(); drawFloor();
    });
    rows.append(row);
  });
}

$("#exportCsvButton").addEventListener("click", () => {
  if (!state.measurements.length) return toast("No measurements to export.");
  const keys = ["id", "timestamp", "node_id", "room_name", "note", "floor_plan_x", "floor_plan_y", "rssi", "quality_label", "ssid", "bssid", "channel"];
  const escape = (value) => `"${String(value ?? "").replaceAll('"', '""')}"`;
  const csv = [keys.join(","), ...state.measurements.map((item) => keys.map((key) => escape(item[key])).join(","))].join("\n");
  const link = document.createElement("a");
  link.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
  link.download = `wifi-survey-${new Date().toISOString().slice(0, 10)}.csv`;
  link.click();
  URL.revokeObjectURL(link.href);
});

function renderReport() {
  const values = state.measurements.map((item) => item.rssi);
  const average = values.length ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) : "--";
  $("#reportSummary").innerHTML = [
    ["Points", state.measurements.length],
    ["Average RSSI", average === "--" ? "--" : `${average} dBm`],
    ["Rooms", new Set(state.measurements.map((item) => item.room_name)).size]
  ].map(([label, value]) => `<div class="report-stat"><span>${label}</span><b>${value}</b></div>`).join("");

  const labels = ["Excellent", "Good", "Fair", "Weak", "Very Weak"];
  $("#qualityBars").innerHTML = labels.map((label) => {
    const count = state.measurements.filter((item) => item.quality_label === label).length;
    const percent = state.measurements.length ? count / state.measurements.length * 100 : 0;
    return `<div class="bar-row"><span>${label}</span><div class="bar-track"><div class="bar-fill" style="width:${percent}%;background:${qualityColor(label)}"></div></div><b>${count}</b></div>`;
  }).join("");

  const rect = reportCanvas.getBoundingClientRect();
  const dpr = devicePixelRatio || 1;
  reportCanvas.width = Math.round(rect.width * dpr);
  reportCanvas.height = Math.round(rect.height * dpr);
  reportCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
  reportCtx.clearRect(0, 0, rect.width, rect.height);
  if (!state.image) return;
  const scale = Math.min(rect.width / state.image.width, rect.height / state.image.height);
  const x = (rect.width - state.image.width * scale) / 2;
  const y = (rect.height - state.image.height * scale) / 2;
  reportCtx.drawImage(state.image, x, y, state.image.width * scale, state.image.height * scale);
  state.measurements.forEach((measurement, index) => drawMarker(reportCtx, {
    x: x + measurement.floor_plan_x * state.image.width * scale,
    y: y + measurement.floor_plan_y * state.image.height * scale
  }, qualityColor(measurement.quality_label), String(index + 1)));
}

$("#printButton").addEventListener("click", () => window.print());
window.addEventListener("resize", () => { drawFloor(); renderReport(); });

async function init() {
  $("#planWidth").value = state.plan.widthM || "";
  $("#planLength").value = state.plan.lengthM || "";
  updateScaleReadout();
  renderMeasurements();
  await loadPlanImage().catch(() => {});
  drawFloor();
  refreshStatus();
  setInterval(refreshStatus, 2000);
}

init();
