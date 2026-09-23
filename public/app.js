const views = document.querySelectorAll(".view");
const title = document.querySelector("#title");
const navButtons = document.querySelectorAll(".nav button");
const ragResults = document.querySelector("#ragResults");
const ragMeta = document.querySelector("#ragMeta");
const apiStatus = document.querySelector("#apiStatus");
let ragRequestId = 0;

navButtons.forEach((button) => {
  button.onclick = () => {
    navButtons.forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    views.forEach((view) => view.classList.remove("active"));
    document.querySelector(`#${button.dataset.view}`).classList.add("active");
    title.textContent = button.textContent;

    if (button.dataset.view === "rag") {
      loadRag();
    }
    if (button.dataset.view === "database" && dbState.token) {
      loadCollections();
    }
  };
});

function setApiStatus(mode, text) {
  apiStatus.className = `status status-${mode}`;
  apiStatus.querySelector("span").textContent = text;
}

async function checkHealth() {
  try {
    const response = await fetch("/api/health");
    if (!response.ok) throw new Error(`Health request failed: ${response.status}`);
    const data = await response.json();
    setApiStatus(data.status === "ok" ? "ok" : "error", data.status === "ok" ? "API подключен" : "API недоступен");
  } catch {
    setApiStatus("error", "Нет ответа от API");
  }
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function renderEmptyState(text) {
  ragResults.replaceChildren();
  const state = document.createElement("div");
  state.className = "empty-state";
  state.textContent = text;
  ragResults.appendChild(state);
}

function label(space) {
  return {
    commercial: "Коммерческое",
    development: "Разработка",
    content: "Контент"
  }[space] || space;
}

async function loadRag() {
  const q = document.querySelector("#ragQuery").value;
  const space = document.querySelector("#ragSpace").value;
  const params = new URLSearchParams({ q });

  if (space) {
    params.set("space", space);
  }

  ragMeta.textContent = "Загрузка...";
  renderEmptyState("Ищем релевантные материалы...");

  const requestId = ++ragRequestId;
  try {
    const response = await fetch(`/api/rag?${params.toString()}`);
    if (!response.ok) throw new Error(`RAG request failed: ${response.status}`);
    const data = await response.json();
    if (requestId !== ragRequestId) return;
    const items = Array.isArray(data.items) ? data.items : [];

    ragMeta.textContent = items.length ? `Найдено: ${items.length}` : "Совпадений нет";

    if (!items.length) {
      renderEmptyState("По этому запросу ничего не найдено.");
      return;
    }

    ragResults.innerHTML = items.map((item) => `
      <article class="rag-card">
        <small>${escapeHtml(label(item.space))}</small>
        <h3>${escapeHtml(item.title)}</h3>
        <p>${escapeHtml(item.summary)}</p>
        <div class="tags">${(Array.isArray(item.tags) ? item.tags : []).map((tag) => `<span>${escapeHtml(tag)}</span>`).join("")}</div>
      </article>
    `).join("");
  } catch {
    if (requestId !== ragRequestId) return;
    ragMeta.textContent = "Ошибка запроса";
    renderEmptyState("Не удалось загрузить RAG-результаты.");
  }
}

document.querySelector("#ragQuery").oninput = loadRag;
document.querySelector("#ragSpace").onchange = loadRag;

document.querySelector("#searchButton").onclick = () => {
  document.querySelector("#ragQuery").value = document.querySelector("#globalSearch").value;
  document.querySelector('button[data-view="rag"]').click();
};

function bmiLabel(category) {
  return {
    low: "ниже нормы",
    normal: "норма",
    high: "избыточная масса",
    obesity: "ожирение"
  }[category] || category;
}

document.querySelector("#calculate").onclick = async () => {
  const result = document.querySelector("#calcResult");
  result.textContent = "Считаем BMI...";

  try {
    const response = await fetch("/api/calculators/bmi", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        weightKg: Number(document.querySelector("#weight").value),
        heightCm: Number(document.querySelector("#height").value)
      })
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.message || `BMI request failed: ${response.status}`);
    result.textContent = data.value ? `${data.value} ${data.unit} • ${bmiLabel(data.category)}` : (data.message || "Нет данных");
  } catch {
    result.textContent = "Не удалось выполнить расчёт BMI.";
  }
};

document.querySelector("#calculateEgfr").onclick = async () => {
  const result = document.querySelector("#egfrResult");
  result.textContent = "Считаем eGFR...";

  try {
    const response = await fetch("/api/calculators/egfr", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        age: Number(document.querySelector("#egfrAge").value),
        creatinine: Number(document.querySelector("#egfrCreatinine").value),
        sex: document.querySelector("#egfrSex").value
      })
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.message || `eGFR request failed: ${response.status}`);
    result.textContent = data.value ? `${data.value} ${data.unit} • ${data.formula}` : (data.message || "Нет данных");
  } catch {
    result.textContent = "Не удалось выполнить расчёт eGFR.";
  }
};

checkHealth();
renderEmptyState("Введите запрос, чтобы показать материалы библиотеки.");


const dbState = { token: localStorage.getItem("med_admin_token") || "", collectionId: "", page: 1, pageSize: 50, total: 0 };
const db = (id) => document.querySelector(id);

function dbHeaders() {
  return { "Content-Type": "application/json", ...(dbState.token ? { Authorization: `Bearer ${dbState.token}` } : {}) };
}

async function dbFetch(path, options = {}) {
  const response = await fetch(path, { ...options, headers: { ...dbHeaders(), ...(options.headers || {}) } });
  const data = await response.json().catch(() => ({}));
  if (response.status === 401 || response.status === 403) {
    dbState.token = "";
    localStorage.removeItem("med_admin_token");
    dbWorkspace(false);
  }
  if (!response.ok) throw new Error(data.message || `Database request failed: ${response.status}`);
  return data;
}

function dbWorkspace(authorized) {
  db("#dbLogin").hidden = authorized;
  db("#dbWorkspace").hidden = !authorized;
}

async function dbLogin() {
  const meta = db("#dbLoginMeta");
  meta.textContent = "Входим...";
  try {
    const data = await dbFetch("/api/auth/login", {
      method: "POST",
      body: JSON.stringify({ email: db("#dbEmail").value, password: db("#dbPassword").value })
    });
    if (data.user?.role !== "ADMIN") throw new Error("Для Data Store нужна роль ADMIN.");
    dbState.token = data.token;
    localStorage.setItem("med_admin_token", data.token);
    dbWorkspace(true);
    meta.textContent = "Авторизация успешна.";
    await loadCollections();
  } catch (error) {
    meta.textContent = error.message || "Не удалось войти.";
  }
}

async function loadCollections() {
  try {
    const collections = await dbFetch("/api/data/collections");
    const select = db("#dbCollection");
    select.replaceChildren();
    if (!collections.length) {
      const option = document.createElement("option");
      option.textContent = "Коллекций нет";
      option.value = "";
      select.appendChild(option);
      dbState.collectionId = "";
      renderDbRows([]);
      return;
    }
    collections.forEach((collection) => {
      const option = document.createElement("option");
      option.value = collection.id;
      option.textContent = `${collection.name} • ${collection._count.records} записей`;
      select.appendChild(option);
    });
    if (!collections.some((item) => item.id === dbState.collectionId)) dbState.collectionId = collections[0].id;
    select.value = dbState.collectionId;
    dbState.page = 1;
    await loadRecords();
  } catch (error) {
    db("#dbStats").textContent = error.message || "Не удалось загрузить коллекции.";
  }
}

async function loadRecords() {
  if (!dbState.collectionId) return;
  const params = new URLSearchParams({
    page: String(dbState.page),
    pageSize: String(dbState.pageSize),
    q: db("#dbQuery").value.trim()
  });
  try {
    const data = await dbFetch(`/api/data/collections/${encodeURIComponent(dbState.collectionId)}/records?${params}`);
    dbState.total = data.total;
    db("#dbStats").textContent = `${data.total} записей • ${data.pages || 1} страниц`;
    db("#dbPage").textContent = `Страница ${data.page} из ${Math.max(data.pages, 1)}`;
    db("#dbPrev").disabled = data.page <= 1;
    db("#dbNext").disabled = data.page >= data.pages;
    renderDbRows(data.items);
  } catch (error) {
    db("#dbStats").textContent = error.message || "Не удалось загрузить записи.";
    renderDbRows([]);
  }
}

function renderDbRows(items) {
  const tbody = db("#dbRows");
  tbody.replaceChildren();
  if (!items.length) {
    const row = document.createElement("tr");
    row.innerHTML = '<td colspan="6" class="empty-cell">Записей нет</td>';
    tbody.appendChild(row);
    return;
  }
  items.forEach((item) => {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td><code>${escapeHtml(item.externalId)}</code></td>
      <td>${escapeHtml(item.title || "—")}</td>
      <td>${escapeHtml(item.recordType || "object")}</td>
      <td>${escapeHtml(item.version)}</td>
      <td>${escapeHtml(new Date(item.updatedAt).toLocaleString("ru-RU"))}</td>
      <td><button class="small-button" data-record-id="${escapeHtml(item.id)}">JSON</button></td>
    `;
    row.querySelector("button").onclick = () => openRecord(item.id);
    tbody.appendChild(row);
  });
}

async function openRecord(recordId) {
  try {
    const item = await dbFetch(`/api/data/collections/${encodeURIComponent(dbState.collectionId)}/records/${encodeURIComponent(recordId)}`);
    db("#dbRecordPanel").hidden = false;
    db("#dbRecordTitle").textContent = item.title || item.externalId;
    db("#dbRecordMeta").textContent = `${item.recordType || "object"} • v${item.version} • ${item.status}`;
    db("#dbRecordJson").textContent = JSON.stringify(item.payload, null, 2);
    db("#dbRecordPanel").scrollIntoView({ behavior: "smooth", block: "start" });
  } catch (error) {
    db("#dbRecordMeta").textContent = error.message || "Не удалось открыть запись.";
  }
}


async function exportDbCollection() {
  try {
    const format = db("#dbExportFormat").value;
    const response = await fetch(`/api/data/collections/${encodeURIComponent(dbState.collectionId)}/export?format=${encodeURIComponent(format)}`, {
      headers: dbHeaders()
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.message || `Export failed: ${response.status}`);
    }
    const isNdjson = format === "ndjson";
    const body = await response.text();
    const blob = new Blob([body], { type: isNdjson ? "application/x-ndjson;charset=utf-8" : "application/json;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${dbState.collectionId}-export.${isNdjson ? "ndjson" : "json"}`;
    link.click();
    URL.revokeObjectURL(url);
  } catch (error) {
    alert(error.message || "Не удалось экспортировать коллекцию.");
  }
}

function detectClientPayload(raw, filename = "") {
  const text = raw.trim();
  if (!text) throw new Error("Файл пустой.");
  if (/\.(jsonl|ndjson)$/i.test(filename) || (!text.startsWith("[") && text.includes("\n") && text.split("\n").filter(Boolean).every((line) => line.trim().startsWith("{")))) {
    const items = text.split("\n").map((line) => line.trim()).filter(Boolean).map((line, index) => {
      try { return JSON.parse(line); } catch { throw new Error(`Ошибка JSON в строке ${index + 1}`); }
    });
    return items;
  }
  try { return JSON.parse(text); } catch { throw new Error("Некорректный JSON/NDJSON."); }
}

function showImportPreview() {
  const preview = db("#dbPreview");
  try {
    const payload = detectClientPayload(db("#dbPayload").value, db("#dbFilename").value);
    const sample = Array.isArray(payload) ? payload.slice(0, 3) : payload;
    const count = Array.isArray(payload) ? payload.length : 1;
    preview.hidden = false;
    preview.innerHTML = `<strong>Структура распознана</strong><br>Записей: ${count}<br><pre>${escapeHtml(JSON.stringify(sample, null, 2))}</pre>`;
  } catch (error) {
    preview.hidden = false;
    preview.textContent = error.message || "Не удалось распознать структуру.";
  }
}

async function importDbPayload() {
  const meta = db("#dbImportMeta");
  meta.textContent = "Импортируем...";
  try {
    const filename = db("#dbFilename").value.trim() || db("#dbFile").files[0]?.name || undefined;
    const payload = detectClientPayload(db("#dbPayload").value, filename || "");
    const result = await dbFetch(`/api/data/collections/${encodeURIComponent(dbState.collectionId)}/import`, {
      method: "POST",
      body: JSON.stringify({ filename, data: payload })
    });
    meta.textContent = `Готово: ${result.imported}/${result.total}, ошибок: ${result.rejected}.`;
    await loadCollections();
  } catch (error) {
    meta.textContent = error.message || "Ошибка импорта. Проверьте JSON.";
  }
}

async function createDbCollection() {
  const key = prompt("Ключ коллекции (латиница, цифры, _ или -):", "medical-mcp");
  if (!key) return;
  const name = prompt("Название коллекции:", "Medical MCP");
  if (!name) return;
  try {
    await dbFetch("/api/data/collections", {
      method: "POST",
      body: JSON.stringify({ key, name })
    });
    await loadCollections();
  } catch (error) {
    alert(error.message || "Не удалось создать коллекцию.");
  }
}


db("#dbLoginButton").onclick = dbLogin;
db("#dbPassword").onkeydown = (event) => { if (event.key === "Enter") dbLogin(); };
db("#dbCollection").onchange = async (event) => { dbState.collectionId = event.target.value; dbState.page = 1; await loadRecords(); };
db("#dbRefresh").onclick = loadCollections;
db("#dbQuery").oninput = (() => {
  let timer;
  return () => { clearTimeout(timer); timer = setTimeout(() => { dbState.page = 1; loadRecords(); }, 250); };
})();
db("#dbPrev").onclick = () => { if (dbState.page > 1) { dbState.page--; loadRecords(); } };
db("#dbNext").onclick = () => { dbState.page++; loadRecords(); };
db("#dbImportToggle").onclick = () => { db("#dbImportPanel").hidden = !db("#dbImportPanel").hidden; };\ndb("#dbExport").onclick = exportDbCollection;
db("#dbImport").onclick = importDbPayload;
db("#dbPreviewButton").onclick = showImportPreview;
db("#dbFile").onchange = async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  db("#dbFilename").value = file.name;
  try {
    db("#dbPayload").value = await file.text();
    showImportPreview();
  } catch {
    db("#dbImportMeta").textContent = "Не удалось прочитать файл.";
  }
};
db("#dbCreateCollection").onclick = createDbCollection;

if (dbState.token) {
  dbWorkspace(true);
  if (document.querySelector("#database").classList.contains("active")) loadCollections();
} else {
  dbWorkspace(false);
}
