# AGENTS.md

Guidance for coding agents working in this repository.

## Project Snapshot

`xsdstyle` is a single-file XSLT 3.0 documentation generator. `xsdstyle.xsl`
transforms W3C XSD 1.1 schemas into one self-contained, accessible,
deterministic HTML page.

It ships directly via Saxon, through local `make` targets, and as a Docker-based
GitHub Action: `action.yml` -> `Dockerfile` -> `entrypoint.sh`.

Keep the distribution as one stylesheet. Do not add `xsl:include`,
`xsl:import`, or `xsl:use-package`.

## Source Of Truth

The design documents under `docs/` are the product contract. When they disagree,
the higher-priority document wins; amend lower-priority docs rather than
allowing drift.

1. `docs/specification.md` - normative product behavior. Its "must", "must
   not", "should", and "may" statements define generator requirements.
2. `docs/architecture.md` - how the stylesheet satisfies the specification:
   pipeline, records, indexes, QName and namespace resolution, anchor scheme,
   security model, and determinism rules.
3. `docs/dom.md` - generated HTML DOM contract: structure, classes, ARIA, and
   reference-state markup.

Read the relevant document before non-trivial behavior changes. W3C source specs
under `specifications/` are gitignored and large, but authoritative for XSD and
XSLT terminology when present.

## Required Workflow

Work test-first for behavior changes:

1. Add or update the relevant `test/*.xspec` scenario.
2. Run the focused test and confirm it fails for the expected reason.
3. Implement the change.
4. Re-run the focused test.
5. Run the broader suite appropriate to the change, usually `make test`.

This applies to bug fixes and new features. Do not backfill tests to match an
implementation that has already been written.

Documentation-only edits do not require XSpec tests, but keep terminology and
precedence aligned with the design docs.

## Commands

Saxon is discovered from `brew install saxon` on macOS. Otherwise, `make`
vendors checksum-verified Saxon-HE, xmlresolver, and XSpec jars into `.tools/`.
Override Saxon with `SAXON_CP=/path/to/saxon-he.jar`.

```sh
make test                              # run every test/*.xspec under XSpec
make test XSPEC_TESTS=test/foo.xspec   # run one XSpec file
make lint                              # xmllint well-formedness + prettier --check
make format                            # apply Prettier in place
make render SCHEMA=path/to/schema.xsd  # render to out/index.html and copy assets
make smoke-test                        # render XSD-of-XSDs and validate HTML5/CSS
make lint-a11y                         # axe-core WCAG 2.2 AA audit of smoke output
make test-clean                        # remove per-run XSpec HTML reports
```

Prettier uses the pinned XML plugin by absolute plugin path; see the `PRETTIER`
comment in the Makefile. `.prettierrc.json` intentionally omits `plugins`. Use
`make install-prettier` to install the pinned global versions.

CI runs lint, XSpec tests, smoke test through the action, HTML5 validation, and
WCAG 2.2 AA accessibility audit. The dev container reproduces that toolchain.

## Stylesheet Architecture

Follow the pipeline in `docs/architecture.md`:

1. Normalize public parameters into one config map.
2. Collect the schema document graph.
3. Build schema, component, reference, contextual, and diagnostic records.
4. Build indexes and relationship graphs from those records.
5. Render HTML from records and indexes.

Renderers consume records and indexes; they must not rediscover global facts by
rescanning raw XSD nodes. Facts affecting identity, references, diagnostics,
backlinks, anchors, schema membership, or summaries belong in the model or index
layer.

- `f:config()` is the single normalized configuration boundary.
- `f:collect-schemas` walks `xs:import`, `xs:include`, `xs:redefine`, and
  `xs:override` transitively, including chameleon effective namespaces and a
  visited set keyed by URI plus effective namespace.
- Helper functions live in `urn:xsdoc:functions` and use the `f:` prefix in
  both `xsdstyle.xsl` and XSpec tests. Do not use `x:` for project helpers;
  XSpec reserves it.
- Inter-component lookup uses Clark notation (`{ns-uri}localname`) through
  helpers such as `f:clark`. Never compare namespace prefixes.
- `$schemas` is threaded as a tunnel parameter into mode-driven renderers.

## Modes

Keep mode responsibilities separated:

- Unnamed mode (`shallow-skip`) - main render walk.
- `doc` (`text-only-copy`) - `xs:documentation` HTML handling.
- `source` (`shallow-skip`) - XSD source pretty-printer.
- `particle` (`shallow-skip`) - content-model particles.
- `annotation` - `xs:annotation` documentation blocks.
- `inline-type` - anonymous simple and complex types embedded in owner articles.

## Determinism And Anchors

Same input plus same parameters must produce byte-identical HTML.

Do not introduce timestamps, random IDs, host paths, or ordering dependent on
map iteration or hashing. Synthetic namespace IDs (`ns1`, `ns2`, etc.) are
assigned in first-seen schema-collection order. Anchors follow
`docs/architecture.md` section 9 and `docs/dom.md`:

- Global components: `{kind-abbrev}-{ns-id}-{localname}`.
- Contextual constructs: owner-anchor based deterministic suffixes.
- Diagnostics: stable diagnostic record IDs or deterministic diagnostic anchors.

## Diagnostics And References

Diagnostics are documentation facts, not validation errors. Failed loads,
unresolved QNames, skipped cycles, invalid parameter normalization, and similar
conditions become visible diagnostic records.

Use wording that describes documentation behavior: "not loaded", "not
resolved", or "not expanded". References are never guessed away.

Every QName-valued reference should become a reference record. Reference records
classify states as internal resolved, built-in/specification, external
unresolved, or unresolved with diagnostics.

## Parameters And Wrappers

Eight public `xsl:param`s live at the top of `xsdstyle.xsl`:

- `page-title`
- `asset-base-uri`
- `show-source`
- `documentation-markup`
- `interface-language`
- `documentation-language`
- `interface-direction`
- `robots-noindex`

Each parameter is mirrored as a GitHub Action input and forwarded by
`entrypoint.sh` only when non-empty, so stylesheet defaults remain authoritative.
Override parameters on the Saxon CLI with `name=value`.

Invalid values are normalized to documented defaults and surfaced as
diagnostics, not hard failures.

## Security

Treat `xs:documentation` and `xs:appinfo` as untrusted input.

`documentation-markup=safe` is the default. It applies the allowlist, only
promotes no-namespace or XHTML elements to HTML, strips schema-authored IDs that
could collide with generated anchors, and rejects unsafe URL schemes such as
`javascript:`, `data:`, `vbscript:`, and `file:`.

`documentation-markup=permissive` may copy documentation verbatim and is the only
path that can emit `<script>` or `on*=` attributes. Treat allowlist, URL-scheme,
escaping, and permissive-mode changes as security-sensitive.

The generator must display `vc:*` versioning attributes. Do not add an
`xsd-version` parameter or filter output by XSD version.

## Assets And Progressive Enhancement

The page must render all schema facts without JavaScript. JavaScript adds only
affordances such as search/filter, copy-link, expand/collapse, theme toggle, and
keyboard shortcuts. It derives its search index from the rendered DOM and must
not fetch, synthesize, or evaluate schema content.

- `assets/xsdstyle.css` uses BEM, CSS custom properties,
  `prefers-color-scheme`, and CSS logical properties for RTL.
- `assets/xsdstyle.js` is vanilla JavaScript with no dependencies.
- `entrypoint.sh` and `make render` copy `assets/` beside the generated HTML.
- The stylesheet links assets under `asset-base-uri`.

Icon SVGs live in `assets/ico-*.svg` and are read at transform time relative to
`static-base-uri()`. To add an icon, add the file under `assets/` and list it in
`$icon-names`.

## DOM, Accessibility, And Styling

The generated DOM contract is in `docs/dom.md`. Preserve semantic HTML,
landmarks, headings, stable classes and IDs, reference states, and diagnostic
reachability.

Facts must not exist only in a class name, color, icon, tooltip, or JavaScript
state. CSS may reinforce meaning, but color must not be the only distinction.
Filtering may visually hide unmatched content but must not remove schema facts
from the document.

Use logical CSS properties where practical. Code-like values should remain
readable in LTR and RTL interfaces.

## Localization

UI strings live in the inline `i18n-messages` catalog. Lookup is deterministic:
exact BCP 47 tag, then primary language subtag, then English. Missing keys
render as `[[key]]`.

`interface-language` controls generated chrome and `<html lang>`.
`documentation-language` is only a fallback for XSD-authored prose wrappers when
a block has no `xml:lang`. Schema-authored names, QNames, namespace URIs, XPath,
regexes, facet values, and source code are not translated.

To add a locale, copy the `en` block, change the outer key to a lowercase BCP
47 tag, translate values, and leave message keys unchanged. A fixed subset of
messages is emitted as JSON for `xsdstyle.js`.
