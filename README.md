# xsdstyle

An Extensible Stylesheet Language Transformations (XSLT) stylesheet to generate
documentation for XML Schema Definition (XSD) schemas.

## Use as a GitHub Action

Render an XSD and publish the result in one workflow:

```yaml
- uses: bardiharborow/xsdstyle@v1
  with:
    xsd-file: schemas/my-schema.xsd
- uses: actions/upload-pages-artifact@v3
  with:
    path: out
```

The action runs in a container with Saxon-HE preinstalled, so it only works on
Linux runners (`ubuntu-latest`, `ubuntu-24.04`, etc.).

### Action inputs

| Name             | Required | Default      | Description                                                                                                                                           |
| ---------------- | -------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `xsd-file`       | yes      | —            | Path to the input `.xsd` file, relative to the workspace.                                                                                             |
| `output-dir`     | no       | `out`        | Directory the generated site is written into.                                                                                                         |
| `output-html`    | no       | `index.html` | Filename for the generated HTML page, inside `output-dir`.                                                                                            |
| `title`          | no       | (see below)  | Page title.                                                                                                                                           |
| `base-href`      | no       | `./assets/`  | URL prefix for `xsdstyle.css` and `xsdstyle.js`.                                                                                                      |
| `include-source` | no       | `true`       | Embed the raw XSD source per component.                                                                                                               |
| `doc-html`       | no       | `safe`       | How to render HTML inside `xs:documentation` (`safe` or `permissive`).                                                                                |
| `ui-lang`        | no       | `en`         | BCP 47 language tag for the UI chrome. Drives `<html lang="…">` and the chrome translation lookup.                                                    |
| `xml-lang`       | no       | `en`         | BCP 47 language tag for XSD-sourced prose. Emitted as a fallback `lang="…"` on documentation wrappers when the XSD block has no per-block `xml:lang`. |
| `dir`            | no       | `auto`       | Writing direction for `<html dir="…">`. `auto` infers `rtl` from `ui-lang`; or `ltr`/`rtl` explicit.                                                  |
| `noindex`        | no       | `false`      | Emit `<meta name="robots" content="noindex">` in the generated page.                                                                                  |

See [Parameters](#parameters) for the semantics of each one.

### Action outputs

| Name         | Description                                          |
| ------------ | ---------------------------------------------------- |
| `output-dir` | The directory containing `index.html` and `assets/`. |

The container runs as root, so files written into the workspace are owned by
root on the runner host. That is the GitHub Actions default for Docker actions
and matches how `actions/checkout` and friends are usually consumed.

## Manual usage

`xsdstyle.xsl` is an XSLT 3.0 stylesheet. Install a compatible XSLT tool, such
as Saxon, and run it against the XSD you want to document. Then copy the bundled
CSS and JS next to the generated HTML:

```sh
brew install saxon
saxon -s:schema.xsd -xsl:xsdstyle.xsl -o:out/index.html
cp -R assets out/assets
```

### Parameters

Override with `-param:name=value` on the Saxon command line.

- **`title`** (string) — Page title. Defaults to `@id`, then `Schema: {targetNamespace}`, then `XSD Documentation`.
- **`base-href`** (string, default `./assets/`) — URL prefix for `xsdstyle.css` and `xsdstyle.js`. Set this when the assets live somewhere other than `./assets/`.
- **`include-source`** (boolean, default `true`) — Embed the raw XSD source for each component. Set to `false` to drop the per-component source blocks.
- **`doc-html`** (string, default `safe`) — How to render embedded HTML inside `xs:documentation`. `safe` applies an allowlist of tags and attributes and strips `javascript:`, `data:`, `vbscript:`, and `file:` hrefs. `permissive` copies every element and attribute verbatim — only use this when every schema author is trusted, since the output can carry `<script>`, `on*=` handlers, etc.
- **`ui-lang`** (string, default `en`) — BCP 47 language tag for the UI chrome. Emitted as the `<html lang="…">` attribute on the generated page and selects which UI message catalog (sidebar headings, table column titles, button labels, occurrence tooltips, etc.) is used. Currently only `en` is bundled; unknown tags fall back to English. See [Localisation](#localisation) for adding a translation.
- **`xml-lang`** (string, default `en`) — BCP 47 language tag for XSD-sourced prose. Emitted as a fallback `lang="…"` on `<xs:annotation>` / `<xs:documentation>` wrappers when the block has no per-block `xml:lang`. Per-block `xml:lang` on the XSD always wins for its own wrapper. This parameter does not affect chrome lookup or `<html lang>`. Callers who previously passed `xml-lang=fr` expecting French chrome now need `ui-lang=fr`.
- **`dir`** (string, default `auto`) — Writing direction emitted as the `<html dir="…">` attribute. `auto` resolves to `rtl` when `ui-lang`'s primary subtag is one of `ar`, `he`, `fa`, `ur`, `ps`, `yi`, `dv`, `ug`, `ckb`, `sd`, `arc`, and to `ltr` otherwise. Pass `ltr` or `rtl` to override the inference. The stylesheet uses CSS logical properties throughout, so the chrome flips automatically; XSD source blocks stay LTR regardless.
- **`noindex`** (boolean, default `false`) — When `true`, emit `<meta name="robots" content="noindex">` in the page `<head>` so search engines skip indexing it. Useful for preview deployments, drafts, or internal-only schemas.

Example with parameters:

```sh
saxon \
  -s:schema.xsd \
  -xsl:xsdstyle.xsl \
  -o:out/index.html \
  title="My Schema" \
  base-href=/static/xsdstyle/ \
  include-source=false
```

## Localisation

The UI chrome rendered by `xsdstyle.xsl` — sidebar headings, page metadata
labels, table column titles, button labels, occurrence tooltips, the "Show
more / Show less" toggle, and so on — flows through a single inline message
catalog (`xsl:variable name="i18n-messages"` near the top of Region 9). The
active locale is picked from the `ui-lang` parameter via this fallback chain:

1. Exact tag match (e.g. `fr-CA`)
2. Primary subtag match (e.g. `fr`)
3. English (`en`)

The HTML `lang="…"` attribute always reflects the caller-supplied `ui-lang`
verbatim, even when the message lookup falls back. Missing keys render as
`[[key]]` so omissions are visible during development.

XSD content language is a separate axis, controlled by `xml-lang`. When an
`<xs:annotation>` or `<xs:documentation>` block carries its own `@xml:lang`,
that wins for the surrounding HTML wrapper; otherwise the wrapper falls back
to `lang="$xml-lang"`. The chrome locale (`ui-lang`) is independent and never
shows up on the doc wrappers.

A small fixed-shape subset of messages is also emitted as a JSON `<script
type="application/json" id="xsdoc-i18n">` block, which `xsdstyle.js` reads to
localise its dynamic strings (filter status line, "Show more" toggle, aria
labels). The script keeps a baked-in English fallback so it still works
standalone.

### Adding a locale

1. Copy the `'en':` block inside `$i18n-messages`.
2. Change the outer key to your BCP 47 tag (lowercase; e.g. `'fr'`, `'pt-br'`).
3. Translate the values; leave keys untouched — they are part of the contract.
4. Test the render with `-param:ui-lang=<your-tag>`.

Sentences that embed `<code>` elements (such as the XSD 1.1 features list)
are split into adjacent keys around the literal, or use the
`emit-i18n-with-codes` named template that walks `{placeholder}` tokens and
emits `<code>` spans inline.

## Testing

Unit tests live in `test/*.xspec` and run under [XSpec](https://github.com/xspec/xspec), the XSLT/XQuery test framework. The Makefile vendors a pinned XSpec release into `.tools/` on first run (XSpec isn't packaged in Homebrew), and discovers Saxon from `brew install saxon`:

```sh
brew install saxon
make test
```

To use a Saxon jar from elsewhere, override `SAXON_CP`:

```sh
SAXON_CP=/path/to/saxon-he.jar make test
```

Per-run HTML reports are written to `test/xspec/` (gitignored). Run `make test-clean` to drop them.

## History

This project was inspired by the [xs3p](https://github.com/neeraj9/xs3p) project.

## License

This project is licensed under the terms of [the MIT License](LICENSE).

## Biblography

World Wide Web Consortium. (2012). _W3C XML Schema Definition Language (XSD) 1.1 Part 1: Structures_. https://www.w3.org/TR/xmlschema11-1/

World Wide Web Consortium. (2017). _XSL Transformations (XSLT) Version 3.0_. https://www.w3.org/TR/xslt-30/
