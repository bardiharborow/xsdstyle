/* xsdstyle — vanilla JS for filter, copy-link, scrollspy, print.
   No dependencies.

   DOM hooks expected (matching what the stylesheet emits):
     #toc-filter          search input
     #toc-filter-status   ARIA live status
     #toc-doc-matches     container for documentation-only hits
     #xsdoc-index         <script type="application/json"> search index
     #xsdoc-i18n          <script type="application/json"> message bundle
     .sidebar__toc-group  TOC group container
       li[data-name]      individual TOC entries
     .component[id]       component card
     .copy-link[data-anchor]   copy-permalink button
     .copy-link-icon, .copy-link-status   button affordances
*/

(function () {
  "use strict";

  document.addEventListener("DOMContentLoaded", init);

  /* Initialised lazily on first use so it works regardless of script load
     order; cached after the first read. */
  var I18N = null;

  function init() {
    var index = readIndex();
    wireFilter(index);
    wireCopyLinks();
    wireScrollspy();
    wirePrintExpand();
    wireKeyShortcuts();
    wireDocCollapse();
  }

  /* ----- i18n ----- */

  /* The English bundle is baked in so the script still works if the
     stylesheet ever omits the #xsdoc-i18n block (e.g. running this file
     in isolation). The stylesheet's bundle is overlaid at runtime. */
  function readI18n() {
    var fallback = {
      showMore: "Show more",
      showLess: "Show less",
      showMoreOf: "Show more of {label}",
      showLessOf: "Show less of {label}",
      descriptionSuffix: "{name} description",
      componentSingular: "component",
      componentPlural: "components",
      moreDocMatches: " more documentation matches",
      docMatches: " documentation matches",
    };
    var node = document.getElementById("xsdoc-i18n");
    if (!node) return fallback;
    try {
      var parsed = JSON.parse(node.textContent || "{}");
      if (parsed && typeof parsed === "object") {
        for (var k in fallback) {
          if (typeof parsed[k] !== "string") parsed[k] = fallback[k];
        }
        return parsed;
      }
    } catch (e) {
      /* fall through */
    }
    return fallback;
  }

  function t(key, params) {
    if (!I18N) I18N = readI18n();
    var s = typeof I18N[key] === "string" ? I18N[key] : "[[" + key + "]]";
    if (!params) return s;
    return s.replace(/\{(\w+)\}/g, function (_, k) {
      return params[k] != null ? String(params[k]) : "";
    });
  }

  /* ----- Search index ----- */

  function readIndex() {
    var node = document.getElementById("xsdoc-index");
    if (!node) return [];
    try {
      var parsed = JSON.parse(node.textContent || "[]");
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  /* ----- Filter ----- */

  var DOC_MATCH_LIMIT = 10;
  var DOC_SNIPPET_PAD = 60;

  function wireFilter(index) {
    var input = document.getElementById("toc-filter");
    if (!input) return;
    var docHits = document.getElementById("toc-doc-matches");
    var status = document.getElementById("toc-filter-status");

    input.addEventListener("input", function () {
      var q = input.value.trim().toLowerCase();
      var nameHits = 0;
      var groups = document.querySelectorAll(".sidebar__toc-group");
      groups.forEach(function (group) {
        var visible = 0;
        group.querySelectorAll("li[data-name]").forEach(function (li) {
          var name = li.getAttribute("data-name") || "";
          var match = !q || name.indexOf(q) !== -1;
          li.classList.toggle("hidden", !match);
          if (match) {
            visible++;
            nameHits++;
          }
        });
        group.classList.toggle("hidden", visible === 0 && !!q);
      });

      var docMatches = [];
      if (q && docHits) {
        for (var i = 0; i < index.length && docMatches.length < DOC_MATCH_LIMIT; i++) {
          var entry = index[i];
          var name = (entry.n || "").toLowerCase();
          var doc = (entry.d || "").toLowerCase();
          var docIdx = doc.indexOf(q);
          if (docIdx !== -1 && name.indexOf(q) === -1) {
            docMatches.push({ entry: entry, idx: docIdx });
          }
        }
      }
      renderDocMatches(docHits, q, docMatches, index);

      if (status) {
        if (!q) {
          status.textContent = "";
        } else {
          var more =
            docHits &&
            index.filter(function (e) {
              return (e.d || "").toLowerCase().indexOf(q) !== -1 && (e.n || "").toLowerCase().indexOf(q) === -1;
            }).length;
          status.textContent =
            nameHits +
            " " +
            (nameHits === 1 ? t("componentSingular") : t("componentPlural")) +
            (more > docMatches.length
              ? ", " + (more - docMatches.length) + t("moreDocMatches")
              : docMatches.length
                ? ", " + docMatches.length + t("docMatches")
                : "") +
            " for '" +
            q +
            "'";
        }
      }
    });

    input.addEventListener("keydown", function (e) {
      if (e.key === "Escape") {
        input.value = "";
        input.dispatchEvent(new Event("input"));
        input.blur();
      }
    });
  }

  function renderDocMatches(node, q, matches, index) {
    if (!node) return;
    if (!q || matches.length === 0) {
      node.hidden = true;
      node.innerHTML = "";
      return;
    }
    var html = matches
      .map(function (m) {
        return (
          '<a href="#' +
          escapeAttr(m.entry.a) +
          '">' +
          "<strong>" +
          escapeText(m.entry.n) +
          "</strong>" +
          '<span class="muted"> — ' +
          buildSnippet(m.entry.d, q) +
          "</span>" +
          "</a>"
        );
      })
      .join("<br>");
    node.hidden = false;
    node.innerHTML = html;
  }

  function buildSnippet(text, q) {
    var lower = text.toLowerCase();
    var idx = lower.indexOf(q);
    if (idx === -1) return escapeText(text.slice(0, DOC_SNIPPET_PAD * 2)) + "…";
    var start = Math.max(0, idx - DOC_SNIPPET_PAD);
    var end = Math.min(text.length, idx + q.length + DOC_SNIPPET_PAD);
    var slice = (start > 0 ? "…" : "") + text.slice(start, end) + (end < text.length ? "…" : "");
    return highlight(slice, q);
  }

  function highlight(text, q) {
    var lower = text.toLowerCase();
    var ql = q.toLowerCase();
    var out = "";
    var i = 0;
    while (i < text.length) {
      var found = lower.indexOf(ql, i);
      if (found === -1) {
        out += escapeText(text.slice(i));
        break;
      }
      out += escapeText(text.slice(i, found));
      out += "<mark>" + escapeText(text.slice(found, found + q.length)) + "</mark>";
      i = found + q.length;
    }
    return out;
  }

  function escapeText(s) {
    return String(s).replace(/[&<>]/g, function (c) {
      return c === "&" ? "&amp;" : c === "<" ? "&lt;" : "&gt;";
    });
  }
  function escapeAttr(s) {
    return escapeText(s).replace(/"/g, "&quot;");
  }

  /* ----- Copy-link buttons ----- */

  function wireCopyLinks() {
    document.addEventListener("click", function (e) {
      var btn = e.target.closest && e.target.closest(".copy-link");
      if (!btn) return;
      var anchor = btn.getAttribute("data-anchor");
      if (!anchor) return;
      var url = location.origin + location.pathname + "#" + anchor;
      if (location.hash !== "#" + anchor) location.hash = anchor;
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(url).then(
          function () {
            flashCopied(btn, true);
          },
          function () {
            flashCopied(btn, false);
          },
        );
      } else {
        flashCopied(btn, false);
      }
    });
  }

  function flashCopied(btn, ok) {
    btn.classList.add("copied");
    var icon = btn.querySelector(".copy-link__icon");
    if (icon) {
      icon.dataset.prev = icon.textContent;
      icon.textContent = ok ? "✓" : "✕";
    }
    setTimeout(function () {
      btn.classList.remove("copied");
      if (icon) icon.textContent = icon.dataset.prev || "#";
    }, 1500);
  }

  /* ----- Scrollspy (intersection observer on .component[id]) ----- */

  function wireScrollspy() {
    if (typeof IntersectionObserver === "undefined") return;
    var anchors = {};
    document.querySelectorAll('.sidebar__toc-group li a[href^="#"]').forEach(function (a) {
      anchors[a.getAttribute("href").slice(1)] = a;
    });
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          var link = anchors[entry.target.id];
          if (!link) return;
          if (entry.isIntersecting) {
            link.classList.add("active");
            link.setAttribute("aria-current", "location");
          } else {
            link.classList.remove("active");
            link.removeAttribute("aria-current");
          }
        });
      },
      { rootMargin: "0px 0px -75% 0px", threshold: 0 },
    );
    document.querySelectorAll(".component[id]").forEach(function (el) {
      observer.observe(el);
    });
  }

  /* ----- Print: expand all <details> ----- */

  function wirePrintExpand() {
    var saved = new Map();
    window.addEventListener("beforeprint", function () {
      document.querySelectorAll("details").forEach(function (d) {
        saved.set(d, d.open);
        d.open = true;
      });
    });
    window.addEventListener("afterprint", function () {
      saved.forEach(function (open, d) {
        if (document.contains(d)) d.open = open;
      });
      saved.clear();
    });
  }

  /* ----- Collapse long documentation blocks with a "Show more" toggle ----- */

  function wireDocCollapse() {
    var COLLAPSED_PX = 144; // mirrors the 9em max-height in CSS at default font-size
    var SLACK_PX = 32; // don't bother clamping content that's only slightly over
    var seq = 0;

    var run = function () {
      var docs = document.querySelectorAll(".component__doc, .page-header__doc");
      docs.forEach(function (doc) {
        if (doc.dataset.collapseProcessed) return;
        if (doc.parentNode && doc.parentNode.closest && doc.parentNode.closest(".component__doc, .page-header__doc"))
          return;
        doc.dataset.collapseProcessed = "1";
        if (doc.scrollHeight <= COLLAPSED_PX + SLACK_PX) return;

        var contentId = "doc-collapse-" + ++seq;
        var labelBase = describedByLabel(doc);

        var content = document.createElement("div");
        content.className = "doc-collapse__content";
        content.id = contentId;
        content.inert = true;
        while (doc.firstChild) content.appendChild(doc.firstChild);
        doc.appendChild(content);

        var btn = document.createElement("button");
        btn.type = "button";
        btn.className = "doc-collapse__toggle";
        btn.setAttribute("aria-expanded", "false");
        btn.setAttribute("aria-controls", contentId);
        btn.textContent = t("showMore");
        if (labelBase) btn.setAttribute("aria-label", t("showMoreOf", { label: labelBase }));
        doc.appendChild(btn);
        doc.classList.add("doc-collapse", "doc-collapse--collapsed");

        btn.addEventListener("click", function () {
          var collapsed = doc.classList.toggle("doc-collapse--collapsed");
          btn.setAttribute("aria-expanded", collapsed ? "false" : "true");
          btn.textContent = collapsed ? t("showMore") : t("showLess");
          content.inert = collapsed;
          if (labelBase)
            btn.setAttribute(
              "aria-label",
              collapsed ? t("showMoreOf", { label: labelBase }) : t("showLessOf", { label: labelBase }),
            );
        });
      });
    };

    function describedByLabel(doc) {
      var component = doc.closest && doc.closest(".component");
      if (component) {
        var heading = component.querySelector(".component__name, .component__heading, h1, h2, h3");
        if (heading && heading.textContent) return t("descriptionSuffix", { name: heading.textContent.trim() });
      }
      if (doc.classList.contains("page-header__doc")) {
        var pageHeading = document.querySelector(".page-header h1, header h1, h1");
        if (pageHeading && pageHeading.textContent)
          return t("descriptionSuffix", { name: pageHeading.textContent.trim() });
      }
      return "";
    }

    if (document.fonts && document.fonts.ready && typeof document.fonts.ready.then === "function") {
      document.fonts.ready.then(run);
    } else {
      run();
    }
  }

  /* ----- Keyboard shortcuts ("/" focuses filter) ----- */

  function wireKeyShortcuts() {
    document.addEventListener("keydown", function (e) {
      if (e.target && /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)) return;
      if (e.key === "/" && !e.metaKey && !e.ctrlKey && !e.altKey) {
        var input = document.getElementById("toc-filter");
        if (input) {
          e.preventDefault();
          input.focus();
          input.select();
        }
      }
    });
  }
})();
