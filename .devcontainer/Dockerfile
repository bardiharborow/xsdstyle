# Mirrors the CI toolchain (.github/workflows/ci.yml): Java 21 (Temurin) for
# Saxon / XSpec / vnu.jar. Node 24 is layered on via the devcontainer "node"
# feature in devcontainer.json. Debian bookworm is deliberate: its apt repo
# ships a chromium + chromium-driver pair built from the same release, so the
# a11y audit gets a version-matched driver (the "session not created" mismatch
# the Makefile's lint-a11y comment warns about).
FROM mcr.microsoft.com/devcontainers/java:1-21-bookworm

# OS packages the Makefile targets need but the base image lacks:
#   make            — the build runner for every target
#   curl, unzip     — install-saxon / install-xspec / install-vnu fetch + unpack
#   libxml2-utils   — provides xmllint for `make lint-xml`
#   chromium,
#   chromium-driver — `make lint-a11y` drives headless Chrome via @axe-core/cli
#   fonts-liberation — gives headless chromium real fonts so layout/CSS render
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        make \
        curl \
        unzip \
        libxml2-utils \
        chromium \
        chromium-driver \
        fonts-liberation \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# `make lint-a11y` resolves the driver from $CHROMEDRIVER first; point it at the
# Debian-packaged binary so the audit uses the version-matched chromium above.
ENV CHROMEDRIVER=/usr/bin/chromedriver
