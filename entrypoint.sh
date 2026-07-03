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
[ -n "${INPUT_PAGE_TITLE:-}" ]              && set -- "$@" "page-title=$INPUT_PAGE_TITLE"
[ -n "${INPUT_ASSET_BASE_URI:-}" ]          && set -- "$@" "asset-base-uri=$INPUT_ASSET_BASE_URI"
[ -n "${INPUT_SHOW_SOURCE:-}" ]             && set -- "$@" "show-source=$INPUT_SHOW_SOURCE"
[ -n "${INPUT_DOCUMENTATION_MARKUP:-}" ]    && set -- "$@" "documentation-markup=$INPUT_DOCUMENTATION_MARKUP"
[ -n "${INPUT_INTERFACE_LANGUAGE:-}" ]      && set -- "$@" "interface-language=$INPUT_INTERFACE_LANGUAGE"
[ -n "${INPUT_DOCUMENTATION_LANGUAGE:-}" ]  && set -- "$@" "documentation-language=$INPUT_DOCUMENTATION_LANGUAGE"
[ -n "${INPUT_INTERFACE_DIRECTION:-}" ]     && set -- "$@" "interface-direction=$INPUT_INTERFACE_DIRECTION"
[ -n "${INPUT_ROBOTS_NOINDEX:-}" ]          && set -- "$@" "robots-noindex=$INPUT_ROBOTS_NOINDEX"

java -cp "/opt/xsdstyle/lib/saxon-he.jar:/opt/xsdstyle/lib/xmlresolver.jar" \
    net.sf.saxon.Transform "$@"

rm -rf "$output_dir/assets"
cp -R /opt/xsdstyle/assets "$output_dir/assets"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "output-dir=$output_dir" >> "$GITHUB_OUTPUT"
fi
