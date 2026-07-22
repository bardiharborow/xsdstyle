# XSD Documentation Generator DOM Contract

This document defines the generated HTML DOM contract for the generator
specified in `docs/specification.md` and implemented according to
`docs/architecture.md`.

The specification is the product contract. The architecture describes the
internal model and rendering pipeline. This document describes the shape of the
HTML emitted by that pipeline. When documents disagree, the precedence is:

1. `docs/specification.md`
2. `docs/architecture.md`
3. this document

The DOM must contain all schema facts without JavaScript. CSS and JavaScript
may improve presentation and interaction, but they must derive from the
already-rendered DOM rather than from a separate schema-data payload.

Code examples in this document are representative and abbreviated. The class
names, IDs, data attributes, landmarks, reference states, and accessibility
rules are normative; literal whitespace, omitted sibling elements, and example
text are not.

The DOM contract is intentionally narrower than a pixel design. It defines the
semantic structure, stable selectors, state attributes, and accessibility
requirements that tests and assets may rely on. CSS may change visual
treatment, and JavaScript may add progressive state, but neither may require a
schema fact that is absent from the server-rendered HTML.

## 1. Goals

- Make the page useful immediately: title, schema overview, component
  navigation, and diagnostics are reachable without a splash screen.
- Keep semantic HTML as the source of truth for schema facts.
- Provide stable anchors for components, contextual constraints, diagnostics,
  and schema documents.
- Make reference states programmatically distinct: internal, built-in,
  external, and unresolved.
- Give CSS and JavaScript explicit hooks that are not the only carriers of
  meaning.
- Preserve accessibility under no-JavaScript, keyboard-only, screen-reader,
  high-contrast, and right-to-left interface conditions.
- Keep markup deterministic so output comparison tests can assert the rendered
  contract.

## 2. Design Principles

The DOM should be rendered from model records, not by letting presentation
templates rediscover global facts from raw XSD nodes. Raw source nodes remain
available for documentation, appinfo, local context, and source listings, but
component identity, references, diagnostics, backlinks, and feature summaries
should be represented by explicit records before rendering.

Use semantic elements first:

- `header` for global page chrome and component headers.
- `nav` for component navigation.
- `main` for schema content.
- `section` for overview, component-kind groups, diagnostics, and reusable
  fact blocks.
- `article` for each global component.
- `table`, `caption`, `thead`, `tbody`, `th`, and `td` for dense matrices.
- `dl`, `dt`, and `dd` for sparse metadata.
- `details` and `summary` for optional source and long auxiliary detail.

Use classes for styling families and `data-*` attributes for behavior or state.
No fact may exist only in a class name, color, icon, tooltip, or JavaScript
object.

Keep the markup testable. When a fact is useful to CSS or JavaScript, expose it
with stable text and, where useful, a stable `data-*` value. When a fact is
useful to readers, expose it as visible text or accessible text. A hook that
only works for one asset version is not part of the contract unless it is
listed in the JavaScript or CSS sections below.

Prefer additive changes. New blocks, classes, and data attributes may be added
when they expose new documented facts. Renaming or removing an existing hook is
a breaking DOM-contract change and should update stylesheet output, assets,
tests, and this document together.

## 3. Top-Level Page Shell

The page should use one stable shell:

```html
<html lang="..." dir="...">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <meta name="generator" content="xsdstyle ..." />
    <meta name="robots" content="noindex" />
    <title>...</title>
    <script>
      ...
    </script>
    <link rel="stylesheet" href=".../xsdstyle.css" />
    <script src=".../xsdstyle.js" defer></script>
  </head>
  <body>
    <a class="skip-link" href="#main">Skip to main content</a>
    <div hidden>
      <svg class="icon-sprite" aria-hidden="true">
        <symbol id="ico-expand" viewBox="0 0 16 16">...</symbol>
        ...
      </svg>
    </div>
    <header class="topbar">...</header>
    <div class="layout">
      <nav class="sidebar" aria-label="Components">...</nav>
      <main class="main" id="main" tabindex="-1">...</main>
    </div>
    <p id="copy-status" class="visually-hidden" role="status" aria-live="polite"></p>
    <script type="application/json" id="xsdoc-i18n">
      ...
    </script>
  </body>
</html>
```

Rules:

- `lang` comes from `interface-language`.
- `dir` comes from normalized `interface-direction`.
- The robots meta tag is emitted only when `robots-noindex` is true.
- The title text follows the title derivation rules in the specification.
- The early inline script may restore a stored theme preference only. It must
  not write schema content.
- The JSON script contains localized runtime UI strings only, not schema data.
- The hidden sprite defines each icon's geometry exactly once as a `<symbol>`;
  every icon site references it with a same-document `<svg><use href="#ico-…">`
  so repeated icons never duplicate path data. The `hidden` wrapper keeps the
  sprite out of layout even without CSS; it carries no content for readers.

## 4. Global Header

The header provides page identity and page-level controls.

```html
<header class="topbar">
  <div class="brand">
    <span class="brand__mark" aria-hidden="true">XSD</span>
    <span class="brand__title">...</span>
    <span class="brand__ns" title="Target namespace">...</span>
  </div>
  <div class="topbar__actions">
    <button class="iconbtn" type="button" data-toggle-all="all" data-state="closed">
      <svg class="ico-expand" aria-hidden="true"><use href="#ico-expand" /></svg>
      <svg class="ico-collapse" aria-hidden="true"><use href="#ico-collapse" /></svg>
      <span class="iconbtn__label">Expand all</span>
    </button>
    <button class="iconbtn theme-toggle" type="button" aria-label="Switch theme">
      <svg data-when="to-dark" aria-hidden="true"><use href="#ico-theme-dark" /></svg>
      <svg data-when="to-light" aria-hidden="true"><use href="#ico-theme-light" /></svg>
      <span class="iconbtn__label" data-when="to-dark">Dark</span>
      <span class="iconbtn__label" data-when="to-light">Light</span>
    </button>
  </div>
</header>
```

Rules:

- The title follows the `page-title` fallback rules from the specification.
- Namespace text is real text, not only a `title` attribute.
- Every button has a visible label, visually-hidden label, or `aria-label`.
- `data-toggle-all`, `data-state`, and `data-when` are JavaScript hooks only.
- Inline `<svg>` icons are decorative (`aria-hidden="true"`); which one shows is a
  pure CSS function of the `data-state` / `data-when` hook, so the icon stays
  correct without JavaScript. They carry no label and add no content. Each icon
  `<svg>` holds only a `<use>` reference into the hidden sprite (§3); the
  class / `data-when` hooks stay on the outer `<svg>` so CSS swapping and
  `currentColor` theming are unaffected.

## 5. Navigation

Navigation is a normal table of contents first and a filterable control when
JavaScript is available.

```html
<nav class="sidebar" aria-label="Components">
  <search class="nav-filter">
    <div class="nav-search" data-has-value="false">
      <svg aria-hidden="true"><use href="#ico-search" /></svg>
      <label class="visually-hidden" for="nav-filter-input">Filter components</label>
      <input
        id="nav-filter-input"
        type="search"
        autocomplete="off"
        spellcheck="false"
        placeholder="Filter components"
        aria-describedby="nav-filter-hint"
        aria-keyshortcuts="/ Escape"
      />
      <kbd class="nav-slash" aria-hidden="true">/</kbd>
      <button class="nav-clear" type="button" aria-label="Clear filter">Clear</button>
    </div>
    <p id="nav-filter-hint" class="visually-hidden">...</p>
    <p class="nav-result-note" role="status" aria-live="polite" hidden></p>
  </search>

  <div class="nav-group" data-kind="element">
    <button class="nav-group__head" type="button" aria-expanded="true">
      <span class="nav-group__swatch" aria-hidden="true"></span>
      <span class="nav-group__label">Elements</span>
      <span class="nav-group__count" data-total="12">12</span>
    </button>
    <ul class="nav-list">
      <li>
        <a class="nav-link" href="#el-Customer">
          <span class="nav-link__name">Customer</span>
          <span class="nav-link__hit" hidden>documentation match</span>
        </a>
      </li>
    </ul>
  </div>
</nav>
```

Rules:

- Navigation groups follow canonical component order: elements, complex types,
  simple types, attributes, attribute groups, model groups, notations.
- Each `href` points to an existing component article.
- `data-kind` uses the model component kind names: `element`, `complexType`,
  `simpleType`, `attribute`, `attributeGroup`, `group`, and `notation`.
- Filtering may hide unmatched DOM nodes visually. It must not remove schema
  content from the DOM.
- Filter text is derived from rendered component names, QNames, namespaces,
  kind labels, and visible documentation text.
- The leading `<svg>` and the `<kbd class="nav-slash">/</kbd>` hint are decorative
  (`aria-hidden`); the `kbd` mirrors `aria-keyshortcuts="/ Escape"` on the input and
  CSS hides it on focus or once the field has a value. Neither is required to read
  or use the filter without JavaScript.

## 6. Main Content Order

The main region should be deterministic:

```html
<main class="main" id="main" tabindex="-1">
  <div class="main__inner">
    <section class="overview" id="overview" aria-labelledby="ov-title">...</section>
    <section class="kind-section" id="kind-el" aria-labelledby="kind-el-title">...</section>
    <section class="kind-section" id="kind-ct" aria-labelledby="kind-ct-title">...</section>
    <section class="kind-section" id="kind-st" aria-labelledby="kind-st-title">...</section>
    <section class="kind-section" id="kind-at" aria-labelledby="kind-at-title">...</section>
    <section class="kind-section" id="kind-ag" aria-labelledby="kind-ag-title">...</section>
    <section class="kind-section" id="kind-gr" aria-labelledby="kind-gr-title">...</section>
    <section class="kind-section" id="kind-no" aria-labelledby="kind-no-title">...</section>
    <section class="diagnostics" id="diagnostics" aria-labelledby="diagnostics-title">...</section>
  </div>
</main>
<footer class="colophon">...</footer>
```

The colophon footer is a sibling landmark after `main`, not part of the main
content region.

Empty component-kind sections may be omitted. The diagnostics section may be
omitted only when there are no diagnostics.

Main-content order must not change based on component counts, feature presence,
or JavaScript availability. Optional sections may be omitted when empty, but
sections that are present keep the canonical order above.

## 7. Overview

The overview is the map of the schema collection and must be useful before a
reader reaches component details.

```html
<section class="overview" id="overview" aria-labelledby="ov-title">
  <p class="eyebrow">Schema reference</p>
  <h1 class="overview__title" id="ov-title">...</h1>

  <section class="block" aria-labelledby="overview-doc-title">...</section>

  <section class="block" aria-labelledby="overview-metadata-title">
    <h2 class="block__title" id="overview-metadata-title">Schema metadata</h2>
    <dl class="proplist">...</dl>
  </section>

  <section class="block" aria-labelledby="overview-defaults-title">...</section>
  <section class="block" aria-labelledby="overview-features-title">...</section>
  <section class="block" aria-labelledby="schema-documents-title">...</section>
</section>
```

Required overview content:

- Primary document URI when available.
- Declared and effective target namespace information.
- Schema metadata named in the specification. An empty-valued metadata
  attribute renders the localized `(none)` marker inside its `dd/code`, never
  an empty element.
- Schema-level annotation, documentation, and appinfo.
- Default attributes and default open content when present.
- XSD 1.0 and XSD 1.1 feature summaries.
- Schema collection rows for the primary document and every include, import,
  redefine, and override edge.
- Load, cycle, and unresolved-reference diagnostic summaries.

When `documentation-markup` is `permissive`, the top of the overview carries a
visible notice identifying the mode as unsafe for untrusted schemas:

```html
<p class="notice notice--unsafe" role="note" data-code="permissive-markup">...</p>
```

Schema collection rows should expose both source and model facts. There are
two row families sharing the `schema-row` class: one row per collected schema
document, and one row per composition edge.

Per-document rows describe each collected schema document instance:

```html
<div class="schema-row" id="schema-doc-s1" data-document-id="s1" data-status="loaded">
  <span class="schema-row__rel" data-rel="primary">primary</span>
  <span class="schema-row__uri">schema.xsd</span>
  <span class="schema-row__declared-ns">declared: ...</span>
  <span class="schema-row__effective-ns">effective: ...</span>
  <span class="schema-row__version"
    >Version: <code dir="ltr"><bdi>1.2.3</bdi></code></span
  >
  <span class="schema-row__status">loaded</span>
</div>
```

Per-edge rows describe each authored `xs:include`, `xs:import`, `xs:redefine`,
or `xs:override` declaration:

```html
<div class="schema-row" id="schema-edge-1" data-status="loaded">
  <span class="schema-row__in">in <code dir="ltr">schema.xsd</code></span>
  <span class="schema-row__rel" data-rel="include">include</span>
  <span class="schema-row__uri">common.xsd</span>
  <span class="schema-row__declared-ns">namespace: ...</span>
  <span class="schema-row__status">loaded</span>
</div>
```

Rules:

- Document rows use `id="schema-doc-s{n}"`, carry `data-document-id`, and use
  `data-rel` values `primary` or `reachable`. Component "defined in" links
  point at these IDs.
- Edge rows use `id="schema-edge-{n}"`, carry no `data-document-id`, and use
  `data-rel` values `include`, `import`, `redefine`, or `override`. The
  `schema-row__in` span names the declaring document.
- `schema-row__version` appears in both row families whenever the (loaded)
  schema document declares `@version`; the value is code-like and
  bidi-isolated.
- Edge rows without a `schemaLocation` (namespace-only imports) show a
  `not-requested` status rather than a load failure.
- When the composition declaration carries an `xs:annotation`, the edge row
  renders its documentation and appinfo after the fact spans, using the
  standard `doc is-clampable` / `doc__body` structure from §14.
- Displayed URIs are relativized against the primary schema directory.

Chameleon includes must distinguish declared no-namespace source from the
effective namespace used for component identity.

## 8. Component Sections

Each kind section groups global component articles.

```html
<section class="kind-section" id="kind-el" aria-labelledby="kind-el-title">
  <div class="section-head">
    <p class="eyebrow">12 components</p>
    <h2 id="kind-el-title">Elements</h2>
  </div>
  <article class="cmp" id="el-Customer" data-kind="element" data-name="Customer">...</article>
</section>
```

Rules:

- Sections use canonical component order.
- Component article order is effective namespace, then alphabetical by name
  (case-insensitive primary key, case-sensitive secondary key), with source
  order as the final tiebreak — the same ordering as navigation.
- Article IDs follow the anchor contract from the architecture:
  `{kind-abbreviation}-{namespace-id}-{local-name}` with deterministic suffixes
  for redefined, overridden, or otherwise colliding components. The primary
  namespace uses an empty namespace ID, so its anchors collapse to
  `{kind-abbreviation}-{local-name}` (`el-Customer`); secondary namespaces use
  `ns1`, `ns2`, … in first-seen collection order (`el-ns1-Customer`).

## 9. Component Article Shell

Every global component uses the same article shell so scanning and testing are
consistent.

```html
<article
  class="cmp"
  id="ct-Address"
  aria-labelledby="ct-Address-name"
  data-component-id="ct-Address"
  data-kind="complexType"
  data-name="Address"
  data-clark="{urn:example}Address"
  data-doc="postal address"
>
  <header class="cmp__head">
    <div class="cmp__id">
      <div class="cmp__titleline">
        <span class="kind" data-kind="complexType">complex type</span>
        <h3 class="cmp__name" id="ct-Address-name"><bdi>Address</bdi></h3>
        <div class="flags">
          <span class="flag" data-flag="mixed">mixed</span>
          <span class="flag" data-flag="xsd11">XSD 1.1 feature</span>
        </div>
      </div>
      <code class="cmp__fqn" dir="ltr"><bdi>{urn:example}Address</bdi></code>
      <div class="cmp__meta">
        <span>Defined in <a href="#schema-doc-s1">schema.xsd</a></span>
      </div>
    </div>
    <div class="cmp__actions">
      <button class="iconbtn" type="button" data-copy-link="ct-Address" title="Copy link" aria-label="Copy link">
        <svg class="copybtn__link" aria-hidden="true"><use href="#ico-copy-link" /></svg>
        <svg class="copybtn__check" aria-hidden="true"><use href="#ico-copy-check" /></svg>
        <span class="copybtn__tip" aria-hidden="true">Copied</span>
      </button>
    </div>
  </header>

  <div class="cmp__body">...</div>
</article>
```

The head flag set is `abstract`, `mixed`, `nillable`, `redefined`,
`overridden`, and `xsd11` (present when the component uses any XSD 1.1
construct). Versioning annotations get their own per-component panel rather
than a head flag. `aria-labelledby` points at the heading so the article
landmark is named.

Rules:

- The component heading is the article's accessible name.
- `data-component-id` may carry the internal model ID, but links must use the
  stable HTML `id`.
- `data-doc` may duplicate normalized visible documentation for filtering. It
  must not contain documentation absent from the visible DOM.
- Flags use readable text. Color and icon shape are secondary.
- Component names, Clark QNames, and other code-like values are wrapped in
  `<bdi>` (usually inside a `dir="ltr"` code container) so they stay readable
  under RTL page chrome.
- Every copy-link target is an existing ID and reports through `#copy-status`.
- On a successful copy the JS toggles `.is-copied` on the button for ~1.4s; CSS
  then swaps the link icon for the `.copybtn__check` mark and raises the
  `.copybtn__tip` bubble. Both are `aria-hidden` — the spoken confirmation is the
  `#copy-status` live region, so the visual cue never double-announces.

## 10. Reusable Blocks

Use `section.block` for related facts inside overview and component articles:

```html
<section class="block">
  <h4 class="block__title" id="ct-Address-attrs-title">Attributes</h4>
  ...
</section>
```

Blocks inside component articles carry no accessible name (`aria-labelledby`),
so they are not region landmarks: their titles repeat across every article
("Documentation", "Properties", "See also", …) and hundreds of identically
named landmarks would defeat landmark navigation. In-article structure is
navigated by the heading hierarchy instead; the `block__title` heading keeps
its stable `{anchor}-…-title` id. Named landmarks exist only at page level —
the overview (and its uniquely named blocks), the kind sections, and the
diagnostics section.

Use `dl.proplist` for sparse properties:

```html
<dl class="proplist">
  <div>
    <dt>Base type</dt>
    <dd><a class="xref xref--int" href="#ct-Base">Base</a></dd>
  </div>
</dl>
```

A named simple type's "Simple type definition" proplist opens with a Variety
row (`dd[data-variety]`, values `atomic|list|union|unknown|unspecified`) and,
when the source carries an `xs:restriction`, `xs:list`, or `xs:union` child, a
Derived by row (`dd[data-derivation]`, values `restriction|list|union`). The
row texts are localized while the `data-*` values are stable vocabulary; for a
pure list or union type the two rows read the same word, and they diverge when
a restriction constrains a list or union base.

Anonymous simple types skip the proplist in favor of a compact headline that
leads with the derivation keyword:

```html
<p class="inline-def" data-derivation="restriction" data-variety="atomic">
  <span class="chip" data-derivation="restriction">restriction</span>
  <span class="inline-def__of">of</span>
  <a class="xref xref--int" href="#st-Code">Code</a>
</p>
```

Named operand types (`@base`, `@itemType`, `@memberTypes` tokens) render as
references in the headline; anonymous operand types recurse below it in their
usual `inline-type--base|item|member` wrappers, followed by the facet table.
An anonymous simple type with no derivation child keeps the localized
"Anonymous simple type." paragraph and the variety proplist, so the
"not specified in source" state stays visible.

Use tables for dense repeated facts:

```html
<div class="tbl-wrap">
  <table class="tbl">
    <caption>
      Attribute uses for Address
    </caption>
    <thead>
      <tr>
        <th scope="col">Name</th>
        <th scope="col">Type</th>
        <th scope="col">Use</th>
      </tr>
    </thead>
    <tbody>
      ...
    </tbody>
  </table>
</div>
```

Captions stay in the markup as the table's accessible name but are visually
hidden by the stylesheet; the block heading above the table carries the
visible label.

Complex-type content-model blocks open with an explicit classification line:

```html
<p class="content-type" data-content-type="element-only" data-open="true">element-only content · open</p>
```

`data-content-type` is one of `empty`, `simple`, `element-only`, or `mixed`;
`data-open` reflects whether the type receives effective open content (own
`xs:openContent` or applicable schema-level default open content — never for
simple-content types).

Use `.tree` for content models:

```html
<div class="tree" role="list">
  <div class="tree__node" role="listitem">
    <div class="tree__row">
      <span class="chip chip--comp" data-comp="sequence">sequence</span>
      <span class="occurs" title="Occurs 1 to many" role="img" aria-label="Occurs 1 to many">1..*</span>
    </div>
    <div class="tree__children" role="list">...</div>
  </div>
</div>
```

The particle walk behind `.tree` reaches through `xs:complexContent` and
`xs:simpleContent` derivation bodies and includes top-level `xs:group`
references, so a type whose only particle is a group reference still gets a
tree. When a complex type has no particles at all, the `.tree` container is
omitted entirely — an empty `<div class="tree">` is never emitted.

Occurrence markers carry `role="img"` with the expanded reading in
`aria-label`, so the compact `1..*` notation stays screen-reader friendly; the
`title` duplicates that reading for pointer users and is never the only
carrier.

An element particle with a declared `@type` renders the reference after a
muted colon separator (`<span class="tree__sep">:</span>`), reading as
`name : Type`.

Particle rows annotate local declaration facts with `chip` spans keyed by
`data-particle-flag`, distinct from the component-level `data-flag` badges:

```html
<span class="chip" data-particle-flag="nillable">nillable</span>
<span class="chip" data-particle-flag="default"
  >default=<code dir="ltr"><bdi>0</bdi></code></span
>
```

Recognized values are `nillable`, `abstract`, `default`, `fixed`, `form`,
`block`, `final`, and the XSD 1.1 local `targetNamespace`.

Wildcard rows (in content-model trees and anyAttribute table rows) render
namespace/notNamespace/notQName values through token spans: `##`-tokens as
`<code class="wildcard-token">` carrying `data-wildcard-attr`
(`namespace`/`notNamespace`/`notQName`), `data-wildcard-kind`
(`element`/`attribute`), and a `title` that explains the token as it applies
to that attribute and wildcard kind; explicit namespace URIs as
`<code class="wildcard-ns">`. Every displayed wildcard also carries
`<span class="wildcard-provenance" data-provenance="...">` with one of
`direct`, `open-content`, `default-open-content`, or `attribute-group`.
(A `base-type` origin cannot occur: the renderer is source-honest, so a
wildcard inherited from a base type renders in the declaring type's own
section.) Wildcard annotations render inside the wildcard's `tree__node` or
table row.

Anonymous inline types render where they occur inside a
`div.inline-type` wrapper, with a context modifier such as
`inline-type--attribute` when nested in an attribute use; inline facet tables
add `inline-facets` to their `tbl-wrap`. Anonymous complex types render the
same derivation proplist, content-type classification line, content-model
tree, attribute-use table, and assertions block as named complex types; their
nested block headings and row IDs are anchored by the owner's local anchor
(`{owner-anchor}-{position-path}-...`). Table captions that would name the
component fall back to the localized phrases `anonymous complex type` /
`anonymous simple type` when the owner has no name, e.g.
`Attribute uses for anonymous complex type`.

Every `.tbl-wrap` table wrapper is a keyboard tab stop: it carries
`tabindex="0"`, `role="group"`, and an `aria-label` whose text mirrors the
table's `<caption>`. Table wrappers scroll horizontally when a table overflows,
and without the tab stop a keyboard-only user could not scroll a table that
contains no focusable content. `role="group"` (not `region`) keeps the wrapper
out of the landmark list.

A facet row's ID cell contains a
`<code dir="ltr"><bdi>` wrapper only when the facet declares `@id`; it stays
empty otherwise. A facet row's Fixed cell renders
`<span class="flag" data-flag="fixed">` when `@fixed` is true, the raw
attribute value for an explicit non-true value, and stays empty when the
attribute is absent; pattern-step rows keep the raw space-joined `@fixed`
values, since `xs:pattern` cannot legally carry the attribute and that cell
is pure source disclosure. Attribute-use tables mark the use
value with a `use` span and modifier, for example
`<span class="use use--required">required</span>`.

Attribute tables expand referenced attribute groups: each `xs:attributeGroup`
reference emits a header row (row header `attribute group`, the reference in
the Type/ref cell, and a muted note that the group's attributes follow),
followed by one ordinary attribute row per attribute the group introduces,
recursively through nested group references. Rows introduced by a group carry
`data-via="{clark-name-of-group}"` and append
`<span class="attr-via muted">via <a class="xref xref--int" …>Group</a></span>`
to the Name cell. When expansion would revisit a group already being expanded
(a cycle) or the reference is ambiguous, the header row's note cell instead
carries `data-code="recursive-expansion-stopped"` with a "not expanded"
message and no attribute rows are emitted for that reference. Local attribute
declarations show `@form` and the XSD 1.1 `@targetNamespace` as
`data-particle-flag` chips in the Name cell, and `anyAttribute` rows include a
Documentation cell rendering the wildcard's annotation.

The Inheritable and Documentation columns are conditional per table: the
Inheritable header/cells appear only when some displayed attribute (directly or
via group expansion) authors `@inheritable`, and the Documentation header/cells
appear only when some displayed attribute or wildcard annotation renders
content. Wide cells span the trailing columns accordingly: group header/stop
cells use `colspan="2 + inheritable? + documentation?"`, and the `anyAttribute`
processContents cell uses `colspan="2 + inheritable?"`. An attribute use with
no `@type`, no `@ref`, and no inline type renders
`<span class="muted attr-no-type">no declared type</span>` in the Type/ref
cell.

Pattern facets render one row per restriction step rather than one row per
facet, because patterns within a step are alternatives (OR) while steps
combine as conjoined constraints (AND). Each step row carries
`data-restriction-step="{n}"` (steps numbered in document order) and its ID is
`{owner-anchor}-facet-pattern-step-{n}`; same-step pattern values are joined
by `<span class="facet-or">or</span>`, and a muted `step {n} of {m}` label
appears in the facet-name cell when more than one step contributes patterns.
The XSD 1.1-only facets (`assertion`, `explicitTimezone`) append
`<span class="flag" data-flag="xsd11">` to their facet-name cell, and
assertion facet rows show `@xpathDefaultNamespace` in a muted line under the
test expression.

Use disclosure only for optional detail, not for required facts:

```html
<details class="disclosure" data-kind-block="source">
  <summary>Source <span class="src-lang">xml</span></summary>
  <pre class="src" dir="ltr"><code>...</code></pre>
</details>
```

`data-kind-block` values in use are `source` for source listings and
`appinfo` for the inert appinfo disclosure; the expand/collapse-all control
targets both.

Other recurring block-level classes:

- `featuregroup` / `featuregroup__title` and `ul.featurelist[data-version]`
  wrap the overview's XSD 1.0 and 1.1 feature summaries.
- The derivation chain renders as `deriv__node` items (with `--ancestor` /
  `--descendant` modifiers, `deriv__name`, `deriv__rel`, and nested
  `deriv__children` lists); the component being viewed carries `is-this`,
  `aria-current="location"`, and a `deriv__this-tag` label.
- `see-also__group` wraps each relation family (heading plus list) inside the
  See also block.
- `component__attrs-inherited` and `type-alternatives__inherited` (with its
  `type-alt-note` explanation) mark attributes and type alternatives that are
  declared on the type but only available to derived contexts; both share the
  `attrs-inherited__list` list class.
- `inline-marker` labels anonymous inline definitions in tables and trees.
- `wildcard-token`, `wildcard-provenance[data-provenance]`, and the
  `data-wildcard-attr` / `data-wildcard-kind` attributes carry wildcard token
  semantics (the architecture describes the provenance values).

## 11. Cross-References

Reference records should render into distinct markup states:

```html
<a class="xref xref--int" href="#ct-Address"><bdi>Address</bdi></a>
<a
  class="xref xref--ext xref--builtin"
  href="https://www.w3.org/TR/xmlschema11-2/#string"
  rel="external noopener noreferrer"
  target="_blank"
  ><bdi>xs:string</bdi></a
>
<span class="xref xref--external" tabindex="0"><bdi>ex:RemoteType</bdi></span>
<span class="xref xref--unresolved" tabindex="0" aria-describedby="diag-unresolved-1"><bdi>missing:Type</bdi></span>
```

The four markup states realize the model's `resolved`, `builtin`, `external`,
and `unresolved` reference states; they map onto the specification's three
display states, with `external` and `unresolved` sharing the visible-non-link
treatment while staying programmatically distinct.

Rules:

- Internal links point to generated anchors.
- Built-in and specification links use external anchors with
  `rel="external noopener noreferrer"` protection for the new browsing
  context. Built-ins that exist only in XSD 1.1 are followed by an adjacent
  `<span class="flag" data-flag="xsd11">XSD 1.1</span>` marker.
- External references identify known namespaces outside the loaded collection
  when no local target exists.
- Unresolved references stay visible, are keyboard discoverable, and link to a
  diagnostic when possible.
- Reference text is bidi-isolated with `<bdi>` in every state.
- The visible text preserves the authored lexical QName where useful; resolved
  metadata can be provided in adjacent text or labels.
- The external and unresolved spans carry `tabindex="0"` and a localized
  `title` explaining the state. Unresolved spans additionally carry
  `aria-describedby="diag-unresolved-{n}"` pointing at their diagnostic list
  entry whenever the marker's source attribute appears in the unresolved-scan
  (attributes rendered outside that scan, such as wildcard `notQName` tokens,
  stay focusable but undescribed).

## 12. Contextual Constructs

Contextual records render inside their owning component or overview block. They
do not get top-level component sections, but important constraints should still
have stable anchors where backlinks or diagnostics may point.

Recommended IDs:

- Identity constraints: `{owner-anchor}-{k|kr|u}-{name}` (kind abbreviation
  for key/keyref/unique). Ref-only constraints (XSD 1.1 `@ref`, no `@name`)
  use `ref-{sanitized-ref}` as the name part, with a deterministic
  sibling-count suffix for collisions. The identity-constraint table includes
  a Documentation column, and an `@ref` renders in the Name cell as an
  internal `xref--int` link to the referenced constraint's row when
  resolvable, or an `xref--unresolved` span otherwise. The Kind cell's row
  header wraps the constraint's local-name in
  `<span class="chip" data-ic-kind="key|keyref|unique">`; the text is XSD
  vocabulary and is not localized. The Fields cell renders `ul.ic-fields`
  with one `li > code[dir="ltr"]` per `xs:field` in source order — a
  single-field constraint still renders the list, and a field-less
  constraint leaves the cell empty (no empty `ul`).
- Assertions: `{owner-anchor}-assert-{source-order}`.
- Type alternatives: `{owner-anchor}-alt-{source-order}`.
- Facets: `{owner-anchor}-facet-{facet-name}-{source-order}`.
- Wildcards: `{owner-anchor}-wildcard-{source-order}`.
- Diagnostics: `diag-{code}-{source-order}` or the diagnostic record ID.

Contextual renderers must preserve source order when order is semantically
meaningful, especially type alternatives, particles, repeated facets, and
assertions.

## 13. Diagnostics

Diagnostics are page content and should be linkable.

```html
<section class="diagnostics" id="diagnostics" aria-labelledby="diagnostics-title">
  <h2 id="diagnostics-title">Diagnostics</h2>
  <ol class="diagnostic-list">
    <li id="diag-unresolved-1" class="diagnostic" data-severity="warning" data-code="qname-unresolved">
      <p class="diagnostic__summary">QName reference not resolved.</p>
      <p class="diagnostic__context">In <a href="#ct-Address">Address</a>, attribute <code>@base</code>.</p>
    </li>
  </ol>
</section>
```

Rules:

- Diagnostics are ordered by document, source order, then diagnostic code.
- Each diagnostic has a stable ID.
- Diagnostic links are bidirectional when possible: the diagnostic identifies
  its source context, and the source context links or describes the diagnostic.
- The diagnostics section is not the only place diagnostics appear; relevant
  overview rows, component articles, or unresolved references should link to
  the diagnostic.
- Wording should describe documentation behavior: "not loaded", "not
  resolved", "not expanded", or "not recognized".

## 14. Documentation and Appinfo

`xs:documentation` and `xs:appinfo` are untrusted source content.

Documentation blocks should render as:

```html
<div class="doc is-clampable" lang="en" dir="auto">
  <div class="doc__body">
    <span
      class="component__doc-lang"
      role="img"
      title="Documentation language: en"
      aria-label="Documentation language: en"
      >en</span
    >
    ...
  </div>
  <button class="doc__toggle" type="button" data-more="Show more" data-less="Show less" hidden>Show more</button>
  <a class="component__doc-source" href="..." aria-label="Documentation source">Source</a>
</div>
```

Rules:

- Preserve author-supplied `xml:lang`.
- Use `documentation-language` when no `xml:lang` is present.
- The full documentation text is always present in `doc__body`; clamping is a
  presentational overflow treatment, never a content cut.
- `doc__body`, the `is-clampable` modifier, and the `doc__toggle` button are
  emitted only when the documentation element has renderable content
  (non-whitespace text or element children). A link-only block (bare `@source`)
  renders as `div.doc` containing just the `component__doc-source` anchor; a
  block with neither content nor a usable `@source` renders nothing. The
  section heading is unaffected.
- In safe mode, whitespace at the very start and end of a documentation block
  is treated as authoring indentation and trimmed; interior whitespace and
  line breaks are preserved. Permissive mode copies content verbatim.
- The `doc__toggle` button is pre-authored with localized `data-more` and
  `data-less` labels and starts `hidden`. JavaScript reveals it only when the
  prose actually overflows, toggling `is-clamped` on the block; without
  JavaScript the prose renders fully expanded.
- The `component__doc-lang` badge appears only when the block carries an
  authored `xml:lang`, with its expansion in `aria-label`.
- The `component__doc-source` link appears only when `xs:documentation/@source`
  survives safe-URL filtering, and carries a localized `aria-label` expanding
  its terse visible text.
- Safe mode promotes only allowed no-namespace or XHTML elements.
- Safe mode removes executable content, event handlers, unsafe links, and
  schema-authored IDs that could collide with generated anchors.
- Unsupported elements preserve readable text where possible.
- Appinfo renders as inert structured/source-like content and is never
  executed.

## 15. Source Listings

Source listings are optional and controlled by `show-source`.

```html
<details class="disclosure" data-kind-block="source">
  <summary>XSD source</summary>
  <pre class="src" dir="ltr"><code>...</code></pre>
</details>
```

Rules:

- Source listings supplement structured rendering. They must not be the only
  place a required fact appears.
- XML remains text, selectable, escaped, and left-to-right.
- Syntax highlighting spans may be added, but text content must preserve the
  source fragment.
- The fragment root carries only the namespace declarations the fragment uses
  (see the specification's source-rendering rules); unused in-scope prefixed
  declarations are not re-emitted.

## 16. JavaScript Contract

The script is an enhancement layer over already complete HTML. It may add
state, affordances, and live feedback, but it must not fetch, synthesize, or
reinterpret schema facts. All selectors below are part of the asset contract:
if the stylesheet changes one, the JavaScript and DOM tests must change in the
same commit.

JavaScript reads these pre-authored hooks:

| Hook                                 | Purpose                                                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `.theme-toggle`                      | Toggle client-side theme preference.                                                                    |
| `#nav-filter-input`                  | Component filter input.                                                                                 |
| `.nav-search`                        | Filter field wrapper carrying `data-has-value`.                                                         |
| `.nav-clear`                         | Clear the component filter.                                                                             |
| `.nav-result-note`                   | Live filter status.                                                                                     |
| `.nav-group` / `.nav-group__head`    | Collapsible navigation group and its toggle.                                                            |
| `.nav-group__count`                  | Per-group count; `data-total` remembers the full count.                                                 |
| `.nav-link__hit`                     | Badge shown when a match came from metadata, not name.                                                  |
| `.cmp[data-kind][data-name]`         | Search/filter target; `data-clark`, `data-doc`, and the visible localized `.kind` label feed the index. |
| `.nav-link[href]`                    | Navigation target.                                                                                      |
| `[data-copy-link]`                   | Copy component permalink.                                                                               |
| `#copy-status`                       | Copy feedback live region.                                                                              |
| `[data-toggle-all]`                  | Expand/collapse `details.disclosure[data-kind-block]`.                                                  |
| `.iconbtn__label`                    | Swappable label inside toggle buttons.                                                                  |
| `.doc.is-clampable` / `.doc__toggle` | Clampable documentation block and toggle with localized `data-more` / `data-less` labels.               |
| `#xsdoc-i18n`                        | Localized runtime strings only.                                                                         |

JavaScript writes only presentation state back to the DOM:

- `data-theme` on `<html>` and `aria-pressed` on `.theme-toggle`; the choice
  persists in the `xsdstyle-theme` localStorage key read by the inline
  bootstrap.
- `hidden` on filtered components, nav links, and empty nav groups;
  `data-has-value` on `.nav-search`; live counts in `.nav-group__count`;
  result text in `.nav-result-note`.
- `aria-expanded` on `.nav-group__head` and `is-collapsed` on `.nav-group`.
- `is-copied` on a copy button for about 1.4 seconds after a successful copy.
- `data-state` on `[data-toggle-all]`; the label is swapped only when the
  button provides `data-label-expand` / `data-label-collapse` alternates.
- `is-clamped` on clampable documentation blocks; the toggle's `hidden` state
  once overflow has been measured.
- Scroll-spy: `is-active` and `aria-current="true"` on the `.nav-link` whose
  component is in view.

JavaScript must not fetch schema data, evaluate schema constraints, or create
schema facts absent from the HTML.

## 17. CSS Contract

CSS may style these semantic families:

- Shell: `topbar`, `layout`, `sidebar`, `main`, `main__inner`.
- Navigation: `nav-filter`, `nav-search`, `nav-group`, `nav-list`,
  `nav-link`.
- Component articles: `cmp`, `cmp__head`, `cmp__body`, `cmp__actions`.
- Facts: `block`, `proplist`, `tbl`, `tree`, `deriv`,
  `featurelist`, `inline-type`, `inline-def`, `inline-facets`,
  `ic-fields`, `schemas`, `schema-row`.
- State: `kind`, `flag`, `chip`, `xref`, `occurs`, `use` (with modifiers such
  as `use--required`), `diagnostic`.
- Source and documentation: `doc`, `disclosure`, `src`, `tok-*`.

CSS must preserve the textual representation of facts. Hue may reinforce
component kinds, warnings, unresolved references, or versioning features, but
it must not be the only distinction.

## 18. Responsive and Directional Behavior

Desktop layout should use a top bar, sidebar, and main content column. Narrow
screens should stack navigation before content or use a non-modal navigation
region. The page must remain usable without a drawer script.

Tables may scroll inside `.tbl-wrap`. Code, QName, namespace URI, XPath, regex,
and source values may wrap or scroll in their own containers, but they must not
overlap controls.

The page direction follows `interface-direction`. Code-like schema content
should use `dir="ltr"` or bidi isolation so namespace braces, prefixes,
operators, and punctuation remain readable in right-to-left interfaces.

## 19. Testing Implications

DOM tests should assert the observable contract:

- The no-JavaScript page contains overview, navigation, component articles,
  diagnostics, and source blocks when enabled.
- All component anchors follow the deterministic anchor shape.
- Navigation links point to existing article IDs.
- Reference states use distinct classes and accessible text.
- Unresolved references point to diagnostics when diagnostic records exist.
- Tables have captions or labelled headings and scoped headers.
- Buttons, filters, and copy controls have accessible names.
- Schema-collection document and edge rows carry their IDs, `data-rel` values,
  and per-row facts (`schema-row__in`, `schema-row__version`).
- Documentation blocks use the `doc is-clampable` / `doc__body` / `doc__toggle`
  structure with the full text present.
- Names, QNames, and code-like values are bidi-isolated with `<bdi>`.
- Runtime JSON contains UI strings only.
- Search derives from visible component DOM, not a schema-data payload.
- RTL interfaces keep code-like schema content readable.

These tests should be added alongside model and rendering tests from
`docs/architecture.md` rather than replacing them.
