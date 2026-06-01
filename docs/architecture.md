# xsdstyle — architecture

This document is the authoritative design for the XSLT 3.0 stylesheet at
`xsdstyle.xsl`. It is the contract the implementation must satisfy: where
this document and the stylesheet disagree, this document is wrong and should
be amended (rather than silently allowing drift).

The W3C specifications for XSD 1.1 (Parts 1 & 2) and XSLT 3.0 live in
`specifications/` and are authoritative for terminology and feature semantics.

## 1. Goals and non-goals

### 1.1 Goals

- **Comprehensive XSD 1.1 rendering.** Every construct defined in _W3C XML
  Schema Definition Language (XSD) 1.1 Part 1: Structures_ and _Part 2:
  Datatypes_ should be either rendered visually or surfaced as metadata in the
  generated HTML.
- **XSLT 3.0 throughout.** The implementation language is XSLT 3.0 as defined
  in the W3C _XSL Transformations (XSLT) Version 3.0_ recommendation. Saxon-HE
  13 is the target processor.
- **Single-file stylesheet.** No `xsl:include`, no `xsl:import`, no
  `xsl:package`, no`xsl:use-package`. One file, organised into clearly
  delineated regions with shared functions and modes.
- **Multi-schema collection walk.** Honour `xs:import`, `xs:include`,
  `xs:redefine`, and `xs:override` transitively, with the chameleon-include
  rule applied to includes whose target schema lacks a `targetNamespace`.
- **Static, accessible HTML.** The output is a single self-contained HTML page
  that renders correctly without JavaScript. JS adds search and
  expand-all-affordances; it never adds content.
- **Deterministic output.** Given the same input schema and parameters, two
  runs produce byte-identical HTML.

### 1.2 Non-goals

- **Sample XML instance generation.** (Possible follow-up.)
- **Schema validation.** We trust the input. We do not check that the schema
  is internally consistent or that referenced QNames resolve.
- **Multi-file output.** One HTML file per invocation.
- **Browser-side framework dependencies.** No bundlers, no transpilation, no
  CSS preprocessors.

## 2. XSD 1.1 coverage matrix

The table below enumerates the XSD 1.1 constructs the new stylesheet must
recognise. "Where rendered" names the HTML region; "Indicator" names the
visible cue.

| Construct (Part 1 §)                                           | XSD 1.0? | XSD 1.1?            | Where rendered                                                                                            | Indicator                                     |
| -------------------------------------------------------------- | -------- | ------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| `xs:schema` (§3.1)                                             | ✅       | ✅                  | Overview card                                                                                             | Target NS, location, attribute defaults       |
| `xs:element` (§3.3)                                            | ✅       | ✅                  | `components--element` section                                                                             | Per-component card                            |
| `xs:attribute` (§3.2)                                          | ✅       | ✅                  | Attribute table + global section                                                                          | Row in table; card for globals                |
| `xs:complexType` (§3.4)                                        | ✅       | ✅                  | `components--complex-type` section                                                                        | Per-component card                            |
| `xs:simpleType` (§3.16)                                        | ✅       | ✅                  | `components--simple-type` section                                                                         | Per-component card                            |
| `xs:group` (§3.7)                                              | ✅       | ✅                  | `components--group` section                                                                               | Per-component card                            |
| `xs:attributeGroup` (§3.6)                                     | ✅       | ✅                  | `components--attribute-group` section                                                                     | Per-component card                            |
| `xs:notation` (§3.12)                                          | ✅       | ✅                  | `components--notation` section                                                                            | Per-component card                            |
| `xs:key` / `xs:keyref` / `xs:unique` (§3.11)                   | ✅       | ✅                  | `component__identity-constraints`                                                                         | Constraint table                              |
| `xs:import` (§4.2.6)                                           | ✅       | ✅                  | Overview "Schemas" card                                                                                   | Row per import                                |
| `xs:include` (§4.2.3)                                          | ✅       | ✅                  | Overview "Schemas" card                                                                                   | Row per include, with chameleon note          |
| `xs:redefine` (§4.2.5)                                         | ✅       | ❌ (deprecated 1.1) | Overview + per-component badge                                                                            | `badge--redefined`                            |
| `xs:override` (§4.2.5)                                         | ❌       | ✅                  | Overview + per-component badge                                                                            | `badge--overridden`                           |
| `xs:assert` (§3.13)                                            | ❌       | ✅                  | `component__assertions`                                                                                   | Code-formatted XPath rows                     |
| `xs:alternative` (§3.4.4.3, CTA)                               | ❌       | ✅                  | `component__type-alternatives`                                                                            | Conditional rows + CTA context note           |
| `xs:openContent` (§3.4.1.4)                                    | ❌       | ✅                  | `component__open-content`                                                                                 | Mode badge + wildcard                         |
| `xs:defaultOpenContent` (§3.16.2.2)                            | ❌       | ✅                  | Overview "Defaults" card + per-type footnote                                                              | Effective mode + footnote                     |
| `@defaultAttributes` (§3.1) / `@defaultAttributesApply` (§3.4) | ❌       | ✅                  | Overview "Defaults" + per-type footnote                                                                   | "Default attrs applied" footnote              |
| `@inheritable` on `xs:attribute` (§3.2.2)                      | ❌       | ✅                  | Attribute table                                                                                           | Dedicated **Inheritable** column              |
| Inheritable attrs in CTA context (§3.4.4.3)                    | ❌       | ✅                  | `component__type-alternatives` sub-block                                                                  | "Inherited test-context attributes" list      |
| `xs:all` with `maxOccurs>1` / wildcards (§3.8.1)               | ❌       | ✅                  | Content model                                                                                             | Occurrence marker + wildcard inner            |
| `xs:any/@notQName` w/ XSD-1.1 tokens (§3.10)                   | ❌       | ✅                  | Wildcard inner                                                                                            | Code tokens (`##defined`, `##definedSibling`) |
| `vc:minVersion`, `vc:maxVersion` (App. F)                      | ❌       | ✅                  | Component header badge + per-component "Version controls" panel + overview "XSD 1.1 features in use" card | `badge--vc-decorated`; aggregated list        |
| `vc:typeAvailable` / `vc:typeUnavailable` (App. F)             | ❌       | ✅                  | Same as above                                                                                             | Same                                          |
| `vc:facetAvailable` / `vc:facetUnavailable` (App. F)           | ❌       | ✅                  | Same as above                                                                                             | Same                                          |
| Built-in primitives & derivations (Part 2)                     | ✅       | ✅                  | Type references resolve to W3C spec URLs                                                                  | `<a href="…">` to external doc                |
| `xs:list` / `xs:union` (§3.16.6)                               | ✅       | ✅                  | Simple-type derivation panel                                                                              | Composition shown inline                      |
| Facets (length, pattern, enumeration, totalDigits, …)          | ✅       | ✅                  | `component__facets`                                                                                       | Facet table; values rendered as code          |
| Substitution groups (§3.3.6)                                   | ✅       | ✅                  | `component__see-also`                                                                                     | Member list + transitive head chain           |

The coverage matrix is exercised by the XSpec suite in `test/` and by
`make smoke-test`, which renders the W3C XSD-of-XSDs end-to-end and
validates the resulting HTML/CSS with vnu.jar.

## 3. XSLT 3.0 features leveraged

The stylesheet leans on XSLT 3.0 features pragmatically — we use 3.0 features
only where they remove ceremony or buy us correctness, not for novelty.

- **Maps and arrays** for the component catalog and the kind dispatch table.
- **`xsl:iterate` with `xsl:break`** for the schema-collection graph walk.
- **Accumulators** for `nsid` minting (synthetic IDs for secondary
  namespaces). One pass over the schema collection emits a stable ID per
  distinct namespace URI without round-tripping through a lookup map.
- **`xsl:try` / `xsl:catch`** wrapping each `doc()` call in
  `x:collect-schemas`.
- **Higher-order `fold-left`** for the base-chain walk in inherited-content
  rendering.
- **`xsl:mode` with `on-no-match`**
- **JSON output via `serialize()`** for the embedded search index.
- **Sequence types everywhere.** Every function and template signature
  declares `as=` to catch type drift at compile time.

We **do not** use:

- `xsl:package` / `xsl:use-package` (single-file mandate).
- Streaming. The whole-document model — we walk backq and forth across the
  schema collection too many times — is incompatible.
- `xsl:fork` / `xsl:merge`. No use case in this pipeline.

## 4. Region layout of the single file

`xsdstyle.xsl` is one file, top-to-bottom organised as 15 regions. Each
region starts with a banner comment containing "Region N. Name" so a grep
for `Region` jumps between sections.

| #   | Region                        | Lines (approx.) | Contents                                                                                                                                                                                                                                                                     |
| --- | ----------------------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Preamble                      | 1–30            | `xsl:stylesheet`, namespaces (`xs`, `vc`, `xhtml`, `x`), `xpath-default-namespace`, `xsl:output`, `expand-text`                                                                                                                                                              |
| 2   | Parameters                    | 30–120          | The 7 `xsl:param`s with type, default, and docblock                                                                                                                                                                                                                          |
| 3   | Global constants              | 120–200         | XSD/vc namespace URIs, builtin-type catalog, XSD 1.1 token tables                                                                                                                                                                                                            |
| 4   | Keys                          | 200–280         | `substitutionMembers`, `typeUsersByType`, `typeUsersByBase`, `identityConstraintByQName`, `inheritableAttrsByType`, `openContentByType`, `vcDecorated`                                                                                                                       |
| 5   | `xsl:mode` declarations       | 280–340         | 10 modes (§6 below)                                                                                                                                                                                                                                                          |
| 6   | Pure helper functions         | 340–550         | `x:clark`, `x:resolve-qname`, `x:occurs`, `x:occurs-title`, `x:xsd-true`, `x:format-notQName`, `x:safe-href`, `x:abbr`, `x:ns-id`, `x:anchor`, `x:is-xs`, `x:xsd-indent`, `x:vc-attrs`                                                                                       |
| 7   | Schema-aware helper functions | 550–800         | `x:tns`, `x:relative-source`, `x:anchor-for`, `x:find-component`, `x:owner-component`, `x:owner-type`, `x:component-qname`, `x:component-link`, `x:xs-builtin-href`, `x:is-redefined`, `x:is-overridden`, `x:effective-open-content`, `x:inheritable-attrs`, `x:doc-snippet` |
| 8   | Schema collection             | 800–900         | `x:collect-schemas` (`xsl:iterate`-based) + diagnostics                                                                                                                                                                                                                      |
| 9   | Global catalogs               | 900–960         | `$primary`, `$schemas`, `$schema-tns`, `$kinds`, `$all-components`                                                                                                                                                                                                           |
| 10  | Root template                 | 960–1100        | `xsl:template match="/"`, page skeleton                                                                                                                                                                                                                                      |
| 11  | Sidebar / TOC / JSON index    | 1100–1350       | TOC builder, per-kind groups, search-index emission                                                                                                                                                                                                                          |
| 12  | Per-kind component renderers  | 1350–1700       | Named templates per kind (element, complexType, simpleType, attribute, attributeGroup, group, notation)                                                                                                                                                                      |
| 13  | Sub-renderers                 | 1700–2400       | Model, attribute table, facets, identity constraints, type-alternatives + CTA context, derivation chain, open-content panel, redefine/override decoration                                                                                                                    |
| 14  | Documentation renderer        | 2400–2600       | `doc-safe` (allowlist + scheme sanitisation) and `doc-permissive` (verbatim) modes                                                                                                                                                                                           |
| 15  | XSD source pretty-printer     | 2600–2900       | `xsd-source` mode with indentation helper and syntax highlighting                                                                                                                                                                                                            |

Line ranges are approximate; the banner comments are the authoritative
boundary markers.

## 5. Data model

### 5.1 Schema collection (`$schemas`)

A map produced by `x:collect-schemas`. Keys:

- `'primary'`: the input `xs:schema` element node.
- `'all'`: a sequence of every `xs:schema` element node reachable from the
  primary via `xs:import`, `xs:include`, `xs:redefine`, `xs:override`. Each
  node is the actual element in its source document — chameleon-included
  schemas keep their original (empty) `@targetNamespace`; the effective
  namespace is recorded separately.
- `'ns-by-uri'`: a `map(xs:anyURI, xs:string)` mapping document URI → effective
  target namespace. For chameleon includes the value is the including
  schema's target namespace.
- `'uri-by-ns'`: the reverse mapping (multi-valued).
- `'errors'`: a sequence of diagnostic messages from failed `doc()` calls.
- `'nsids'`: a `map(xs:string, xs:string)` mapping effective namespace URI →
  short ID (`""` for the primary namespace, `"ns1"`, `"ns2"`, … otherwise),
  derived by the `nsid` accumulator.

### 5.2 Component catalog (`$all-components`)

A sequence of `map(*)` records, one per top-level component:

```
{
  'kind':       'element' | 'complexType' | 'simpleType' | 'attribute'
              | 'attributeGroup' | 'group' | 'notation',
  'node':       element(),         (: the XSD source element :)
  'name':       xs:string,         (: NCName from @name :)
  'qname':      xs:QName,
  'ns-id':      xs:string,         (: anchor namespace ID :)
  'anchor':     xs:string,         (: full HTML id attribute :)
  'is-redefined': xs:boolean,
  'is-overridden': xs:boolean,
  'vc-attrs':   attribute()*,
  'doc-snippet': xs:string?
}
```

### 5.3 Link graph

The four keys defined in Region 4 (`substitutionMembers`, `typeUsersByType`,
`typeUsersByBase`, `identityConstraintByQName`) plus the three new keys
(`inheritableAttrsByType`, `openContentByType`, `vcDecorated`) form the
link graph. All key lookups are by Clark-form QName (e.g.
`{http://example.com/ns}Foo`).

`vcDecorated` is `match="*[@vc:* | descendant::*[@vc:*]]"` —
its presence (non-empty key result) tells the per-component renderer to
include a `badge--vc-decorated` and a `component__vc-controls` sub-block.

## 6. Rendering pipeline

```
input.xsd
  │
  ▼
parse + xs:include/import/redefine/override walk
  │
  ▼
x:collect-schemas  ──► $schemas (map with primary, all, ns mappings, errors)
  │
  ▼
build $all-components from $schemas['all']
  │
  ▼
group components by 'kind' (in the canonical order listed in §2)
  │
  ▼
root template emits the HTML skeleton, then dispatches to per-kind renderers
  │
  ▼
per-kind renderer calls sub-renderers (model, attrs, facets, IC, CTA, ...)
  │
  ▼
documentation renderer (safe or permissive) wraps every <xs:documentation>
  │
  ▼
XSD source pretty-printer renders <details><pre> per component if $include-source
  │
  ▼
sidebar + TOC + JSON search index emitted last (so it can reference component anchors)
```

Each arrow corresponds to a region in the file. There is no second pass over
the schema collection — every walk reads from the catalogs built once.

## 7. Namespace and QName resolution

XSD's namespace conventions are subtle in two specific places.

### 7.1 Unprefixed QName attribute values

When an attribute like `@type="Foo"` or `@base="Bar"` has no prefix, XSD says
to resolve it against the in-scope default namespace at the point of the
reference. But schemas conventionally declare `xmlns="http://www.w3.org/2001/XMLSchema"`
at the schema root, which would (naively) bind every unprefixed reference to
the XSD namespace itself. `x:resolve-qname` therefore tries the schema's own
`@targetNamespace` first, then the default namespace, and reports unresolved
QNames as a diagnostic on the component catalog.

### 7.2 Chameleon includes

A schema document included via `xs:include` whose own `@targetNamespace` is
absent inherits the namespace of the including schema. `x:collect-schemas`
records the effective namespace in `$schemas?ns-by-uri` so downstream code
sees the same namespace it would see if the include had been "physically"
substituted.

### 7.3 Clark form as canonical key

All inter-component lookups use Clark form (`{ns-uri}localname`). Two
identical local names in different namespaces have distinct Clark forms;
unqualified names use `{}localname`. `x:clark` is the canonical Clark-form
function. It is the only correct argument to any of the key lookups.

## 8. Documentation processing

`xs:documentation` is rendered via one of two modes selected by the
`$doc-html` parameter:

- **`safe`** (default). The renderer walks the documentation subtree and
  copies only elements/attributes that pass an allowlist. The allowed
  elements roughly match a Markdown-rendered HTML set: `p`, `br`, `ul`,
  `ol`, `li`, `em`, `strong`, `code`, `pre`, `a`, `h1`–`h6`, `blockquote`,
  `figure`, `figcaption`, `img`, `table`/`thead`/`tbody`/`tr`/`th`/`td`,
  `details`, `summary`. Allowed attributes are limited to `id`, `class`,
  `title`, `lang`, `href` (on `a`), `src` and `alt` (on `img`), and
  `colspan`/`rowspan` (on `th`/`td`). `href` values pass `x:safe-href`:
  schemes `javascript:`, `data:`, `vbscript:`, `file:` are rejected
  (case- and whitespace-insensitive); only `http:`, `https:`, `mailto:`,
  `tel:`, and same-document fragments are admitted. Disallowed elements
  have their text content emitted; disallowed attributes are dropped.
- **`permissive`** (opt-in). The subtree is copied verbatim. This mode is
  documented as unsafe and is only appropriate when every schema author is
  trusted, because it can carry `<script>`, `on*=` handlers, etc.

Whitespace in `xs:documentation` is preserved as `<br/>` for explicit
newlines.
`xml:lang` propagates onto the wrapper element if present.

## 9. Identity and link strategy

### 9.1 Anchor format

Each rendered component card carries an `id` attribute formed as:

```
{kind-abbr}-{ns-id}-{name}
```

where `kind-abbr` is one of `el` (element), `ct` (complexType), `st`
(simpleType), `at` (attribute), `ag` (attributeGroup), `gr` (group), `no`
(notation). `ns-id` is empty (so the leading `-` collapses) for the primary
namespace, or `ns1`/`ns2`/… for secondary namespaces. `name` is the
component's local name. Redefined and overridden components get the
suffixes `-redefined` and `-overridden` respectively.

### 9.2 Cross-schema references

`x:component-link` is the single point of truth for type/element/group/etc.
references. It distinguishes three cases:

1. **XSD built-in** (`{http://www.w3.org/2001/XMLSchema}…`) — renders an
   external `<a href="https://www.w3.org/TR/xmlschema11-2/#…">` to the W3C
   datatype spec.
2. **User-defined and resolvable** — renders an internal anchor
   `<a href="#{x:anchor-for(qname)}">`.
3. **User-defined and unresolvable** — renders a `<code>` with a `title`
   attribute explaining the lookup failure.

### 9.3 Copy-link affordance

Every component card carries a `<button class="copy-link" data-anchor="…">`
that the JS turns into a click-to-copy URL.

## 10. `vc:*` rendering semantics

`vc:*` is the Conditional-Inclusion vocabulary defined in _XSD 1.1 Part 1_
Appendix F. A schema author writes `<xs:foo vc:minVersion="1.1">` to declare
that `<xs:foo>` should be skipped by 1.0 processors.

This stylesheet **displays** `vc:*` attributes but **does not filter** on
them. The output is intentionally a superset of every version: each
`vc:*`-decorated component carries:

1. A `badge--vc-decorated` in its component header.
2. A `component__vc-controls` panel listing the `vc:*` attribute(s) and their
   values as a `<dl>`.
3. An entry in the overview "XSD 1.1 features in use" card, which aggregates
   every `vc:*` occurrence anywhere in the schema collection (not just at the
   top level — but the overview card groups by component to avoid noise from
   nested annotations).

This decision means we do not need an active-version parameter and our
output is independent of how a real processor would interpret the schema.
The trade-off is that consumers of the documentation see all variants at
once; this is the right default for documentation but the wrong default for
runtime validation, and the README must be explicit about that.

## 11. Error handling

Two failure classes can occur in normal operation:

- **`doc()` failure on an `xs:import`/`xs:include` target.** The
  `xsl:try`/`xsl:catch` in `x:collect-schemas` records a diagnostic into
  `$schemas?errors`. The overview "Schemas" card surfaces the failed
  reference as a row with a red badge and the error message. The schema
  collection continues processing remaining references.
- **Unresolvable QName in a `@type`/`@base`/`@ref`/etc. attribute.**
  `x:component-link` renders the literal QName text as a `<code>` with a
  `title="referenced component not found"` attribute. The overview gains an
  "Unresolved references" diagnostic card if any are present.

No error condition aborts the run. The output always renders. The README
documents how to surface diagnostics during CI.

## 12. Security model

- **Documentation HTML sanitisation.** As described in §8. The `safe` mode
  is the default; `permissive` requires opt-in and is explicitly warned
  about in the README and stylesheet docblock.
- **No remote resource fetch.** The stylesheet calls `doc()` only on
  `schemaLocation` URIs from the input. Image/script/CSS references inside
  `xs:documentation` are emitted as `<img src="…">` / `<a href="…">` but no
  prefetch happens at transform time.
- **Deterministic output.** The renderer emits no timestamps, no random
  IDs, and no host-specific paths. Synthetic IDs from the `nsid`
  accumulator are stable across runs because the accumulator visits
  schemas in document order.
- **Output is single-file static HTML.** No `<script src="…">` to a third
  party; the JS lives under `base-href` and is the consumer's
  responsibility.

## 13. Parameter surface

Eight `xsl:param` declarations.

| Name             | Type         | Default       | Purpose                                                                                                                     |
| ---------------- | ------------ | ------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `title`          | `xs:string?` | `()`          | Page `<title>` and `<h1>`. Falls back to `xs:schema/@id`, then `"Schema: " + targetNamespace`, then `"XSD Documentation"`.  |
| `base-href`      | `xs:string`  | `'./assets/'` | URL prefix for `xsdstyle.css` and `xsdstyle.js`.                                                                            |
| `include-source` | `xs:boolean` | `true()`      | Emit the per-component XSD source `<details>` block.                                                                        |
| `doc-html`       | `xs:string`  | `'safe'`      | Documentation HTML mode. `safe` (allowlist) or `permissive` (verbatim).                                                     |
| `ui-lang`        | `xs:string`  | `'en'`        | BCP-47 tag for `<html lang="…">` and the chrome catalog lookup.                                                             |
| `xml-lang`       | `xs:string`  | `'en'`        | BCP-47 tag emitted as a `lang="…"` fallback on XSD-prose wrappers when no per-block `@xml:lang`.                            |
| `dir`            | `xs:string`  | `'auto'`      | Writing direction for `<html dir="…">`. `auto` infers `rtl` from `ui-lang` (ar/he/fa/ur/…), else `ltr`; or pass explicitly. |
| `noindex`        | `xs:boolean` | `false()`     | Emit `<meta name="robots" content="noindex">`.                                                                              |

No `xsd-version` parameter (see §10). No `theme` parameter (CSS variables +
`prefers-color-scheme` handle dark mode without a stylesheet param). No
multi-file output param (out of scope).

## 14. Assets contract

Two files under `assets/`:

- **`xsdstyle.css`** — BEM stylesheet. CSS custom properties drive the light /
  dark theme via `prefers-color-scheme`. Major blocks: `page-header`,
  `layout`, `sidebar` + `sidebar__search` + `sidebar__toc`, `content`,
  `overview` + `overview__facts` + `overview__xsd11` +
  `overview__default-open-content` + `overview__schemas`, `components` +
  `components--{kind}`, `component` + `component--{kind}` + `component__*`
  for header/doc/model/attrs/open-content/type-alternatives/vc-controls/see-also/source,
  `badge` + `badge--*` modifiers.
- **`xsdstyle.js`** — Vanilla, no dependencies, ~100 lines. Responsibilities:
  (a) on `DOMContentLoaded`, read `<script type="application/json" id="xsdoc-index">`
  and build an in-memory array; (b) wire the `.sidebar__search` input to
  filter visible TOC entries by substring against `name` and `doc-snippet`,
  with `<mark>` highlight in the result chrome; (c) show top-N (default 10)
  documentation-only hits in a `.sidebar__doc-matches` block under the TOC;
  (d) wire `.copy-link` buttons to copy `location.href + "#" + data-anchor`;
  (e) wire `.expand-all` / `.collapse-all` toggles to set every
  `<details open>` simultaneously; (f) keyboard shortcuts: `/` focuses the
  filter, `Esc` clears it.

The stylesheet emits `<link rel="stylesheet" href="{$base-href}xsdstyle.css">`
and `<script src="{$base-href}xsdstyle.js" defer></script>`. The action's
`entrypoint.sh` and the README's "Manual usage" example are responsible for
copying `assets/` next to the generated HTML.

## 15. Testing strategy

### 15.1 Layout

```
test/
├── xsdstyle.xspec   # XSpec unit tests for pure functions (55 scenarios)
└── fixtures/
    ├── xsd11-base.xsd
    ├── xsd11-features.xsd
    ├── open-content.xsd
    ├── inheritable.xsd
    └── vc-features.xsd
```

`xsdstyle.xspec` uses the standard XSpec pattern (nested `x:scenario`
with `x:call function="f:…"` and `x:expect select="…"`). End-to-end
verification — does the stylesheet produce valid HTML against a real
schema? — lives in `make smoke-test`, which renders the W3C XSD-of-XSDs
and validates the output with vnu.jar.

### 15.2 TDD order

1. **Pure helpers first** (cheap, drive design): `x:clark`, `x:resolve-qname`,
   `x:occurs`, `x:occurs-title`, `x:format-notQName`, `x:safe-href`,
   `x:xsd-true`, `x:vc-attrs`, `x:is-redefined`, `x:is-overridden`,
   `x:abbr`, `x:is-xs`, `x:anchor`.
2. **Schema-aware helpers** (`x:effective-open-content`, `x:inheritable-attrs`,
   `x:collect-schemas`) are exercised end-to-end via `make smoke-test` because
   they require a real schema context.

### 15.3 Fixture coverage

The original `test/fixtures/xsd11-features.xsd` covers most of XSD 1.1 but
lacks `openContent`, multi-attribute `@inheritable`, and the full `vc:*`
attribute set. Three new fixtures fill the gap and live alongside the
originals in `test/fixtures/`:

- `open-content.xsd` — own + default + mode="none" + inherited open content.
- `inheritable.xsd` — `@inheritable` on a base type, with a CTA element in
  a derived type to exercise inherited test-context surfacing.
- `vc-features.xsd` — every `vc:*` attribute (`minVersion`, `maxVersion`,
  `typeAvailable`/`Unavailable`, `facetAvailable`/`Unavailable`).

### 15.4 Makefile

`make test` runs every `test/*.xspec` via XSpec; `make smoke-test` renders
the W3C XSD-of-XSDs end-to-end and validates the HTML/CSS with vnu.jar.
Both should pass on every commit.

## 16. Open questions and known risks

These are documented here so they don't get lost in a chat history. They
should be revisited at the end of the implementation phase.

1. **`xs:override` chain depth.** Capped at one level (per the user's scope
   decision). A cycle guard is still required because override loops are
   spec-illegal but cheap to detect, and we'd rather report than infinite-
   loop on a malformed schema.
2. **CTA inherited-context display.** The renderer shows inheritable
   attributes from the _direct enclosing_ element type. If a deeper
   ancestor in the document tree also contributes, a "see ancestor types"
   link is emitted but the recursive walk is not done. This bounds output
   size; revisit if real-world schemas need transitive context.
3. **`vc:*` in nested positions.** `vc:*` is allowed on any XSD-namespace
   element. Component-level badges and panels reflect both top-level and
   nested usage. The overview "XSD 1.1 features in use" card aggregates by
   the _innermost named ancestor component_ to keep the list readable.
4. **JSON search-index snippet length.** Truncates documentation
   snippets to 240 chars.
5. **XSpec snapshot brittleness.** Integration tests assert narrow
   `x:context` selectors, not full-document equality. Negative assertions
   (e.g. "no open-content panel emitted for this component") use `count(...)=0`.
6. **Saxon-HE 13 vs older Saxon.** The Makefile and Dockerfile pin
   Saxon-HE 13. The new stylesheet's XSLT 3.0 idiom set is a strict subset
   of Saxon-HE 13's capabilities, but we should verify that
   `xsl:try`/`xsl:catch` and `xsl:iterate` are both available without
   licensed Saxon-EE (they are, per the Saxonica docs, but a CI smoke
   test against the Maven Central jar in `.tools/` is wise).
