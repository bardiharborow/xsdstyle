# XSD Documentation Generator Architecture

This document describes the implementation architecture of the generator
specified in `docs/specification.md`.

The specification is the product contract. This architecture describes how the
stylesheet should satisfy that contract in a maintainable way. When the two
documents disagree, `docs/specification.md` wins.

The document has two audiences:

- Contributors changing `xsdstyle.xsl`, who need the phase boundaries,
  record shapes, and rendering invariants.
- Reviewers comparing behavior to the product contract, who need to know which
  implementation choices are intentional and which are current gaps.

The default distribution remains a single stylesheet. The "layers" below are
organizational boundaries inside that file, not separate modules or packages.

This document describes the target architecture, not a waiver from the product
contract. Where the current stylesheet has not reached the target, section 19
names the gap explicitly. Do not soften earlier sections to match a temporary
implementation limitation; fix the limitation or keep it listed as a gap.

When a behavior change affects what users see, update the specification first.
When a markup or asset hook changes, update the DOM contract in the same
change. Architecture changes should explain where a fact is produced, how it is
keyed, and which renderer consumes it.

## 1. Architectural Goals

The generator should be built around a small number of explicit phases:

1. Normalize parameters.
2. Collect the schema document graph.
3. Build a documentation model from the loaded schemas.
4. Build indexes and diagnostics over that model.
5. Render deterministic, accessible HTML.
6. Let CSS and JavaScript progressively enhance the already complete HTML.

The most important architectural rule is that rendering should not directly
discover facts by repeatedly scanning raw schema nodes. Raw XSD nodes remain
available for source rendering and local context, but cross-reference
resolution, diagnostics, anchors, schema membership, and feature summaries
should be driven by model records or shared indexes.

This keeps the behavior understandable as coverage grows from simple component
cards to the full XSD 1.0 and XSD 1.1 surface.

## 2. Implementation Shape

The default distribution should remain one top-level XSLT 3.0 stylesheet,
`xsdstyle.xsl`, with no required package graph. Conceptually, however, the
stylesheet should be organized as layers:

| Layer         | Responsibility                                                                                 |
| ------------- | ---------------------------------------------------------------------------------------------- |
| Configuration | Public parameters, parameter validation, i18n message catalogs, static XSD catalogs.           |
| Collection    | Load the primary schema and reachable schema documents.                                        |
| Model         | Convert loaded documents into schema, component, reference, and diagnostic records.            |
| Indexes       | Provide namespace-aware lookup, backlinks, feature summaries, and cycle guards.                |
| Rendering     | Emit overview, navigation, component sections, contextual constructs, diagnostics, and source. |
| Assets        | Provide optional CSS and dependency-free JavaScript enhancement.                               |

`xsl:mode` should separate rendering concerns. `xsl:function` should handle pure
helpers and model/index lookup. `xsl:key` may be used for node-backed lookup,
but maps should be preferred when the lookup target is a model record rather
than a source node.

The stylesheet must not require schema-aware processing or streaming.

Implementation changes should preserve three practical constraints:

- Keep the public stylesheet self-contained; no `xsl:include`, `xsl:import`,
  `xsl:package`, or `xsl:use-package`.
- Prefer deterministic maps, arrays, and sorted sequences over processor- or
  hash-order-dependent iteration.
- Keep raw source nodes attached to records whenever source rendering,
  diagnostics, or local namespace resolution may need them later.

The single-file constraint does not mean every concern should be interleaved.
Use regions, named templates, functions, and modes to keep phase boundaries
obvious inside the file. A contributor should be able to tell whether a change
belongs to configuration, collection, model construction, indexing, rendering,
or assets without tracing the entire stylesheet.

## 3. Public Parameter Boundary

The public parameter names are the names in the specification:

| Parameter                | Internal responsibility                                |
| ------------------------ | ------------------------------------------------------ |
| `page-title`             | Override the generated title and main heading.         |
| `asset-base-uri`         | Prefix generated CSS and JavaScript URLs.              |
| `show-source`            | Include or omit source fragments.                      |
| `documentation-markup`   | Select `safe` or `permissive` documentation rendering. |
| `interface-language`     | Set generated UI language and message lookup.          |
| `documentation-language` | Fallback language for schema-authored documentation.   |
| `interface-direction`    | Set or infer page direction.                           |
| `robots-noindex`         | Emit or omit the robots noindex meta tag.              |

Parameter normalization should produce a single configuration map:

```xquery
map {
  'page-title': xs:string,
  'asset-base-uri': xs:string,
  'show-source': xs:boolean,
  'documentation-markup': 'safe' | 'permissive',
  'interface-language': xs:string,
  'documentation-language': xs:string,
  'requested-interface-direction': xs:string,
  'interface-direction': 'ltr' | 'rtl',
  'robots-noindex': xs:boolean,
  'diagnostics': map(*)*
}
```

`page-title` is the empty string when the parameter is unset; the derived
title is computed downstream. `requested-interface-direction` stores the
lower-cased parameter value after defaulting to `auto` (an invalid value is
preserved here and reported as a diagnostic). `interface-direction` is the
computed HTML direction after applying `auto` inference from
`interface-language`.

Invalid parameter values should be normalized to the documented default and
reported as diagnostics in the generated page.

Wrapper tooling should pass through only values the user supplied. Empty action
inputs or shell variables should not mask stylesheet defaults with empty
strings unless the parameter explicitly defines empty string as a meaningful
value, as `page-title` does.

## 4. Schema Collection

Schema collection is a graph walk over `xs:include`, `xs:import`,
`xs:redefine`, and `xs:override`.

The collection phase should produce document-instance records rather than only
a sequence of `xs:schema` elements. A document can appear with different
effective namespaces when the same chameleon schema is included from different
target namespaces, so URI alone is not a sufficient identity for every
collected schema instance.

```xquery
map {
  'id': xs:string,
  'uri': xs:string,
  'node': element(xs:schema)?,
  'declared-target-namespace': xs:string,
  'effective-target-namespace': xs:string,
  'is-primary': xs:boolean,
  'is-chameleon': xs:boolean,
  'load-status': 'loaded' | 'not-loaded' | 'not-schema' | 'not-requested',
  'incoming-edge': map(*)?,
  'outgoing-edges': map(*)*
}
```

An edge record should preserve the authored composition declaration:

```xquery
map {
  'relation': 'include' | 'import' | 'redefine' | 'override',
  'declared-namespace': xs:string?,
  'schema-location': xs:string?,
  'resolved-uri': xs:string?,
  'source-node': element(),
  'target-node': node()?,
  'effective-target-namespace': xs:string?,
  'status': 'loaded' | 'not-loaded' | 'not-schema' | 'not-requested' | 'cycle-skipped'
}
```

Collection rules:

- Resolve relative `schemaLocation` against the base URI of the declaration.
- Traverse transitively.
- Guard every load with `doc-available()` before calling `doc()`, so a
  missing or unparsable document never aborts the transform.
- Continue after failed loads and record diagnostics.
- Treat imports without `schemaLocation` as namespace dependencies, not load
  failures.
- For `include`, `redefine`, and `override`, apply the chameleon effective
  namespace when the referenced schema has no `@targetNamespace`. The current
  stylesheet applies this only for include and redefine; extending it to
  override is a known gap tracked in section 19.
- Prevent non-termination using a visited key that includes both resolved URI
  and effective namespace where chameleon behavior can change identity.
- Preserve all composition declarations for the overview, even when traversal
  skips a repeated or cyclic document.

Collection is deliberately source-honest. It records what the schema author
declared and what the renderer was able to load; it does not validate that
imports, includes, redefines, or overrides are legally arranged. A loaded
document can therefore contribute both useful components and diagnostics about
the traversal path that reached it.

Collection records should be immutable once produced. Later phases may derive
indexes, diagnostics, and display labels from them, but should not rewrite
collection status in place. That keeps load behavior reproducible and makes
diagnostics explainable.

## 5. Documentation Model

The model layer should turn loaded schema document instances into explicit
records. This is the central architectural boundary: renderers should consume
records and ask indexes for relationships rather than rediscovering global
facts ad hoc.

Records should carry values in the form most useful to renderers:

- Human-readable authored values, such as lexical QNames and raw attribute
  values, are preserved for display.
- Namespace-aware keys, such as Clark names, are stored for lookup.
- Stable IDs and anchors are computed once and reused by navigation,
  references, diagnostics, and tests.
- Source nodes remain available for local context, annotations, and source
  listings, but they are not the only representation of a global fact.

### 5.1 Component Records

Every global component gets a component record:

```xquery
map {
  'id': xs:string,
  'kind': 'element' | 'attribute' | 'complexType' | 'simpleType'
        | 'attributeGroup' | 'group' | 'notation',
  'node': element(),
  'name': xs:string,
  'qname': xs:QName,
  'clark': xs:string,
  'document-id': xs:string,
  'effective-target-namespace': xs:string,
  'anchor': xs:string,
  'disposition': 'normal' | 'redefined' | 'overridden',
  'versioning-attributes': attribute()*,
  'versioning-records': map(*)*,
  'documentation-text': xs:string,
  'source-order': xs:integer
}
```

Components declared inside `xs:redefine` and `xs:override` are records in their
own right and must be visibly marked. Their anchors must be stable and must not
collide with the component they redefine or override.

The containers constrain what can appear inside them: `xs:redefine` may contain
only simple type, complex type, model group, and attribute group definitions;
`xs:override` may additionally contain element, attribute, and notation
declarations. The "unknown XSD namespace element in a schema position"
diagnostic fires only for local names outside the XSD vocabulary; a known
element misplaced in a container (for example `xs:element` inside
`xs:redefine`) is not separately diagnosed — the generator is a documentation
renderer, not a validator, and leaves structural validity to schema
processors.

The canonical component ordering is:

1. Elements
2. Complex types
3. Simple types
4. Attributes
5. Attribute groups
6. Model groups
7. Notations

Within each kind, order by effective namespace, then alphabetically by name
(case-insensitive primary key, case-sensitive secondary key), with source
order as the final deterministic tiebreak. This matches the specification's
§7.3 ordering rule and applies to both the navigation and the main component
sections.

### 5.2 Contextual Records

Contextual constructs do not all need top-level sections, but they should still
be represented consistently:

- Annotation and appinfo blocks.
- Local element and attribute declarations.
- Particles and model groups.
- Wildcards.
- Identity constraints.
- Type alternatives.
- Assertions and assertion facets.
- Open content and default open content.
- Attribute uses and attribute-group expansions.
- Facets.
- Versioning annotations.

These records should carry their nearest owning component ID where one exists.
This lets feature summaries and diagnostics group nested facts under useful
headings rather than producing a flat list.

Contextual record payloads should preserve authored details needed for
structured rendering, including:

- Wildcard namespace constraints, `@notNamespace`, `@notQName`,
  `@processContents`, occurrence range for `xs:any`, annotation, and whether
  the wildcard admits elements, attributes, or both.
- Wildcard token classification for `##any`, `##other`, `##local`,
  `##targetNamespace`, `##defined`, and `##definedSibling`. Classification
  must respect token placement: `##any` and `##other` appear only in
  `@namespace`; `##defined` and `##definedSibling` appear only in `@notQName`;
  and `##definedSibling` is valid only on element wildcards (`xs:any`).
  Labels therefore depend on both the carrying attribute and the wildcard
  kind.
- Wildcard provenance: direct declaration, open content, default open
  content, or attribute group. (A base-type origin cannot occur in the
  source-honest rendering model: a wildcard inherited from a base type
  renders in the declaring type's own section as direct content.)
- Facet `@value`, `@fixed`, `@id`, annotation, source position or context, and
  whether the facet is XSD 1.1-only.
- Type-alternative source order, `@test`, default-alternative state,
  `@xpathDefaultNamespace`, selected type, inline type, annotation, and CTA
  inheritable-attribute context. Each inheritable attribute in that context
  must record whether it is inherited from an ancestor type or declared on the
  current type, because attributes declared on the current type are not
  inherited into that type's own test context.
- Assertion `@test`, `@xpathDefaultNamespace`, optional message or annotation,
  and owning type or facet context.
- Open-content mode, wildcard, explicit versus effective origin, and
  `@appliesToEmpty` where represented. Mode values are constrained by origin:
  `none` is allowed only on `xs:openContent`, while `xs:defaultOpenContent`
  permits only `interleave` and `suffix`.
- Versioning attribute exact QName and value, the XSD element carrying it, the
  nearest owning schema component, and whether it came from schema-level or
  nested content.

### 5.3 Reference Records

Every QName-valued reference should become a reference record:

```xquery
map {
  'id': xs:string,
  'source-node': element(),
  'source-attribute': xs:string,
  'lexical-value': xs:string,
  'resolved-qname': xs:QName?,
  'clark': xs:string?,
  'expected-kind': xs:string,
  'owner-component-id': xs:string?,
  'state': 'resolved' | 'builtin' | 'external' | 'unresolved',
  'target-component-id': xs:string?,
  'diagnostic-id': xs:string?
}
```

List-valued QName attributes — `@memberTypes` and the XSD 1.1 multi-head
`@substitutionGroup` — produce one reference record per token, each resolved
and displayed independently.

This architecture avoids mixing link creation with QName resolution. The model
decides what a reference means; the renderer decides how to display each state.

Renderers must keep the reference states visually and programmatically
distinct. The four model states map onto the specification's three display
states: `resolved` renders as an internal link, `builtin` as an external W3C
specification link, and `external` and `unresolved` both render as visible
non-links distinguished by whether the namespace is known:

- Internal resolved links point to generated anchors.
- Built-in or specification links point to external W3C sections.
- External references identify known namespaces outside the loaded collection.
- Unresolved references remain visible and must expose diagnostic context to
  keyboard and assistive-technology users, for example by being focusable or by
  using labelled diagnostic text.

Reference records should be the only place that classifies a QName reference
as resolved, built-in, external, or unresolved. Renderers may format those
states differently, but they should not repeat namespace lookup logic or invent
new states locally.

## 6. QName and Namespace Resolution

QName resolution must be namespace-aware and context-sensitive.

The resolver should accept:

- The lexical QName value.
- The source element carrying the attribute.
- The expected component kind.
- The nearest schema document instance.

It should return a reference record, not only an `xs:QName`.

For prefixed values, use the lexical namespace binding at the source element.
For unprefixed values, first try the effective target namespace of the owning
schema document when a same-named component of the expected kind exists there.
If no such component exists, fall back to normal lexical `resolve-QName()`.

This explicit same-target-namespace preference matches common XSD authoring
practice where `xmlns` on `xs:schema` is the XSD namespace but unprefixed
references are intended to name schema components in the target namespace.

Unresolved references must remain visible in output and must create diagnostics.
They must not be guessed away.

## 7. Indexes and Relationship Graphs

Indexes should be built after the component and reference records exist.

The stylesheet prebuilds six reverse-reference maps through shared index
helpers before rendering component sections. Keys are the Clark name of the
referenced component; values are the referencing nodes in document order:

| Index                      | Key                         | Value                                                    |
| -------------------------- | --------------------------- | -------------------------------------------------------- |
| Type users                 | type Clark QName            | Nodes carrying `@type`, `@base`, or `@itemType` matches. |
| Keyrefs by referenced key  | key/unique Clark QName      | `xs:keyref` nodes whose `@refer` resolves to the key.    |
| Element references         | element Clark QName         | `xs:element[@ref]` nodes.                                |
| Group references           | group Clark QName           | `xs:group[@ref]` nodes.                                  |
| Attribute-group references | attribute-group Clark QName | `xs:attributeGroup[@ref]` nodes.                         |
| Attribute references       | attribute Clark QName       | `xs:attribute[@ref]` nodes.                              |

Every other relationship lookup (component matching, identity-constraint
targets, substitution members and heads, wildcard and facet facts, versioning
owners) is computed per component from the schema nodes; the indexes exist
where a per-component scan would otherwise be repeated across the whole page.

When adding a relationship, first decide whether it is a global relationship
that many components will query or a local detail rendered only from an owning
component. Global relationships belong in records or indexes. Local details can
stay in the relevant renderer when doing so preserves source order and does not
duplicate work across the page.

Indexes should be derived data. A stale or partial index is worse than a local
scan, so each index must document its key, value, ordering, and source records.
When the source records change, the index construction and tests should change
in the same patch.

Cycle-prone expansions must carry a visited set:

- Model group expansion.
- Attribute group expansion.
- Type derivation chains.
- Substitution group head chains.
- Schema collection traversal.

When a cycle is detected, stop expansion, render the reference that caused it,
and emit a diagnostic such as "not expanded: recursive group reference".

## 8. Rendering Pipeline

The root template should be thin. It should assemble the page skeleton and then
delegate to rendering modes that consume the model.

Recommended pipeline:

```text
initial xs:schema document
  -> normalized configuration
  -> schema collection records
  -> component/context/reference records
  -> indexes and diagnostics
  -> HTML skeleton
  -> overview
  -> navigation
  -> component sections
  -> diagnostics
  -> optional source fragments
  -> i18n/runtime data for progressive enhancement
```

The HTML must contain all schema facts without JavaScript. JavaScript may
filter, reveal, copy links, toggle themes, and update status text, but it must
derive schema content from the rendered DOM.

Rendering modes should preserve accessibility as an output property, not only a
visual concern. Tables need captions or labelled headings and useful `th`
scopes. Navigation, filters, icon-only buttons, copy-link controls, theme
controls, and disclosure controls need accessible names. JavaScript-updated
counts or status messages should use a live region or equivalent discoverable
text. Filtering must not trap focus in hidden content, and focus indicators
must remain visible.

Rendering should be deterministic. Avoid renderer-local calls that depend on
the current time, host filesystem paths, processor-generated IDs, or map
iteration order. If a renderer needs an ID, label, sort key, or diagnostic
anchor, prefer computing it in the model or index phase and passing it through.

## 9. Page Structure

The generated page should use this high-level structure:

```html
<html lang="..." dir="...">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <meta name="generator" content="..." />
    <!-- robots noindex meta only when requested -->
    <title>...</title>
    <script>
      <!-- inline theme bootstrap -->
    </script>
    <link rel="stylesheet" href="..." />
    <script src="..." defer="defer"></script>
  </head>
  <body>
    <a class="skip-link" href="#main">...</a>
    <header>...</header>
    <nav aria-label="...">...</nav>
    <main id="main">
      <section id="overview">...</section>
      <section id="kind-el">...</section>
      <section id="kind-ct">...</section>
      <section id="kind-st">...</section>
      <section id="kind-at">...</section>
      <section id="kind-ag">...</section>
      <section id="kind-gr">...</section>
      <section id="kind-no">...</section>
      <section id="diagnostics">...</section>
    </main>
  </body>
</html>
```

The head carries the generator, viewport, and color-scheme metadata required by
the specification, plus the robots meta tag when `robots-noindex` is true. The
tiny inline theme-bootstrap script is a deliberate exception to the single
deferred script: it must run before first paint to avoid a theme flash, and it
does nothing except apply a stored theme preference to the root element. All
other behavior lives in the deferred script.

The diagnostics section may be omitted only when there are no diagnostics.
Every diagnostic should also be reachable from the relevant overview or
component context.

Component anchors should use the deterministic shape:

```text
{kind-abbreviation}-{namespace-id}-{local-name}
```

The abbreviations are `el`, `ct`, `st`, `at`, `ag`, `gr`, and `no` for
element, complex type, simple type, attribute, attribute group, model group,
and notation. The primary namespace may use an empty namespace ID; secondary
namespaces use `ns1`, `ns2`, and so on in first-seen schema-collection order.
A namespace referenced but never collected gets a deterministic
`nsx-{sanitized-uri}` ID. Redefined and overridden components append the
deterministic suffixes `-redefined` and `-overridden`; those are the only
collision suffixes at the component level (two same-kind, same-namespace,
same-name components outside redefine/override are invalid schemas and get
identical anchors).

Nested linkable constructs use two schemes, both page-unique and
deterministic without processor-generated IDs:

- Identity constraints: `{owner-anchor}-{k|kr|u}-{name}` where the middle
  token abbreviates key/keyref/unique. A ref-only constraint (XSD 1.1 `@ref`,
  no `@name`) uses `ref-{sanitized-ref}` as its name part, with a
  sibling-count suffix when identical ref-only siblings would collide.
- Other nested constructs (type alternatives, inline types, local elements):
  the enclosing top-level component's anchor plus the construct's
  sibling-position path inside that component.

## 10. Component Rendering

Component renderers should share a common shell:

- Stable `id`.
- Heading with kind, name, and namespace.
- Badges for state such as abstract, mixed, nillable, redefined, overridden,
  XSD 1.1 feature, and versioning annotations.
- Defined-in document link or label.
- Annotation/documentation blocks.
- Kind-specific facts.
- See-also/backlink section.
- Optional source fragment.

Kind-specific renderers then fill the body:

| Kind            | Required renderer focus                                                                                                      |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Element         | Type, references, value constraints, occurrence for local use, substitution groups, identity constraints, type alternatives. |
| Attribute       | Type, use, value constraints, form, inheritable, local/global context.                                                       |
| Complex type    | Derivation, content model, attributes, assertions, open content, default attributes, hierarchy.                              |
| Simple type     | Variety, restriction/list/union, facets, built-in datatype links, NOTATION enumerations.                                     |
| Attribute group | Attribute uses, nested group references, wildcard, users.                                                                    |
| Model group     | `all`, `choice`, `sequence`, particles, references, users.                                                                   |
| Notation        | Public/system identifiers and NOTATION enumeration links.                                                                    |

Local and anonymous constructs should render inline where they occur. They do
not receive top-level component sections in the current page contract.

Complex-type rendering must compute effective open content with the product
display rule: a type's own `xs:openContent` wins; otherwise schema-level
`xs:defaultOpenContent` applies only to complex-content types, and applies to
empty complex types only when `@appliesToEmpty` is true. Simple-content types
must not be shown as receiving effective open content.

Default-attribute rendering must link schema-level `@defaultAttributes` to the
referenced attribute group when resolvable and show, for each complex type,
whether defaults apply after considering `@defaultAttributesApply`.

Attribute tables decide their conditional columns (Inheritable, Documentation)
once per table: `f:attribute-table-nodes` collects the attribute and wildcard
nodes the table will show by mirroring the row-emission walk exactly —
descendant axis on the owner, child axis inside referenced attribute groups,
and the same ambiguity and visited-set stops as the row expansion — so a column
is emitted iff some row will populate it. The Documentation decision reuses
`f:annotation-renders`, the same predicate the documentation renderer uses to
decide whether an annotation emits anything (non-whitespace text, element
children, a usable `@source` link, or appinfo).

Simple-type rendering must preserve repeated facets and show facet `@id`,
`@fixed`, annotations, and source context where available. Built-in datatype
links should cover the XSD 1.1 catalog, and XSD 1.1-only built-ins and facets
such as `xs:dateTimeStamp`, `xs:yearMonthDuration`, `xs:dayTimeDuration`, and
`xs:explicitTimezone` should receive an XSD 1.1 marker when they occur.

Repeated pattern facets have combination semantics the rendering must respect:
multiple `xs:pattern` facets within one restriction step combine with OR, while
pattern facets across derivation steps combine with AND. Same-step patterns
must not be presented as independent conjoint constraints.

The Configuration layer should carry a static fundamental-facet catalog for
built-in types — ordered, bounded, cardinality, and numeric — alongside the
datatype link catalog, so simple-type rendering can expose fundamental facet
information when it is known.

Type-alternative rendering should surface the inherited-versus-declared
distinction recorded in the CTA context (section 5.2): attributes declared on
the current type are not available to that type's own test context, only to
derived or descendant contexts.

Wildcard rendering must display `@namespace`, `@notNamespace`, `@notQName`,
`@processContents`, all recognized wildcard tokens, annotations, occurrence
range for `xs:any`, whether the wildcard admits elements or attributes, and
whether it was introduced directly, through open content, through default
open content, or through an attribute group (base-type introduction renders
in the declaring type's own section).

Versioning rendering must cover `vc:minVersion`, `vc:maxVersion`,
`vc:typeAvailable`, `vc:typeUnavailable`, `vc:facetAvailable`, and
`vc:facetUnavailable`. A versioning panel should show the exact attribute name
and value, the XSD element carrying it, and the nearest owning schema
component. The output should explain that documentation displays the source and
does not apply conditional inclusion filtering by default.

## 11. Overview Rendering

The overview is the reader's map of the schema collection. It should include:

- Primary document URI when available.
- Target namespace and schema metadata.
- Effective namespace summary for every loaded schema document.
- Composition table for imports, includes, redefines, and overrides.
- Load, cycle, and unresolved-reference diagnostics.
- XSD 1.0 and XSD 1.1 feature summaries.
- Schema-level annotations, default attributes, and default open content.

The overview should distinguish declared target namespace from effective target
namespace for chameleon includes.

Schema metadata should be explicit, not a catch-all label. Render `@version`,
`@id`, `@xml:lang`, `@elementFormDefault`, `@attributeFormDefault`,
`@blockDefault`, `@finalDefault`, `@xpathDefaultNamespace`,
`@defaultAttributes`, and `@defaultAttributesApply` where present.

The XSD 1.1 feature summary should include grouped versioning annotations and
should not flatten nested `vc:*` attributes into a noisy global list.

## 12. Diagnostics

Diagnostics should be records, not formatted strings until rendering time.
The stylesheet uses two record shapes. Collection diagnostics carry the
offending node:

```xquery
map {
  'code': xs:string,
  'severity': 'info' | 'warning',
  'node': node()
}
```

Parameter diagnostics carry the parameter facts needed for the context
sentence:

```xquery
map {
  'code': 'invalid-parameter',
  'severity': 'info',
  'param': xs:string,
  'value': xs:string,
  'normalized': xs:string
}
```

The unresolved-reference, unknown-element, and recursive-expansion categories
are derived directly from the scanned attribute and element nodes rather than
materialized as records; their list ids (`diag-unresolved-{n}`,
`diag-unknown-{n}`, `diag-recursive-{n}`) come from position in the
deterministic scan.

Minimum diagnostic categories:

- Schema document not loaded.
- Loaded document is not an `xs:schema`.
- Schema traversal skipped a cycle or duplicate instance.
- QName reference not resolved.
- Recursive group or attribute-group expansion stopped.
- Unknown XSD namespace element in a schema position.
- Invalid parameter value normalized to a default.

Diagnostics are documentation facts, not validation errors. Wording should use
"not loaded", "not resolved", "not expanded", or "not recognized".

Diagnostic IDs should be stable for unchanged input. If a diagnostic is linked
from an unresolved reference, overview row, or component article, the link
target must be generated by the same deterministic scan that produced the
diagnostic list entry.

## 13. Source Rendering

Source rendering should be an isolated mode. It should receive a source node
and output escaped, readable XML.

Requirements:

- Preserve element and attribute names.
- Preserve attributes, and re-declare on the fragment root the namespace
  declarations the fragment uses. A prefix counts as used when the emitter
  picks it for an element or attribute name inside the fragment, or when it
  appears as a QName-shaped token in an attribute value; unused in-scope
  prefixed declarations are omitted, and the default namespace declaration is
  always kept. (Declarations made on descendants of the fragment root are not
  re-emitted — a pre-existing limitation unchanged by pruning.)
- Preserve meaningful annotation text.
- Keep source blocks textual and selectable.
- Wrap global component source in `details`.
- May wrap schema-level composition declarations in `details` when useful.
- Respect `show-source`.
- Use syntax highlighting only as presentation; the textual XML remains the
  carrier of source facts.

Source rendering must not be used as a substitute for structured rendering.
All important schema facts must be available outside the source listing.

## 14. Documentation Markup

`xs:documentation` and `xs:appinfo` are untrusted input.

The safe documentation renderer should:

- Promote only no-namespace or XHTML elements from an allowlist.
- Drop executable elements and event-handler attributes.
- Reject dangerous URL schemes after trimming whitespace and control
  characters.
- Add `rel="external noopener noreferrer"` to promoted links that open a new
  browsing context.
- Prevent schema-authored IDs from colliding with generated anchors.
- Render unsupported elements by preserving text content.
- Avoid `img`; safe mode has no schema-authored image policy.

The permissive renderer may copy content verbatim, but the generated page and
documentation should identify this mode as unsafe for untrusted schemas.

`xs:appinfo` should render as source-like structured content and must never be
executed.

## 15. Internationalization and Direction

All generated UI text should flow through a message catalog. Schema-authored
names, QNames, namespace URIs, XPath expressions, regexes, facet values, and
source code must not be translated.

The lookup chain is:

1. Exact `interface-language`.
2. Primary language subtag.
3. English.
4. Visible missing-key marker during development.

`documentation-language` applies only to schema-authored prose wrappers that do
not carry `xml:lang`.

`interface-direction=auto` should infer direction from the interface language.
Code-like schema content should render left-to-right or in bidi-isolating
elements even when the interface is right-to-left.

Documentation wrappers should preserve author-supplied `xml:lang`. When a
documentation block has no `xml:lang`, the wrapper should use
`documentation-language`. `xs:appinfo` and source listings should not be
assigned prose language unless the source explicitly supplies one.

Generated chrome that a user can see or interact with should use the message
catalog, including table captions and columns, badge text, button labels,
`aria-label` values, filter placeholders, runtime status strings, copy-link
feedback, theme labels, and diagnostic headings.

## 16. Assets and Progressive Enhancement

The default asset contract is:

- `${asset-base-uri}xsdstyle.css`
- `${asset-base-uri}xsdstyle.js`

Icon SVGs are read at transform time and inlined once into the page as a
hidden `symbol` sprite, so icons require no runtime image fetches and the page
stays a single document. The only other script content is the inline
theme-bootstrap exception described in section 9.

The stylesheet should render useful HTML without either asset. CSS improves
presentation. JavaScript may add:

- Navigation filtering.
- Copy-link controls.
- Expand/collapse all.
- Theme preference layered over `prefers-color-scheme`.
- Live result counts and status messages.

JavaScript should not require dependencies and should not fetch schema data.
When it needs runtime strings, the XSLT may embed a small JSON message block.
The search index should be derived from rendered DOM content so the DOM remains
the source of truth.

CSS must preserve contrast in light and dark color schemes and must not rely on
hue alone to distinguish component kinds, warnings, unresolved references, or
versioning features. Source, QName, namespace URI, XPath, regex, and code-like
values should remain left-to-right or bidi-isolated under RTL page chrome.

## 17. Determinism

Determinism is a system property. The architecture should avoid dependencies
on processor-specific node ordering beyond document order.

Rules:

- Sort schema collection work queues deterministically when multiple outgoing
  edges are discovered at the same location.
- Assign schema document IDs in collection order.
- Assign namespace IDs in first-seen collection order.
- Generate anchors from the specified kind abbreviation, namespace ID, local
  name, and deterministic suffixes for collisions.
- Keep diagnostics in fixed category buckets — parameter, collection,
  unknown-element, recursive-expansion, unresolved-reference — with document
  order inside each bucket.
- Relativize local source URIs against the primary schema directory when
  displaying paths, so host-specific absolute paths do not leak into normal
  output.

## 18. Testing Architecture

Tests should assert the visible HTML contract, not only helper behavior.

The concrete harness is XSpec on Saxon-HE, run through `make test` with the
tooling vendored under `.tools/`. The existing suites map onto the layers
below: `helpers.xspec` and `parameters.xspec` cover unit behavior;
`references.xspec`, `relationships.xspec`, and `diagnostics.xspec` cover
integration behavior; `dom.xspec`, `xsd11.xspec`, and `i18n.xspec` cover the
generated page contract.

Recommended layers:

- XSpec unit tests for QName resolution, anchor generation, occurrence
  formatting, safe-link filtering, datatype/facet link catalogs, and parameter
  normalization.
- XSpec integration tests for collection traversal, chameleon includes,
  failed loads, cyclic group expansion, and reference states.
- Golden or structural HTML tests for representative schemas covering each
  global component kind and each XSD 1.1 feature.
- Browser or DOM tests for no-JavaScript usability, keyboard-visible controls,
  accessible names, table headings, filtering behavior, copy-link status,
  status live-region behavior, contrast-sensitive states, and theme toggling.
- Determinism tests that render the same input twice and compare normalized
  output.

Every public parameter in the specification should have direct test coverage.
Coverage should also assert the exact anchor shape, reference-state rendering,
effective open-content/default-attribute rules, wildcard tokens and negative
constraints, versioning panels, XSD 1.1 datatype/facet markers, and optional
source fragments for composition declarations.

The suite must also include the specification's end-to-end renders, each with
its own fixture:

- A compact schema exercising every XSD 1.0 component family.
- A compact schema exercising the XSD 1.1-only features.
- A multi-document collection with include, import, redefine, override,
  chameleon include, and at least one missing reference.
- A substantial real-world or standards schema large enough to expose
  performance, navigation, and HTML-validity problems.

Each end-to-end render is gated on: valid HTML (the Nu validator is vendored
at `.tools/vnu.jar`), required local assets present, no broken same-document
component links, and completion without non-termination on cyclic input.

## 19. Known Limitations

`xsdstyle.xsl` currently diverges from the target architecture in the following
ways. These are not product exceptions; they are implementation gaps to close
without weakening `docs/specification.md`.

- Chameleon effective namespaces are applied for `xs:include` and
  `xs:redefine` but not for `xs:override` (section 4).
- Schema-record lookup from a node keys on document URI alone, so a
  chameleon document included under two effective namespaces resolves to the
  first collected instance rather than the per-instance document records with
  their own IDs described in section 4.
- Reference resolution happens inside shared index and unresolved-reference
  helpers rather than producing the centralized reference records of section
  5.3, so reference states and diagnostics are not derived from one shared
  model. The unresolved-reference scan feeds both the diagnostics list and the
  `aria-describedby` wiring on unresolved markers.
- The four end-to-end fixtures and their validation gates (section 18) are
  not implemented.

When a limitation is fixed, remove or amend the corresponding bullet in this
section in the same change. Do not leave solved gaps documented as active
constraints.
