.PHONY: \
	lint lint-xml lint-format lint-a11y format \
	install-prettier install-xspec install-saxon install-vnu install-axe install-sample-schemas \
	test test-coverage coverage test-clean \
	render smoke-test smoke-test-clean

TOOLS_DIR := .tools
ASSETS_DIR := assets
TEST_DIR := test
XSL := xsdstyle.xsl

CURL := curl -fsSL

define require_saxon_cp
	@if [ -z "$$SAXON_CP" ]; then \
		echo "ERROR: SAXON_CP could not be resolved."; \
		echo "  Try: brew install saxon  (or)  make install-saxon"; \
		exit 1; \
	fi
endef

define require_xspec_tests
	@if [ -z "$(XSPEC_TESTS)" ]; then echo "no xspec tests found in $(TEST_DIR)/"; exit 1; fi
endef

define download_checked
if [ ! -f "$(1)" ]; then \
	echo "==> Downloading $(2) into $(TOOLS_DIR)/"; \
	mkdir -p "$(TOOLS_DIR)"; \
	$(CURL) -o "$(1)" "$(3)"; \
	echo "$(4)  $(1)" | shasum -a 256 -c -; \
fi
endef

define run_xspec
	@set -e; for t in $(XSPEC_TESTS); do echo "==> $$t"; "$(XSPEC)" $(1) "$$t"; done
endef

PRETTIER_VERSION := 3.3.3
PRETTIER_XML_VERSION := 3.4.1
PRETTIER_GLOB := **/*.{xsl,xml,xsd,xspec,css,js,json,yml,yaml,md}

# Prettier 3's ESM plugin loader resolves package names relative to the CWD,
# so a globally-installed plugin isn't found by name. Pass its absolute path
# via --plugin instead. `.prettierrc.json` deliberately omits "plugins".
PRETTIER := prettier --plugin $$(npm root -g)/@prettier/plugin-xml/src/plugin.js

# XSpec is not packaged in Homebrew, so we vendor a pinned release into .tools/.
XSPEC_VERSION := 4.0.2
XSPEC_SHA256  := fcbbf2b79a2933ef021f6bcb1ac72e6225287327b19531e54e505d96f7c180cf
XSPEC_DIR     := $(TOOLS_DIR)/xspec-$(XSPEC_VERSION)
XSPEC         ?= $(XSPEC_DIR)/bin/xspec.sh
XSPEC_ZIP     := $(TOOLS_DIR)/xspec.zip
XSPEC_TESTS   := $(wildcard $(TEST_DIR)/*.xspec)

# Saxon-HE and xmlresolver jars used by xspec.sh. Pinned to the same releases
# as the Dockerfile so the test classpath matches the runtime image.
SAXON_VERSION       := 13.0
SAXON_SHA256        := 258fb4788b8e1bd986f9aed14269669412da88c7bb289b747878d4353f6168aa
SAXON_LOCAL         := $(TOOLS_DIR)/saxon-he-$(SAXON_VERSION).jar
SAXON_URL           := https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/$(SAXON_VERSION)/Saxon-HE-$(SAXON_VERSION).jar
XMLRESOLVER_VERSION := 6.0.23
XMLRESOLVER_SHA256  := 8bd99540e826dada93126fa05c3a0b54f5db00701d7be98193673099307e77e2
XMLRESOLVER_LOCAL   := $(TOOLS_DIR)/xmlresolver-$(XMLRESOLVER_VERSION).jar
XMLRESOLVER_URL     := https://repo1.maven.org/maven2/org/xmlresolver/xmlresolver/$(XMLRESOLVER_VERSION)/xmlresolver-$(XMLRESOLVER_VERSION).jar

# Homebrew ships saxon-he with a MANIFEST.MF Class-Path that pulls in its
# bundled xmlresolver automatically, so on macOS one jar is enough.
BREW_SAXON := $(firstword \
  $(wildcard /opt/homebrew/opt/saxon/libexec/saxon-he-*.jar) \
  $(wildcard /usr/local/opt/saxon/libexec/saxon-he-*.jar))

# Composed classpath for the vendored install. Saxon-HE 13 needs xmlresolver
# on the classpath at runtime; the plain Maven Central jar has no Class-Path
# manifest entry, so we have to pass both jars explicitly.
VENDORED_SAXON_CP := $(SAXON_LOCAL):$(XMLRESOLVER_LOCAL)

# SAXON_CP resolution order: caller override → Homebrew install → vendored
# .tools/ download. The vendored path is named unconditionally; the test
# target depends on install-saxon, so the files will exist by the time
# xspec.sh actually reads SAXON_CP.
SAXON_CP ?= $(or $(BREW_SAXON),$(VENDORED_SAXON_CP))
export SAXON_CP

# Run all lint checks: XML well-formedness + Prettier format check.
lint: lint-xml lint-format

# Well-formedness check for the stylesheet. Does not require network or schemas.
lint-xml:
	xmllint --noout $(XSL)

# Verify formatting without modifying files. Fails if any file would be changed.
lint-format:
	$(PRETTIER) --check "$(PRETTIER_GLOB)"

# Apply Prettier formatting in place.
format:
	$(PRETTIER) --write "$(PRETTIER_GLOB)"

# Download and unpack xspec into .tools/ if not already present. Re-runs are
# a no-op once the target script exists, so this is safe to call repeatedly.
install-xspec:
	@if [ ! -x "$(XSPEC)" ]; then \
		echo "==> Downloading xspec v$(XSPEC_VERSION) into $(TOOLS_DIR)/"; \
		mkdir -p "$(TOOLS_DIR)"; \
		$(CURL) -o "$(XSPEC_ZIP)" "https://github.com/xspec/xspec/archive/refs/tags/v$(XSPEC_VERSION).zip"; \
		echo "$(XSPEC_SHA256)  $(XSPEC_ZIP)" | shasum -a 256 -c -; \
		unzip -q -o "$(XSPEC_ZIP)" -d "$(TOOLS_DIR)/"; \
		chmod +x "$(XSPEC)"; \
		rm "$(XSPEC_ZIP)"; \
	fi

# Download Saxon-HE + xmlresolver into .tools/. Skip entirely when Homebrew
# already provides Saxon (its bundled manifest pulls in xmlresolver itself).
install-saxon:
	@if [ -n "$(BREW_SAXON)" ]; then \
		echo "==> Saxon available via Homebrew at $(BREW_SAXON), skipping download"; \
	else \
		$(call download_checked,$(SAXON_LOCAL),Saxon-HE $(SAXON_VERSION),$(SAXON_URL),$(SAXON_SHA256)); \
		$(call download_checked,$(XMLRESOLVER_LOCAL),xmlresolver $(XMLRESOLVER_VERSION),$(XMLRESOLVER_URL),$(XMLRESOLVER_SHA256)); \
	fi

# Run every test/*.xspec. install-saxon is a no-op if SAXON_CP already resolves
# to a real jar (e.g. via `brew install saxon`).
test: install-xspec install-saxon
	$(require_xspec_tests)
	$(require_saxon_cp)
	$(call run_xspec)

# Run every test/*.xspec and emit XSpec's XSLT coverage reports. Reports are
# written next to the normal XSpec reports as test/xspec/*-coverage.{xml,html}.
test-coverage: install-xspec install-saxon
	$(require_xspec_tests)
	$(require_saxon_cp)
	$(call run_xspec,-c)

# Short alias for local coverage checks.
coverage: test-coverage

# Drop the per-run xspec artefacts (compiled stylesheets, HTML reports,
# coverage XML/HTML reports).
test-clean:
	rm -rf $(TEST_DIR)/xspec

# Local mirror of the CI smoke-test job. Fetches the W3C XSD-of-XSDs (the
# canonical real-world payload), renders it through xsdstyle.xsl with Saxon,
# then validates the HTML/CSS with vnu.jar — same steps as .github/workflows/ci.yml.
SMOKE_SCHEMAS := $(TOOLS_DIR)/schemas
SMOKE_OUT     := out
VNU_JAR       := $(TOOLS_DIR)/vnu.jar
VNU_URL       := https://github.com/validator/validator/releases/download/latest/vnu.jar

# Cache the W3C XSD-of-XSDs + DTDs under .tools/schemas/ for the smoke test.
# No-op once XMLSchema.xsd is present.
install-sample-schemas:
	@if [ ! -f $(SMOKE_SCHEMAS)/XMLSchema.xsd ]; then \
		echo "==> Fetching W3C XMLSchema.xsd + DTDs into $(SMOKE_SCHEMAS)/"; \
		mkdir -p $(SMOKE_SCHEMAS); \
		$(CURL) -o $(SMOKE_SCHEMAS)/XMLSchema.xsd https://www.w3.org/2001/XMLSchema.xsd; \
		$(CURL) -o $(SMOKE_SCHEMAS)/XMLSchema.dtd https://www.w3.org/2001/XMLSchema.dtd; \
		$(CURL) -o $(SMOKE_SCHEMAS)/datatypes.dtd https://www.w3.org/2001/datatypes.dtd; \
		$(CURL) -o $(SMOKE_SCHEMAS)/xml.xsd       https://www.w3.org/2001/xml.xsd; \
	fi

# Download the Nu HTML Checker into .tools/. No-op once the jar is present.
install-vnu:
	@if [ ! -f $(VNU_JAR) ]; then \
		echo "==> Downloading vnu.jar into $(TOOLS_DIR)/"; \
		mkdir -p "$(TOOLS_DIR)"; \
		$(CURL) -o $(VNU_JAR) $(VNU_URL); \
	fi

# Render an arbitrary XSD to HTML. Usage: make render SCHEMA=path/to/schema.xsd
# Output goes to $(RENDER_OUT)/$(RENDER_HTML); both have sensible defaults.
RENDER_OUT  ?= out
RENDER_HTML ?= index.html

render: install-saxon
	@if [ -z "$(SCHEMA)" ]; then \
		echo "ERROR: SCHEMA is required. Usage: make render SCHEMA=path/to/schema.xsd"; \
		exit 1; \
	fi
	@if [ ! -f "$(SCHEMA)" ]; then \
		echo "ERROR: schema not found: $(SCHEMA)"; \
		exit 1; \
	fi
	$(require_saxon_cp)
	@mkdir -p $(RENDER_OUT)
	@echo "==> Rendering $(SCHEMA) -> $(RENDER_OUT)/$(RENDER_HTML)"
	java -cp "$$SAXON_CP" net.sf.saxon.Transform \
		-s:$(SCHEMA) \
		-xsl:$(XSL) \
		-o:$(RENDER_OUT)/$(RENDER_HTML)
	@rm -rf $(RENDER_OUT)/assets
	@cp -R $(ASSETS_DIR) $(RENDER_OUT)/assets

# smoke-test = render the W3C XSD-of-XSDs, then validate the output via vnu.jar.
smoke-test: SCHEMA      = $(SMOKE_SCHEMAS)/XMLSchema.xsd
smoke-test: RENDER_OUT  = $(SMOKE_OUT)
smoke-test: RENDER_HTML = index.html
smoke-test: install-vnu install-sample-schemas render
	@echo "==> Validating HTML5/CSS via vnu.jar"
	java -jar $(VNU_JAR) --also-check-css \
		$(SMOKE_OUT)/index.html $(SMOKE_OUT)/assets/xsdstyle.css
	@echo "==> smoke-test passed"

# Drop the smoke-test output. Leaves the cached schemas + vnu.jar in .tools/ alone.
smoke-test-clean:
	rm -rf $(SMOKE_OUT)

# Install prettier + the XML plugin globally. Run once per machine.
install-prettier:
	npm install -g prettier@$(PRETTIER_VERSION) @prettier/plugin-xml@$(PRETTIER_XML_VERSION)

# Deque's axe-core CLI for automated WCAG conformance checks. Drives a headless
# Chrome via selenium-webdriver. We deliberately do NOT install the chromedriver
# npm package — it pins to the latest Chrome release, which routinely drifts
# ahead of the Chrome shipped on GitHub runners (and Homebrew) and crashes with
# a "session not created" version mismatch. Instead, lint-a11y resolves the
# driver at runtime from $CHROMEWEBDRIVER (set on github-hosted runners) or
# $PATH (e.g. `brew install chromedriver` on macOS).
AXE_VERSION := 4.10.2

# Tags for WCAG 2.2 A + AA, plus axe's curated "best-practice" rules (things
# that aren't strictly required by WCAG but catch real accessibility issues:
# region landmarks, skip links, duplicate IDs in aria, etc.). axe groups rules
# by spec version and level, so we include every band that contributes to the
# 2.2 AA bar: 2.0 A/AA, the 2.1 additions, and the 2.2 additions on top.
AXE_TAGS := wcag2a,wcag2aa,wcag21a,wcag21aa,wcag22aa,best-practice

install-axe:
	npm install -g @axe-core/cli@$(AXE_VERSION)

# WCAG 2.2 A/AA audit of a rendered page. Defaults to the smoke-test artifact;
# override A11Y_TARGET to point at another HTML file (must be a path on disk —
# axe is invoked with a file:// URL so the page can load its sibling assets).
A11Y_TARGET ?= $(SMOKE_OUT)/index.html

lint-a11y:
	@if [ ! -f "$(A11Y_TARGET)" ]; then \
		echo "ERROR: $(A11Y_TARGET) not found. Run 'make smoke-test' first, or set A11Y_TARGET=path/to/page.html."; \
		exit 1; \
	fi
	@target_abs="$$(cd "$$(dirname "$(A11Y_TARGET)")" && pwd)/$$(basename "$(A11Y_TARGET)")"; \
		driver_arg=""; \
		if [ -n "$$CHROMEDRIVER" ] && [ -x "$$CHROMEDRIVER" ]; then \
			driver_arg="--chromedriver-path $$CHROMEDRIVER"; \
		elif [ -n "$$CHROMEWEBDRIVER" ] && [ -x "$$CHROMEWEBDRIVER/chromedriver" ]; then \
			driver_arg="--chromedriver-path $$CHROMEWEBDRIVER/chromedriver"; \
		fi; \
		echo "==> axe-core WCAG 2.2 A/AA audit of $$target_abs"; \
		axe "file://$$target_abs" --tags $(AXE_TAGS) --exit $$driver_arg
