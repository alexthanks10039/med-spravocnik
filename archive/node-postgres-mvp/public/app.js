const views = document.querySelectorAll(".view");
const title = document.querySelector("#title");
const navButtons = document.querySelectorAll(".nav button");
const ragResults = document.querySelector("#ragResults");
const ragMeta = document.querySelector("#ragMeta");
const apiStatus = document.querySelector("#apiStatus");

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
  };
});

function setApiStatus(mode, text) {
  apiStatus.className = `status status-${mode}`;
  apiStatus.querySelector("span").textContent = text;
}

async function checkHealth() {
  try {
    const response = await fetch("/api/health");
    const data = await response.json();
    setApiStatus(data.status === "ok" ? "ok" : "error", data.status === "ok" ? "API подключен" : "API недоступен");
  } catch {
    setApiStatus("error", "Нет ответа от API");
  }
}

function renderEmptyState(text) {
  ragResults.innerHTML = `<div class="empty-state">${text}</div>`;
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

  try {
    const response = await fetch(`/api/rag?${params.toString()}`);
    const data = await response.json();
    const items = data.items || [];

    ragMeta.textContent = items.length ? `Найдено: ${items.length}` : "Совпадений нет";

    if (!items.length) {
      renderEmptyState("По этому запросу ничего не найдено.");
      return;
    }

    ragResults.innerHTML = items.map((item) => `
      <article class="rag-card">
        <small>${label(item.space)}</small>
        <h3>${item.title}</h3>
        <p>${item.summary}</p>
        <div class="tags">${item.tags.map((tag) => `<span>${tag}</span>`).join("")}</div>
      </article>
    `).join("");
  } catch {
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
    result.textContent = data.value ? `${data.value} ${data.unit} • ${data.formula}` : (data.message || "Нет данных");
  } catch {
    result.textContent = "Не удалось выполнить расчёт eGFR.";
  }
};

checkHealth();
renderEmptyState("Введите запрос, чтобы показать материалы библиотеки.");
