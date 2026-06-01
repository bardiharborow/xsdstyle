# syntax=docker/dockerfile:1

FROM eclipse-temurin:21-jre-alpine

ADD --checksum=sha256:258fb4788b8e1bd986f9aed14269669412da88c7bb289b747878d4353f6168aa \
    https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/13.0/Saxon-HE-13.0.jar \
    /opt/xsdstyle/lib/saxon-he.jar

ADD --checksum=sha256:8bd99540e826dada93126fa05c3a0b54f5db00701d7be98193673099307e77e2 \
    https://repo1.maven.org/maven2/org/xmlresolver/xmlresolver/6.0.23/xmlresolver-6.0.23.jar \
    /opt/xsdstyle/lib/xmlresolver.jar

COPY xsdstyle.xsl /opt/xsdstyle/xsdstyle.xsl
COPY assets/ /opt/xsdstyle/assets/
COPY --chmod=+x entrypoint.sh /opt/xsdstyle/bin/xsdstyle

ENTRYPOINT ["/opt/xsdstyle/bin/xsdstyle"]
