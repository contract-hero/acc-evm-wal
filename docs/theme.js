// Palette toggle — three-state: system (no override) → light → dark → system.
// Reads localStorage `acc-evm-wal-theme` if set; otherwise honors
// prefers-color-scheme via the CSS @media query (no `data-theme` attribute).

(function () {
  const STORAGE_KEY = "acc-evm-wal-theme";
  const root = document.documentElement;

  function apply(theme) {
    if (theme === "light" || theme === "dark") {
      root.setAttribute("data-theme", theme);
    } else {
      root.removeAttribute("data-theme");
    }
  }

  // 1. Apply stored preference on first paint (script is in <head>, before body).
  try {
    apply(localStorage.getItem(STORAGE_KEY));
  } catch (_) {
    /* localStorage disabled — fall through to prefers-color-scheme. */
  }

  // 2. Wire the toggle once the DOM is ready.
  document.addEventListener("DOMContentLoaded", function () {
    const btn = document.querySelector(".theme-toggle");
    if (!btn) return;
    btn.addEventListener("click", function () {
      const current = root.getAttribute("data-theme");
      const next = current === "dark" ? "light" : current === "light" ? null : "dark";
      apply(next);
      try {
        if (next) {
          localStorage.setItem(STORAGE_KEY, next);
        } else {
          localStorage.removeItem(STORAGE_KEY);
        }
      } catch (_) {
        /* ignore */
      }
    });
  });
})();
