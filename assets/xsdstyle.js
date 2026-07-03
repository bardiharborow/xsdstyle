/* =========================================================================
   xsdstyle.js - progressive enhancement only.

   The generated HTML is complete without this file. This script only adds
   client-side affordances: filtering, copy links, disclosure controls, doc
   clamp toggles, theme preference, scroll-spy, and hash-target focus.

   Every node access is guarded. The search index is derived from rendered DOM,
   and localized runtime strings come from #xsdoc-i18n when present.
   ========================================================================= */
(() => {
  "use strict";

  const doc = document;
  const root = doc.documentElement;
  const prefersReduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

  const sel = {
    component: ".cmp",
    docBlock: ".doc.is-clampable",
    docBody: ".doc__body",
    docToggle: ".doc__toggle",
    filterInput: "#nav-filter-input",
    filterNote: ".nav-result-note",
    filterWrap: ".nav-search",
    kindLabel: ".kind",
    navClear: ".nav-clear",
    navGroup: ".nav-group",
    navGroupCount: ".nav-group__count",
    navGroupHead: ".nav-group__head",
    navHit: ".nav-link__hit",
    navLink: ".nav-link",
    swappableLabel: ".iconbtn__label",
    themeToggle: ".theme-toggle",
  };

  const $ = (selector, ctx = doc) => ctx?.querySelector(selector) ?? null;
  const $$ = (selector, ctx = doc) => (ctx ? [...ctx.querySelectorAll(selector)] : []);
  const on = (el, event, handler, options) => el?.addEventListener(event, handler, options);
  const normalize = (value) => (value ?? "").toLowerCase().normalize("NFKD");
  const escapeCss = (value) =>
    window.CSS?.escape ? CSS.escape(value) : (value ?? "").replace(/[^a-zA-Z0-9_-]/g, "\\$&");

  const i18n = readJson("#xsdoc-i18n");
  const text = (key, fallback) => (typeof i18n[key] === "string" ? i18n[key] : fallback);
  const formatCount = (message, count) => {
    const value = String(message);
    return /\{(?:n|count)\}/.test(value) ? value.replace(/\{(?:n|count)\}/g, count) : `${count} ${value}`;
  };

  function readJson(selector) {
    try {
      const el = $(selector);
      return el ? JSON.parse(el.textContent) || {} : {};
    } catch (e) {
      return {};
    }
  }

  function buildComponentIndex() {
    return $$(sel.component).map((el) => {
      const { name = "", clark = "", kind = "", doc: docText = "" } = el.dataset;
      const kindLabel = $(sel.kindLabel, el)?.textContent ?? "";

      return {
        el,
        id: el.id,
        name: normalize(name),
        meta: normalize(`${clark} ${kind} ${kindLabel} ${docText}`),
        navLink: el.id ? $(`${sel.navLink}[href="#${escapeCss(el.id)}"]`) : null,
      };
    });
  }

  function setHidden(el, hidden) {
    if (el) el.hidden = hidden;
  }

  function setExpanded(button, expanded) {
    if (button) button.setAttribute("aria-expanded", String(expanded));
  }

  function setButtonLabel(button, label) {
    const target = $(sel.swappableLabel, button);
    if (target && label) target.textContent = label;
  }

  function currentTheme() {
    return root.dataset.theme || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
  }

  function setupThemeToggle() {
    const button = $(sel.themeToggle);
    if (!button) return;

    const reflect = () => button.setAttribute("aria-pressed", String(currentTheme() === "dark"));
    reflect();

    on(button, "click", () => {
      const next = currentTheme() === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      try {
        localStorage.setItem("xsdstyle-theme", next);
      } catch (e) {
        /* Storage may be blocked; the session theme still applies. */
      }
      reflect();
    });
  }

  function setupNavGroups(groups) {
    for (const group of groups) {
      const head = $(sel.navGroupHead, group);
      const count = $(sel.navGroupCount, group);

      if (count && !count.dataset.total) count.dataset.total = count.textContent.trim();

      on(head, "click", () => {
        const collapsed = group.classList.toggle("is-collapsed");
        setExpanded(head, !collapsed);
      });
    }
  }

  function resetFilter(components, groups, note) {
    for (const component of components) {
      setHidden(component.el, false);
      setHidden(component.navLink, false);
      setHidden($(sel.navHit, component.navLink), true);
    }

    for (const group of groups) {
      setHidden(group, false);
      const count = $(sel.navGroupCount, group);
      if (count) count.textContent = count.dataset.total ?? count.textContent;
    }

    if (note) {
      note.hidden = true;
      note.textContent = "";
    }
  }

  function revealNavGroup(group) {
    if (!group.classList.contains("is-collapsed")) return;

    group.classList.remove("is-collapsed");
    setExpanded($(sel.navGroupHead, group), true);
  }

  function updateGroupCounts(groups) {
    for (const group of groups) {
      const shown = $$(sel.navLink, group).filter((link) => !link.hidden).length;
      setHidden(group, shown === 0);

      const count = $(sel.navGroupCount, group);
      if (count) count.textContent = shown;

      revealNavGroup(group);
    }
  }

  function setupFilter(components, groups) {
    const wrap = $(sel.filterWrap);
    const input = $(sel.filterInput);
    const note = $(sel.filterNote);
    const clearButton = $(sel.navClear);
    if (!input) return;

    const run = () => {
      const raw = input.value.trim();
      const query = normalize(raw);
      if (wrap) wrap.dataset.hasValue = raw ? "true" : "false";

      if (!query) {
        resetFilter(components, groups, note);
        return;
      }

      let visible = 0;
      for (const component of components) {
        const nameHit = component.name.includes(query);
        const metaHit = component.meta.includes(query);
        const show = nameHit || metaHit;

        setHidden(component.el, !show);
        setHidden(component.navLink, !show);
        setHidden($(sel.navHit, component.navLink), !(metaHit && !nameHit));
        if (show) visible++;
      }

      updateGroupCounts(groups);

      if (note) {
        note.hidden = false;
        note.textContent = formatCount(text("filterResults", "components shown"), visible);
      }
    };

    const debouncedRun = debounce(run, 80);
    on(input, "input", debouncedRun);
    on(clearButton, "click", () => {
      input.value = "";
      run();
      input.focus();
    });

    setupFilterShortcuts(input, run);
    if (input.value.trim()) run();
  }

  function debounce(fn, wait) {
    let timer;
    return () => {
      clearTimeout(timer);
      timer = setTimeout(fn, wait);
    };
  }

  function setupFilterShortcuts(input, reset) {
    on(doc, "keydown", (event) => {
      const active = doc.activeElement;
      const typing = /^(INPUT|TEXTAREA|SELECT)$/.test(active?.tagName ?? "");

      if (event.key === "/" && !typing) {
        event.preventDefault();
        input.focus();
        input.select();
        return;
      }

      if (event.key === "Escape" && active === input) {
        if (input.value) {
          input.value = "";
          reset();
        } else {
          input.blur();
        }
      }
    });
  }

  function copyFallback(value) {
    const textarea = doc.createElement("textarea");
    textarea.value = value;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    doc.body.appendChild(textarea);
    textarea.select();

    let ok = false;
    try {
      ok = doc.execCommand("copy");
    } catch (e) {
      ok = false;
    }

    doc.body.removeChild(textarea);
    return ok;
  }

  async function copyText(value) {
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value);
        return true;
      }
    } catch (e) {
      /* Fall through to the execCommand path. */
    }

    return copyFallback(value);
  }

  function announceCopy(message) {
    const live = $("#copy-status");
    if (live) live.textContent = message;
  }

  function setupCopyLinks() {
    for (const button of $$("[data-copy-link]")) {
      on(button, "click", () => {
        const id = button.getAttribute("data-copy-link");
        const url = `${location.origin}${location.pathname}${location.search}#${id}`;

        copyText(url).then((ok) => {
          if (!ok) {
            announceCopy(text("copyFailed", "Copy failed"));
            return;
          }

          announceCopy(text("copyOk", "Link copied"));
          history.replaceState(null, "", `#${id}`);
          button.classList.add("is-copied");
          setTimeout(() => button.classList.remove("is-copied"), 1400);
        });
      });
    }
  }

  function disclosureSelector(scope) {
    return scope && scope !== "all"
      ? `details.disclosure[data-kind-block="${escapeCss(scope)}"]`
      : "details.disclosure[data-kind-block]";
  }

  function setupDisclosureToggles() {
    for (const button of $$("[data-toggle-all]")) {
      on(button, "click", () => {
        const scope = button.getAttribute("data-toggle-all");
        const open = button.getAttribute("data-state") !== "open";

        for (const detail of $$(disclosureSelector(scope))) detail.open = open;
        if (scope === "all" || scope === "doc") {
          for (const block of $$(sel.docBlock)) setDocClamp(block, !open);
        }

        button.setAttribute("data-state", open ? "open" : "closed");
        setButtonLabel(button, open ? button.dataset.labelCollapse : button.dataset.labelExpand);
      });
    }
  }

  function docToggleFor(block) {
    const inside = $(sel.docToggle, block);
    if (inside) return inside;

    const next = block.nextElementSibling;
    return next?.classList?.contains("doc__toggle") ? next : null;
  }

  function setDocClamp(block, clamped) {
    block.classList.toggle("is-clamped", clamped);

    const button = docToggleFor(block);
    if (button) button.textContent = clamped ? (button.dataset.more ?? "") : (button.dataset.less ?? "");
  }

  function setupDocClamps() {
    for (const block of $$(sel.docBlock)) {
      const body = $(sel.docBody, block) ?? block;
      const button = docToggleFor(block);
      if (!button) continue;

      block.classList.add("is-clamped");
      if (body.scrollHeight - body.clientHeight <= 4) {
        block.classList.remove("is-clamped", "is-clampable");
        button.hidden = true;
        continue;
      }

      button.hidden = false;
      setDocClamp(block, true);
      on(button, "click", () => setDocClamp(block, !block.classList.contains("is-clamped")));
    }
  }

  function setupScrollSpy(components) {
    if (!("IntersectionObserver" in window) || !components.length) return;

    const byElement = new Map(components.map((component) => [component.el, component]));
    let current = null;

    const setActive = (link) => {
      if (current === link) return;

      current?.classList.remove("is-active");
      current?.removeAttribute("aria-current");
      current = link ?? null;

      if (current) {
        current.classList.add("is-active");
        current.setAttribute("aria-current", "true");
      }
    };

    const observer = new IntersectionObserver(
      (entries) => {
        const best = entries
          .filter((entry) => entry.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0];
        const component = best && byElement.get(best.target);
        if (component?.navLink) setActive(component.navLink);
      },
      { rootMargin: "-15% 0px -70% 0px", threshold: 0 },
    );

    for (const component of components) observer.observe(component.el);
    for (const link of $$(sel.navLink)) on(link, "click", () => setActive(link));
  }

  function setupHashFocus() {
    on(doc, "click", (event) => {
      const anchor = event.target.closest?.('a[href^="#"]');
      if (!anchor) return;

      const id = anchor.getAttribute("href").slice(1);
      const target = id && doc.getElementById(id);
      if (!target) return;

      setTimeout(
        () => {
          target.setAttribute("tabindex", "-1");
          target.focus({ preventScroll: true });
        },
        prefersReduce ? 0 : 320,
      );
    });
  }

  const components = buildComponentIndex();
  const groups = $$(sel.navGroup);

  setupThemeToggle();
  setupNavGroups(groups);
  setupFilter(components, groups);
  setupCopyLinks();
  setupDisclosureToggles();
  setupDocClamps();
  setupScrollSpy(components);
  setupHashFocus();
})();
