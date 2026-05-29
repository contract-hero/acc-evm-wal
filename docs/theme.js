// Two-state palette toggle (light ↔ dark). System preference is the
// auto-derived first-paint default and stays in sync until the reader
// overrides via the toggle; once stored in localStorage, the override
// is what wins on every subsequent visit.

(function () {
  const STORAGE_KEY = "acc-evm-wal-theme";
  const root = document.documentElement;
  const mql = window.matchMedia("(prefers-color-scheme: dark)");

  function readStored() {
    try {
      return localStorage.getItem(STORAGE_KEY);
    } catch (_) {
      return null;
    }
  }
  function writeStored(theme) {
    try {
      localStorage.setItem(STORAGE_KEY, theme);
    } catch (_) {
      /* private mode — silently fall through */
    }
  }
  function apply(theme) {
    root.setAttribute("data-theme", theme);
  }

  // Resolve the active theme on first paint — script is in <head> before
  // <body>, so this runs before the browser commits any pixels.
  apply(readStored() || (mql.matches ? "dark" : "light"));

  // Stay in sync with system changes ONLY while the reader hasn't overridden.
  mql.addEventListener("change", function (e) {
    if (!readStored()) apply(e.matches ? "dark" : "light");
  });

  // Wire the toggle once the body has parsed.
  document.addEventListener("DOMContentLoaded", function () {
    const btn = document.querySelector(".theme-toggle");
    if (!btn) return;
    btn.addEventListener("click", function () {
      const next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
      apply(next);
      writeStored(next);
    });
  });
})();
