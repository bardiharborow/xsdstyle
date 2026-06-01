#!/bin/sh
set -eu

if [ -z "${INPUT_XSD_FILE:-}" ]; then
    echo "::error::Input 'xsd-file' is required."
    exit 1
fi

if [ ! -f "$INPUT_XSD_FILE" ]; then
    echo "::error::XSD file not found: $INPUT_XSD_FILE"
    exit 1
fi

output_dir="${INPUT_OUTPUT_DIR:-out}"
output_html="${INPUT_OUTPUT_HTML:-index.html}"
mkdir -p "$output_dir"

set -- \
    "-s:$INPUT_XSD_FILE" \
    "-xsl:/opt/xsdstyle/xsdstyle.xsl" \
    "-o:$output_dir/$output_html"

# Only forward stylesheet parameters when the caller set them non-empty,
# so the XSL's own defaults remain authoritative for omitted inputs.
[ -n "${INPUT_TITLE:-}" ]          && set -- "$@" "title=$INPUT_TITLE"
[ -n "${INPUT_BASE_HREF:-}" ]      && set -- "$@" "base-href=$INPUT_BASE_HREF"
[ -n "${INPUT_INCLUDE_SOURCE:-}" ] && set -- "$@" "include-source=$INPUT_INCLUDE_SOURCE"
[ -n "${INPUT_DOC_HTML:-}" ]       && set -- "$@" "doc-html=$INPUT_DOC_HTML"
[ -n "${INPUT_UI_LANG:-}" ]        && set -- "$@" "ui-lang=$INPUT_UI_LANG"
[ -n "${INPUT_XML_LANG:-}" ]       && set -- "$@" "xml-lang=$INPUT_XML_LANG"
[ -n "${INPUT_DIR:-}" ]            && set -- "$@" "dir=$INPUT_DIR"
[ -n "${INPUT_NOINDEX:-}" ]        && set -- "$@" "noindex=$INPUT_NOINDEX"

java -cp "/opt/xsdstyle/lib/saxon-he.jar:/opt/xsdstyle/lib/xmlresolver.jar" \
    net.sf.saxon.Transform "$@"

rm -rf "$output_dir/assets"
cp -R /opt/xsdstyle/assets "$output_dir/assets"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "output-dir=$output_dir" >> "$GITHUB_OUTPUT"
fi
