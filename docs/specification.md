# XSD Documentation Generator Specification

This document specifies a documentation generator for XML Schema Definition
(XSD) schemas. The generator transforms one XSD schema document, plus every
reachable schema document in its schema collection, into a stand-alone HTML
documentation page by using XSLT.

This is the product contract for the project. `docs/architecture.md` explains
how the stylesheet is organized to satisfy this contract, and `docs/dom.md`
defines the emitted HTML shape.

The document set has an explicit precedence order:

1. This specification defines required observable behavior.
2. `docs/architecture.md` defines the intended implementation structure.
3. `docs/dom.md` defines generated markup, CSS hooks, and JavaScript hooks.

When these documents disagree, the higher-precedence document wins. The
lower-precedence document should be amended in the same change that exposes
the disagreement.

The local source specifications in `specifications/` are authoritative for
XSD and XSLT terminology:

- `W3C XML Schema Definition Language (XSD) 1.1 Part 1_ Structures.html`
- `W3C XML Schema Definition Language (XSD) 1.1 Part 2_ Datatypes.html`
- `XSL Transformations (XSLT) Version 3.0.html`

Where this document says "must", "must not", "should", or "may", those words
are normative for this generator.

This document intentionally describes observable behavior, not implementation
mechanics. Requirements are written in terms of generated HTML, public
parameters, supported schema constructs, security posture, and testable
outcomes. Internal record shapes, helper functions, modes, and CSS/JavaScript
hooks belong in the architecture and DOM documents unless they affect the
public contract.

Use this document as a checklist when changing behavior. A change that adds,
removes, or reinterprets generated schema facts should update this
specification first, then the architecture and DOM contracts as needed, then
the stylesheet and tests. A change that only reorganizes implementation code
should normally update `docs/architecture.md` without changing this
specification.

## 1. Purpose

The generator must help a reader understand an XSD schema as a vocabulary
contract. The generated page must make these questions answerable without
requiring the reader to inspect raw XML first:

- What global declarations and type definitions exist?
- Which schemas contributed them, and under which effective namespaces?
- How do declarations, types, groups, constraints, and references relate?
- What element structures, attribute uses, values, and facets are permitted?
- Which XSD 1.1 features, versioning annotations, and schema composition
  mechanisms affect the source?
- Which facts could not be resolved or expanded by the documentation renderer?

The output must be a single stand-alone HTML page that is useful when opened
directly from disk, hosted as static content, or published from a CI system.
The page must not require JavaScript for content. JavaScript may enhance search,
navigation, copy-link behavior, disclosure controls, and theme behavior, but
all schema facts must be present in the initial HTML.

The generator must support XSD 1.0 and XSD 1.1. Supporting XSD 1.0 means
rendering every construct defined by XSD 1.0 as represented in the XSD 1.1
specifications. Supporting XSD 1.1 means additionally rendering every XSD 1.1
construct and versioning feature. The generator is a documentation renderer,
not a schema validator.

The page may explain that some source is malformed, unavailable, unsupported,
or unresolved. It must not pretend to validate schema correctness, and it must
not hide source constructs merely because they are conditionally included,
versioned, deprecated, or outside the loaded schema collection.

The generator's core value is source-honest documentation: show what was
authored, show what was loaded, link what can be linked deterministically, and
make unresolved or skipped facts visible.

## 2. Inputs

### 2.1 Primary Input

The primary input is an XML document whose document element is `xs:schema`,
using the schema namespace `http://www.w3.org/2001/XMLSchema`.

The stylesheet must accept the primary schema as the initial context document.
An implementation may also expose a wrapper command, GitHub Action, or CLI that
passes that document to the stylesheet.

### 2.2 Schema Collection

The generator must discover and render the schema collection reachable from the
primary schema through:

- `xs:include`
- `xs:import`
- `xs:redefine`
- `xs:override`

The collection walk must be transitive and must prevent infinite traversal when
schema documents contain circular references.

The generator must resolve relative `schemaLocation` values against the base URI
of the schema document that contains the reference.

If a referenced document cannot be loaded, the generator must continue and emit
a visible diagnostic in the HTML. A missing referenced schema must not abort the
whole documentation render.

### 2.3 Chameleon Includes

When a schema document without `@targetNamespace` is reached through
`xs:include`, `xs:redefine`, or `xs:override`, the generator must treat that
document as having the effective target namespace of the including schema for
the purposes of component naming, linking, grouping, and display.

The generator should still preserve and display the document's actual source
namespace state where useful, so a reader can understand that a chameleon
include was used.

### 2.4 Versioned Schema Documents

The generator must accept schemas written for XSD 1.0, XSD 1.1, or mixed
schema collections that use XSD 1.1 conditional inclusion. It must display
versioning annotations but must not use them to silently remove content.

## 3. Output

### 3.1 HTML Contract

The output must be one HTML5 document containing:

- A document title and primary heading.
- Schema overview metadata.
- A navigation area or table of contents.
- A complete component inventory.
- Per-component sections for every global component.
- Inline rendering of anonymous/local constructs where they are used.
- Diagnostics for missing schema documents and unresolved references.
- Optional source listings for schema fragments.

The generated page must be deterministic. Given the same input documents,
stylesheet, parameters, and asset versions, two runs must produce the same HTML
apart from environment-controlled line ending normalization.

The page must be usable without network access except for user-clicked external
links to specifications or documentation sources.

### 3.2 Stand-alone Assets

The HTML may reference local CSS and JavaScript assets by configurable URLs.
Those assets must be optional for understanding schema content:

- CSS improves presentation but must not be the only carrier of a schema fact.
- JavaScript enhances interaction but must not create schema content that is
  absent from the HTML.
- External third-party scripts, fonts, trackers, or CDNs must not be required.

The default asset contract should consist of one stylesheet, one deferred
script, and any image assets required under `asset-base-uri`. The script must
be dependency-free browser JavaScript and must act only as progressive
enhancement.

The HTML should include a generator meta tag, viewport metadata, and color
scheme metadata. If a theme toggle is provided, it must be a client-side
preference layered on top of `prefers-color-scheme`; it must not require a
stylesheet parameter or change the generated schema facts.

### 3.3 Accessibility

The generated HTML must:

- Include a skip link to the main content.
- Use semantic landmarks such as `header`, `nav`, `main`, `section`,
  `article`, `table`, `caption`, `details`, and `summary` where appropriate.
- Keep landmark names unique: only page-level sections (overview, per-kind
  sections, diagnostics) carry accessible names. Repeated per-component blocks
  must not be named region landmarks; their headings provide in-article
  navigation.
- Preserve heading order.
- Provide unique, stable anchors for linkable components and constraints.
- Use text labels for badges and state indicators, not color alone.
- Preserve keyboard navigation for links, filters, disclosure controls, and
  copy-link buttons.
- Make horizontally scrollable table wrappers keyboard-focusable
  (`tabindex="0"`) with an accessible name and a non-landmark role, so
  keyboard-only users can scroll tables that contain no focusable content.
- Respect the language and direction parameters, and preserve `xml:lang` from
  `xs:documentation` when present.

Navigation and controls must have accessible names. Icon-only controls are
allowed only when they have an `aria-label` or equivalent text. Search inputs
must have an associated label, and any result-count/status text updated by
JavaScript should use an appropriate live region or otherwise be discoverable
without relying on visual changes alone.

Tables must include captions or nearby labelled headings, and column headers
must be represented with `th` cells and scopes where useful. Captions may be
visually hidden as long as they remain exposed to assistive technology. Code/source blocks
must remain text, not images, and must preserve left-to-right reading order for
XML source regardless of the page direction.

Interactive states must be perceivable and operable with a keyboard. Focus
indicators must not be removed. Collapsible source blocks, show-more controls,
theme controls, copy-link controls, and filter clearing must all be reachable
and usable without a pointer device. If JavaScript hides filtered content, it
must not trap focus in hidden sections.

Visual presentation must maintain sufficient contrast in light and dark color
schemes. Text must not rely on hue alone to distinguish component kinds,
warnings, unresolved references, or versioning features.

## 4. Parameters

The stylesheet must define the following parameter surface.

| Name                     | Type         | Default     | Requirement                                                                                                                       |
| ------------------------ | ------------ | ----------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `page-title`             | `xs:string?` | empty       | Overrides the page title and main heading. If absent, derive from `xs:schema/@id`, then `@targetNamespace`, then a generic title. |
| `asset-base-uri`         | `xs:string`  | `./assets/` | Prefix for local CSS and JS asset URLs.                                                                                           |
| `show-source`            | `xs:boolean` | `true()`    | Controls whether component source fragments are embedded.                                                                         |
| `documentation-markup`   | `xs:string`  | `safe`      | Controls rendering of markup inside `xs:documentation`; allowed values are `safe` and `permissive`.                               |
| `interface-language`     | `xs:string`  | `en`        | Sets `<html lang>` and selects user-interface strings.                                                                            |
| `documentation-language` | `xs:string`  | `en`        | Fallback language for XSD prose when a documentation block has no `xml:lang`.                                                     |
| `interface-direction`    | `xs:string`  | `auto`      | Sets `<html dir>`; allowed values are `auto`, `ltr`, and `rtl`.                                                                   |
| `robots-noindex`         | `xs:boolean` | `false()`   | Emits a noindex robots meta tag when true.                                                                                        |

Additional parameters may be added only when they preserve deterministic output
and do not hide schema facts by default.

Parameter handling must be forgiving and visible. Invalid values should be
normalized to the documented default, the generated page should report a
diagnostic, and the transform should continue unless the XSLT processor cannot
parse the supplied value as the declared parameter type. Wrapper tools and
actions should forward only non-empty user inputs so the stylesheet defaults
remain authoritative.

## 5. XSLT Requirements

The generator must be implemented as XSLT 3.0. It must use standard XSLT,
XPath, and Functions and Operators features where possible. Processor-specific
extensions may be used only behind clearly documented feature gates.

The stylesheet should be deliverable as one top-level stylesheet module. It
must not require callers to manage an XSLT package graph. Use of `xsl:include`,
`xsl:import`, `xsl:package`, or `xsl:use-package` is therefore out of scope for
the default distribution.

The stylesheet should use:

- `xsl:mode` to separate rendering concerns.
- `xsl:function` for pure helpers such as QName resolution, anchor generation,
  occurrence formatting, URI sanitization, and datatype link generation.
- `xsl:key` or equivalent maps for cross-reference lookup.
- Maps and arrays where they simplify catalogs and message lookup.
- `xsl:try` / `xsl:catch` or an equivalent documented strategy for recoverable
  `doc()` failures.
- HTML output serialization.

The stylesheet must not require schema-aware XSLT processing. The input schema
is XML source to be documented, not a schema used to validate the transform's
source tree.

The stylesheet must not require XSLT streaming. The generator needs random
access across the loaded schema collection for references, derivation chains,
backlinks, and diagnostics.

The default distribution must remain operational as a single stylesheet plus
local assets. Build wrappers, Make targets, Docker images, and GitHub Actions
may improve delivery, but they must not become the only way to obtain the
documented HTML behavior.

## 6. Namespace and QName Resolution

The generator must resolve QName-valued schema attributes in the lexical context
where they appear. This applies to all references including:

- `@type`
- `@base`
- `@ref`
- `@substitutionGroup`
- `@itemType`
- `@memberTypes`
- `@refer`
- `@defaultAttributes`

The `@type` and `@ref` entries include XSD 1.1 uses such as
`xs:alternative/@type` and identity-constraint references through
`xs:key/@ref`, `xs:unique/@ref`, and `xs:keyref/@ref`.

The generator must distinguish:

- The XSD namespace.
- The schema's target namespace.
- The no-namespace case.
- Imported namespaces.
- Chameleon-included effective namespaces.
- Namespace prefixes used only for lexical QName expression.

For documentation links and indexes, the generator must use a namespace-aware
canonical key such as Clark notation, not local names alone.

For unprefixed QName-valued references, the generator should prefer the schema
component's effective target namespace before falling back to the lexical
default namespace. This matches common XSD authoring practice where the schema
element's default namespace is the XSD namespace but unprefixed type names refer
to same-target-namespace user types.

Unresolved QNames must remain visible as unresolved references. They must not be
silently dropped or guessed.

## 7. Component Inventory

The generator must render the XSD abstract component model. Global components
must receive top-level documentation sections. Local and helper components must
be rendered in the context where they occur.

### 7.1 Global Components

The following global components must be rendered as first-class documentation
entries:

- Attribute declarations from top-level `xs:attribute`.
- Element declarations from top-level `xs:element`.
- Complex type definitions from top-level `xs:complexType`.
- Simple type definitions from top-level `xs:simpleType`.
- Attribute group definitions from top-level `xs:attributeGroup`.
- Model group definitions from top-level `xs:group`.
- Notation declarations from top-level `xs:notation`.

Components inside `xs:redefine` and `xs:override` must be rendered and visibly
marked as redefined or overridden. `xs:redefine` may contain only simple type,
complex type, model group, and attribute group definitions; `xs:override` may
additionally contain element, attribute, and notation declarations.

### 7.2 Contextual Components

The following components and constructs must be rendered where they occur.
XSD 1.1 classes identity-constraint definitions, type alternatives, and
assertions as secondary components; annotations, attribute uses, particles,
model groups, and wildcards are helper components; open content is a property
of complex type definitions rather than a component kind. All of them are
contextual for documentation purposes:

- Annotation components from `xs:annotation`.
- Attribute uses from local attributes and attribute-group expansion context.
- Particles, including occurrence ranges.
- Model groups from `xs:all`, `xs:choice`, and `xs:sequence`.
- Wildcards from `xs:any` and `xs:anyAttribute`.
- Identity-constraint definitions from `xs:key`, `xs:keyref`, and `xs:unique`.
- Type alternatives from `xs:alternative`.
- Assertions from `xs:assert` and simple-type assertion facets.
- Open content from `xs:openContent` and `xs:defaultOpenContent`.

### 7.3 Ordering

The main component inventory should use this order:

1. Elements
2. Complex types
3. Simple types
4. Attributes
5. Attribute groups
6. Model groups
7. Notations

Within each kind, components should be ordered by effective namespace, then by
local name using a case-insensitive primary key and a case-sensitive secondary
key, with source order as the final deterministic tiebreak. The same ordering
applies to navigation and to the main component sections.

This ordering is part of the determinism contract. It must not depend on map
iteration order, processor hash order, filesystem directory order, or the order
in which an XSLT processor happens to evaluate independent expressions.

## 8. Schema Overview

The overview must include:

- Primary schema document URI when available.
- Target namespace.
- `@version`, `@id`, `@xml:lang`, `@elementFormDefault`,
  `@attributeFormDefault`, `@blockDefault`, `@finalDefault`,
  `@xpathDefaultNamespace`, `@defaultAttributes`, and
  `@defaultAttributesApply` where present. A metadata attribute that is present
  but empty-valued (including values injected by a DTD internal subset) must
  render an explicit `(none)` marker rather than an empty value.
- A feature summary for XSD 1.0 constructs in use.
- A feature summary for XSD 1.1 constructs in use.
- A list of imported, included, redefined, and overridden schema documents.
- Effective namespace summary for every schema document in the collection.
- Diagnostics for failed document loads.
- Diagnostics for unresolved references.

The overview must render schema-level `xs:annotation`, including
`xs:documentation` and `xs:appinfo`.

The overview should summarize, not replace, component details. A fact may be
listed in the overview for orientation, but the owning component or schema row
must still carry the detailed rendering when that fact has a natural owner.

## 9. Element Declarations

For every global element declaration, and for every local element declaration
inside a content model, the generator must display:

- Name, target namespace, and qualification status.
- Whether it is global or local.
- Type definition, including inline anonymous type when present.
- `@ref` target when the declaration is a reference.
- `@minOccurs` and `@maxOccurs` when local.
- Value constraints from `@default` and `@fixed`.
- `@nillable`.
- `@abstract`.
- `@block` and `@final`.
- `@form`.
- XSD 1.1 `@targetNamespace` on local declarations.
- `@substitutionGroup` head or heads.
- Identity constraints declared under the element.
- Type alternatives declared under the element.
- Annotations.
- Source fragment when enabled.

The generator must also render see-also relationships:

- Members of a substitution group for a global head element.
- The substitution group head chain for a member.
- Types that use the element declaration by reference when this can be
  discovered from the loaded schema collection.
- Identity constraints and keyrefs associated with the element.

## 10. Attribute Declarations and Attribute Uses

For every global attribute declaration and every attribute use in a complex
type or attribute group, the generator must display:

- Name, target namespace, and qualification status.
- Whether it is global or local.
- Type definition, including inline anonymous simple type when present.
- `@ref` target when the declaration is a reference.
- `@use`, including optional, required, and prohibited.
- Value constraints from `@default` and `@fixed`.
- `@form`.
- XSD 1.1 `@targetNamespace` on local declarations.
- XSD 1.1 `@inheritable`.
- Annotations.
- Source fragment for global declarations when enabled.

Attribute tables for complex types and attribute groups must include attributes
introduced directly and attributes introduced by referenced attribute groups.
When expansion would be ambiguous or cyclic, the generator must stop expansion,
show the reference, and emit a cycle/ambiguity note rather than recurse
indefinitely.

An attribute use with no `@type`, no `@ref`, and no inline type must display an
explicit "no declared type" marker; the generator must not infer or display
`xs:anySimpleType` in its place.

Table columns whose value would be absent for every row of a given table
(currently Inheritable and Documentation) must be omitted from that table. The
Inheritable column appears when any displayed attribute — including attributes
introduced through referenced attribute groups — authors `@inheritable`
(whether `true` or `false`); the Documentation column appears when at least one
displayed attribute or wildcard carries an annotation that renders content.

## 11. Complex Type Definitions

For every complex type definition, the generator must display:

- Name or anonymous context.
- Target namespace for named types.
- Base type and derivation method.
- `@abstract`.
- `@final` and `@block`.
- `@mixed`.
- XSD 1.1 `@defaultAttributesApply`.
- Content type: empty, simple content, element-only, mixed, or open.
- Simple content derivation through `xs:simpleContent`.
- Complex content derivation through `xs:complexContent`.
- Content model tree.
- Attribute uses and attribute wildcard.
- Assertions.
- Open content and effective default open content.
- Annotations.
- Derivation chain and known derived types.
- Source fragment when enabled.

The content model renderer must preserve the grammar structure:

- `xs:sequence` as ordered sequence.
- `xs:choice` as alternatives.
- `xs:all` as unordered all-group.
- `xs:group/@ref` as a link to a model group definition.
- Local element particles.
- Element references.
- Wildcard particles.
- Occurrence ranges on every particle.

The generator must support XSD 1.1 `xs:all` changes: wildcards and group
references inside all-groups, and `maxOccurs` values greater than 1 on member
particles where they appear in source. The `xs:all` group itself remains
limited to `minOccurs` and `maxOccurs` of 0 or 1.

## 12. Simple Type Definitions

For every simple type definition, the generator must display:

- Name or anonymous context.
- Target namespace for named types.
- Variety: atomic, list, or union.
- Base type or primitive/root type when derivable from source.
- Derivation by restriction, list, or union.
- `@final`.
- Facets, including repeated facets.
- Annotations.
- Source fragment when enabled.

The generator must render:

- `xs:restriction/@base` and inline restriction base types.
- `xs:list/@itemType` and inline item types.
- `xs:union/@memberTypes` and inline member types.
- Every constraining facet allowed by XSD 1.0 and XSD 1.1.
- XSD regular expression patterns as code without attempting to reinterpret
  them as JavaScript regular expressions.

### 12.1 Datatype Links

References to built-in XSD datatypes must link to the relevant Part 2 section
when the type is in the XSD namespace.

The generator must know the XSD 1.1 built-in datatype set, including:

- Special built-ins: `xs:anySimpleType`, and the XSD 1.1-only
  `xs:anyAtomicType`.
- Primitive datatypes: `xs:string`, `xs:boolean`, `xs:decimal`, `xs:float`,
  `xs:double`, `xs:duration`, `xs:dateTime`, `xs:time`, `xs:date`,
  `xs:gYearMonth`, `xs:gYear`, `xs:gMonthDay`, `xs:gDay`, `xs:gMonth`,
  `xs:hexBinary`, `xs:base64Binary`, `xs:anyURI`, `xs:QName`,
  `xs:NOTATION`.
- Ordinary built-ins derived from primitives, including normalized strings,
  tokens, names, ID/IDREF/ENTITY families, integer families, unsigned integer
  families, `xs:positiveInteger`, `xs:yearMonthDuration`,
  `xs:dayTimeDuration`, and `xs:dateTimeStamp`.

For XSD 1.0 compatibility, the generator must still render references to all
XSD 1.0 built-ins correctly.

### 12.2 Facets

The generator must render all constraining facets:

- `xs:length`
- `xs:minLength`
- `xs:maxLength`
- `xs:pattern`
- `xs:enumeration`
- `xs:whiteSpace`
- `xs:maxInclusive`
- `xs:maxExclusive`
- `xs:minExclusive`
- `xs:minInclusive`
- `xs:totalDigits`
- `xs:fractionDigits`
- `xs:assertion`
- `xs:explicitTimezone`

Facet display must include `@value`, `@fixed`, `@id`, annotation, and source
position/context where available. Enumeration values for NOTATION-derived
types should link to matching notation declarations when resolvable.

Only `xs:pattern`, `xs:enumeration`, and `xs:assertion` may meaningfully appear
more than once in a restriction. Multiple pattern facets in one restriction
step are combined with OR, while pattern facets across derivation steps are
combined with AND; the rendering must not present repeated patterns in one
step as independent conjoint constraints.

Note that Part 2 names the facet component "assertions" while its element is
`xs:assertion`; the separate `xs:assert` element is the Part 1 complex-type
assertion.

The generator should expose fundamental facet information for built-in types
when known: ordered, bounded, cardinality, and numeric. The values `finite`
and `countably infinite` are values of the cardinality facet, not facets
themselves.

## 13. Model Group and Attribute Group Definitions

For every global `xs:group`, the generator must display:

- Name and target namespace.
- The contained `xs:all`, `xs:choice`, or `xs:sequence` model group.
- Annotations.
- Known references to the group from loaded schemas.
- Source fragment when enabled.

For every global `xs:attributeGroup`, the generator must display:

- Name and target namespace.
- Attribute uses.
- Attribute-group references.
- Attribute wildcard.
- Annotations.
- Known references to the attribute group from loaded schemas.
- Source fragment when enabled.

Recursive group and attribute-group references must be detected and displayed
without infinite expansion.

## 14. Wildcards

The generator must render `xs:any` and `xs:anyAttribute` with:

- Namespace constraint from `@namespace`.
- XSD 1.1 negative namespace constraints from `@notNamespace`.
- XSD 1.1 disallowed names from `@notQName`.
- Process contents from `@processContents`: strict, lax, or skip.
- Occurrence range for `xs:any`.
- Annotation.

The renderer must recognize and display wildcard tokens, including:

- `##any`
- `##other`
- `##local`
- `##targetNamespace`
- XSD 1.1 `##defined`
- XSD 1.1 `##definedSibling`

Token placement is constrained: `##any` and `##other` are allowed in
`@namespace` but not `@notNamespace`; `##local` and `##targetNamespace` are
allowed in both; `##defined` and `##definedSibling` appear only in `@notQName`;
and `##definedSibling` is allowed only on element wildcards (`xs:any`), not on
`xs:anyAttribute`. The renderer must label tokens according to the attribute
and wildcard kind on which they appear.

Wildcard display must make clear whether a wildcard admits elements,
attributes, or both, and whether it is introduced directly, through a base type,
through open content, or through an attribute group.

## 15. Identity Constraints

The generator must render `xs:key`, `xs:unique`, and `xs:keyref` with:

- Kind.
- Name and stable anchor.
- Selector XPath from `xs:selector/@xpath`.
- Field XPath values from `xs:field/@xpath`.
- `xs:keyref/@refer` target, linked when resolvable.
- Annotations.

XSD 1.1 allows an identity constraint to be a reference through `@ref`. When
`@ref` is present, the generator must render the reference, link to the
referenced identity constraint when resolvable, and keep unresolved references
visible.

The generator must not evaluate selector or field XPath expressions. It must
display them as schema-authored constraints.

When a key or unique constraint is referenced by one or more keyrefs, the target
component must include a backlink section.

## 16. Type Alternatives

The generator must render XSD 1.1 conditional type assignment from
`xs:alternative` with:

- Source order.
- `@test` XPath expression, if present.
- Selected type from `@type` or inline type.
- Default alternative, when an alternative has no `@test`. Only the last
  alternative may omit `@test`; it then serves as the default.
- `@xpathDefaultNamespace`.
- Annotations.
- Inheritable attributes relevant to the test context, when discoverable.

The generator must not evaluate alternative tests. It must display their order
because the first successful alternative determines the selected type.

When showing inheritable attributes available to a CTA test context, the
generator should distinguish attributes inherited from ancestor type
definitions from attributes declared on the type itself. Attributes declared on
the current type are inherited by derived or descendant contexts, but they are
not inherited to the same type's own test context.

## 17. Assertions

The generator must render XSD 1.1 assertions from:

- `xs:assert` on complex types.
- `xs:assertion` facets on simple types.

For each assertion, display:

- `@test` XPath expression.
- `@xpathDefaultNamespace`.
- Optional message or annotation content when present in source.
- Owning type or facet context.

The generator must not evaluate assertions.

## 18. Open Content and Default Attributes

The generator must render XSD 1.1 open content from:

- `xs:openContent` in complex types.
- `xs:defaultOpenContent` at schema level.

For each open-content declaration, display:

- Mode: none, interleave, or suffix. The `none` mode is allowed only on
  `xs:openContent`; `xs:defaultOpenContent` permits only `interleave` and
  `suffix`.
- Wildcard details.
- Whether it is explicit on the type or inherited/effective from schema
  default open content.
- Whether it applies to empty content, where that information is represented.
- Annotations.

When computing effective open content for documentation, the generator must use
the following display rule: a type's own `xs:openContent` wins; otherwise
schema-level `xs:defaultOpenContent` applies only to complex-content types, and
applies to empty complex types only when `@appliesToEmpty` is true. Simple
content types must not be shown as receiving effective open content.

The generator must render schema-level `@defaultAttributes` and complex-type
`@defaultAttributesApply`, linking to the referenced attribute group when
resolvable and showing whether defaults apply to each complex type.

## 19. Notations

For every notation declaration, the generator must display:

- Name and target namespace.
- `@public`.
- `@system`.
- Annotations.
- Source fragment when enabled.

Simple-type enumeration values derived from `xs:NOTATION` should link to
matching notation declarations when resolvable.

## 20. Annotations, Documentation, and Appinfo

The generator must render `xs:annotation` wherever it appears. It must support:

- `xs:documentation`
- `xs:appinfo`
- `@source`
- `xml:lang`
- Mixed text and markup content.
- Foreign namespace content.

### 20.1 Documentation HTML Modes

In `safe` mode, the generator must sanitize markup inside `xs:documentation`.
It should allow common prose markup such as paragraphs, lists, emphasis, code,
preformatted text, block quotes, links, headings, and tables. It must remove or
neutralize executable content, event-handler attributes, dangerous URL schemes,
and IDs that could collide with generated anchors.

Safe mode must only promote elements in no namespace or the XHTML namespace to
HTML. A foreign-namespace element with an HTML local name must not become HTML
by accident. Allowed links must be limited to safe schemes such as `http`,
`https`, `mailto`, `tel`, `ftp`, `ftps`, relative URLs, and same-document
fragments; schemes such as `javascript`, `data`, `vbscript`, and `file` must be
rejected case-insensitively after trimming/control-character normalization.
Copied documentation links should include `rel="external noopener noreferrer"`
when they open a new browsing context.

Safe mode should not emit `img` from schema-authored documentation. The safe
fallback for unsupported elements is to render their text children and drop
unsafe attributes.

In safe mode, whitespace at the very start and end of a documentation block
should be treated as authoring indentation and trimmed. Interior whitespace
and line breaks must be preserved.

In `permissive` mode, the generator may copy documentation content verbatim.
The mode must be documented as unsafe and suitable only for trusted schemas.

A documentation element with no renderable content (no non-whitespace text and
no element children, in either mode) must not produce an empty body or an
expansion control. When such an element carries a `@source` that survives
safe-URL filtering, the source link must still be rendered; when it carries
neither, the element renders nothing. The enclosing "Documentation" section
heading is unaffected by this rule.

`xs:appinfo` should be shown as structured source-like content by default. The
generator must not execute appinfo content.

## 21. Schema Composition Features

Annotations authored on composition declarations (`xs:include`, `xs:import`,
`xs:redefine`, `xs:override`) must be rendered with the declaration's entry in
the schema overview, following the documentation rendering rules of section 20.

### 21.1 Include

`xs:include` must be displayed in the schema overview, including
`@schemaLocation`, load status, and chameleon behavior.

### 21.2 Import

`xs:import` must be displayed with `@namespace`, `@schemaLocation`, load status,
and the imported namespace's components when loaded. Imports without
`@schemaLocation` must be listed as namespace dependencies rather than load
failures.

### 21.3 Redefine

`xs:redefine` must be displayed as an XSD 1.0 composition mechanism retained in
XSD 1.1 with changed/deprecated status. Redefined simple types, complex types,
model groups, and attribute groups must be visibly marked and linked to their
base/original names when resolvable.

The generator must not try to prove that a redefinition is valid. It must
document what the schema declares.

### 21.4 Override

`xs:override` must be displayed as an XSD 1.1 composition mechanism.
Overridden components must be visibly marked. The generator should display an
override map showing which loaded schema documents and components are affected
when discoverable.

The generator must prevent cycles or repeated override walks from causing
non-termination.

## 22. Versioning and Conditional Inclusion

The generator must render XSD 1.1 versioning attributes in the namespace
`http://www.w3.org/2007/XMLSchema-versioning`:

- `vc:minVersion`
- `vc:maxVersion`
- `vc:typeAvailable`
- `vc:typeUnavailable`
- `vc:facetAvailable`
- `vc:facetUnavailable`

These attributes may appear on XSD elements. The generator must display:

- The exact attribute name and value.
- The element on which it appears.
- The nearest owning schema component.
- An explanation that the documentation renderer shows the source and does not
  apply conditional inclusion filtering by default.

The feature summary must report when versioning annotations are present. Since
`vc:*` can occur deeply inside components, the summary should group nested
versioning annotations by the nearest named owning component to avoid a noisy
flat list.

## 23. XSD 1.0 and XSD 1.1 Feature Coverage Matrix

| Feature                                       | XSD 1.0 | XSD 1.1             | Rendering requirement                                           |
| --------------------------------------------- | ------- | ------------------- | --------------------------------------------------------------- |
| Schema document metadata                      | Yes     | Yes                 | Overview metadata and schema collection table.                  |
| Global elements                               | Yes     | Yes                 | Component cards, content constraints, type links.               |
| Global attributes                             | Yes     | Yes                 | Component cards and attribute-use tables.                       |
| Complex types                                 | Yes     | Yes                 | Derivation, content model, attributes, assertions/open content. |
| Simple types                                  | Yes     | Yes                 | Variety, derivation, facets, built-in datatype links.           |
| Model groups                                  | Yes     | Yes                 | Definition cards and content model expansion.                   |
| Attribute groups                              | Yes     | Yes                 | Definition cards and attribute expansion.                       |
| Notations                                     | Yes     | Yes                 | Notation cards and NOTATION enumeration links.                  |
| Identity constraints                          | Yes     | Yes                 | Selector/field/keyref tables with backlinks.                    |
| Substitution groups                           | Yes     | Yes                 | Head/member links and abstract/block metadata.                  |
| Include/import                                | Yes     | Yes                 | Schema collection graph with load diagnostics.                  |
| Chameleon include                             | Yes     | Yes                 | Effective namespace handling and visible note.                  |
| Redefine                                      | Yes     | Retained/deprecated | Redefined markers and source context.                           |
| Override                                      | No      | Yes                 | Overridden markers and override map.                            |
| Assertions on complex types                   | No      | Yes                 | Assertion panels.                                               |
| Assertion facet on simple types               | No      | Yes                 | Facet table rows.                                               |
| Type alternatives                             | No      | Yes                 | Ordered CTA table.                                              |
| Open content                                  | No      | Yes                 | Open-content panel and wildcard rendering.                      |
| Default open content                          | No      | Yes                 | Overview and effective per-type note.                           |
| Default attributes                            | No      | Yes                 | Overview and per-type application note.                         |
| Inheritable attributes                        | No      | Yes                 | Attribute tables and CTA context notes.                         |
| Identity constraint references (`@ref`)       | No      | Yes                 | Reference rendering with links to the target constraint.        |
| Local declaration `targetNamespace`           | No      | Yes                 | Element and attribute declaration details.                      |
| Wildcard `notNamespace` and `notQName`        | No      | Yes                 | Wildcard details with tokens.                                   |
| `xs:all` wildcards and `maxOccurs>1`          | No      | Yes                 | Content model support.                                          |
| Conditional inclusion `vc:*`                  | No      | Yes                 | Versioning panels and feature summary.                          |
| `xs:dateTimeStamp`                            | No      | Yes                 | Built-in datatype link and XSD 1.1 marker.                      |
| `xs:yearMonthDuration` / `xs:dayTimeDuration` | No      | Yes                 | Built-in datatype links and XSD 1.1 marker.                     |
| `xs:explicitTimezone` facet                   | No      | Yes                 | Facet rendering.                                                |

## 24. Cross-References and Anchors

Every global component and every identity constraint must have a stable anchor.
Anchor generation must be deterministic and namespace-aware.

Global component anchors should use this stable shape:

```text
{kind-abbreviation}-{namespace-id}-{local-name}
```

The kind abbreviations are `el`, `ct`, `st`, `at`, `ag`, `gr`, and `no` for
element, complex type, simple type, attribute, attribute group, model group, and
notation respectively. The primary namespace may use an empty namespace ID;
secondary namespaces must receive deterministic IDs such as `ns1`, `ns2`, and
so on in schema-collection order. Redefined and overridden components must get
stable suffixes such as `-redefined` and `-overridden` to avoid collisions.

The generator must render internal links for resolvable references to:

- Elements.
- Attributes.
- Simple types.
- Complex types.
- Attribute groups.
- Model groups.
- Notations.
- Identity constraints.

References to XSD built-in types and facets should link to W3C specification
sections. References outside the loaded schema collection must remain visible
as unresolved or external, depending on whether they identify a known namespace
without a loaded document.

Cross-references must have three visually and programmatically distinct states:
internal resolved links, external built-in/specification links, and unresolved
references. Unresolved references should remain focusable or otherwise expose a
diagnostic title so keyboard and assistive-technology users can discover why no
link was created.

References to known non-XSD namespaces outside the loaded schema collection may
render as external unresolved references rather than diagnostics when no local
document was requested or loaded. They must still preserve the authored lexical
QName and the namespace identity, so the reader can distinguish "outside this
documentation set" from "could not be resolved in a loaded set".

The generator should provide backlinks where they are useful and inexpensive:

- Type users.
- Derived types.
- Substitution group members.
- Group users.
- Attribute-group users.
- Attribute users.
- Keyref users.

## 25. Source Rendering

When `show-source` is true, the generator must include a source fragment for
each global component and may include source fragments for schema-level
composition declarations.

Source rendering must:

- Escape markup safely.
- Preserve attributes, and emit the namespace declarations the fragment uses:
  a prefix counts as used when it appears in an emitted element or attribute
  name or as a QName-shaped token in an attribute value. Unused in-scope
  prefixed declarations may be omitted; the default namespace declaration must
  always be preserved.
- Preserve meaningful text in annotations.
- Avoid changing the schema semantics.
- Use syntax highlighting only as presentation.

Source blocks should be wrapped in `details` so the page remains scannable.

## 26. Search and Navigation

The page must include navigation grouped by component kind. It should include a
client-side filter when JavaScript is available.

The JavaScript filter should build its search index from the rendered DOM
rather than from a separate schema-data payload. A small JSON message bundle for
localized runtime strings is allowed, but schema content must remain in the
HTML itself.

Search/filter behavior should match:

- Component local name.
- QName or namespace display.
- Documentation text.
- Kind label.

Filtering must not remove content from the document; it may hide unmatched
sections visually while a filter is active. Clearing the filter must restore
the full page without reloading.

## 27. Internationalization

The generator must separate:

- UI language: labels, headings, table headers, buttons, status messages.
- XSD prose language: `xs:documentation` content.

`interface-language` must control the HTML document language and UI message
lookup. `documentation-language` must be used only as a fallback for
XSD-authored prose wrappers. Per-block `xml:lang` must override
`documentation-language`.

UI message lookup must have a deterministic fallback chain: exact BCP 47 tag,
then primary language subtag, then English. Missing message keys must be
visibly detectable during development, for example by rendering a bracketed key
placeholder rather than silently falling back to an empty string.

All generated chrome that a user can see or interact with must flow through the
UI message catalog. This includes headings, table captions and column labels,
badges, button labels, aria labels, filter placeholders, dynamic JavaScript
status strings, copy-link feedback, show-more/show-less text, theme labels, and
diagnostic headings. Schema-authored names, QNames, namespace URIs, XPath
expressions, regexes, facet values, and source code must not be translated.

The generator must preserve author-supplied `xml:lang` on each
`xs:documentation` wrapper. When a documentation block has no `xml:lang`, the
wrapper must use `documentation-language`. `xs:appinfo` and source listings
should not be assigned a prose language unless the source explicitly supplies
one.

`interface-direction=auto` should infer right-to-left layout from the primary
language subtag for common RTL languages. Explicit `interface-direction=ltr`
and `interface-direction=rtl` must override inference.

Direction handling must distinguish UI chrome from schema/source content. The
page `dir` follows `interface-direction`; schema source, QNames, namespace URIs,
XPath expressions, regexes, and code-like values should render left-to-right or
inside bidi-isolating elements so punctuation and prefixes remain readable in
RTL interfaces. Free-form documentation prose may use `dir="auto"` or the
author's explicit direction where available.

Layout CSS should use logical properties where practical so navigation,
spacing, and alignment work in both LTR and RTL interfaces without a separate
stylesheet.

## 28. Security

The generator must treat schema-authored documentation and appinfo as untrusted
content by default.

The default output must:

- Escape text and attributes.
- Sanitize documentation markup in `safe` mode.
- Reject dangerous link schemes in copied documentation links.
- Avoid executable inline schema-authored content.
- Avoid remote script or style dependencies.
- Avoid generated IDs derived from unsanitized arbitrary strings.

The generator must document the risks of `documentation-markup=permissive`.

## 29. Diagnostics

Diagnostics must be visible in the generated HTML and should be easy to find
from the overview. At minimum, diagnostics must cover:

- Unloaded schema documents.
- Circular schema-location traversal avoided by the generator.
- Unresolved QName references.
- Recursive group or attribute-group expansion stopped by the generator.
- Unsupported or unknown XSD namespace elements encountered in schema positions.
- Invalid parameter values that were normalized or defaulted.

Diagnostics must not be phrased as validation errors unless the generator
actually performs validation. The preferred language is "not loaded",
"not resolved", "not expanded", or "not recognized".

Every diagnostic should include enough context for a reader to locate the
source of the issue: the affected schema document when known, the nearest
owning component when one exists, the XSD element or attribute involved, and a
link from the relevant overview row, component article, or unresolved marker
when that link can be generated deterministically. Diagnostics are page facts,
not transient console output.

## 30. Non-Goals

The generator must not be required to:

- Validate schema correctness.
- Validate XML instances.
- Generate sample XML instances.
- Produce PSVI output.
- Evaluate XPath assertions, identity constraints, or type alternatives.
- Apply conditional inclusion filtering by default.
- Produce multiple HTML files.
- Require browser-side frameworks.

These capabilities may be added later only as explicit, documented extensions.

## 31. Testing Requirements

The implementation must include automated tests derived from this
specification's behavior and from the XSD 1.0/1.1 feature surface. Tests may be
unit, integration, browser, or end-to-end tests, but the suite must prove the
observable HTML contract rather than merely exercising internal helper
functions.

The preferred workflow is test-first for behavior changes: add or update the
smallest scenario that captures the intended observable behavior, confirm it
fails for the expected reason, change the stylesheet, then run the relevant
single XSpec file before the full suite. Documentation-only changes do not need
new XSpec scenarios, but they must not weaken the requirements below.

### 31.1 Parameters and Output Contract

Tests must cover every public parameter:

- `page-title`: explicit title, `@id` fallback, target-namespace fallback, and
  generic fallback.
- `asset-base-uri`: generated CSS and JS URLs.
- `show-source`: source blocks present and absent.
- `documentation-markup`: `safe` and `permissive` behavior.
- `interface-language`: `<html lang>` and UI message lookup.
- `documentation-language`: fallback language on XSD prose wrappers.
- `interface-direction`: `auto`, explicit `ltr`, and explicit `rtl`.
- `robots-noindex`: robots meta tag present and absent.

Output-contract tests must verify HTML5 serialization, one-page output,
deterministic anchors, deterministic generated namespace IDs, generator
metadata, local asset references, no required remote dependencies, and usable
content when JavaScript is disabled.

### 31.2 Schema Collection and Resolution

Tests must cover schema collection traversal through `xs:include`,
`xs:import`, `xs:redefine`, and `xs:override`, including transitive traversal,
relative `schemaLocation` resolution, missing `schemaLocation` on imports,
failed document loads, and cycle prevention.

QName-resolution tests must cover prefixed references, unprefixed same-target
namespace references, default-namespace fallback, no-namespace references,
imported namespaces, chameleon-included effective namespaces, unresolved
references, and Clark-form-equivalent namespace separation for same local names
in different namespaces.

### 31.3 Component Coverage

Tests must cover every global component kind:

- `xs:element`
- `xs:attribute`
- `xs:complexType`
- `xs:simpleType`
- `xs:group`
- `xs:attributeGroup`
- `xs:notation`

For each kind, tests must verify name, namespace, annotations, stable anchor,
navigation entry, source rendering when enabled, source omission when disabled,
cross-references, and unresolved-reference presentation where applicable.

Tests must also cover contextual/helper components: annotations, appinfo,
attribute uses, particles, model groups, wildcards, identity constraints, type
alternatives, assertions, open content, and default open content.

### 31.4 Elements, Attributes, and Type Definitions

Element tests must cover global and local declarations, references, anonymous
types, named type links, `minOccurs`, `maxOccurs`, `default`, `fixed`,
`nillable`, `abstract`, `block`, `final`, `form`, XSD 1.1 local
`targetNamespace`, identity constraints, type alternatives, and
substitution-group heads and members.

Attribute tests must cover global and local declarations, references, anonymous
simple types, named type links, `use` values including `prohibited`, `default`,
`fixed`, `form`, XSD 1.1 local `targetNamespace`, and XSD 1.1 `inheritable`.

Complex-type tests must cover simple content, complex content, extension,
restriction, empty content, element-only content, mixed content, attribute uses,
attribute wildcards, derivation chains, known derived types, assertions, own
open content, and inherited/effective default open content.

Simple-type tests must cover restriction, list, union, inline member/item types,
named member/item types, built-in datatype links, XSD 1.0 built-ins, XSD
1.1-only built-ins, NOTATION-derived enumerations, and every constraining facet:
`length`, `minLength`, `maxLength`, `pattern`, `enumeration`, `whiteSpace`,
`maxInclusive`, `maxExclusive`, `minExclusive`, `minInclusive`, `totalDigits`,
`fractionDigits`, `assertion`, and `explicitTimezone`. Repeated-facet tests
must cover multiple pattern facets in one restriction step rendered with
OR-within-step semantics and patterns across derivation steps rendered with
AND-across-step semantics.

### 31.5 Content Models, Groups, and Wildcards

Content-model tests must cover `xs:sequence`, `xs:choice`, `xs:all`, nested
model groups, `xs:group/@ref`, local element particles, element references,
wildcard particles, and occurrence ranges including `0`, `1`, bounded values,
and `unbounded`.

Group tests must cover model group definitions, group references, recursive or
cyclic group references, attribute group definitions, attribute group
references, recursive or cyclic attribute-group references, and known
references/backlinks.

Wildcard tests must cover `xs:any`, `xs:anyAttribute`, `namespace`,
`notNamespace`, `notQName`, `processContents`, all wildcard tokens (`##any`,
`##other`, `##local`, `##targetNamespace`, `##defined`,
`##definedSibling`), token placement rules including `##definedSibling` on
element wildcards only, and XSD 1.1 wildcards inside `xs:all`.

### 31.6 Constraints and XSD 1.1 Features

Identity-constraint tests must cover `xs:key`, `xs:unique`, `xs:keyref`,
selector XPath, multiple field XPath values, keyref `refer` links, unresolved
`refer`, XSD 1.1 identity-constraint references through `@ref` both resolved
and unresolved, and backlinks from key/unique targets to keyrefs.

Substitution-group tests must cover member-to-head links, head-to-member
backlinks, abstract heads, blocking metadata, and transitive head chains.

XSD 1.1 feature tests must cover `xs:assert`, `xs:assertion`,
`xs:alternative` source order and default alternative, `@xpathDefaultNamespace`,
CTA inherited-attribute context, `xs:openContent`, `xs:defaultOpenContent`,
`@appliesToEmpty`, `@defaultAttributes`, `@defaultAttributesApply`,
`@inheritable`, XSD 1.1 `xs:all` changes, wildcard negation, and all
`vc:*` attributes (`minVersion`, `maxVersion`, `typeAvailable`,
`typeUnavailable`, `facetAvailable`, `facetUnavailable`) including nested
versioning annotations grouped by owning component.

Composition tests must cover redefined and overridden components, visible
markers, stable non-colliding anchors, and non-termination prevention for
malformed or cyclic composition graphs.

### 31.7 Documentation, Security, and Source Rendering

Documentation tests must cover `xs:documentation`, `xs:appinfo`, `@source`,
`xml:lang`, text-only documentation, mixed content, safe-mode allowlisted
markup, safe-mode foreign namespace handling, unsafe element stripping, unsafe
attribute stripping, rejected URL schemes, allowed URL schemes, explicit line
break preservation, and permissive-mode verbatim rendering for trusted input.

Security tests must verify escaping of schema-authored text and attributes,
absence of executable schema-authored content in default output, no generated
IDs from unsanitized arbitrary strings, and documented unsafe behavior for
`documentation-markup=permissive`.

Source-rendering tests must verify escaped markup, namespace preservation,
attribute preservation, annotation text preservation, left-to-right source
direction, and syntax highlighting that does not alter source text.

### 31.8 Navigation, Assets, and Progressive Enhancement

Navigation tests must cover component grouping, component counts, search/filter
matches by name, QName/namespace, kind, and documentation text, clearing the
filter, no content loss after filtering, copy-link targets, expand/collapse
controls, and DOM-derived search indexing.

Asset tests must verify generated links to the stylesheet and deferred script,
no third-party runtime dependencies, no required schema-data JavaScript payload,
localized runtime-string availability, theme behavior layered on
`prefers-color-scheme`, and no-JavaScript readability.

### 31.9 Internationalization and Accessibility

Internationalization tests must cover exact locale fallback, primary-subtag
fallback, English fallback, missing-key visibility, full chrome localization,
JavaScript runtime-string localization, `<html lang>`, `xml:lang` preservation,
`documentation-language` fallback, `interface-direction=auto`, explicit
direction overrides, RTL chrome, and LTR/bidi-isolated rendering of QNames,
namespace URIs, XPath expressions, regexes, facet values, and source code.

Accessibility tests must cover landmark structure, skip-link target, heading
order, labelled navigation/search/buttons, icon-button accessible names,
table captions and headers, focus indicators, keyboard access to every
interactive control, no focus traps during filtering, live/status
discoverability for filter results and copy-link feedback, focusable unresolved
reference diagnostics, non-color-only indicators, source blocks as text, and
contrast in light and dark schemes.

### 31.10 Diagnostics and End-to-End Gates

Diagnostic tests must cover unloaded schema documents, circular schema
collection traversal, unresolved QNames, recursive group expansion,
recursive attribute-group expansion, unknown XSD-namespace elements in schema
positions, and invalid parameter values that are normalized or defaulted.

End-to-end tests must render at least:

- A compact schema that intentionally exercises every XSD 1.0 component family.
- A compact schema that intentionally exercises the XSD 1.1-only features.
- A multi-document schema collection with include, import, redefine, override,
  chameleon include, and at least one missing reference.
- A substantial real-world or standards schema large enough to expose
  performance, navigation, and HTML-validity problems.

Every end-to-end render must validate the produced HTML, verify required local
assets, check for broken same-document component links, and assert that the
transform completes without non-termination on cyclic inputs.

## 32. Acceptance Criteria

An implementation satisfies this specification when:

- It renders a stand-alone HTML page from a primary schema using XSLT 3.0.
- It walks the schema collection through include, import, redefine, and
  override without non-termination.
- It renders every XSD 1.0 and XSD 1.1 feature listed in this document.
- It preserves all schema-authored documentation and appinfo safely.
- It creates stable, namespace-aware links among schema components.
- It reports recoverable problems in the HTML instead of aborting.
- It remains usable with CSS disabled and with JavaScript disabled.
- Its automated tests cover the feature matrix and pass in CI.
