# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single XSLT 3.0 stylesheet (`xsdstyle.xsl`, ~3900 lines) that transforms a W3C
XSD 1.1 schema into a self-contained, accessible, deterministic HTML
documentation page. Shipped three ways: directly via Saxon, as a `make` target,
and as a Docker-based GitHub Action (`action.yml` → `Dockerfile` → `entrypoint.sh`).

## Design documents are the contract

Three documents under `docs/` define the product, and they form an explicit
precedence chain — when they disagree, the higher one wins, and the lower one
should be amended rather than allowing drift:

1. **`docs/specification.md`** — the product contract. Its "must / must not /
   should / may" are normative for the generator.
2. **`docs/architecture.md`** — how the stylesheet satisfies that contract:
   the phase pipeline, record shapes, indexes, QName/namespace resolution,
   anchor scheme, security model, and determinism rules.
3. **`docs/dom.md`** — the generated HTML DOM contract (element structure,
   classes, ARIA, reference-state markup).

Read the relevant document before any non-trivial change. The W3C source specs
under `specifications/` (XSD 1.1 Parts 1 & 2, XSLT 3.0; gitignored, large) are
authoritative for XSD/XSLT terminology.

## Commands

Saxon is discovered automatically from `brew install saxon` (macOS); otherwise
`make` vendors pinned Saxon-HE + xmlresolver + XSpec jars into `.tools/` on first
run (checksum-verified). Override the Saxon classpath with `SAXON_CP=/path/to/saxon-he.jar`.

```sh
make test            # run every test/*.xspec under XSpec
make lint            # lint-xml (xmllint well-formedness) + lint-format (prettier --check)
make format          # apply Prettier in place
make render SCHEMA=path/to/schema.xsd   # render one XSD -> out/index.html (+ assets)
make smoke-test      # render the W3C XSD-of-XSDs, validate HTML5/CSS via vnu.jar
make lint-a11y       # axe-core WCAG 2.2 AA audit of the smoke-test output
```

To run a **single** XSpec file, override `XSPEC_TESTS` on the command line (it
overrides the in-file default and reuses all Saxon/XSpec setup):

```sh
make test XSPEC_TESTS=test/parameters.xspec
```

Prettier requires the XML plugin and is invoked by **absolute plugin path** (an
ESM loader quirk — see the `PRETTIER` comment in the Makefile; `.prettierrc.json`
deliberately omits `"plugins"`). `make install-prettier` installs the pinned
versions globally. Per-run XSpec HTML reports land in `test/xspec/` (gitignored);
`make test-clean` removes them.

CI (`.github/workflows/ci.yml`) runs five jobs on every push/PR: lint, XSpec
test, smoke-test (renders via the action itself), HTML5 validation (vnu.jar), and
the WCAG 2.2 AA a11y audit. A dev container under `.devcontainer/` reproduces the
full toolchain (Java 21, Node 24, xmllint, version-matched Chromium/chromedriver).

## Test-driven development

Work test-first. Before changing `xsdstyle.xsl` (or any behaviour-bearing code),
add or update the relevant `test/*.xspec` scenario so it captures the intended
behaviour, run it, and confirm it **fails** for the expected reason. Only then
make the change that turns it green, and re-run `make test` to confirm. This
applies to bug fixes (write a failing test that reproduces the bug first) as well
as new features. Don't write the implementation and the test together, and don't
backfill a test after the fact to match whatever the code happens to do.

## Stylesheet architecture

- **Single file, no includes.** No `xsl:include` / `import` / `use-package` —
  this is a hard mandate; the distribution must remain one stylesheet.

- **Layered pipeline, not a flat template tree.** The file follows the layers in
  `docs/architecture.md`: normalize parameters → collect the schema document
  graph → build component/reference/diagnostic **records** → build indexes →
  render. Renderers consume records and ask indexes for relationships; they must
  **not** rediscover global facts by re-scanning raw XSD nodes. `f:config()`
  produces the single normalized config map; `f:collect-schemas` walks
  `xs:import`/`include`/`redefine`/`override` transitively (with the chameleon
  effective-namespace rule and a visited set keyed by URI + effective namespace).

- **Function namespace / prefix gotcha.** Helper functions live in
  `urn:xsdoc:functions`, bound to prefix **`f:`** in both `xsdstyle.xsl` and the
  `*.xspec` tests (e.g. `f:clark`, `f:anchor`, `f:qname`, `f:reference-qname`).
  Do **not** use the prefix `x:` — it is reserved by XSpec for its own
  namespace.

- **Six modes.** Unnamed (`shallow-skip`) for the main render walk; `doc`
  (`text-only-copy`) for `xs:documentation` HTML; `source` (`shallow-skip`) for
  the XSD source pretty-printer; `particle` (`shallow-skip`) for content-model
  particles; `annotation` for rendering `xs:annotation` documentation blocks;
  `inline-type` for anonymous simple/complex types embedded in owner articles.
  The `$schemas` record set is threaded as a tunnel parameter into the
  mode-driven renderers.

- **Clark form for all lookups.** Inter-component references resolve through
  Clark notation (`{ns-uri}localname`) via `f:clark`; never compare prefixes.

- **Determinism is required.** Same input + params → byte-identical HTML. No
  timestamps, random IDs, or host paths. Synthetic namespace IDs (`ns1`, `ns2`,
  …) are assigned in first-seen schema-collection order; anchors follow the
  `{kind-abbrev}-{ns-id}-{localname}` scheme in `docs/architecture.md` §9.
  Don't introduce ordering that depends on map iteration or hashing.

- **`vc:*` is displayed, not filtered.** Output is a superset of all XSD
  versions; there is deliberately no `xsd-version` parameter and no conditional
  inclusion. Don't add filtering.

- **Diagnostics are documentation facts, not validation errors.** Failed loads,
  unresolved QNames, skipped cycles, etc. become first-class diagnostic records
  rendered into the page; wording uses "not loaded", "not resolved", "not
  expanded". References are never "guessed away".

- **Documentation HTML sanitisation is security-sensitive.** `xs:documentation`
  is untrusted input. `documentation-markup=safe` (default) applies an
  element/attribute allowlist plus URL-scheme checks (rejects `javascript:`,
  `data:`, `vbscript:`, `file:`). `permissive` copies verbatim and is the only
  path that can emit `<script>`/`on*=`. Treat changes to the allowlist or the
  safe-href logic as security changes.

## Parameters

Eight public `xsl:param`s (top of `xsdstyle.xsl`), each mirrored as a GitHub
Action input (`action.yml`) and forwarded by `entrypoint.sh` only when non-empty
so XSL defaults stay authoritative: `page-title`, `asset-base-uri`, `show-source`,
`documentation-markup`, `interface-language`, `documentation-language`,
`interface-direction`, `robots-noindex`. Override on the Saxon CLI with
`name=value`. Invalid values are normalized to the documented default and
surfaced as a diagnostic, not a hard error. See `docs/specification.md` and the
README for per-parameter semantics.

## Assets and progressive enhancement

`assets/xsdstyle.css` (BEM, CSS custom properties + `prefers-color-scheme` dark
mode, CSS logical properties for RTL) and `assets/xsdstyle.js` (vanilla, no
dependencies: search/filter, copy-link, expand/collapse, theme toggle, `/` and
`Esc` shortcuts). The page renders fully without JavaScript; **JS never adds
schema content**, only affordances, and derives its search index from the
rendered DOM. The stylesheet links these under `asset-base-uri`; `entrypoint.sh`
and `make render` copy `assets/` next to the generated HTML.

Icon SVGs are stored as `assets/ico-*.svg` and read at transform time
(resolved relative to the stylesheet via `static-base-uri()`), so rendering
requires `assets/` to sit next to `xsdstyle.xsl`. `f:icon-sprite()` emits each
icon once as a `<symbol>` in a hidden sprite; `f:icon()` emits the use-site
`<svg><use>` reference — see `docs/dom.md` §3. To add an icon, drop the file
in `assets/` and list it in `$icon-names`.

## Localisation

UI chrome strings flow through one inline catalog (`xsl:variable name="i18n-messages"`),
selected by `interface-language` (exact tag → primary subtag → `en`). Missing
keys render as `[[key]]` so omissions are visible. `interface-language` (chrome +
`<html lang>`) is a separate axis from `documentation-language` (fallback `lang`
on XSD-prose wrappers when a block has no `xml:lang`). A fixed subset is also
emitted as JSON for `xsdstyle.js`. To add a locale: copy the `'en':` block,
change the outer key to a lowercase BCP-47 tag, translate values, leave keys
untouched.
