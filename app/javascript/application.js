// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

document.addEventListener("turbo:load", () => {
  const form = document.querySelector("form[data-loading-target]");
  if (!form) return;

  const loading = document.querySelector("[data-loading-indicator]");
  const results = document.querySelector("[data-results-container]");
  const trending = document.querySelector("[data-trending-section]");
  const frame = document.getElementById("results");
  const budgetToggle = document.querySelector("[data-budget-toggle]");
  const budgetPanel = document.querySelector("[data-budget-panel]");

  form.addEventListener("turbo:submit-start", () => {
    if (loading) loading.classList.remove("hidden");
    if (results) results.classList.add("opacity-60");
    if (trending) trending.classList.add("hidden");
    if (frame) {
      frame.innerHTML =
        '<div class="mx-auto max-w-3xl text-center text-slate-300 sm:text-slate-500">Searching…</div>';
    }
  });

  form.addEventListener("turbo:submit-end", () => {
    if (loading) loading.classList.add("hidden");
    if (results) results.classList.remove("opacity-60");
    if (trending) trending.classList.remove("hidden");
  });

  if (budgetToggle && budgetPanel) {
    budgetToggle.addEventListener("click", () => {
      budgetPanel.classList.toggle("hidden");
    });
  }
});

const applyStoreFilter = (store) => {
  const filterButtons = document.querySelectorAll("[data-store-filter]");
  const cards = document.querySelectorAll("[data-product-card]");
  const count = document.querySelector("[data-results-count]");

  if (!cards.length) return;

  cards.forEach((card) => {
    const cardStore = card.getAttribute("data-store");
    if (store === "all" || cardStore === store) {
      card.classList.remove("hidden");
    } else {
      card.classList.add("hidden");
    }
  });

  const visible = Array.from(cards).filter((card) => !card.classList.contains("hidden"));
  if (count) count.textContent = `${visible.length}`;

  filterButtons.forEach((btn) =>
    btn.classList.remove("bg-white", "text-slate-900", "sm:bg-slate-900", "sm:text-white")
  );
  const active = Array.from(filterButtons).find(
    (btn) => btn.getAttribute("data-store-filter") === store
  );
  if (active) {
    active.classList.add("bg-white", "text-slate-900", "sm:bg-slate-900", "sm:text-white");
  }
};

document.addEventListener("click", (event) => {
  const target = event.target.closest("[data-store-filter]");
  if (!target) return;
  const store = target.getAttribute("data-store-filter");
  applyStoreFilter(store);
});

document.addEventListener("turbo:load", () => applyStoreFilter("all"));
document.addEventListener("turbo:frame-load", () => {
  document
    .querySelectorAll("[data-product-card].hidden")
    .forEach((card) => card.classList.remove("hidden"));
  applyStoreFilter("all");
});
