# xsdstyle

`xsdstyle` transforms an XSD 1.0 or XSD 1.1 schema collection into a single,
static HTML documentation page. It follows `xs:include`, `xs:import`,
`xs:redefine`, and `xs:override` links, documents global schema components,
renders local constructs where they are used, and keeps unresolved or unloaded
facts visible as diagnostics.

The distribution is intentionally small: one XSLT 3.0 stylesheet plus local
CSS, JavaScript, and icon assets. The generated page does not require
JavaScript to expose schema facts; JavaScript only adds progressive
enhancements such as filtering, copy links, disclosure controls, and theme
behavior.

## Features

- Single-page HTML output suitable for local files, static hosting, or CI
  artifacts.
- Documentation for elements, complex types, simple types, attributes,
  attribute groups, model groups, notations, annotations, identity constraints,
  assertions, alternatives, wildcards, open content, and source fragments.
- Transitive schema collection loading for imports, includes, redefines, and
  overrides, including chameleon include effective namespaces.
- Namespace-aware reference linking using resolved QNames rather than prefixes.
- Visible diagnostics for failed schema loads, unresolved references, parameter
  normalization, and skipped expansions.
- Deterministic anchors and ordering for stable links and reproducible output.
- Accessible semantic HTML with keyboard-operable controls and light/dark
  color-scheme support.
- Safe default handling for markup embedded in `xs:documentation`.

## Quick Start

Render a schema with the local Make target:

```sh
make render SCHEMA=path/to/schema.xsd
```

The generated site is written to `out/index.html`, with bundled assets copied
to `out/assets/`.

On macOS, Saxon can be provided by Homebrew:

```sh
brew install saxon
make render SCHEMA=path/to/schema.xsd
```

On other systems, or when Homebrew Saxon is not available, the Makefile vendors
checksum-verified Saxon-HE and xmlresolver jars into `.tools/` automatically.
You can also provide your own Saxon classpath:

```sh
SAXON_CP=/path/to/saxon-he.jar make render SCHEMA=path/to/schema.xsd
```

## Direct Saxon Usage

You can run the stylesheet directly with any XSLT 3.0 processor compatible with
the project requirements. With Saxon:

```sh
java -cp "$SAXON_CP" net.sf.saxon.Transform \
  -s:path/to/schema.xsd \
  -xsl:xsdstyle.xsl \
  -o:out/index.html
```

When running directly, copy `assets/` beside the generated HTML or set
`asset-base-uri` to the URL where the assets will be served.

## Parameters

Override stylesheet parameters with Saxon `name=value` arguments:

```sh
java -cp "$SAXON_CP" net.sf.saxon.Transform \
  -s:path/to/schema.xsd \
  -xsl:xsdstyle.xsl \
  -o:out/index.html \
  page-title="Customer API" \
  show-source=false
```

| Parameter                | Default     | Description                                                       |
| ------------------------ | ----------- | ----------------------------------------------------------------- |
| `page-title`             | derived     | Overrides the page title and primary heading.                     |
| `asset-base-uri`         | `./assets/` | Prefix for `xsdstyle.css`, `xsdstyle.js`, and icon assets.        |
| `show-source`            | `true`      | Embeds source fragments for documented components.                |
| `documentation-markup`   | `safe`      | Renders `xs:documentation` markup in `safe` or `permissive` mode. |
| `interface-language`     | `en`        | Sets UI language and `<html lang>`.                               |
| `documentation-language` | `en`        | Fallback language for schema-authored prose without `xml:lang`.   |
| `interface-direction`    | `auto`      | Sets `<html dir>`; accepts `auto`, `ltr`, or `rtl`.               |
| `robots-noindex`         | `false`     | Emits a `noindex` robots meta tag when true.                      |

Invalid values are normalized to documented defaults where possible and
reported in the generated diagnostics rather than silently ignored.

## GitHub Action

Use the Docker-based action to publish schema documentation from a workflow:

```yaml
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: bardiharborow/xsdstyle@v1
        with:
          xsd-file: schemas/customer.xsd
          output-dir: out
          output-html: index.html
          page-title: Customer Schema
```

The action writes the generated HTML and copied assets into `output-dir`.
All stylesheet parameters are available as action inputs with the same names.

## Security

Schema-authored documentation is treated as untrusted input. The default
`documentation-markup=safe` mode allowlists documentation markup, strips IDs
that could collide with generated anchors, and rejects unsafe URL schemes.

Use `documentation-markup=permissive` only for trusted schemas. It may copy
schema-authored markup verbatim, including scripts and event-handler
attributes.

## Development

Run the XSpec suite:

```sh
make test
```

Run one focused XSpec file:

```sh
make test XSPEC_TESTS=test/example.xspec
```

Run lint checks:

```sh
make lint
```

Format supported source files:

```sh
make format
```

Render the W3C XSD-of-XSDs and validate the generated HTML/CSS:

```sh
make smoke-test
```

Run the accessibility audit against a rendered page:

```sh
make lint-a11y
```

Behavioral changes should start with the relevant XSpec scenario. The product
contract lives in `docs/specification.md`; `docs/architecture.md` describes the
stylesheet pipeline; `docs/dom.md` defines the generated HTML contract.

## History

This project was inspired by the [xs3p](https://github.com/neeraj9/xs3p) project.

## License

This project is licensed under the terms of the [MIT License](LICENSE).

## Bibliography

World Wide Web Consortium. (2012). _W3C XML Schema Definition Language (XSD) 1.1 Part 1: Structures_. https://www.w3.org/TR/xmlschema11-1/

World Wide Web Consortium. (2012). _W3C XML Schema Definition Language (XSD) 1.1 Part 2: Datatypes_. https://www.w3.org/TR/xmlschema11-2/

World Wide Web Consortium. (2017). _XSL Transformations (XSLT) Version 3.0_. https://www.w3.org/TR/xslt-30/
