#!/bin/bash
# PostToolUse hook (Edit|Write): validate XML well-formedness, then auto-format
# with Prettier using the same invocation as the Makefile. Exit 2 feeds errors
# back to Claude; missing tooling is skipped rather than treated as failure.
set -u

command -v jq >/dev/null 2>&1 || exit 0

file="$(jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$file" ] && [ -f "$file" ] || exit 0

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$file" in
  "$project_dir"/*) ;;
  *) exit 0 ;;
esac

# Never touch generated/vendored output.
relative="${file#"$project_dir"/}"
case "$relative" in
  out/* | .tools/* | test/xspec/* | specifications/* | reference/*) exit 0 ;;
esac

extension="${file##*.}"

case "$extension" in
  xsl | xml | xsd | xspec)
    if command -v xmllint >/dev/null 2>&1; then
      if ! errors="$(xmllint --noout "$file" 2>&1)"; then
        echo "xmllint: $relative is not well-formed XML:" >&2
        echo "$errors" >&2
        exit 2
      fi
    fi
    ;;
esac

# Same file set and --plugin quirk as `make format`: bare prettier silently
# skips XML because .prettierrc.json deliberately omits "plugins".
case "$extension" in
  xsl | xml | xsd | xspec | css | js | json | yml | yaml | md)
    if command -v prettier >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
      plugin="$(npm root -g)/@prettier/plugin-xml/src/plugin.js"
      if [ -f "$plugin" ]; then
        prettier --plugin "$plugin" --log-level warn --write "$file" >&2 || true
      fi
    fi
    ;;
esac

# Run XSpec: the edited test file alone, or the full suite when the stylesheet
# itself changed. Test failures feed back to Claude; a failure is expected
# mid-TDD (test-first), so this is information, not a gate on the edit.
xspec_target=""
case "$relative" in
  test/*.xspec) xspec_target="XSPEC_TESTS=$relative" ;;
  xsdstyle.xsl) xspec_target="" ;;
  *) exit 0 ;;
esac
command -v make >/dev/null 2>&1 || exit 0

if [ -n "$xspec_target" ]; then
  output="$(cd "$project_dir" && make test "$xspec_target" 2>&1)"
else
  output="$(cd "$project_dir" && make test 2>&1)"
fi
status=$?

# Missing toolchain (no Saxon/JVM) is an environment problem, not feedback.
if [ $status -ne 0 ] && echo "$output" | grep -q "SAXON_CP could not be resolved"; then
  exit 0
fi

# xspec.sh exits 0 even when scenarios fail, so also parse the result counts.
if echo "$output" | grep -qE 'failed: [1-9]'; then
  status=1
fi

summary="$(echo "$output" | grep -E '^==>|passed:|FAILED|^[[:space:]]*([Ee]rror|ERROR)')"
if [ $status -ne 0 ]; then
  echo "XSpec failed after editing $relative:" >&2
  echo "${summary:-$output}" >&2
  echo "Reports: test/xspec/*-result.html. A failing test is expected if you are mid-TDD (test written first)." >&2
  exit 2
fi
echo "XSpec passed after editing $relative:" >&2
echo "$summary" | grep -E '^==>|passed:' >&2

exit 0
