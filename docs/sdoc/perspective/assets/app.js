import "https://cdn.jsdelivr.net/npm/@perspective-dev/viewer@5.3.0/dist/cdn/perspective-viewer.js";
import "https://cdn.jsdelivr.net/npm/@perspective-dev/viewer-datagrid@5.3.0/dist/cdn/perspective-viewer-datagrid.js";
import "https://cdn.jsdelivr.net/npm/@perspective-dev/viewer-charts@5.3.0/dist/cdn/perspective-viewer-charts.js";
import perspective from "https://cdn.jsdelivr.net/npm/@perspective-dev/client@5.3.0/dist/cdn/perspective.js";

const TABLE_NAME = "strictdoc";
const STORAGE_KEY = "sdoc-perspective/viewer-config/v1";
const DEFAULT_CONFIG = {
  table: TABLE_NAME,
  plugin: "Datagrid",
  theme: "Pro Dark",
  settings: true,
  columns: [
    "UID",
    "TITLE",
    "_NODE_TYPE",
    "DEPTH",
    "STATUS",
    "DOCUMENT_TITLE",
    "RELATION_COUNT",
    "RELATION_ROLES",
  ],
};

const viewer = document.querySelector("#viewer");
const loading = document.querySelector("#loading");
const error = document.querySelector("#error");
const statusText = document.querySelector("#status-text");
let acceptConfigUpdates = false;
let saveInFlight = Promise.resolve();

function readSavedConfig() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved === null ? null : JSON.parse(saved);
  } catch (storageError) {
    console.warn("Cannot read saved Perspective view", storageError);
    return null;
  }
}

function forgetSavedConfig() {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch (storageError) {
    console.warn("Cannot remove saved Perspective view", storageError);
  }
}

async function saveConfig() {
  const token = await viewer.save();
  localStorage.setItem(STORAGE_KEY, JSON.stringify(token));
}

viewer.addEventListener("perspective-config-update", () => {
  if (!acceptConfigUpdates) {
    return;
  }
  saveInFlight = saveInFlight.then(saveConfig).catch((saveError) => {
    console.warn("Cannot save Perspective view", saveError);
  });
});

function updateStats(metadata) {
  document.querySelector("#node-count").textContent =
    metadata.nodes.toLocaleString();
  document.querySelector("#relation-count").textContent =
    metadata.relations.toLocaleString();
  document.querySelector("#document-count").textContent =
    metadata.documents.toLocaleString();
  document.querySelector("#export-duration").textContent =
    `${metadata.durationMs.toLocaleString()} ms`;
}

async function loadViewer() {
  const response = await fetch("/api/data", { cache: "no-store" });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      payload.detail || `data request failed: ${response.status}`,
    );
  }
  if (payload.schema !== "sdoc-perspective/1" || !payload.rows?.length) {
    throw new Error("server returned an empty or incompatible dataset");
  }

  updateStats(payload.export);
  await customElements.whenDefined("perspective-viewer");
  const worker = await perspective.worker();
  await worker.table(payload.rows, { name: TABLE_NAME });
  await viewer.load(worker);

  const saved = readSavedConfig();
  let restored = false;
  if (saved !== null) {
    try {
      await viewer.restore(
        { ...saved, table: TABLE_NAME, theme: "Pro Dark" },
        { suppress_errors: true },
      );
      restored = true;
    } catch (restoreError) {
      console.warn("Saved Perspective view is incompatible", restoreError);
      forgetSavedConfig();
    }
  }
  if (!restored) {
    await viewer.restore(DEFAULT_CONFIG);
  }

  acceptConfigUpdates = true;
  loading.hidden = true;
  statusText.textContent = restored
    ? "saved view restored"
    : "fresh view ready";
  document.documentElement.dataset.ready = "true";
}

loadViewer().catch((loadError) => {
  loading.hidden = true;
  error.hidden = false;
  error.textContent = `Perspective could not load the canon.\n\n${loadError.message}`;
  statusText.textContent = "load failed";
  document.documentElement.dataset.error = "true";
  console.error(loadError);
});
