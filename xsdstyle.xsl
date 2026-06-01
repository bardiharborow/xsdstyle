<?xml version="1.0" encoding="UTF-8" ?>
<!--
  xsdstyle.xsl (new/) — XSLT 3.0 documentation generator for W3C XSD 1.1.

  See docs/architecture.md for the design contract. This file is a single
  stylesheet organised into 15 regions. Each region starts with a banner
  comment containing "Region N. Name" so a grep for 'Region' jumps
  between sections.

  Usage:
    saxon -s:schema.xsd -xsl:new/xsdstyle.xsl -o:out/index.html
    cp -R new/assets out/assets

  Parameters (override with -param:name=value):
    title           Page title (default: derived from @id, @targetNamespace,
                    or "XSD Documentation").
    base-href       Prefix for asset URLs (default: ./assets/).
    include-source  Embed the per-component XSD source <details> block.
    doc-html        How to render embedded HTML inside <xs:documentation>:
                    "safe" (default, allowlist) or "permissive" (verbatim).
    ui-lang         BCP-47 tag for the UI chrome. Drives <html lang="…">
                    and the message-catalog lookup. Default "en".
    xml-lang        BCP-47 tag for XSD-sourced prose. Emitted as a fallback
                    lang="…" on annotation/documentation wrappers when the
                    XSD block has no per-block xml:lang. Default "en".
    dir             Writing direction emitted on <html dir="…">: "auto"
                    (default, infers rtl from $ui-lang for ar/he/fa/ur/…,
                    otherwise ltr), "ltr", or "rtl".
    noindex         Emit <meta name="robots" content="noindex">. Default false.
-->
<!-- ===== Region 1. Preamble ===== -->
<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:vc="http://www.w3.org/2007/XMLSchema-versioning"
  xmlns:x="urn:xsdoc:functions"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:err="http://www.w3.org/2005/xqt-errors"
  xpath-default-namespace="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs vc x map array err"
  expand-text="no">
  <xsl:output method="html" html-version="5" indent="yes" omit-xml-declaration="yes" />
  <xsl:strip-space elements="*" />
  <xsl:preserve-space elements="documentation appinfo" />

  <!--
    Declare the global context item: a document node whose root is
    xs:schema. Saxon's CLI initiation supplies this via -s:schema.xsd;
    callers that invoke the stylesheet without an initial context
    (e.g. xsl:initial-template) must pass the schema document explicitly.
  -->
  <xsl:global-context-item as="document-node(element(schema))" use="optional" />

  <!-- ===== Region 2. Parameters ===== -->

  <xsl:param name="title" as="xs:string?" />
  <xsl:param name="base-href" as="xs:string" select="'./assets/'" />
  <xsl:param name="include-source" as="xs:boolean" select="true()" />
  <xsl:param name="doc-html" as="xs:string" select="'safe'" />
  <xsl:param name="ui-lang" as="xs:string" select="'en'" />
  <xsl:param name="xml-lang" as="xs:string" select="'en'" />
  <xsl:param name="dir" as="xs:string" select="'auto'" />
  <xsl:param name="noindex" as="xs:boolean" select="false()" />

  <!-- ===== Region 3. Global constants ===== -->

  <xsl:variable name="xs-ns" as="xs:string" select="'http://www.w3.org/2001/XMLSchema'" />
  <xsl:variable name="vc-ns" as="xs:string" select="'http://www.w3.org/2007/XMLSchema-versioning'" />
  <xsl:variable name="xsdstyle-version" as="xs:string" select="'0.1.0-dev'" />

  <!--
    Active locale for chrome translation, resolved from $ui-lang. Fallback
    chain: exact BCP-47 tag → primary subtag → 'en'. The HTML lang attribute
    keeps emitting $ui-lang verbatim; only catalog lookup is normalised.
    $xml-lang is a separate axis — it controls the lang="…" fallback on
    XSD-prose wrappers, not the chrome.
  -->
  <xsl:variable
    name="active-locale"
    as="xs:string"
    select="
    let $req := lower-case(normalize-space($ui-lang)),
        $primary := if (contains($req, '-')) then substring-before($req, '-') else $req
    return
      if ($req ne '' and map:contains($i18n-messages, $req)) then $req
      else if ($primary ne '' and map:contains($i18n-messages, $primary)) then $primary
      else 'en'
  " />

  <!--
    BCP-47 primary subtags whose default script is right-to-left. Used to
    resolve $dir='auto' from $ui-lang; matched on the primary subtag only,
    so 'ar', 'ar-EG', and 'ar-Latn-EG' all hit (the last is rare in
    practice). To force a direction regardless of language, pass
    -dir=ltr|rtl explicitly.
  -->
  <xsl:variable
    name="rtl-primary-subtags"
    as="xs:string*"
    select="
    ('ar', 'he', 'fa', 'ur', 'ps', 'yi', 'dv', 'ug', 'ckb', 'sd', 'arc')
  " />

  <!--
    Resolved writing direction. 'auto' (the default) infers from $ui-lang's
    primary subtag against $rtl-primary-subtags; 'ltr' and 'rtl' pass through
    verbatim. Any other value is treated as 'auto'. Chrome direction (not
    XSD-content direction) drives the layout because $ui-lang is what the
    surrounding nav, sidebar, and labels are written in.
  -->
  <xsl:variable
    name="active-dir"
    as="xs:string"
    select="
    let $d := lower-case(normalize-space($dir))
    return
      if ($d = ('ltr', 'rtl')) then $d
      else
        let $req := lower-case(normalize-space($ui-lang)),
            $primary := if (contains($req, '-')) then substring-before($req, '-') else $req
        return if ($primary = $rtl-primary-subtags) then 'rtl' else 'ltr'
  " />

  <!--
    Maximum length for the documentation snippet stored in the search index.
    Tunable; the JS filter truncates display further. 240 chars roughly fits
    two lines of body text in the rendered UI.
  -->
  <xsl:variable name="doc-snippet-max" as="xs:integer" select="240" />

  <!--
    Static kind catalog: per-kind structural metadata (anchor abbreviation,
    BEM modifier slug). The catalog is independent of any input schema so
    helper functions can reference it before the schema collection has
    been walked. Sequence order is also rendering order in the sidebar
    and main content. Plural labels are looked up at use-sites via
    x:t(concat('kind.', $kind?k, '.plural')) so they translate.
  -->
  <xsl:variable
    name="kind-meta"
    as="array(map(xs:string, xs:string))"
    select="[
    map { 'k': 'element',        'abbr': 'el', 'modifier': 'element' },
    map { 'k': 'complexType',    'abbr': 'ct', 'modifier': 'complex-type' },
    map { 'k': 'simpleType',     'abbr': 'st', 'modifier': 'simple-type' },
    map { 'k': 'attribute',      'abbr': 'at', 'modifier': 'attribute' },
    map { 'k': 'attributeGroup', 'abbr': 'ag', 'modifier': 'attribute-group' },
    map { 'k': 'group',          'abbr': 'gr', 'modifier': 'group' },
    map { 'k': 'notation',       'abbr': 'no', 'modifier': 'notation' }
  ]" />

  <!--
    Top-level components of a given kind across the schema collection,
    including their redefined/overridden wrappers where applicable.
    Returns the source XSD elements, in document order per schema.
  -->
  <xsl:function name="x:items-for-kind" as="element()*">
    <xsl:param name="kind" as="xs:string" />
    <xsl:sequence
      select="
      if ($kind eq 'element') then
        $schemas/(element | override/element)
      else if ($kind eq 'complexType') then
        $schemas/(complexType | redefine/complexType | override/complexType)
      else if ($kind eq 'simpleType') then
        $schemas/(simpleType | redefine/simpleType | override/simpleType)
      else if ($kind eq 'attribute') then
        $schemas/(attribute | override/attribute)
      else if ($kind eq 'attributeGroup') then
        $schemas/(attributeGroup | redefine/attributeGroup | override/attributeGroup)
      else if ($kind eq 'group') then
        $schemas/(group | redefine/group | override/group)
      else if ($kind eq 'notation') then
        $schemas/(notation | override/notation)
      else ()
    " />
  </xsl:function>

  <!-- ===== Region 4. Keys ===== -->

  <xsl:key
    name="substitutionMembers"
    match="/schema/element[@substitutionGroup] | /schema/override/element[@substitutionGroup]"
    use="x:clark(x:resolve-qname(string(@substitutionGroup), .))" />

  <xsl:key
    name="typeUsersByType"
    match="element[@type] | attribute[@type]"
    use="x:clark(x:resolve-qname(string(@type), .))" />

  <xsl:key
    name="typeUsersByBase"
    match="extension[@base] | restriction[@base]"
    use="x:clark(x:resolve-qname(string(@base), .))" />

  <xsl:key
    name="identityConstraintByQName"
    match="key | unique"
    use="x:clark(QName(x:tns(ancestor::schema[1]), string(@name)))" />

  <!--
    inheritableAttrsByType — top-level complexTypes that declare at least one
    @inheritable='true' attribute (directly or via attributeGroup ref expanded
    at render time). Indexed by Clark-form QName of the type. Used by the CTA
    renderer to surface inherited test-context attributes.
  -->
  <xsl:key
    name="inheritableAttrsByType"
    match="/schema/complexType[.//attribute[x:xsd-true(@inheritable)]]
         | /schema/redefine/complexType[.//attribute[x:xsd-true(@inheritable)]]
         | /schema/override/complexType[.//attribute[x:xsd-true(@inheritable)]]"
    use="x:clark(QName(x:tns(ancestor::schema[1]), string(@name)))" />

  <!--
    openContentByType — top-level complexTypes that declare their own
    xs:openContent. Indexed by Clark-form QName. The effective-open-content
    resolver consults this key plus the schema-level defaultOpenContent.
  -->
  <xsl:key
    name="openContentByType"
    match="/schema/complexType[complexContent/openContent or openContent]
         | /schema/redefine/complexType[complexContent/openContent or openContent]
         | /schema/override/complexType[complexContent/openContent or openContent]"
    use="x:clark(QName(x:tns(ancestor::schema[1]), string(@name)))" />

  <!--
    vcDecorated — any element in the XSD namespace carrying one or more
    attributes in the vc namespace (Appendix F conditional inclusion). Keyed
    by the local-name of the carrying element, so callers can quickly find
    e.g. all vc-decorated <complexType> elements. Matching only XSD-namespace
    elements avoids accidental hits on host application elements.
  -->
  <xsl:key
    name="vcDecorated"
    match="*[namespace-uri() eq 'http://www.w3.org/2001/XMLSchema']
           [@*[namespace-uri() eq 'http://www.w3.org/2007/XMLSchema-versioning']]"
    use="local-name()" />

  <!-- ===== Region 5. xsl:mode declarations ===== -->

  <xsl:mode name="section" on-no-match="fail" />
  <xsl:mode name="model" on-no-match="shallow-skip" />
  <xsl:mode name="attr-row" on-no-match="fail" />
  <xsl:mode name="facets" on-no-match="shallow-skip" />
  <xsl:mode name="inline-complex" on-no-match="shallow-skip" />
  <xsl:mode name="derivation" on-no-match="shallow-skip" />
  <xsl:mode name="open-content" on-no-match="shallow-skip" />
  <xsl:mode name="doc" on-no-match="shallow-skip" />
  <xsl:mode name="doc-safe" on-no-match="shallow-skip" />
  <xsl:mode name="doc-permissive" on-no-match="shallow-skip" />
  <xsl:mode name="xsd-source" on-no-match="shallow-skip" />

  <!-- ===== Region 6. Pure helper functions ===== -->

  <!--
    Clark notation: {namespace-uri}local-name. Canonical key for inter-
    component lookup. Empty for empty sequence so callers can pipe
    optional QNames without wrapping in if/then.
  -->
  <xsl:function name="x:clark" as="xs:string">
    <xsl:param name="q" as="xs:QName?" />
    <xsl:sequence
      select="
      if (empty($q)) then ''
      else concat('{', string(namespace-uri-from-QName($q)), '}', local-name-from-QName($q))
    " />
  </xsl:function>

  <!--
    XSD's xs:boolean lexical space is 'true'|'false'|'1'|'0'. We accept the
    affirmative pair and return false for everything else (including the
    empty sequence). Typed as xs:string? so callers can pass an attribute()
    directly — XPath atomises it on the call boundary.
  -->
  <xsl:function name="x:xsd-true" as="xs:boolean">
    <xsl:param name="v" as="xs:string?" />
    <xsl:sequence select="exists($v) and $v = ('true', '1')" />
  </xsl:function>

  <!--
    Occurrence marker. ? / * / + for the common cases; [min..max] otherwise.
    XSD 1.1 allows xs:all/@maxOccurs>1, which lands in the [min..max] branch
    naturally. Empty string for the 1..1 default so callers can suppress
    rendering with `if (marker ne '')`.
  -->
  <xsl:function name="x:occurs" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:variable name="min" as="xs:integer" select="if ($node/@minOccurs) then xs:integer($node/@minOccurs) else 1" />
    <xsl:variable name="max" as="xs:string" select="if ($node/@maxOccurs) then string($node/@maxOccurs) else '1'" />
    <xsl:sequence
      select="
      if ($min eq 1 and $max eq '1') then ''
      else if ($min eq 0 and $max eq '1') then '?'
      else if ($min eq 0 and $max eq 'unbounded') then '*'
      else if ($min eq 1 and $max eq 'unbounded') then '+'
      else concat('[', $min, '..', $max, ']')
    " />
  </xsl:function>

  <xsl:function name="x:occurs-title" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:variable name="min" as="xs:integer" select="if ($node/@minOccurs) then xs:integer($node/@minOccurs) else 1" />
    <xsl:variable name="max" as="xs:string" select="if ($node/@maxOccurs) then string($node/@maxOccurs) else '1'" />
    <xsl:variable
      name="params"
      as="map(xs:string, xs:anyAtomicType)"
      select="map { 'min': string($min), 'max': $max }" />
    <xsl:sequence
      select="
      if ($min eq 1 and $max eq '1') then ''
      else if ($min eq 0 and $max eq '1')         then x:t('occurs.optional')
      else if ($min eq 0 and $max eq 'unbounded') then x:t('occurs.zeroOrMore')
      else if ($min eq 1 and $max eq 'unbounded') then x:t('occurs.oneOrMore')
      else if ($max eq 'unbounded')               then x:t('occurs.atLeast', $params)
      else if ($min eq xs:integer($max))          then x:t('occurs.exactly', $params)
      else                                             x:t('occurs.between', $params)
    " />
  </xsl:function>

  <!--
    Message lookup. x:t($key) returns the active-locale text for $key, with
    fallback to 'en' and finally to the literal sentinel '[[key]]' so missing
    keys are visible during development but never fail rendering. x:t($key,
    $params) additionally substitutes {name} placeholders from the params map.
  -->
  <xsl:function name="x:t" as="xs:string">
    <xsl:param name="key" as="xs:string" />
    <xsl:sequence select="x:t($key, map{})" />
  </xsl:function>

  <xsl:function name="x:t" as="xs:string">
    <xsl:param name="key" as="xs:string" />
    <xsl:param name="params" as="map(xs:string, xs:anyAtomicType)" />
    <xsl:variable name="catalog" as="map(xs:string, xs:string)" select="$i18n-messages($active-locale)" />
    <xsl:variable
      name="raw"
      as="xs:string"
      select="
      if (map:contains($catalog, $key)) then $catalog($key)
      else
        let $en := $i18n-messages('en')
        return if (map:contains($en, $key)) then $en($key)
               else concat('[[', $key, ']]')
    " />
    <xsl:sequence select="x:format-message($raw, $params)" />
  </xsl:function>

  <!--
    Substitute every {name} placeholder in $template with the matching entry
    in $params. Placeholder names are ASCII identifiers (chosen by us, not
    user input), so the regex meta-chars only need brace escaping.
  -->
  <xsl:function name="x:format-message" as="xs:string">
    <xsl:param name="template" as="xs:string" />
    <xsl:param name="params" as="map(xs:string, xs:anyAtomicType)" />
    <xsl:iterate select="map:keys($params)">
      <xsl:param name="acc" as="xs:string" select="$template" />
      <xsl:on-completion select="$acc" />
      <xsl:next-iteration>
        <xsl:with-param name="acc" select="replace($acc, concat('\{', ., '\}'), string($params(.)))" />
      </xsl:next-iteration>
    </xsl:iterate>
  </xsl:function>

  <!--
    Emit a translated sentence that includes inline <code> spans. The catalog
    string holds {name} placeholders; this template walks each one and emits
    <code>{value}</code>. Placeholders may appear in any order so translators
    can rephrase freely. Used for paragraphs where embedding XSD literals
    in markup matters (e.g. "declared {inheritableCode} on ancestor types").
  -->
  <xsl:template name="emit-i18n-with-codes">
    <xsl:param name="key" as="xs:string" required="yes" />
    <xsl:param name="codes" as="map(xs:string, xs:string)" required="yes" />
    <xsl:analyze-string select="x:t($key)" regex="\{{(\w+)\}}">
      <xsl:matching-substring>
        <code>
          <xsl:value-of select="$codes(regex-group(1))" />
        </code>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="." />
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>

  <!-- Returns true when $q is in the XSD built-in namespace. -->
  <xsl:function name="x:is-xs" as="xs:boolean">
    <xsl:param name="q" as="xs:QName?" />
    <xsl:sequence select="exists($q) and namespace-uri-from-QName($q) eq $xs-ns" />
  </xsl:function>

  <!--
    Anchor abbreviation for a kind name. Walks the $kind-meta array; defaults
    to the kind name itself if no entry matches (so the function stays a
    total function on string input).
  -->
  <xsl:function name="x:abbr" as="xs:string">
    <xsl:param name="kind" as="xs:string" />
    <xsl:variable
      name="hits"
      as="map(*)*"
      select="
      array:flatten($kind-meta)[. instance of map(*)][?k = $kind]
    " />
    <xsl:sequence select="if (exists($hits)) then string($hits[1]?abbr) else $kind" />
  </xsl:function>

  <!--
    Synthetic namespace ID for an effective namespace URI. The primary
    namespace yields '' so anchors collapse to {abbr}-{name}; secondary
    namespaces yield 'ns1', 'ns2', … in discovery order, or the in-scope
    prefix from the primary schema if one is bound.
  -->
  <xsl:function name="x:ns-id" as="xs:string">
    <xsl:param name="ns" as="xs:string" />
    <xsl:choose>
      <xsl:when test="$ns eq $primary-ns">
        <xsl:sequence select="''" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable
          name="bound"
          as="xs:string?"
          select="
          (for $p in in-scope-prefixes($primary)
           return if (namespace-uri-for-prefix($p, $primary) eq $ns
                      and $p ne '' and $p ne 'xml') then $p else ()
          )[1]
        " />
        <xsl:sequence
          select="
          if (exists($bound) and string($bound) ne '')
            then string($bound)
          else concat('ns', string(index-of($secondary-namespaces, $ns)[1]))
        " />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!--
    Anchor assembly. Format is {abbr}-{nsid}-{name}, collapsing the
    nsid segment when it is empty (primary namespace).
  -->
  <xsl:function name="x:anchor" as="xs:string">
    <xsl:param name="kind" as="xs:string" />
    <xsl:param name="nsid" as="xs:string" />
    <xsl:param name="name" as="xs:string" />
    <xsl:variable name="abbr" select="x:abbr($kind)" />
    <xsl:sequence
      select="
      if ($nsid eq '') then concat($abbr, '-', encode-for-uri($name))
      else concat($abbr, '-', $nsid, '-', encode-for-uri($name))
    " />
  </xsl:function>

  <!--
    URL allowlist for hrefs inside <xs:documentation>. Strips ASCII
    whitespace + C0 controls the same way a browser does before scheme
    resolution, then rejects everything that isn't an http(s)/mailto/tel/
    ftp(s) URL or a relative path/fragment. Returns () for a rejected URL.
  -->
  <xsl:function name="x:safe-href" as="xs:string?">
    <xsl:param name="raw" as="xs:string" />
    <xsl:variable name="stripped" as="xs:string" select="replace($raw, '[\s\p{Cc}]', '')" />
    <xsl:variable name="lower" as="xs:string" select="lower-case($stripped)" />
    <xsl:variable name="has-scheme" as="xs:boolean" select="matches($lower, '^[a-z][a-z0-9+.\-]*:')" />
    <xsl:choose>
      <xsl:when test="$stripped eq ''">
        <xsl:sequence select="()" />
      </xsl:when>
      <xsl:when test="not($has-scheme)">
        <xsl:sequence select="$stripped" />
      </xsl:when>
      <xsl:when test="matches($lower, '^(https?|mailto|tel|ftps?):')">
        <xsl:sequence select="$stripped" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="()" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!--
    Render a whitespace-separated @notQName attribute value, mixing literal
    QNames with the XSD 1.1 wildcard tokens ##defined and ##definedSibling.
    $kind selects the component kind for QName resolution: 'element' for
    xs:any/@notQName, 'attribute' for xs:anyAttribute/@notQName.
  -->
  <xsl:function name="x:format-notQName" as="node()*">
    <xsl:param name="raw" as="xs:string" />
    <xsl:param name="kind" as="xs:string" />
    <xsl:param name="context" as="element()" />
    <xsl:for-each select="tokenize(normalize-space($raw), '\s+')[. ne '']">
      <xsl:if test="position() gt 1">
        <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:choose>
        <xsl:when test=". eq '##defined'">
          <code class="wildcard-token">##defined</code>
        </xsl:when>
        <xsl:when test=". eq '##definedSibling'">
          <code class="wildcard-token">##definedSibling</code>
        </xsl:when>
        <xsl:otherwise>
          <xsl:copy-of select="x:component-link(x:resolve-qname(., $context), $kind, $context)" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>

  <!--
    All attributes on $el whose namespace is the vc:* (XSD 1.1 conditional
    inclusion) namespace. Returns an empty sequence when none are present.
  -->
  <xsl:function name="x:vc-attrs" as="attribute()*">
    <xsl:param name="el" as="element()" />
    <xsl:sequence select="$el/@*[namespace-uri() eq $vc-ns]" />
  </xsl:function>

  <!--
    Detection helpers for wrapped components. is-redefined: inside an
    xs:redefine. is-overridden: inside an xs:override.
  -->
  <xsl:function name="x:is-redefined" as="xs:boolean">
    <xsl:param name="component" as="element()" />
    <xsl:sequence select="exists($component/parent::redefine)" />
  </xsl:function>

  <xsl:function name="x:is-overridden" as="xs:boolean">
    <xsl:param name="component" as="element()" />
    <xsl:sequence select="exists($component/parent::override)" />
  </xsl:function>

  <!-- ===== Region 7. Schema-aware helper functions ===== -->

  <!--
    Effective targetNamespace of a schema, accounting for the chameleon
    rule: a schema reached via xs:include or xs:redefine without its own
    @targetNamespace inherits the including schema's namespace. The fallback
    for schemas not in the collection is the literal @targetNamespace.
  -->
  <xsl:function name="x:tns" as="xs:string">
    <xsl:param name="schema" as="element(schema)" />
    <xsl:variable name="uri" as="xs:string" select="string(base-uri($schema))" />
    <xsl:sequence
      select="
      if (map:contains($schema-tns, $uri)) then $schema-tns($uri)
      else string($schema/@targetNamespace)
    " />
  </xsl:function>

  <xsl:function name="x:relative-source" as="xs:string">
    <xsl:param name="schema" as="element(schema)" />
    <xsl:variable name="uri" as="xs:string" select="string(base-uri($schema))" />
    <xsl:variable name="base" as="xs:string" select="replace($primary-uri, '[^/]+$', '')" />
    <xsl:sequence
      select="
      if ($base ne '' and starts-with($uri, $base)) then substring-after($uri, $base)
      else $uri
    " />
  </xsl:function>

  <xsl:function name="x:component-qname" as="xs:QName">
    <xsl:param name="component" as="element()" />
    <xsl:sequence select="QName(x:tns($component/ancestor::schema[1]), string($component/@name))" />
  </xsl:function>

  <xsl:function name="x:anchor-for" as="xs:string">
    <xsl:param name="component" as="element()" />
    <xsl:variable name="ns" as="xs:string" select="x:tns($component/ancestor::schema[1])" />
    <xsl:variable
      name="base"
      select="
      x:anchor(local-name($component), x:ns-id($ns), string($component/@name))
    " />
    <xsl:sequence
      select="
      if (x:is-redefined($component)) then concat($base, '-redefined')
      else if (x:is-overridden($component)) then concat($base, '-overridden')
      else $base
    " />
  </xsl:function>

  <!--
    Anchor id for an identity-constraint row. The IC name lives in a
    per-targetNamespace symbol space but real-world schemas reuse names
    across scopes, so a global "kc-{ns}-{name}" anchor can collide. We
    scope by the chain of @name values from the nearest top-level
    ancestor down to the owning element, then suffix the IC name.
  -->
  <xsl:function name="x:anchor-for-ic" as="xs:string">
    <xsl:param name="ic" as="element()" />
    <xsl:variable name="ns" as="xs:string" select="x:tns($ic/ancestor::schema[1])" />
    <xsl:variable name="owner" as="element()" select="$ic/parent::*" />
    <xsl:variable
      name="path"
      as="xs:string*"
      select="$owner/ancestor-or-self::*[@name][ancestor-or-self::schema]/@name/string()" />
    <xsl:variable name="nsid" select="x:ns-id($ns)" />
    <xsl:variable name="prefix" select="if ($nsid eq '') then 'kc' else concat('kc-', $nsid)" />
    <xsl:sequence
      select="
      concat($prefix, '-',
             string-join(for $p in $path return encode-for-uri($p), '--'),
             '-', encode-for-uri(string($ic/@name)))
    " />
  </xsl:function>

  <xsl:function name="x:xs-builtin-href" as="xs:string">
    <xsl:param name="local" as="xs:string" />
    <xsl:sequence
      select="
      if ($local eq 'anyType')
        then 'https://www.w3.org/TR/xmlschema11-1/#anyType'
      else concat('https://www.w3.org/TR/xmlschema11-2/#', $local)
    " />
  </xsl:function>

  <!--
    W3C Part 2 §4.3 anchor for a constraining facet element by local-name.
    Returns '' for foreign/unknown names so callers can suppress the link.
    The element <xs:assertion> appears under the §4.3.13 "Assertions"
    heading whose anchor is the plural rf-assertions.
  -->
  <xsl:function name="x:facet-href" as="xs:string">
    <xsl:param name="local" as="xs:string" />
    <xsl:sequence
      select="
      if ($local = ('length','minLength','maxLength','pattern','enumeration',
                    'whiteSpace','maxInclusive','maxExclusive','minExclusive',
                    'minInclusive','totalDigits','fractionDigits',
                    'explicitTimezone'))
        then concat('https://www.w3.org/TR/xmlschema11-2/#rf-', $local)
      else if ($local eq 'assertion')
        then 'https://www.w3.org/TR/xmlschema11-2/#rf-assertions'
      else ''
    " />
  </xsl:function>

  <!--
    Snippet of the component's xs:documentation prose, normalised and
    truncated to $doc-snippet-max chars on a word boundary. Used by the
    search index emitted in Region 11.
  -->
  <xsl:function name="x:doc-snippet" as="xs:string">
    <xsl:param name="component" as="element()" />
    <xsl:variable name="raw" as="xs:string" select="string-join($component/annotation/documentation//text(), ' ')" />
    <xsl:variable name="norm" as="xs:string" select="normalize-space($raw)" />
    <xsl:sequence
      select="
      if (string-length($norm) le $doc-snippet-max) then $norm
      else
        let $cut := substring($norm, 1, $doc-snippet-max),
            $sp  := if (contains($cut, ' '))
                    then string-length($cut)
                         - string-length(tokenize($cut, ' ')[last()])
                    else $doc-snippet-max
        return concat(substring($cut, 1, $sp - 1), '…')
    " />
  </xsl:function>

  <!--
    Resolve a QName-valued attribute string against a context element,
    with one departure from raw resolve-QName():

      Unprefixed names look up against the owning schema's targetNamespace
      first. Only if no same-named global component exists there do we
      fall back to the in-scope default namespace.

    This matters when authors set xmlns="…XMLSchema" on xs:schema and
    write type="Book". Raw resolve-QName() would bind Book into the XSD
    namespace; the author meant their own targetNamespace.
  -->
  <xsl:function name="x:resolve-qname" as="xs:QName?">
    <xsl:param name="raw" as="xs:string?" />
    <xsl:param name="context" as="element()" />
    <xsl:choose>
      <xsl:when test="empty($raw) or $raw eq ''">
        <xsl:sequence select="()" />
      </xsl:when>
      <xsl:when test="contains($raw, ':')">
        <xsl:sequence select="resolve-QName($raw, $context)" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="owner" as="element(schema)?" select="$context/ancestor-or-self::schema[1]" />
        <xsl:variable name="owner-ns" as="xs:string" select="if (exists($owner)) then x:tns($owner) else ''" />
        <xsl:choose>
          <xsl:when
            test="
            $owner-ns ne ''
              and exists($schemas[x:tns(.) eq $owner-ns]
                          /(element | complexType | simpleType
                            | attribute | attributeGroup
                            | group | notation
                            | redefine/(complexType | simpleType
                                       | attributeGroup | group)
                            | override/(element | complexType | simpleType
                                       | attribute | attributeGroup
                                       | group | notation))
                          [string(@name) eq $raw])
          ">
            <xsl:sequence select="QName($owner-ns, $raw)" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="resolve-QName($raw, $context)" />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="x:resolve" as="xs:QName?">
    <xsl:param name="qname-attr" as="attribute()?" />
    <xsl:sequence
      select="
      if (empty($qname-attr)) then ()
      else x:resolve-qname(string($qname-attr), $qname-attr/parent::*)
    " />
  </xsl:function>

  <!--
    Find the nearest component among the loaded schemas matching ($ns, $local, $kind).
    Direct top-level children are preferred over redefined/overridden ones; the
    special case is when $context sits inside a redefine/override wrapper whose
    wrapped component shares the requested QName — there the base reference must
    point to the original (otherwise the redefined component self-references).

    $kind is one of the XSD component kinds OR the literal 'type', which is an
    alias matching either complexType or simpleType (used by @type / @base).
  -->
  <xsl:function name="x:find-component" as="element()?">
    <xsl:param name="ns" as="xs:string" />
    <xsl:param name="local" as="xs:string" />
    <xsl:param name="kind" as="xs:string" />
    <xsl:param name="context" as="node()?" />
    <xsl:variable name="in-ns" as="element(schema)*" select="$schemas[x:tns(.) eq $ns]" />
    <xsl:variable
      name="skip-wrap"
      as="xs:boolean"
      select="
      exists(($context/ancestor::redefine/*[@name eq $local
              and x:tns(ancestor::schema[1]) eq $ns])[1])
      or
      exists(($context/ancestor::override/*[@name eq $local
              and x:tns(ancestor::schema[1]) eq $ns])[1])
    " />
    <xsl:variable
      name="direct"
      as="element()?"
      select="
      if ($kind eq 'type') then
        ($in-ns/complexType[@name eq $local],
         $in-ns/simpleType[@name eq $local])[1]
      else
        $in-ns/*[local-name() eq $kind and @name eq $local][1]
    " />
    <xsl:variable
      name="redef"
      as="element()?"
      select="
      if ($skip-wrap) then ()
      else if ($kind eq 'type') then
        ($in-ns/redefine/complexType[@name eq $local],
         $in-ns/redefine/simpleType[@name eq $local])[1]
      else
        $in-ns/redefine/*[local-name() eq $kind and @name eq $local][1]
    " />
    <xsl:variable
      name="over"
      as="element()?"
      select="
      if ($skip-wrap) then ()
      else if ($kind eq 'type') then
        ($in-ns/override/complexType[@name eq $local],
         $in-ns/override/simpleType[@name eq $local])[1]
      else
        $in-ns/override/*[local-name() eq $kind and @name eq $local][1]
    " />
    <xsl:sequence select="($direct, $redef, $over)[1]" />
  </xsl:function>

  <xsl:function name="x:owner-component" as="element()?">
    <xsl:param name="node" as="node()" />
    <xsl:sequence
      select="
      ($node/ancestor-or-self::*[(parent::schema or parent::redefine or parent::override)
                                 and not(self::redefine) and not(self::override)])[1]
    " />
  </xsl:function>

  <xsl:function name="x:owner-type" as="element()?">
    <xsl:param name="node" as="node()" />
    <xsl:sequence
      select="
      $node/ancestor::*[(self::complexType or self::simpleType)
                        and (parent::schema or parent::redefine or parent::override)][1]
    " />
  </xsl:function>

  <!--
    Component link. Three cases:
      1. Built-in XSD type → external link to W3C spec.
      2. User-defined and resolvable → internal anchor link.
      3. User-defined and unresolvable → bare <code> with title= for the namespace.
  -->
  <xsl:function name="x:component-link">
    <xsl:param name="qname" as="xs:QName?" />
    <xsl:param name="kind" as="xs:string" />
    <xsl:param name="context" as="node()" />
    <xsl:choose>
      <xsl:when test="empty($qname)">
        <span class="muted">(none)</span>
      </xsl:when>
      <xsl:when test="x:is-xs($qname)">
        <xsl:variable name="local" select="local-name-from-QName($qname)" />
        <a class="ref ref--builtin" href="{x:xs-builtin-href($local)}" rel="noopener noreferrer" target="_blank">
          <code>xs:<xsl:value-of select="$local" /></code>
        </a>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="local" select="local-name-from-QName($qname)" />
        <xsl:variable name="ns" select="string(namespace-uri-from-QName($qname))" />
        <xsl:variable name="prefix" select="string(prefix-from-QName($qname))" />
        <xsl:variable name="match" as="element()?" select="x:find-component($ns, $local, $kind, $context)" />
        <xsl:variable name="display" select="if ($prefix ne '') then concat($prefix, ':', $local) else $local" />
        <xsl:choose>
          <xsl:when test="exists($match)">
            <a class="ref" href="#{x:anchor-for($match)}">
              <code>
                <bdi>
                  <xsl:value-of select="$display" />
                </bdi>
              </code>
            </a>
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable
              name="title"
              as="xs:string"
              select="
              if ($ns eq '') then x:t('helper.defNotFound')
              else x:t('helper.defNotFoundInNs', map { 'ns': $ns })
            " />
            <code class="ref ref--external" title="{$title}">
              <bdi>
                <xsl:value-of select="$display" />
              </bdi>
            </code>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!--
    Effective xs:openContent for a complexType, per XSD 1.1 §3.4.

    Resolution order (first hit wins):
      1. The type's own openContent (under complexContent or directly).
      2. If the type has no own openContent and the schema has a
         defaultOpenContent, the defaultOpenContent applies — but only if
         the type has complex content (per §3.4.1.4) and only if
         defaultOpenContent/@appliesToEmpty='true' or the type has at least
         one explicit particle.

    Returns the effective openContent element (or () when 'none' / absent).
    A wrapper attribute @x:effective-source records whether the result is
    'own' or 'default', so the renderer can show an inheritance footnote.
  -->
  <xsl:function name="x:effective-open-content" as="element()?">
    <xsl:param name="type" as="element()" />
    <xsl:variable
      name="own"
      as="element()?"
      select="
      ($type/openContent, $type/complexContent/openContent)[1]
    " />
    <xsl:choose>
      <xsl:when test="exists($own)">
        <xsl:sequence select="$own" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="schema" as="element(schema)" select="$type/ancestor::schema[1]" />
        <xsl:variable name="default" as="element()?" select="$schema/defaultOpenContent[1]" />
        <xsl:choose>
          <xsl:when test="empty($default)">
            <xsl:sequence select="()" />
          </xsl:when>
          <xsl:when
            test="not($type/complexContent) and not($type/simpleContent)
                          and not($type/sequence | $type/choice | $type/all
                                 | $type/group | $type/openContent)">
            <!--
              The type is empty. defaultOpenContent applies only when
              @appliesToEmpty='true'.
            -->
            <xsl:sequence
              select="
              if (x:xsd-true($default/@appliesToEmpty)) then $default else ()
            " />
          </xsl:when>
          <xsl:when test="$type/simpleContent">
            <!-- simpleContent types are not eligible for open content. -->
            <xsl:sequence select="()" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="$default" />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!--
    Inheritable attributes available to a complexType's CTA test context.
    Walks the base-type chain from $type upwards via @base, collecting
    every <xs:attribute @inheritable='true'> declaration along the way.
    Attributes declared on the type itself are NOT inheritable to itself
    (per spec §3.4.4.3) but ARE inheritable to derived types — so the
    function returns the union of all ancestor inheritable attrs only.

    A cycle guard caps the walk at 32 levels (well above any sane schema).
  -->
  <xsl:function name="x:inheritable-attrs" as="element()*">
    <xsl:param name="type" as="element()" />
    <xsl:sequence select="x:inheritable-attrs($type, ())" />
  </xsl:function>

  <xsl:function name="x:inheritable-attrs" as="element()*">
    <xsl:param name="type" as="element()?" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:choose>
      <xsl:when test="empty($type) or count($visited) ge 32">
        <xsl:sequence select="()" />
      </xsl:when>
      <xsl:otherwise>
        <!--
          Anonymous types (no @name) can't be cycle-tracked by QName, but
          they also can't appear as @base targets, so it's safe to walk
          their base chain without adding them to the visited set.
        -->
        <xsl:variable
          name="here"
          as="xs:string"
          select="if ($type/@name)
                  then x:clark(x:component-qname($type))
                  else ''" />
        <xsl:choose>
          <xsl:when test="$here ne '' and $here = $visited">
            <xsl:sequence select="()" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable
              name="base-q"
              as="xs:QName?"
              select="
              x:resolve($type/complexContent/(extension|restriction)/@base)
            " />
            <xsl:variable
              name="base"
              as="element()?"
              select="
              if (empty($base-q) or x:is-xs($base-q)) then ()
              else x:find-component(
                string(namespace-uri-from-QName($base-q)),
                local-name-from-QName($base-q),
                'complexType',
                $type
              )
            " />
            <xsl:variable
              name="next-visited"
              as="xs:string*"
              select="if ($here ne '') then ($visited, $here) else $visited" />
            <xsl:variable name="ancestor-attrs" as="element()*" select="x:inheritable-attrs($base, $next-visited)" />
            <xsl:variable name="own-inheritable" as="element()*" select="$type//attribute[x:xsd-true(@inheritable)]" />
            <xsl:sequence select="($ancestor-attrs, $own-inheritable)" />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!--
    True when the simpleType ultimately restricts xs:NOTATION (directly or via
    a chain of user-defined simpleType restrictions). Lets the enumeration
    renderer turn each @value into a link to the matching xs:notation.
  -->
  <xsl:function name="x:is-notation-st" as="xs:boolean">
    <xsl:param name="simpleType" as="element()?" />
    <xsl:choose>
      <xsl:when test="empty($simpleType) or not($simpleType/restriction)">
        <xsl:sequence select="false()" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="base-q" as="xs:QName?" select="x:resolve($simpleType/restriction/@base)" />
        <xsl:choose>
          <xsl:when test="empty($base-q)">
            <xsl:sequence select="false()" />
          </xsl:when>
          <xsl:when test="x:clark($base-q) eq concat('{', $xs-ns, '}NOTATION')">
            <xsl:sequence select="true()" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable
              name="base-st"
              as="element()?"
              select="
              x:find-component(
                string(namespace-uri-from-QName($base-q)),
                local-name-from-QName($base-q),
                'simpleType',
                $simpleType
              )
            " />
            <xsl:sequence
              select="
              exists($base-st)
                and not($base-st is $simpleType)
                and x:is-notation-st($base-st)
            " />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ===== Region 8. Schema collection (multi-file) ===== -->

  <!--
    Walk the include / import / redefine / override graph. Returns a
    map { 'schemas': element(schema)*, 'tns': map(uri -> tns), 'errors': xs:string* }.

    The chameleon rule: a schema reached via include/redefine without its
    own @targetNamespace inherits the including schema's effective TNS.
    Imports do not chameleon-promote, so the fallback for an import edge
    is the empty string.

    Implementation: tail-recursive over a parallel queue of (uri, fallback).
    Each iteration dequeues one entry, resolves it via doc(), and appends
    that schema's outgoing edges to the queue. doc() failures are caught
    via xsl:try and recorded as diagnostics on the result map.
  -->
  <xsl:function name="x:collect-schemas" as="map(*)">
    <xsl:param name="queue-uris" as="xs:string*" />
    <xsl:param name="queue-fb" as="xs:string*" />
    <xsl:param name="seen" as="xs:string*" />
    <xsl:param name="acc" as="element(schema)*" />
    <xsl:param name="tns-acc" as="map(xs:string, xs:string)" />
    <xsl:param name="errors" as="xs:string*" />
    <xsl:choose>
      <xsl:when test="empty($queue-uris)">
        <xsl:sequence
          select="map {
          'schemas': $acc,
          'tns': $tns-acc,
          'errors': $errors
        }" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="uri" select="$queue-uris[1]" />
        <xsl:variable name="fallback" select="$queue-fb[1]" />
        <xsl:variable name="rest-uris" select="$queue-uris[position() gt 1]" />
        <xsl:variable name="rest-fb" select="$queue-fb[position() gt 1]" />
        <xsl:choose>
          <xsl:when test="$uri = $seen">
            <xsl:sequence
              select="x:collect-schemas(
              $rest-uris, $rest-fb, $seen, $acc, $tns-acc, $errors
            )" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="loaded" as="map(*)">
              <xsl:try>
                <xsl:variable name="d" select="doc($uri)" />
                <xsl:sequence select="map { 'ok': true(), 'doc': $d }" />
                <xsl:catch>
                  <xsl:sequence
                    select="map { 'ok': false(),
                    'err': concat($uri, ': ', $err:description) }" />
                </xsl:catch>
              </xsl:try>
            </xsl:variable>
            <xsl:choose>
              <xsl:when test="not($loaded?ok)">
                <xsl:sequence
                  select="x:collect-schemas(
                  $rest-uris, $rest-fb, ($seen, $uri),
                  $acc, $tns-acc, ($errors, string($loaded?err))
                )" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:variable name="schema" as="element(schema)?" select="$loaded?doc/schema" />
                <xsl:choose>
                  <xsl:when test="empty($schema)">
                    <xsl:sequence
                      select="x:collect-schemas(
                      $rest-uris, $rest-fb, ($seen, $uri),
                      $acc, $tns-acc,
                      ($errors, concat($uri, ': no xs:schema root'))
                    )" />
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:variable name="own-tns" as="xs:string" select="string($schema/@targetNamespace)" />
                    <xsl:variable
                      name="eff-tns"
                      as="xs:string"
                      select="if ($own-tns ne '') then $own-tns else $fallback" />
                    <xsl:variable name="schema-uri" as="xs:string" select="string(base-uri($schema))" />
                    <xsl:variable
                      name="next-uris"
                      as="xs:string*"
                      select="
                      for $r in $schema/(import | include | redefine | override)[@schemaLocation]
                      return resolve-uri(string($r/@schemaLocation), string(base-uri($r)))
                    " />
                    <xsl:variable
                      name="next-fb"
                      as="xs:string*"
                      select="
                      for $r in $schema/(import | include | redefine | override)[@schemaLocation]
                      return if (local-name($r) eq 'import') then '' else $eff-tns
                    " />
                    <xsl:sequence
                      select="x:collect-schemas(
                      ($rest-uris, $next-uris),
                      ($rest-fb, $next-fb),
                      ($seen, $uri),
                      ($acc, $schema),
                      map:put($tns-acc, $schema-uri, $eff-tns),
                      $errors
                    )" />
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ===== Region 9. Global catalogs ===== -->

  <!--
    Internationalisation catalog. Outer key is a BCP-47 language tag,
    lowercased; inner key is a dotted message key. Active locale is picked
    by $active-locale (Region 3). Unknown keys fall back to 'en'; missing-
    from-'en' keys render as '[[key]]' so omissions are caught quickly.
    Contributors adding a locale: copy the 'en' block, translate values,
    leave keys untouched. Keys preserved across releases are a contract.
    {name} placeholders are substituted via x:t($key, $params).
  -->
  <xsl:variable
    name="i18n-messages"
    as="map(xs:string, map(xs:string, xs:string))"
    select="map {
    'en': map {
      'a11y.skipToContent':            'Skip to content',
      'sidebar.components':            'Components',
      'sidebar.filterAriaLabel':       'Filter components',
      'sidebar.filter':                'Filter',
      'sidebar.filterPlaceholder':     'Filter components…',
      'sidebar.toc':                   'Table of contents',
      'sidebar.schemas':               'Schemas',
      'sidebar.loadedSchemas':         'Loaded schemas',

      'page.title.fallback':           'XSD Documentation',
      'page.title.schemaPrefix':       'Schema: {ns}',
      'page.meta.targetNamespace':     'Target namespace',
      'page.meta.version':             'Version',
      'page.meta.elementForm':         'Element form',
      'page.meta.attributeForm':       'Attribute form',
      'page.meta.blockDefault':        'Block default',
      'page.meta.finalDefault':        'Final default',
      'page.meta.defaultAttributes':   'Default attributes',
      'page.meta.versionControls':     'Version controls',

      'footer.generatedByPrefix':      'Generated by ',
      'footer.generatedBySuffix':      ' v{version}.',

      'kind.element.plural':           'Elements',
      'kind.complexType.plural':       'Complex types',
      'kind.simpleType.plural':        'Simple types',
      'kind.attribute.plural':         'Attributes',
      'kind.attributeGroup.plural':    'Attribute groups',
      'kind.group.plural':             'Model groups',
      'kind.notation.plural':          'Notations',

      'overview.schema':               'Schema',
      'overview.defaultOpenContent':   'Default open content',
      'overview.defaultOpenContent.desc': 'All complex types with complex content receive the following open-content wildcard unless they declare their own ',
      'overview.defaultOpenContent.descMid': ' or ',
      'overview.defaultOpenContent.descTail': '.',
      'overview.xsd11':                'XSD 1.1 features in use',
      'overview.assertions':           'Assertions',
      'overview.assertions.desc':      'co-occurrence constraints expressed in XPath.',
      'overview.cta':                  'Conditional type assignment (CTA)',
      'overview.cta.descPrefix':       'on ',
      'overview.cta.descSuffix':       ' elements: type is selected per-instance via XPath.',
      'overview.openContent':          'Open content',
      'overview.openContent.desc':     'wildcard particles that interleave or append to the standard model.',
      'overview.inheritable':          'Inheritable attributes',
      'overview.inheritable.desc':     'attribute values flow to the CTA test context of descendant elements.',
      'overview.override':             'Override',
      'overview.override.descPrefix':  'components in imported schemas replaced wholesale. See ',
      'overview.override.descSuffix':  ' for the override map.',
      'overview.defaultAttrs':         'Default attributes',
      'overview.defaultAttrs.descPrefix': 'the ',
      'overview.defaultAttrs.descSuffix': ' attribute group is applied to every complex type unless ',
      'overview.defaultAttrs.descTail': '.',
      'overview.vcInclusion':          'Conditional inclusion (',
      'overview.vcInclusion.suffix':   ')',
      'overview.vcInclusion.descPrefix': ' ',
      'overview.vcInclusion.descSuffix': ' annotation site(s). Displayed below; never used to filter output.',

      'schemas.heading':               'Schemas',
      'schemas.diagnostics':           'Resolution diagnostics',
      'schemas.tableCaption':          'Loaded schemas',
      'schemas.col.role':              'Role',
      'schemas.col.location':          'Location',
      'schemas.col.targetNamespace':   'Target namespace',
      'schemas.col.version':           'Version',
      'schemas.role.primary':          'primary',
      'schemas.role.loaded':           'loaded',
      'schemas.declarations':          'Declarations',
      'schemas.declarations.caption':  'Schema declarations (import, include, redefine, override)',
      'schemas.col.in':                'In',
      'schemas.col.relation':          'Relation',
      'schemas.col.namespace':         'Namespace',
      'schemas.col.schemaLocation':    'schemaLocation',

      'component.badge.vcDecorated':   'Has vc:* conditional-inclusion attributes',
      'component.definedInPrefix':     'from ',
      'component.definedInFullPath':   ' (full path: {path})',
      'component.copyLink':            'Copy permanent link',
      'component.xsdSource':           'XSD source',
      'component.type':                'Type',
      'component.substitutionGroup':   'Substitution group',
      'component.default':             'Default',
      'component.fixed':               'Fixed',
      'component.block':               'Block',
      'component.final':               'Final',
      'component.anonymousType':       'Anonymous type',
      'component.defaultAttrsNotApplied': 'Default attributes',
      'component.notApplied':          'not applied',
      'component.contentModel':        'Content model',
      'component.openContent':         'Open content',
      'component.openContent.inheritedPrefix': 'Inherited from ',
      'component.openContent.inheritedSuffix': ' on the schema.',
      'component.definition':          'Definition',
      'component.ofConnector':         'of',
      'component.anonymousMember':     'anonymous member',
      'component.anonymous':           'anonymous',
      'component.inheritable':         'Inheritable',
      'component.particles':           'Particles',
      'component.publicId':            'Public ID',
      'component.systemId':            'System ID',
      'component.nillable':            'nillable',
      'component.inline':              'inline',
      'component.openInherited':       'Open content (inherited)',

      'facets.caption':                'Facets',
      'facets.col.facet':              'Facet',
      'facets.col.value':              'Value',
      'facets.col.fixed':              'Fixed',

      'attrs.heading':                 'Attributes',
      'attrs.caption':                 'Attributes',
      'attrs.col.name':                'Name',
      'attrs.col.type':                'Type',
      'attrs.col.use':                 'Use',
      'attrs.col.default':             'Default',
      'attrs.col.inheritable':         'Inheritable',
      'attrs.col.documentation':       'Documentation',
      'attrs.inheritable.heading':     'Inheritable attributes available to CTA test context',
      'attrs.inheritable.desc':        'These attributes are declared {inheritableCode} on ancestor types and are accessible to any {testCode} evaluated against an instance of this type.',
      'attrs.byReference':             '(by reference)',
      'attrs.yes':                     'yes',
      'attrs.fixedSuffix':             ' (fixed)',

      'identity.heading':              'Identity constraints',
      'identity.caption':              'Identity constraints',
      'identity.col.kind':             'Kind',
      'identity.col.name':             'Name',
      'identity.col.selector':         'Selector',
      'identity.col.fields':           'Fields',
      'identity.col.refersTo':         'Refers to',
      'identity.refNotFound':          'Referenced identity constraint not found in loaded schemas',
      'identity.refNotFoundSr':        ' (referenced identity constraint not found in loaded schemas)',

      'typeAlt.heading':               'Type alternatives',
      'typeAlt.desc':                  'The element''s effective type is selected per-instance via the first matching {altCode} XPath, falling through to the implicit default type.',
      'typeAlt.caption':               'Type alternatives',
      'typeAlt.col.when':              'When (XPath)',
      'typeAlt.col.type':              'Type',
      'typeAlt.col.documentation':     'Documentation',
      'typeAlt.otherwise':             'otherwise (default)',
      'typeAlt.xpathDefaultNs':        'xpath default namespace:',
      'typeAlt.noTypeNoTest':          '(no type, no test — invalid)',
      'typeAlt.implicitFallbackPrefix': 'implicit fallback to ',
      'typeAlt.inheritedHeading':      'Inherited test-context attributes',
      'typeAlt.inheritedDesc':         'The following inheritable attributes from the type chain are available in the {testCode} XPath context.',

      'assertions.heading':            'Assertions',
      'assertions.testPrefix':         'test = ',

      'openCnt.modePrefix':            'mode: ',
      'openCnt.namespace':             'Namespace',
      'openCnt.notNamespace':          'Not namespace',
      'openCnt.notQName':              'Not QName',
      'openCnt.processContents':       'Process contents',

      'vc.heading':                    'Version controls',
      'vc.note':                       'These {vcCode} attributes are XSD 1.1 conditional-inclusion annotations (Appendix F). xsdstyle displays them but does not filter the documentation based on them.',
      'vc.caption':                    'Version-control attributes',
      'vc.col.onElement':              'On element',
      'vc.col.attribute':              'Attribute',
      'vc.col.value':                  'Value',

      'hierarchy.heading':             'Type hierarchy',
      'hierarchy.thisType':            ' (this type)',

      'seeAlso.heading':               'See also',
      'seeAlso.usedAsTypeBy':          'Used as a type by',
      'seeAlso.substitutionMembers':   'Substitution group members',
      'seeAlso.as':                    ' as ',
      'seeAlso.ref':                   ' ref ',

      'doc.langTitle':                 'Documentation language ({lang})',
      'doc.langLabel':                 'Documentation language: {lang}',
      'doc.sourceLink':                'source',

      'helper.defNotFound':            'Definition not found in loaded schemas',
      'helper.defNotFoundInNs':        'Definition not found in loaded schemas (namespace: {ns})',

      'occurs.optional':               'Optional: 0 or 1 occurrence (minOccurs=0, maxOccurs=1)',
      'occurs.zeroOrMore':             'Zero or more occurrences (minOccurs=0, maxOccurs=unbounded)',
      'occurs.oneOrMore':              'One or more occurrences (minOccurs=1, maxOccurs=unbounded)',
      'occurs.atLeast':                'At least {min} occurrences (minOccurs={min}, maxOccurs=unbounded)',
      'occurs.exactly':                'Exactly {min} occurrences (minOccurs={min}, maxOccurs={max})',
      'occurs.between':                'Between {min} and {max} occurrences (minOccurs={min}, maxOccurs={max})',

      'js.showMore':                   'Show more',
      'js.showLess':                   'Show less',
      'js.showMoreOf':                 'Show more of {label}',
      'js.showLessOf':                 'Show less of {label}',
      'js.descriptionSuffix':          '{name} description',
      'js.componentSingular':          'component',
      'js.componentPlural':            'components',
      'js.moreDocMatches':             ' more documentation matches',
      'js.docMatches':                 ' documentation matches'
    }
  }" />

  <xsl:variable name="primary" as="element(schema)" select="/schema" />
  <xsl:variable name="primary-ns" as="xs:string" select="string($primary/@targetNamespace)" />
  <xsl:variable name="primary-uri" as="xs:string" select="string(base-uri($primary))" />

  <xsl:variable
    name="collected"
    as="map(*)"
    select="
    x:collect-schemas(
      for $r in $primary/(import | include | redefine | override)[@schemaLocation]
        return resolve-uri(string($r/@schemaLocation), string(base-uri($r))),
      for $r in $primary/(import | include | redefine | override)[@schemaLocation]
        return if (local-name($r) eq 'import') then '' else $primary-ns,
      $primary-uri,
      (),
      map { $primary-uri: $primary-ns },
      ()
    )
  " />

  <xsl:variable name="schemas" as="element(schema)+" select="($primary, $collected?schemas)" />

  <xsl:variable name="schema-tns" as="map(xs:string, xs:string)" select="$collected?tns" />

  <xsl:variable name="schema-errors" as="xs:string*" select="$collected?errors" />

  <xsl:variable
    name="secondary-namespaces"
    as="xs:string*"
    select="
    distinct-values(
      for $s in ($schemas except $primary) return x:tns($s)
    )[. ne $primary-ns]
  " />

  <!--
    Every top-level component across the schema collection, in document
    order per kind. Includes redefined and overridden components so the
    sidebar and search index find them.
  -->
  <xsl:variable
    name="all-components"
    as="element()*"
    select="
    $schemas/(
      element         | override/element
    | complexType    | redefine/complexType    | override/complexType
    | simpleType     | redefine/simpleType     | override/simpleType
    | attribute      | override/attribute
    | attributeGroup | redefine/attributeGroup | override/attributeGroup
    | group          | redefine/group          | override/group
    | notation       | override/notation
    )
  " />

  <!-- ===== Region 10. Root template ===== -->

  <xsl:template match="/schema">
    <xsl:variable
      name="page-title"
      as="xs:string"
      select="(
      $title,
      @id/string(),
      if (@targetNamespace) then x:t('page.title.schemaPrefix', map { 'ns': string(@targetNamespace) }) else (),
      x:t('page.title.fallback')
    )[. ne ''][1]" />

    <html lang="{$ui-lang}" dir="{$active-dir}">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="color-scheme" content="light dark" />
        <meta name="generator" content="xsdstyle v{$xsdstyle-version}" />
        <xsl:if test="$noindex">
          <meta name="robots" content="noindex" />
        </xsl:if>
        <title>
          <xsl:value-of select="$page-title" />
        </title>
        <link rel="stylesheet" href="{$base-href}xsdstyle.css" />
        <script src="{$base-href}xsdstyle.js" defer="defer" />
      </head>
      <body>
        <a class="skip-link" href="#main">
          <xsl:value-of select="x:t('a11y.skipToContent')" />
        </a>

        <header class="page-header">
          <div class="page-header__inner">
            <h1 class="page-header__title">
              <xsl:value-of select="$page-title" />
            </h1>
            <dl class="page-header__meta">
              <xsl:call-template name="meta-row">
                <xsl:with-param name="label" select="x:t('page.meta.targetNamespace')" />
                <xsl:with-param name="value" select="@targetNamespace/string()" />
                <xsl:with-param name="code" select="true()" />
              </xsl:call-template>
              <xsl:call-template name="meta-row">
                <xsl:with-param name="label" select="x:t('page.meta.version')" />
                <xsl:with-param name="value" select="@version/string()" />
              </xsl:call-template>
              <xsl:call-template name="meta-row">
                <xsl:with-param name="label" select="x:t('page.meta.elementForm')" />
                <xsl:with-param name="value" select="@elementFormDefault/string()" />
                <xsl:with-param name="href" select="'https://www.w3.org/TR/xmlschema11-1/#element-schema'" />
              </xsl:call-template>
              <xsl:call-template name="meta-row">
                <xsl:with-param name="label" select="x:t('page.meta.attributeForm')" />
                <xsl:with-param name="value" select="@attributeFormDefault/string()" />
                <xsl:with-param name="href" select="'https://www.w3.org/TR/xmlschema11-1/#element-schema'" />
              </xsl:call-template>
              <xsl:call-template name="meta-row">
                <xsl:with-param name="label" select="x:t('page.meta.blockDefault')" />
                <xsl:with-param name="value" select="@blockDefault/string()" />
                <xsl:with-param name="code" select="true()" />
              </xsl:call-template>
              <xsl:call-template name="meta-row">
                <xsl:with-param name="label" select="x:t('page.meta.finalDefault')" />
                <xsl:with-param name="value" select="@finalDefault/string()" />
                <xsl:with-param name="code" select="true()" />
              </xsl:call-template>
              <xsl:if test="@defaultAttributes">
                <dt>
                  <xsl:value-of select="x:t('page.meta.defaultAttributes')" />
                </dt>
                <dd>
                  <xsl:copy-of
                    select="
                    x:component-link(x:resolve(@defaultAttributes), 'attributeGroup', .)
                  " />
                </dd>
              </xsl:if>
              <xsl:variable name="schema-vc" as="attribute()*" select="x:vc-attrs(.)" />
              <xsl:if test="exists($schema-vc)">
                <dt>
                  <xsl:value-of select="x:t('page.meta.versionControls')" />
                </dt>
                <dd>
                  <xsl:for-each select="$schema-vc">
                    <xsl:if test="position() gt 1">
                      <xsl:text>, </xsl:text>
                    </xsl:if>
                    <code>vc:<xsl:value-of select="local-name()" />=&quot;<xsl:value-of select="." />&quot;</code>
                  </xsl:for-each>
                </dd>
              </xsl:if>
            </dl>
            <xsl:for-each select="annotation">
              <div class="page-header__doc" lang="{(@xml:lang/string(), $xml-lang)[. ne ''][1]}">
                <xsl:apply-templates select="documentation | appinfo" mode="doc" />
              </div>
            </xsl:for-each>
          </div>
        </header>

        <div class="layout">
          <aside class="sidebar" aria-label="{x:t('sidebar.components')}">
            <search class="sidebar__search" aria-label="{x:t('sidebar.filterAriaLabel')}">
              <label class="sidebar__search-label" for="toc-filter">
                <xsl:value-of select="x:t('sidebar.filter')" />
                <xsl:text> </xsl:text>
                <kbd class="sidebar__search-kbd" aria-hidden="true">/</kbd>
              </label>
              <input
                type="search"
                id="toc-filter"
                class="sidebar__search-input"
                placeholder="{x:t('sidebar.filterPlaceholder')}"
                autocomplete="off"
                aria-describedby="toc-filter-status"
                aria-keyshortcuts="/" />
              <div id="toc-filter-status" class="sidebar__search-status sr-only" role="status" aria-live="polite" />
              <div class="sidebar__doc-matches" id="toc-doc-matches" hidden="hidden" />
            </search>
            <nav class="sidebar__toc" aria-label="{x:t('sidebar.toc')}">
              <xsl:for-each select="1 to array:size($kind-meta)">
                <xsl:variable name="kind" as="map(*)" select="$kind-meta(.)" />
                <xsl:variable name="items" as="element()*" select="x:items-for-kind(string($kind?k))" />
                <xsl:if test="exists($items)">
                  <xsl:call-template name="toc-section">
                    <xsl:with-param name="kind" select="$kind" />
                    <xsl:with-param name="items" select="$items" />
                  </xsl:call-template>
                </xsl:if>
              </xsl:for-each>
              <xsl:if
                test="count($schemas) gt 1 or
                            $schemas/(import | include | redefine | override)">
                <div class="sidebar__toc-group sidebar__toc-group--schemas">
                  <h2 class="sidebar__toc-heading">
                    <xsl:value-of select="x:t('sidebar.schemas')" />
                    <span class="sidebar__toc-count">
                      <xsl:value-of select="count($schemas)" />
                    </span>
                  </h2>
                  <ul>
                    <li>
                      <a href="#schemas">
                        <xsl:value-of select="x:t('sidebar.loadedSchemas')" />
                      </a>
                    </li>
                  </ul>
                </div>
              </xsl:if>
            </nav>
          </aside>

          <main class="content" id="main" tabindex="-1">
            <xsl:call-template name="overview-section" />

            <xsl:for-each select="1 to array:size($kind-meta)">
              <xsl:variable name="kind" as="map(*)" select="$kind-meta(.)" />
              <xsl:variable name="items" as="element()*" select="x:items-for-kind(string($kind?k))" />
              <xsl:if test="exists($items)">
                <section class="components components--{$kind?modifier}" id="kind-{$kind?abbr}">
                  <h2 class="components__heading">
                    <xsl:value-of select="x:t(concat('kind.', $kind?k, '.plural'))" />
                  </h2>
                  <xsl:apply-templates select="$items" mode="section">
                    <xsl:sort select="@name" />
                  </xsl:apply-templates>
                </section>
              </xsl:if>
            </xsl:for-each>

            <xsl:if
              test="count($schemas) gt 1
                          or $schemas/(import | include | redefine | override)
                          or exists($schema-errors)">
              <xsl:call-template name="schemas-section" />
            </xsl:if>
          </main>
        </div>

        <footer class="page-footer">
          <p>
            <xsl:value-of select="x:t('footer.generatedByPrefix')" />
            <a
              href="https://github.com/bardiharborow/xsdstyle"
              rel="external noopener noreferrer"
              target="_blank">xsdstyle</a>
            <xsl:value-of select="x:t('footer.generatedBySuffix', map { 'version': $xsdstyle-version })" />
          </p>
        </footer>

        <xsl:call-template name="i18n-script" />
        <xsl:call-template name="search-index" />
      </body>
    </html>
  </xsl:template>

  <!-- ===== Region 11. Sidebar / TOC / JSON search index / overview ===== -->

  <xsl:template name="meta-row">
    <xsl:param name="label" as="xs:string" />
    <xsl:param name="value" as="xs:string?" />
    <xsl:param name="code" as="xs:boolean" select="false()" />
    <xsl:param name="href" as="xs:string?" select="()" />
    <xsl:if test="exists($value) and $value ne ''">
      <dt>
        <xsl:value-of select="$label" />
      </dt>
      <dd>
        <xsl:choose>
          <xsl:when test="exists($href) and $href ne ''">
            <a href="{$href}">
              <xsl:choose>
                <xsl:when test="$code">
                  <code>
                    <xsl:value-of select="$value" />
                  </code>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="$value" />
                </xsl:otherwise>
              </xsl:choose>
            </a>
          </xsl:when>
          <xsl:when test="$code">
            <code>
              <xsl:value-of select="$value" />
            </code>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$value" />
          </xsl:otherwise>
        </xsl:choose>
      </dd>
    </xsl:if>
  </xsl:template>

  <xsl:template name="toc-section">
    <xsl:param name="kind" as="map(*)" required="yes" />
    <xsl:param name="items" as="element()*" required="yes" />
    <div class="sidebar__toc-group sidebar__toc-group--{$kind?modifier}" data-kind="{$kind?abbr}">
      <h2 class="sidebar__toc-heading">
        <xsl:value-of select="x:t(concat('kind.', $kind?k, '.plural'))" />
        <span class="sidebar__toc-count">
          <xsl:value-of select="count($items)" />
        </span>
      </h2>
      <ul>
        <xsl:for-each select="$items">
          <xsl:sort select="@name" />
          <li data-name="{lower-case(string(@name))}">
            <a href="#{x:anchor-for(.)}">
              <code>
                <xsl:value-of select="@name" />
              </code>
            </a>
          </li>
        </xsl:for-each>
      </ul>
    </div>
  </xsl:template>

  <!--
    Overview: facts, "XSD 1.1 features in use" aggregation, schema-level
    defaultAttributes / defaultOpenContent.
  -->
  <xsl:template name="overview-section">
    <xsl:variable
      name="vc-components"
      as="element()*"
      select="$all-components[descendant-or-self::*[@*[namespace-uri() eq $vc-ns]]]" />
    <xsl:variable name="schema-vc" as="attribute()*" select="x:vc-attrs(.)" />
    <xsl:variable
      name="any-1-1"
      as="xs:boolean"
      select="
      exists($vc-components) or exists($schema-vc)
      or exists($all-components//(assert | alternative | openContent
                                 | attribute[x:xsd-true(@inheritable)]))
      or exists(defaultOpenContent)
      or exists($schemas/override/*)
    " />
    <xsl:if test="defaultOpenContent or $any-1-1">
      <section class="overview" id="overview">
        <h2 class="overview__heading">
          <xsl:value-of select="x:t('overview.schema')" />
        </h2>
        <xsl:if test="defaultOpenContent">
          <div class="overview__default-open-content">
            <h3 class="overview__sub-heading">
              <xsl:value-of select="x:t('overview.defaultOpenContent')" />
            </h3>
            <p>
              <xsl:value-of select="x:t('overview.defaultOpenContent.desc')" />
              <code>xs:openContent</code>
              <xsl:value-of select="x:t('overview.defaultOpenContent.descMid')" />
              <code>mode="none"</code>
              <xsl:value-of select="x:t('overview.defaultOpenContent.descTail')" />
            </p>
            <xsl:apply-templates select="defaultOpenContent" mode="open-content" />
          </div>
        </xsl:if>
        <xsl:if test="$any-1-1">
          <div class="overview__xsd11">
            <h3 class="overview__sub-heading">
              <xsl:value-of select="x:t('overview.xsd11')" />
            </h3>
            <ul class="overview__xsd11-list">
              <xsl:if test="exists($all-components//assert)">
                <li>
                <strong>
                  <xsl:value-of select="x:t('overview.assertions')" />
                </strong>
                (<xsl:value-of select="count($all-components//assert)" />):
                <xsl:text> </xsl:text>
                <xsl:value-of select="x:t('overview.assertions.desc')" />
              </li>
              </xsl:if>
              <xsl:if test="exists($all-components//alternative)">
                <li>
                  <strong>
                    <xsl:value-of select="x:t('overview.cta')" />
                  </strong>
                  <xsl:text> </xsl:text>
                  <xsl:value-of select="x:t('overview.cta.descPrefix')" />
                  <xsl:value-of select="count($all-components/self::element[alternative])" />
                  <xsl:value-of select="x:t('overview.cta.descSuffix')" />
                </li>
              </xsl:if>
              <xsl:if test="exists($all-components//openContent) or exists(defaultOpenContent)">
                <li>
                <strong>
                  <xsl:value-of select="x:t('overview.openContent')" />
                </strong>:
                <xsl:text> </xsl:text>
                <xsl:value-of select="x:t('overview.openContent.desc')" />
              </li>
              </xsl:if>
              <xsl:if test="exists($all-components//attribute[x:xsd-true(@inheritable)])">
                <li>
                <strong>
                  <xsl:value-of select="x:t('overview.inheritable')" />
                </strong>
                (<xsl:value-of select="count($all-components//attribute[x:xsd-true(@inheritable)])" />):
                <xsl:text> </xsl:text>
                <xsl:value-of select="x:t('overview.inheritable.desc')" />
              </li>
              </xsl:if>
              <xsl:if test="exists($schemas/override/*)">
                <li>
                <strong>
                  <xsl:value-of select="x:t('overview.override')" />
                </strong>:
                <xsl:text> </xsl:text>
                <xsl:value-of select="x:t('overview.override.descPrefix')" />
                <a href="#schemas">
                  <xsl:value-of select="x:t('sidebar.schemas')" />
                </a>
                <xsl:value-of select="x:t('overview.override.descSuffix')" />
              </li>
              </xsl:if>
              <xsl:if test="exists(@defaultAttributes)">
                <li>
                <strong>
                  <xsl:value-of select="x:t('overview.defaultAttrs')" />
                </strong>:
                <xsl:value-of select="x:t('overview.defaultAttrs.descPrefix')" />
                <xsl:copy-of
                  select="x:component-link(
                  x:resolve(@defaultAttributes), 'attributeGroup', .)" />
                <xsl:value-of select="x:t('overview.defaultAttrs.descSuffix')" />
                <code>defaultAttributesApply="false"</code>
                <xsl:value-of select="x:t('overview.defaultAttrs.descTail')" />
              </li>
              </xsl:if>
              <xsl:if test="exists($vc-components) or exists($schema-vc)">
                <li>
                <strong>
                  <xsl:value-of select="x:t('overview.vcInclusion')" />
                  <code>vc:*</code>
                  <xsl:value-of select="x:t('overview.vcInclusion.suffix')" />
                </strong>:
                <xsl:value-of select="x:t('overview.vcInclusion.descPrefix')" />
                <xsl:value-of
                  select="count(distinct-values(
                  for $vc in $all-components//@*[namespace-uri() eq $vc-ns]
                    return generate-id($vc/..)
                ))" />
                <xsl:value-of select="x:t('overview.vcInclusion.descSuffix')" />
              </li>
              </xsl:if>
            </ul>
          </div>
        </xsl:if>
      </section>
    </xsl:if>
  </xsl:template>

  <xsl:template name="schemas-section">
    <section class="components components--schemas" id="schemas">
      <h2 class="components__heading">
        <xsl:value-of select="x:t('schemas.heading')" />
      </h2>
      <xsl:if test="exists($schema-errors)">
        <div class="schemas__errors" role="alert">
          <h3>
            <xsl:value-of select="x:t('schemas.diagnostics')" />
          </h3>
          <ul>
            <xsl:for-each select="$schema-errors">
              <li>
                <code>
                  <xsl:value-of select="." />
                </code>
              </li>
            </xsl:for-each>
          </ul>
        </div>
      </xsl:if>
      <table class="schemas__table">
        <caption class="table-caption-sr">
          <xsl:value-of select="x:t('schemas.tableCaption')" />
        </caption>
        <thead>
          <tr>
            <th scope="col">
              <xsl:value-of select="x:t('schemas.col.role')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('schemas.col.location')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('schemas.col.targetNamespace')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('schemas.col.version')" />
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:for-each select="$schemas">
            <tr>
              <td>
                <span class="badge badge--{if (. is $primary) then 'primary' else 'loaded'}">
                  <xsl:value-of
                    select="if (. is $primary) then x:t('schemas.role.primary') else x:t('schemas.role.loaded')" />
                </span>
              </td>
              <td>
                <code>
                  <xsl:value-of select="x:relative-source(.)" />
                </code>
              </td>
              <td>
                <code>
                  <xsl:value-of select="x:tns(.)" />
                </code>
              </td>
              <td>
                <xsl:value-of select="@version" />
              </td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
      <xsl:variable name="decls" select="$schemas/(import | include | redefine | override)" />
      <xsl:if test="exists($decls)">
        <h3 class="schemas__sub-heading">
          <xsl:value-of select="x:t('schemas.declarations')" />
        </h3>
        <table class="schemas__table">
          <caption class="table-caption-sr">
            <xsl:value-of select="x:t('schemas.declarations.caption')" />
          </caption>
          <thead>
            <tr>
              <th scope="col">
                <xsl:value-of select="x:t('schemas.col.in')" />
              </th>
              <th scope="col">
                <xsl:value-of select="x:t('schemas.col.relation')" />
              </th>
              <th scope="col">
                <xsl:value-of select="x:t('schemas.col.namespace')" />
              </th>
              <th scope="col">
                <xsl:value-of select="x:t('schemas.col.schemaLocation')" />
              </th>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="$decls">
              <tr>
                <td>
                  <code>
                    <xsl:value-of select="x:relative-source(ancestor::schema[1])" />
                  </code>
                </td>
                <td>
                  <span class="badge badge--{local-name()}">
                    <xsl:value-of select="local-name()" />
                  </span>
                </td>
                <td>
                  <code>
                    <xsl:value-of select="@namespace" />
                  </code>
                </td>
                <td>
                  <code>
                    <xsl:value-of select="@schemaLocation" />
                  </code>
                </td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
      </xsl:if>
    </section>
  </xsl:template>

  <!--
    JS-side message bundle. Emits the subset of i18n strings that the
    client script consumes (filter status line, doc collapse toggle).
    The shape is a stable, explicitly-enumerated map so the contract
    with assets/xsdstyle.js does not silently widen if the catalog grows.
  -->
  <xsl:template name="i18n-script">
    <script type="application/json" id="xsdoc-i18n">
      <xsl:value-of
        disable-output-escaping="yes"
        select="serialize(
        map {
          'showMore':          x:t('js.showMore'),
          'showLess':          x:t('js.showLess'),
          'showMoreOf':        x:t('js.showMoreOf'),
          'showLessOf':        x:t('js.showLessOf'),
          'descriptionSuffix': x:t('js.descriptionSuffix'),
          'componentSingular': x:t('js.componentSingular'),
          'componentPlural':   x:t('js.componentPlural'),
          'moreDocMatches':    x:t('js.moreDocMatches'),
          'docMatches':        x:t('js.docMatches')
        },
        map { 'method': 'json', 'indent': false() }
      )" />
    </script>
  </xsl:template>

  <!--
    JSON search index emitted as <script type="application/json">. Each
    entry: { a: anchor, n: name, k: kind-abbr, d: doc-snippet }.
  -->
  <xsl:template name="search-index">
    <xsl:variable name="entries" as="map(*)*">
      <xsl:for-each select="1 to array:size($kind-meta)">
        <xsl:variable name="kind" as="map(*)" select="$kind-meta(.)" />
        <xsl:variable name="items" as="element()*" select="x:items-for-kind(string($kind?k))" />
        <xsl:for-each select="$items">
          <xsl:sequence
            select="map {
            'a': x:anchor-for(.),
            'n': string(@name),
            'k': string($kind?abbr),
            'd': x:doc-snippet(.)
          }" />
        </xsl:for-each>
      </xsl:for-each>
    </xsl:variable>
    <script type="application/json" id="xsdoc-index">
      <xsl:value-of
        disable-output-escaping="yes"
        select="serialize(
        array { $entries },
        map { 'method': 'json', 'indent': false() }
      )" />
    </script>
  </xsl:template>

  <!-- ===== Region 12. Per-kind component renderers ===== -->

  <!--
    Component card dispatcher. Every top-level component (and every
    redefined/overridden component) lands here. The card frame is shared;
    the body delegates to per-kind named templates.
  -->
  <xsl:template
    match="
    element | complexType | simpleType | attribute
    | attributeGroup | group | notation
  "
    mode="section">
    <xsl:variable name="kind" as="xs:string" select="local-name()" />
    <xsl:variable
      name="modifier"
      as="xs:string"
      select="
      (array:flatten($kind-meta)[. instance of map(*)][?k = $kind][1]?modifier,
       $kind)[1]
    " />
    <xsl:variable name="abbr" as="xs:string" select="x:abbr($kind)" />
    <xsl:variable name="vc" as="attribute()*" select="x:vc-attrs(.)" />
    <article
      class="component component--{$modifier}"
      id="{x:anchor-for(.)}"
      data-kind="{$abbr}"
      data-name="{lower-case(string(@name))}">
      <header class="component__header">
        <span class="badge badge--kind badge--kind-{$modifier}">
          <xsl:value-of select="$kind" />
        </span>
        <h3 class="component__name">
          <xsl:if test="$kind eq 'attribute'">
            <span class="component__attr-prefix">@</span>
          </xsl:if>
          <code>
            <bdi>
              <xsl:value-of select="@name" />
            </bdi>
          </code>
        </h3>
        <span class="component__qname">
          <code>{<bdi>
            <xsl:value-of select="x:tns(ancestor::schema[1])" />
          </bdi>}<bdi>
            <xsl:value-of select="@name" />
          </bdi></code>
        </span>
        <xsl:if test="x:is-redefined(.)">
          <span class="badge badge--redefined">redefined</span>
        </xsl:if>
        <xsl:if test="x:is-overridden(.)">
          <span class="badge badge--overridden">overridden</span>
        </xsl:if>
        <xsl:if test="x:xsd-true(@abstract)">
          <span class="badge badge--abstract">abstract</span>
        </xsl:if>
        <xsl:if test="x:xsd-true(@mixed)">
          <span class="badge badge--mixed">mixed</span>
        </xsl:if>
        <xsl:if test="x:xsd-true(@nillable)">
          <span class="badge badge--nillable">nillable</span>
        </xsl:if>
        <xsl:if test="exists($vc)
                      or exists(.//*[@*[namespace-uri() eq $vc-ns]])">
          <span
            class="badge badge--vc-decorated"
            title="{x:t('component.badge.vcDecorated')}"
            role="img"
            aria-label="{x:t('component.badge.vcDecorated')}">vc:*</span>
        </xsl:if>
        <xsl:variable name="own-schema" as="element(schema)" select="ancestor::schema[1]" />
        <xsl:if test="not($own-schema is $primary)">
          <span class="badge badge--defined-in" title="{base-uri($own-schema)}">
            <xsl:value-of select="x:t('component.definedInPrefix')" />
            <xsl:value-of select="x:relative-source($own-schema)" />
            <span class="sr-only">
              <xsl:value-of
                select="x:t('component.definedInFullPath', map { 'path': string(base-uri($own-schema)) })" />
            </span>
          </span>
        </xsl:if>
        <button
          type="button"
          class="component__copy-link copy-link"
          data-anchor="{x:anchor-for(.)}"
          title="{x:t('component.copyLink')}"
          aria-label="{x:t('component.copyLink')}">
          <span class="copy-link__icon" aria-hidden="true">#</span>
        </button>
      </header>

      <xsl:apply-templates select="annotation/(documentation | appinfo)" mode="doc" />

      <!-- Kind-specific body -->
      <xsl:choose>
        <xsl:when test="$kind eq 'element'">
          <xsl:call-template name="render-element-body" />
        </xsl:when>
        <xsl:when test="$kind eq 'complexType'">
          <xsl:call-template name="render-complex-type-body" />
        </xsl:when>
        <xsl:when test="$kind eq 'simpleType'">
          <xsl:call-template name="render-simple-type-body" />
        </xsl:when>
        <xsl:when test="$kind eq 'attribute'">
          <xsl:call-template name="render-attribute-body" />
        </xsl:when>
        <xsl:when test="$kind eq 'attributeGroup'">
          <xsl:call-template name="render-attribute-group-body" />
        </xsl:when>
        <xsl:when test="$kind eq 'group'">
          <xsl:call-template name="render-group-body" />
        </xsl:when>
        <xsl:when test="$kind eq 'notation'">
          <xsl:call-template name="render-notation-body" />
        </xsl:when>
      </xsl:choose>

      <xsl:if test="exists($vc) or exists(.//*[@*[namespace-uri() eq $vc-ns]])">
        <xsl:call-template name="render-vc-controls" />
      </xsl:if>

      <xsl:call-template name="render-see-also" />

      <xsl:if test="$include-source">
        <details class="component__source">
          <summary>
            <xsl:value-of select="x:t('component.xsdSource')" />
          </summary>
          <pre class="xsd-source">
            <xsl:apply-templates select="." mode="xsd-source" />
          </pre>
        </details>
      </xsl:if>
    </article>
  </xsl:template>

  <!-- ====== Element ====== -->
  <xsl:template name="render-element-body">
    <dl class="component__props">
      <xsl:variable name="type-q" as="xs:QName?" select="x:resolve(@type)" />
      <xsl:if test="exists($type-q) or @type">
        <dt>
          <xsl:value-of select="x:t('component.type')" />
        </dt>
        <dd>
          <xsl:copy-of select="x:component-link($type-q, 'type', .)" />
        </dd>
      </xsl:if>
      <xsl:if test="@substitutionGroup">
        <dt>
          <xsl:value-of select="x:t('component.substitutionGroup')" />
        </dt>
        <dd>
          <xsl:variable name="ctx" as="element()" select="." />
          <xsl:for-each select="tokenize(normalize-space(@substitutionGroup), '\s+')">
            <xsl:if test="position() gt 1">
              <xsl:text>, </xsl:text>
            </xsl:if>
            <xsl:copy-of
              select="x:component-link(
              x:resolve-qname(., $ctx),
              'element',
              $ctx
            )" />
          </xsl:for-each>
        </dd>
      </xsl:if>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('component.default')" />
        <xsl:with-param name="value" select="@default/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('component.fixed')" />
        <xsl:with-param name="value" select="@fixed/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('component.block')" />
        <xsl:with-param name="value" select="@block/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('component.final')" />
        <xsl:with-param name="value" select="@final/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
    </dl>

    <xsl:if test="complexType | simpleType">
      <section class="component__inline-type">
        <h4 class="component__sub-heading">
          <xsl:value-of select="x:t('component.anonymousType')" />
        </h4>
        <xsl:apply-templates select="complexType | simpleType" mode="inline-complex" />
      </section>
    </xsl:if>

    <xsl:if test="alternative">
      <xsl:call-template name="render-type-alternatives" />
    </xsl:if>

    <xsl:if test="key | unique | keyref">
      <xsl:call-template name="render-identity-constraints" />
    </xsl:if>
  </xsl:template>

  <!-- ====== ComplexType ====== -->
  <xsl:template name="render-complex-type-body">
    <dl class="component__props">
      <xsl:if test="@block">
        <xsl:call-template name="meta-row">
          <xsl:with-param name="label" select="x:t('component.block')" />
          <xsl:with-param name="value" select="@block/string()" />
          <xsl:with-param name="code" select="true()" />
        </xsl:call-template>
      </xsl:if>
      <xsl:if test="@final">
        <xsl:call-template name="meta-row">
          <xsl:with-param name="label" select="x:t('component.final')" />
          <xsl:with-param name="value" select="@final/string()" />
          <xsl:with-param name="code" select="true()" />
        </xsl:call-template>
      </xsl:if>
      <xsl:if test="exists(@defaultAttributesApply)
                    and not(x:xsd-true(@defaultAttributesApply))">
        <dt>
          <xsl:value-of select="x:t('component.defaultAttrsNotApplied')" />
        </dt>
        <dd><code>
          <xsl:value-of select="x:t('component.notApplied')" />
        </code> (<code>defaultAttributesApply="false"</code>)</dd>
      </xsl:if>
    </dl>

    <xsl:call-template name="render-derivation-chain" />

    <section class="component__model">
      <h4 class="component__sub-heading">
        <xsl:value-of select="x:t('component.contentModel')" />
      </h4>
      <xsl:choose>
        <xsl:when test="complexContent">
          <xsl:apply-templates select="complexContent" mode="derivation" />
        </xsl:when>
        <xsl:when test="simpleContent">
          <xsl:apply-templates select="simpleContent" mode="derivation" />
        </xsl:when>
        <xsl:otherwise>
          <ul class="model">
            <xsl:apply-templates select="sequence | choice | all | group | openContent" mode="model" />
          </ul>
        </xsl:otherwise>
      </xsl:choose>
    </section>

    <xsl:variable name="eff-oc" as="element()?" select="x:effective-open-content(.)" />
    <xsl:if test="exists($eff-oc)">
      <section class="component__open-content">
        <h4 class="component__sub-heading">
          <xsl:value-of select="x:t('component.openContent')" />
        </h4>
        <xsl:apply-templates select="$eff-oc" mode="open-content" />
        <xsl:if
          test="not(($eff-oc is openContent)
                          or ($eff-oc is complexContent/openContent))">
          <p class="component__open-content-footnote">
            <xsl:value-of select="x:t('component.openContent.inheritedPrefix')" />
            <code>xs:defaultOpenContent</code>
            <xsl:value-of select="x:t('component.openContent.inheritedSuffix')" />
          </p>
        </xsl:if>
      </section>
    </xsl:if>

    <xsl:if test=".//attribute | .//attributeGroup | .//anyAttribute">
      <xsl:call-template name="render-attribute-table" />
    </xsl:if>

    <xsl:if test=".//assert">
      <xsl:call-template name="render-assertions" />
    </xsl:if>
  </xsl:template>

  <!-- ====== SimpleType ====== -->
  <xsl:template name="render-simple-type-body">
    <section class="component__model">
      <h4 class="component__sub-heading">
        <xsl:value-of select="x:t('component.definition')" />
      </h4>
      <xsl:choose>
        <xsl:when test="restriction">
          <xsl:apply-templates select="restriction" mode="derivation" />
        </xsl:when>
        <xsl:when test="list">
          <p>
            <span class="kw-label kw-label--list">list</span>
            <xsl:value-of select="x:t('component.ofConnector')" />
            <xsl:if test="list/@itemType">
              <xsl:text> </xsl:text>
              <xsl:copy-of select="x:component-link(x:resolve(list/@itemType), 'type', list)" />
            </xsl:if>
          </p>
          <xsl:if test="list/simpleType">
            <div class="component__inline-type">
              <xsl:apply-templates select="list/simpleType" mode="inline-complex" />
            </div>
          </xsl:if>
        </xsl:when>
        <xsl:when test="child::union">
          <p>
            <span class="kw-label kw-label--union">union</span>
            <xsl:value-of select="x:t('component.ofConnector')" />
            <xsl:text>:</xsl:text>
          </p>
          <ul class="component__union">
            <xsl:variable name="union-el" as="element()" select="child::union" />
            <xsl:if test="$union-el/@memberTypes">
              <xsl:for-each select="tokenize(normalize-space($union-el/@memberTypes), '\s+')">
                <li>
                  <xsl:copy-of
                    select="x:component-link(
                    x:resolve-qname(., $union-el),
                    'type',
                    $union-el
                  )" />
                </li>
              </xsl:for-each>
            </xsl:if>
            <xsl:for-each select="$union-el/simpleType">
              <li>
                <span class="inline-marker">
                  <xsl:value-of select="x:t('component.anonymousMember')" />
                </span>
                <div class="component__inline-type">
                  <xsl:apply-templates select="." mode="inline-complex" />
                </div>
              </li>
            </xsl:for-each>
          </ul>
        </xsl:when>
      </xsl:choose>
    </section>
  </xsl:template>

  <!-- ====== Attribute (global) ====== -->
  <xsl:template name="render-attribute-body">
    <dl class="component__props">
      <xsl:if test="@type">
        <dt>
          <xsl:value-of select="x:t('component.type')" />
        </dt>
        <dd>
          <xsl:copy-of select="x:component-link(x:resolve(@type), 'simpleType', .)" />
        </dd>
      </xsl:if>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('component.default')" />
        <xsl:with-param name="value" select="@default/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('component.fixed')" />
        <xsl:with-param name="value" select="@fixed/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
      <xsl:if test="x:xsd-true(@inheritable)">
        <dt>
          <xsl:value-of select="x:t('component.inheritable')" />
        </dt>
        <dd>
          <code>true</code>
        </dd>
      </xsl:if>
    </dl>
    <xsl:if test="simpleType">
      <section class="component__inline-type">
        <h4 class="component__sub-heading">
          <xsl:value-of select="x:t('component.anonymousType')" />
        </h4>
        <xsl:apply-templates select="simpleType" mode="inline-complex" />
      </section>
    </xsl:if>
  </xsl:template>

  <!-- ====== AttributeGroup ====== -->
  <xsl:template name="render-attribute-group-body">
    <xsl:if test="attribute | attributeGroup | anyAttribute">
      <xsl:call-template name="render-attribute-table" />
    </xsl:if>
  </xsl:template>

  <!-- ====== Group ====== -->
  <xsl:template name="render-group-body">
    <section class="component__model">
      <h4 class="component__sub-heading">
        <xsl:value-of select="x:t('component.particles')" />
      </h4>
      <ul class="model">
        <xsl:apply-templates select="sequence | choice | all" mode="model" />
      </ul>
    </section>
  </xsl:template>

  <!-- ====== Notation ====== -->
  <xsl:template name="render-notation-body">
    <dl class="component__props">
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('component.publicId')" />
        <xsl:with-param name="value" select="@public/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('component.systemId')" />
        <xsl:with-param name="value" select="@system/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
    </dl>
  </xsl:template>

  <!-- ===== Region 13. Sub-renderers ===== -->

  <!-- ====== Content model (sequence / choice / all / group / any / element) ====== -->

  <xsl:template match="sequence" mode="model">
    <li class="model__compositor model__compositor--sequence">
      <span class="model__compositor-label">sequence</span>
      <xsl:call-template name="emit-occurs" />
      <ul class="model">
        <xsl:apply-templates mode="model" />
      </ul>
    </li>
  </xsl:template>

  <xsl:template match="choice" mode="model">
    <li class="model__compositor model__compositor--choice">
      <span class="model__compositor-label">choice</span>
      <xsl:call-template name="emit-occurs" />
      <ul class="model">
        <xsl:apply-templates mode="model" />
      </ul>
    </li>
  </xsl:template>

  <xsl:template match="all" mode="model">
    <li class="model__compositor model__compositor--all">
      <span class="model__compositor-label">all</span>
      <xsl:call-template name="emit-occurs" />
      <ul class="model">
        <xsl:apply-templates mode="model" />
      </ul>
    </li>
  </xsl:template>

  <xsl:template match="group[@ref]" mode="model">
    <li class="model__particle model__particle--group">
      <span class="model__particle-label">group</span>
      <xsl:copy-of select="x:component-link(x:resolve(@ref), 'group', .)" />
      <xsl:call-template name="emit-occurs" />
    </li>
  </xsl:template>

  <xsl:template match="element" mode="model">
    <li class="model__particle model__particle--element">
      <xsl:choose>
        <xsl:when test="@ref">
          <xsl:copy-of select="x:component-link(x:resolve(@ref), 'element', .)" />
        </xsl:when>
        <xsl:otherwise>
          <code class="model__particle-name">
            <xsl:value-of select="@name" />
          </code>
          <xsl:if test="@type">
            <span class="model__particle-type">
              <xsl:text> : </xsl:text>
              <xsl:copy-of select="x:component-link(x:resolve(@type), 'type', .)" />
            </span>
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="emit-occurs" />
      <xsl:if test="x:xsd-true(@nillable)">
        <span class="model__particle-nillable">
          <xsl:value-of select="x:t('component.nillable')" />
        </span>
      </xsl:if>
      <xsl:if test="complexType | simpleType">
        <span class="model__particle-inline">
          <xsl:value-of select="x:t('component.inline')" />
        </span>
        <div class="model__inline-type">
          <xsl:apply-templates select="complexType | simpleType" mode="inline-complex" />
        </div>
      </xsl:if>
      <xsl:if test="alternative">
        <details class="model__inline-alternatives">
          <summary>
            <xsl:value-of select="x:t('typeAlt.heading')" />
          </summary>
          <xsl:call-template name="render-type-alternatives" />
        </details>
      </xsl:if>
    </li>
  </xsl:template>

  <xsl:template match="any" mode="model">
    <li class="model__particle model__particle--any">
      <span class="model__particle-label">any</span>
      <xsl:call-template name="emit-wildcard-attrs" />
      <xsl:call-template name="emit-occurs" />
    </li>
  </xsl:template>

  <!-- Open-content children -->
  <xsl:template match="openContent" mode="model">
    <li class="model__particle model__particle--open-content">
      <span class="badge badge--open-content badge--open-content--{(@mode, 'interleave')[1]}">
        <xsl:value-of select="(@mode, 'interleave')[1]" />
      </span>
      <xsl:apply-templates select="any" mode="model" />
    </li>
  </xsl:template>

  <!-- ====== Derivation panel (complexContent / simpleContent / simpleType restriction) ====== -->

  <xsl:template match="complexContent" mode="derivation">
    <div class="component__derivation">
      <xsl:if test="x:xsd-true(@mixed)">
        <span class="badge badge--mixed">mixed</span>
      </xsl:if>
      <xsl:apply-templates select="extension | restriction" mode="derivation" />
    </div>
  </xsl:template>

  <xsl:template match="simpleContent" mode="derivation">
    <div class="component__derivation component__derivation--simple-content">
      <xsl:apply-templates select="extension | restriction" mode="derivation" />
    </div>
  </xsl:template>

  <xsl:template match="extension" mode="derivation">
    <div class="component__derivation-step component__derivation-step--extension">
      <p>
        <span class="kw-label kw-label--extension">extension</span>
        <xsl:value-of select="x:t('component.ofConnector')" />
        <xsl:text> </xsl:text>
        <xsl:copy-of select="x:component-link(x:resolve(@base), 'type', .)" />
      </p>
      <xsl:if test="sequence | choice | all | group | openContent">
        <ul class="model">
          <xsl:apply-templates select="sequence | choice | all | group | openContent" mode="model" />
        </ul>
      </xsl:if>
    </div>
  </xsl:template>

  <xsl:template match="restriction" mode="derivation">
    <div class="component__derivation-step component__derivation-step--restriction">
      <p>
        <span class="kw-label kw-label--restriction">restriction</span>
        <xsl:value-of select="x:t('component.ofConnector')" />
        <xsl:text> </xsl:text>
        <xsl:copy-of select="x:component-link(x:resolve(@base), 'type', .)" />
      </p>
      <xsl:if test="sequence | choice | all | group | openContent">
        <ul class="model">
          <xsl:apply-templates select="sequence | choice | all | group | openContent" mode="model" />
        </ul>
      </xsl:if>
      <xsl:if
        test="*[not(self::sequence|self::choice|self::all|self::group
                          |self::attribute|self::attributeGroup|self::anyAttribute
                          |self::annotation|self::assert|self::openContent)]">
        <xsl:call-template name="render-facets" />
      </xsl:if>
    </div>
  </xsl:template>

  <!-- ====== Inline complex/simple types (anonymous) ====== -->

  <xsl:template match="complexType" mode="inline-complex">
    <div class="inline-complex inline-complex--complex">
      <xsl:choose>
        <xsl:when test="complexContent">
          <xsl:apply-templates select="complexContent" mode="derivation" />
        </xsl:when>
        <xsl:when test="simpleContent">
          <xsl:apply-templates select="simpleContent" mode="derivation" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:if test="sequence | choice | all | group | openContent">
            <ul class="model">
              <xsl:apply-templates select="sequence | choice | all | group | openContent" mode="model" />
            </ul>
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:variable name="eff-oc" select="x:effective-open-content(.)" />
      <xsl:if test="exists($eff-oc) and not(complexContent/openContent or openContent)">
        <div class="inline-complex__open-content">
          <h5>
            <xsl:value-of select="x:t('component.openInherited')" />
          </h5>
          <xsl:apply-templates select="$eff-oc" mode="open-content" />
        </div>
      </xsl:if>
      <xsl:if
        test="attribute | attributeGroup | anyAttribute
                    | .//restriction/attribute | .//extension/attribute">
        <xsl:call-template name="render-attribute-table" />
      </xsl:if>
      <xsl:if test=".//assert">
        <xsl:call-template name="render-assertions" />
      </xsl:if>
    </div>
  </xsl:template>

  <xsl:template match="simpleType" mode="inline-complex">
    <div class="inline-complex inline-complex--simple">
      <xsl:choose>
        <xsl:when test="restriction">
          <xsl:apply-templates select="restriction" mode="derivation" />
        </xsl:when>
        <xsl:when test="list">
          <div>
            <span class="kw-label kw-label--list">list</span>
            <xsl:value-of select="x:t('component.ofConnector')" />
            <xsl:text> </xsl:text>
            <xsl:choose>
              <xsl:when test="list/@itemType">
                <xsl:copy-of select="x:component-link(x:resolve(list/@itemType), 'type', list)" />
              </xsl:when>
              <xsl:when test="list/simpleType">
                <xsl:apply-templates select="list/simpleType" mode="inline-complex" />
              </xsl:when>
            </xsl:choose>
          </div>
        </xsl:when>
        <xsl:when test="child::union">
          <xsl:variable name="union-el" as="element()" select="child::union" />
          <div>
            <span class="kw-label kw-label--union">union</span>
            <xsl:value-of select="x:t('component.ofConnector')" />
            <xsl:text> </xsl:text>
            <xsl:if test="$union-el/@memberTypes">
              <xsl:for-each select="tokenize(normalize-space($union-el/@memberTypes), '\s+')">
                <xsl:if test="position() gt 1">
                  <xsl:text>, </xsl:text>
                </xsl:if>
                <xsl:copy-of
                  select="x:component-link(
                  x:resolve-qname(., $union-el),
                  'type',
                  $union-el
                )" />
              </xsl:for-each>
            </xsl:if>
            <xsl:for-each select="$union-el/simpleType">
              <xsl:if test="position() gt 1 or ../@memberTypes">
                <xsl:text>, </xsl:text>
              </xsl:if>
              <span class="inline-marker">
                <xsl:value-of select="x:t('component.anonymous')" />
              </span>
              <xsl:apply-templates select="." mode="inline-complex" />
            </xsl:for-each>
          </div>
        </xsl:when>
      </xsl:choose>
    </div>
  </xsl:template>

  <!-- ====== Facets (simpleType restriction children) ====== -->

  <xsl:template name="render-facets">
    <xsl:variable
      name="facet-children"
      as="element()*"
      select="
      *[not(self::sequence|self::choice|self::all|self::group
            |self::attribute|self::attributeGroup|self::anyAttribute
            |self::annotation|self::assert|self::openContent
            |self::simpleType)]
    " />
    <xsl:variable name="is-notation" select="x:is-notation-st(parent::simpleType)" />
    <xsl:if test="exists($facet-children)">
      <table class="facets">
        <caption class="table-caption-sr">
          <xsl:value-of select="x:t('facets.caption')" />
        </caption>
        <thead>
          <tr>
            <th scope="col">
              <xsl:value-of select="x:t('facets.col.facet')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('facets.col.value')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('facets.col.fixed')" />
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:for-each select="$facet-children">
            <tr class="facets__row facets__row--{local-name()}">
              <td>
                <xsl:variable
                  name="href"
                  as="xs:string"
                  select="
                  if (namespace-uri() eq $xs-ns) then x:facet-href(local-name()) else ''
                " />
                <xsl:choose>
                  <xsl:when test="$href ne ''">
                    <a class="ref ref--builtin" href="{$href}" rel="external noopener noreferrer" target="_blank">
                      <code>
                        <xsl:value-of select="local-name()" />
                      </code>
                    </a>
                  </xsl:when>
                  <xsl:otherwise>
                    <code>
                      <xsl:value-of select="local-name()" />
                    </code>
                  </xsl:otherwise>
                </xsl:choose>
              </td>
              <td>
                <xsl:choose>
                  <xsl:when test="local-name() eq 'enumeration' and $is-notation">
                    <xsl:variable name="n-q" as="xs:QName?" select="x:resolve-qname(string(@value), .)" />
                    <xsl:copy-of select="x:component-link($n-q, 'notation', .)" />
                  </xsl:when>
                  <xsl:otherwise>
                    <code>
                      <bdi>
                        <xsl:value-of select="@value" />
                      </bdi>
                    </code>
                  </xsl:otherwise>
                </xsl:choose>
                <xsl:apply-templates select="annotation/(documentation|appinfo)" mode="doc" />
              </td>
              <td>
                <xsl:if test="x:xsd-true(@fixed)">
                  <span class="badge badge--fixed">fixed</span>
                </xsl:if>
              </td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </xsl:if>
  </xsl:template>

  <!-- ====== Attribute table ====== -->

  <xsl:template name="render-attribute-table">
    <xsl:variable
      name="own-attrs"
      as="element()*"
      select="
      (descendant::attribute[parent::*[
        self::complexType or self::attributeGroup
        or self::restriction or self::extension
      ]] union descendant::attributeGroup[@ref])
    " />
    <xsl:variable name="any-attr" as="element()*" select="descendant::anyAttribute" />
    <xsl:variable
      name="inherited"
      as="element()*"
      select="
      if (self::complexType) then x:inheritable-attrs(.) else ()
    " />

    <section class="component__attrs">
      <h4 class="component__sub-heading">
        <xsl:value-of select="x:t('attrs.heading')" />
      </h4>
      <table class="attrs">
        <caption class="table-caption-sr">
          <xsl:value-of select="x:t('attrs.caption')" />
        </caption>
        <thead>
          <tr>
            <th scope="col">
              <xsl:value-of select="x:t('attrs.col.name')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('attrs.col.type')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('attrs.col.use')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('attrs.col.default')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('attrs.col.inheritable')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('attrs.col.documentation')" />
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates select="$own-attrs" mode="attr-row" />
          <xsl:for-each select="$any-attr">
            <tr class="attrs__row attrs__row--any">
              <td colspan="6">
                <span class="model__particle-label">anyAttribute</span>
                <xsl:call-template name="emit-wildcard-attrs" />
              </td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
      <xsl:if test="exists($inherited)">
        <div class="component__attrs-inherited">
          <h5>
            <xsl:value-of select="x:t('attrs.inheritable.heading')" />
          </h5>
          <p>
            <xsl:call-template name="emit-i18n-with-codes">
              <xsl:with-param name="key" select="'attrs.inheritable.desc'" />
              <xsl:with-param
                name="codes"
                select="map {
                'inheritableCode': 'inheritable=&quot;true&quot;',
                'testCode': 'xs:alternative/@test'
              }" />
            </xsl:call-template>
          </p>
          <ul class="attrs-inherited__list">
            <xsl:for-each select="$inherited">
              <li>
                <code>@<xsl:value-of select="(@name, @ref)[1]" /></code>
                <xsl:if test="@type">
                  <span class="muted"> : </span>
                  <xsl:copy-of select="x:component-link(x:resolve(@type), 'simpleType', .)" />
                </xsl:if>
              </li>
            </xsl:for-each>
          </ul>
        </div>
      </xsl:if>
    </section>
  </xsl:template>

  <xsl:template match="attribute[@ref]" mode="attr-row">
    <tr class="attrs__row attrs__row--ref">
      <td>
        <xsl:copy-of select="x:component-link(x:resolve(@ref), 'attribute', .)" />
      </td>
      <td>
        <span class="muted">
          <xsl:value-of select="x:t('attrs.byReference')" />
        </span>
      </td>
      <td>
        <xsl:value-of select="(@use, 'optional')[1]" />
      </td>
      <td>
        <code>
          <bdi>
            <xsl:value-of select="@default" />
          </bdi>
        </code>
      </td>
      <td class="attrs__inheritable">
        <xsl:if test="x:xsd-true(@inheritable)">
          <xsl:value-of select="x:t('attrs.yes')" />
        </xsl:if>
      </td>
      <td>
        <xsl:apply-templates select="annotation/(documentation|appinfo)" mode="doc" />
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="attribute[@name]" mode="attr-row">
    <tr class="attrs__row">
      <td>
        <code>@<bdi>
          <xsl:value-of select="@name" />
        </bdi></code>
      </td>
      <td>
        <xsl:choose>
          <xsl:when test="@type">
            <xsl:copy-of select="x:component-link(x:resolve(@type), 'simpleType', .)" />
          </xsl:when>
          <xsl:when test="simpleType">
            <span class="inline-marker">
              <xsl:value-of select="x:t('component.anonymous')" />
            </span>
            <div class="attrs__inline-type">
              <xsl:apply-templates select="simpleType" mode="inline-complex" />
            </div>
          </xsl:when>
          <xsl:otherwise>
            <xsl:copy-of
              select="x:component-link(
              QName('http://www.w3.org/2001/XMLSchema', 'anySimpleType'),
              'simpleType',
              .
            )" />
          </xsl:otherwise>
        </xsl:choose>
      </td>
      <td>
        <xsl:value-of select="(@use, 'optional')[1]" />
      </td>
      <td>
        <xsl:choose>
          <xsl:when test="@fixed">
            <code>
              <bdi>
                <xsl:value-of select="@fixed" />
              </bdi>
            </code>
            <xsl:value-of select="x:t('attrs.fixedSuffix')" />
          </xsl:when>
          <xsl:when test="@default">
            <code>
              <bdi>
                <xsl:value-of select="@default" />
              </bdi>
            </code>
          </xsl:when>
        </xsl:choose>
      </td>
      <td class="attrs__inheritable">
        <xsl:if test="x:xsd-true(@inheritable)">
          <span class="badge badge--inheritable">
            <xsl:value-of select="x:t('attrs.yes')" />
          </span>
        </xsl:if>
      </td>
      <td>
        <xsl:apply-templates select="annotation/(documentation|appinfo)" mode="doc" />
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="attributeGroup[@ref]" mode="attr-row">
    <tr class="attrs__row attrs__row--group-ref">
      <td colspan="6">
        <span class="model__particle-label">attributeGroup</span>
        <xsl:copy-of select="x:component-link(x:resolve(@ref), 'attributeGroup', .)" />
      </td>
    </tr>
  </xsl:template>

  <!-- ====== Identity constraints ====== -->

  <xsl:template name="render-identity-constraints">
    <section class="component__identity-constraints">
      <h4 class="component__sub-heading">
        <xsl:value-of select="x:t('identity.heading')" />
      </h4>
      <table class="identity-constraints">
        <caption class="table-caption-sr">
          <xsl:value-of select="x:t('identity.caption')" />
        </caption>
        <thead>
          <tr>
            <th scope="col">
              <xsl:value-of select="x:t('identity.col.kind')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('identity.col.name')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('identity.col.selector')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('identity.col.fields')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('identity.col.refersTo')" />
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:for-each select="key | unique | keyref">
            <tr id="{x:anchor-for-ic(.)}" class="identity-constraints__row identity-constraints__row--{local-name()}">
              <td>
                <span class="badge badge--ic badge--ic-{local-name()}">
                  <xsl:value-of select="local-name()" />
                </span>
              </td>
              <td>
                <code>
                  <xsl:value-of select="@name" />
                </code>
              </td>
              <td>
                <code>
                  <xsl:value-of select="selector/@xpath" />
                </code>
              </td>
              <td>
                <ul class="identity-constraints__fields">
                  <xsl:for-each select="field">
                    <li>
                      <code>
                        <xsl:value-of select="@xpath" />
                      </code>
                    </li>
                  </xsl:for-each>
                </ul>
              </td>
              <td>
                <xsl:if test="self::keyref and @refer">
                  <xsl:variable name="refer-q" as="xs:QName?" select="x:resolve(@refer)" />
                  <xsl:variable
                    name="refer-ic"
                    as="element()?"
                    select="key('identityConstraintByQName', x:clark($refer-q))[1]" />
                  <xsl:choose>
                    <xsl:when test="exists($refer-ic)">
                      <a href="#{x:anchor-for-ic($refer-ic)}">
                        <code>
                          <xsl:value-of select="@refer" />
                        </code>
                      </a>
                    </xsl:when>
                    <xsl:otherwise>
                      <code class="ref ref--external" title="{x:t('identity.refNotFound')}">
                        <xsl:value-of select="@refer" />
                      </code>
                      <span class="sr-only">
                        <xsl:value-of select="x:t('identity.refNotFoundSr')" />
                      </span>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:if>
              </td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </section>
  </xsl:template>

  <!-- ====== Type alternatives (CTA, XSD 1.1) ====== -->

  <xsl:template name="render-type-alternatives">
    <section class="component__type-alternatives">
      <h4 class="component__sub-heading">
        <xsl:value-of select="x:t('typeAlt.heading')" />
      </h4>
      <p>
        <xsl:call-template name="emit-i18n-with-codes">
          <xsl:with-param name="key" select="'typeAlt.desc'" />
          <xsl:with-param name="codes" select="map { 'altCode': 'xs:alternative/@test' }" />
        </xsl:call-template>
      </p>
      <table class="type-alternatives">
        <caption class="table-caption-sr">
          <xsl:value-of select="x:t('typeAlt.caption')" />
        </caption>
        <thead>
          <tr>
            <th scope="col">
              <xsl:value-of select="x:t('typeAlt.col.when')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('typeAlt.col.type')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('typeAlt.col.documentation')" />
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:for-each select="alternative">
            <tr
              class="type-alternatives__row{
              if (@test) then ''
              else ' type-alternatives__row--default'
            }">
              <td>
                <xsl:choose>
                  <xsl:when test="@test">
                    <code>
                      <xsl:value-of select="@test" />
                    </code>
                  </xsl:when>
                  <xsl:otherwise>
                    <em>
                      <xsl:value-of select="x:t('typeAlt.otherwise')" />
                    </em>
                  </xsl:otherwise>
                </xsl:choose>
                <xsl:if test="@xpathDefaultNamespace">
                  <div class="muted">
                    <small>
                      <xsl:value-of select="x:t('typeAlt.xpathDefaultNs')" />
                      <xsl:text> </xsl:text>
                      <code>
                        <xsl:value-of select="@xpathDefaultNamespace" />
                      </code>
                    </small>
                  </div>
                </xsl:if>
              </td>
              <td>
                <xsl:choose>
                  <xsl:when test="@type">
                    <xsl:copy-of select="x:component-link(x:resolve(@type), 'type', .)" />
                  </xsl:when>
                  <xsl:when test="complexType | simpleType">
                    <span class="inline-marker">
                      <xsl:value-of select="x:t('component.anonymous')" />
                    </span>
                    <xsl:apply-templates select="complexType | simpleType" mode="inline-complex" />
                  </xsl:when>
                  <xsl:otherwise>
                    <code>xs:error</code>
                    <small class="muted">
                      <xsl:value-of select="x:t('typeAlt.noTypeNoTest')" />
                    </small>
                  </xsl:otherwise>
                </xsl:choose>
              </td>
              <td>
                <xsl:apply-templates select="annotation/(documentation|appinfo)" mode="doc" />
              </td>
            </tr>
          </xsl:for-each>
          <xsl:if test="@type and not(alternative[not(@test)])">
            <tr class="type-alternatives__row type-alternatives__row--default">
              <td>
                <em>
                  <xsl:value-of select="x:t('typeAlt.otherwise')" />
                </em>
              </td>
              <td>
                <xsl:copy-of select="x:component-link(x:resolve(@type), 'type', .)" />
              </td>
              <td>
                <span class="muted">
                  <xsl:value-of select="x:t('typeAlt.implicitFallbackPrefix')" />
                  <code>@type</code>
                </span>
              </td>
            </tr>
          </xsl:if>
        </tbody>
      </table>
      <!--
        Inheritable attributes for the CTA test context come from the
        enclosing complexType's ancestor chain (§3.4.4.3). Walk to the
        nearest enclosing complexType, then call x:inheritable-attrs.
      -->
      <xsl:variable name="enclosing-type" as="element()?" select="ancestor::complexType[1]" />
      <xsl:variable
        name="inherited"
        as="element()*"
        select="
        if (exists($enclosing-type)) then x:inheritable-attrs($enclosing-type) else ()
      " />
      <xsl:if test="exists($inherited)">
        <div class="type-alternatives__inherited">
          <h5>
            <xsl:value-of select="x:t('typeAlt.inheritedHeading')" />
          </h5>
          <p>
            <xsl:call-template name="emit-i18n-with-codes">
              <xsl:with-param name="key" select="'typeAlt.inheritedDesc'" />
              <xsl:with-param name="codes" select="map { 'testCode': '@test' }" />
            </xsl:call-template>
          </p>
          <ul>
            <xsl:for-each select="$inherited">
              <li>
                <code>@<xsl:value-of select="(@name, @ref)[1]" /></code>
                <xsl:if test="@type">
                  <span class="muted"> : </span>
                  <xsl:copy-of select="x:component-link(x:resolve(@type), 'simpleType', .)" />
                </xsl:if>
              </li>
            </xsl:for-each>
          </ul>
        </div>
      </xsl:if>
    </section>
  </xsl:template>

  <!-- ====== Assertions (XSD 1.1) ====== -->

  <xsl:template name="render-assertions">
    <section class="component__assertions">
      <h4 class="component__sub-heading">
        <xsl:value-of select="x:t('assertions.heading')" />
      </h4>
      <ul class="assertions">
        <xsl:for-each select=".//assert">
          <li class="assertions__item">
            <code class="assertions__test">
              <xsl:value-of select="x:t('assertions.testPrefix')" />
              <xsl:value-of select="@test" />
            </code>
            <xsl:if test="@xpathDefaultNamespace">
              <div class="muted">
                <small>
                  <xsl:value-of select="x:t('typeAlt.xpathDefaultNs')" />
                  <xsl:text> </xsl:text>
                  <code>
                    <xsl:value-of select="@xpathDefaultNamespace" />
                  </code>
                </small>
              </div>
            </xsl:if>
            <xsl:apply-templates select="annotation/(documentation|appinfo)" mode="doc" />
          </li>
        </xsl:for-each>
      </ul>
    </section>
  </xsl:template>

  <!-- ====== Open content (XSD 1.1) ====== -->

  <xsl:template match="openContent | defaultOpenContent" mode="open-content">
    <div class="open-content">
      <p>
        <span class="badge badge--open-content badge--open-content--{(@mode, 'interleave')[1]}">
          <xsl:value-of select="x:t('openCnt.modePrefix')" />
          <xsl:value-of select="(@mode, 'interleave')[1]" />
        </span>
        <xsl:if test="self::defaultOpenContent and @appliesToEmpty">
          <span class="muted">
            (appliesToEmpty=<code>
            <xsl:value-of select="@appliesToEmpty" />
          </code>)
          </span>
        </xsl:if>
      </p>
      <xsl:apply-templates select="any" mode="any-detail" />
    </div>
  </xsl:template>

  <xsl:template match="any" mode="any-detail">
    <dl class="open-content__wildcard">
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('openCnt.namespace')" />
        <xsl:with-param name="value" select="@namespace/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('openCnt.notNamespace')" />
        <xsl:with-param name="value" select="@notNamespace/string()" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
      <xsl:if test="@notQName">
        <dt>
          <xsl:value-of select="x:t('openCnt.notQName')" />
        </dt>
        <dd>
          <xsl:copy-of select="x:format-notQName(string(@notQName), 'element', .)" />
        </dd>
      </xsl:if>
      <xsl:call-template name="meta-row">
        <xsl:with-param name="label" select="x:t('openCnt.processContents')" />
        <xsl:with-param name="value" select="(@processContents, 'strict')[1]" />
        <xsl:with-param name="code" select="true()" />
      </xsl:call-template>
    </dl>
  </xsl:template>

  <!-- ====== Wildcard attrs (xs:any / xs:anyAttribute) inline ====== -->

  <xsl:template name="emit-wildcard-attrs">
    <xsl:text> </xsl:text>
    <span class="wildcard">
      <xsl:variable name="parts" as="element()*">
        <xsl:if test="@namespace">
          <part>
            <code>ns=<xsl:value-of select="@namespace" /></code>
          </part>
        </xsl:if>
        <xsl:if test="@notNamespace">
          <part>
            <code>!ns=<xsl:value-of select="@notNamespace" /></code>
          </part>
        </xsl:if>
        <xsl:if test="@notQName">
          <part>
            <code>!q=</code>
            <xsl:text> </xsl:text>
            <xsl:copy-of
              select="
              x:format-notQName(
                string(@notQName),
                if (self::any) then 'element' else 'attribute',
                .
              )
            " />
          </part>
        </xsl:if>
        <xsl:if test="@processContents">
          <part>
            <code>pc=<xsl:value-of select="@processContents" /></code>
          </part>
        </xsl:if>
      </xsl:variable>
      <xsl:for-each select="$parts">
        <xsl:if test="position() gt 1">
          <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:copy-of select="node()" />
      </xsl:for-each>
    </span>
  </xsl:template>

  <!-- ====== Occurrence marker (?, *, +, [m..n]) ====== -->

  <xsl:template name="emit-occurs">
    <xsl:variable name="marker" select="x:occurs(.)" />
    <xsl:if test="$marker ne ''">
      <xsl:variable name="long" as="xs:string" select="x:occurs-title(.)" />
      <span class="occurs" title="{$long}" role="img" aria-label="{$long}">
        <xsl:value-of select="$marker" />
      </span>
    </xsl:if>
  </xsl:template>

  <!-- ====== Derivation chain (ancestors / descendants) ====== -->

  <xsl:template name="render-derivation-chain">
    <xsl:variable name="ancestors" as="element()*" select="x:type-ancestors(., ())" />
    <xsl:variable
      name="qname-clark"
      as="xs:string?"
      select="
      if (@name) then x:clark(x:component-qname(.)) else ()
    " />
    <xsl:variable
      name="descendants"
      as="element()*"
      select="
      if (exists($qname-clark)) then
        for $s in $schemas,
            $u in key('typeUsersByBase', $qname-clark, $s)
        return x:owner-type($u)
      else ()
    " />
    <xsl:if test="exists($ancestors) or exists($descendants)">
      <xsl:variable name="self" as="element()" select="." />
      <xsl:variable name="named-descendants" as="element()*" select="$descendants[@name]" />
      <!-- $ancestors comes back closest-first; reverse so the root is rendered first. -->
      <xsl:variable name="ancestors-root-first" as="element()*" select="reverse($ancestors)" />
      <section class="component__derivation-chain">
        <h4 class="component__sub-heading">
          <xsl:value-of select="x:t('hierarchy.heading')" />
        </h4>
        <ul class="hierarchy hierarchy--tree">
          <xsl:call-template name="render-hierarchy-tree">
            <xsl:with-param name="ancestors" select="$ancestors-root-first" />
            <xsl:with-param name="self" select="$self" />
            <xsl:with-param name="descendants" select="$named-descendants" />
          </xsl:call-template>
        </ul>
      </section>
    </xsl:if>
  </xsl:template>

  <!--
    Emit a nested <li> chain: root ancestor wraps the next ancestor, …, which
    wraps the current type, which in turn wraps its direct descendants. When
    $ancestors is empty the current type is the root of the rendered tree.
  -->
  <xsl:template name="render-hierarchy-tree">
    <xsl:param name="ancestors" as="element()*" />
    <xsl:param name="self" as="element()" />
    <xsl:param name="descendants" as="element()*" />
    <xsl:choose>
      <xsl:when test="empty($ancestors)">
        <li class="hierarchy__node hierarchy__node--self" aria-current="location">
          <code>
            <xsl:value-of select="$self/@name" />
          </code>
          <span class="hierarchy__self-marker">
            <xsl:value-of select="x:t('hierarchy.thisType')" />
          </span>
          <xsl:if test="exists($descendants)">
            <ul class="hierarchy__children">
              <xsl:for-each select="$descendants">
                <xsl:sort select="@name" />
                <li class="hierarchy__node hierarchy__node--descendant">
                  <a href="#{x:anchor-for(.)}">
                    <code>
                      <xsl:value-of select="@name" />
                    </code>
                  </a>
                </li>
              </xsl:for-each>
            </ul>
          </xsl:if>
        </li>
      </xsl:when>
      <xsl:otherwise>
        <li class="hierarchy__node hierarchy__node--ancestor">
          <a href="#{x:anchor-for($ancestors[1])}">
            <code>
              <xsl:value-of select="$ancestors[1]/@name" />
            </code>
          </a>
          <ul class="hierarchy__children">
            <xsl:call-template name="render-hierarchy-tree">
              <xsl:with-param name="ancestors" select="tail($ancestors)" />
              <xsl:with-param name="self" select="$self" />
              <xsl:with-param name="descendants" select="$descendants" />
            </xsl:call-template>
          </ul>
        </li>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Recursive ancestor-walk via @base. Cycle guard via $visited set. -->
  <xsl:function name="x:type-ancestors" as="element()*">
    <xsl:param name="type" as="element()?" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:choose>
      <xsl:when test="empty($type) or count($visited) ge 32">
        <xsl:sequence select="()" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable
          name="here"
          select="
          if ($type/@name) then x:clark(x:component-qname($type)) else ''
        " />
        <xsl:choose>
          <xsl:when test="$here = $visited">
            <xsl:sequence select="()" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable
              name="base-q"
              as="xs:QName?"
              select="
              x:resolve(
                $type/(complexContent | simpleContent)/(extension | restriction)/@base
                | $type/restriction/@base
              )
            " />
            <xsl:choose>
              <xsl:when test="empty($base-q) or x:is-xs($base-q)">
                <xsl:sequence select="()" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:variable
                  name="base"
                  as="element()?"
                  select="
                  x:find-component(
                    string(namespace-uri-from-QName($base-q)),
                    local-name-from-QName($base-q),
                    'type',
                    $type
                  )
                " />
                <xsl:sequence
                  select="
                  ($base,
                   x:type-ancestors($base, ($visited, $here)))[exists(.)]
                " />
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- ====== vc:* controls panel ====== -->

  <xsl:template name="render-vc-controls">
    <xsl:variable name="all-vc-attrs" as="attribute()*" select="
      .//@*[namespace-uri() eq $vc-ns]
    " />
    <section class="component__vc-controls">
      <h4 class="component__sub-heading">
        <xsl:value-of select="x:t('vc.heading')" />
      </h4>
      <p class="component__vc-controls-note">
        <xsl:call-template name="emit-i18n-with-codes">
          <xsl:with-param name="key" select="'vc.note'" />
          <xsl:with-param name="codes" select="map { 'vcCode': 'vc:*' }" />
        </xsl:call-template>
      </p>
      <table class="vc-controls">
        <caption class="table-caption-sr">
          <xsl:value-of select="x:t('vc.caption')" />
        </caption>
        <thead>
          <tr>
            <th scope="col">
              <xsl:value-of select="x:t('vc.col.onElement')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('vc.col.attribute')" />
            </th>
            <th scope="col">
              <xsl:value-of select="x:t('vc.col.value')" />
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:for-each select="$all-vc-attrs">
            <xsl:sort select="local-name(..)" />
            <xsl:sort select="local-name(.)" />
            <tr>
              <td>
                <code>xs:<xsl:value-of select="local-name(..)" /></code>
              </td>
              <td>
                <code>vc:<xsl:value-of select="local-name()" /></code>
              </td>
              <td>
                <code>
                  <xsl:value-of select="." />
                </code>
              </td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </section>
  </xsl:template>

  <!-- ====== See-also: derived types, substitution group members, IC refs ====== -->

  <xsl:template name="render-see-also">
    <xsl:variable name="qname" as="xs:QName?" select="
      if (@name) then x:component-qname(.) else ()
    " />
    <xsl:variable name="clark" as="xs:string?" select="
      if (exists($qname)) then x:clark($qname) else ()
    " />
    <xsl:variable
      name="users-by-type"
      as="element()*"
      select="
      if (exists($clark) and (self::complexType or self::simpleType)) then
        for $s in $schemas return key('typeUsersByType', $clark, $s)
      else ()
    " />
    <xsl:variable
      name="subst-members"
      as="element()*"
      select="
      if (exists($clark) and self::element) then
        for $s in $schemas return key('substitutionMembers', $clark, $s)
      else ()
    " />
    <xsl:variable
      name="keyref-targets"
      as="element()*"
      select="
      if (exists($clark) and self::element) then
        for $kr in $schemas//keyref[@refer]
        return (if (x:clark(x:resolve($kr/@refer))
                    = (for $ic in $schemas//(key | unique)[ancestor::element[1] is current()]
                         return x:clark(QName(x:tns($ic/ancestor::schema[1]), string($ic/@name)))))
                then $kr else ())
      else ()
    " />
    <xsl:if
      test="exists($users-by-type)
                  or exists($subst-members)
                  or exists($keyref-targets)">
      <section class="component__see-also">
        <h4 class="component__sub-heading">
          <xsl:value-of select="x:t('seeAlso.heading')" />
        </h4>
        <xsl:if test="exists($users-by-type)">
          <div class="see-also__group">
            <h5>
              <xsl:value-of select="x:t('seeAlso.usedAsTypeBy')" />
            </h5>
            <ul>
              <xsl:for-each select="$users-by-type">
                <xsl:variable name="owner" as="element()?" select="x:owner-component(.)" />
                <xsl:if test="exists($owner) and $owner/@name">
                  <li>
                    <a href="#{x:anchor-for($owner)}">
                      <code>
                        <xsl:value-of select="$owner/@name" />
                      </code>
                    </a>
                    <xsl:if test="not($owner is .)">
                      <span class="muted">
                        <xsl:value-of select="x:t('seeAlso.as')" />
                        <xsl:value-of select="local-name()" />
                        <xsl:if test="@name">
                          <xsl:text> </xsl:text>
                          <code>
                            <xsl:value-of select="@name" />
                          </code>
                        </xsl:if>
                        <xsl:if test="@ref">
                          <xsl:value-of select="x:t('seeAlso.ref')" />
                          <code>
                            <xsl:value-of select="@ref" />
                          </code>
                        </xsl:if>
                      </span>
                    </xsl:if>
                  </li>
                </xsl:if>
              </xsl:for-each>
            </ul>
          </div>
        </xsl:if>
        <xsl:if test="exists($subst-members)">
          <div class="see-also__group">
            <h5>
              <xsl:value-of select="x:t('seeAlso.substitutionMembers')" />
            </h5>
            <ul>
              <xsl:for-each select="$subst-members">
                <li>
                  <a href="#{x:anchor-for(.)}">
                    <code>
                      <xsl:value-of select="@name" />
                    </code>
                  </a>
                </li>
              </xsl:for-each>
            </ul>
          </div>
        </xsl:if>
      </section>
    </xsl:if>
  </xsl:template>

  <!-- ===== Region 14. Documentation renderer ===== -->

  <xsl:variable
    name="doc-allowed-elements"
    as="xs:string+"
    select="(
    'p','div','span','br','hr',
    'em','strong','i','b','u','s','sub','sup',
    'code','kbd','samp','var','pre',
    'a','abbr','cite','q','blockquote',
    'ul','ol','li','dl','dt','dd',
    'table','thead','tbody','tfoot','tr','th','td','caption','colgroup','col',
    'h1','h2','h3','h4','h5','h6',
    'figure','figcaption'
  )" />

  <xsl:variable
    name="doc-allowed-attrs"
    as="xs:string+"
    select="(
    'class','title','lang','id','dir',
    'colspan','rowspan','scope','headers',
    'datetime','start','reversed','value'
  )" />

  <xsl:template match="annotation/documentation" mode="doc">
    <xsl:variable name="has-children" select="exists(*)" />
    <xsl:variable name="raw" select="string(.)" as="xs:string" />
    <xsl:variable
      name="trimmed-text"
      as="xs:string"
      select="
      replace(replace($raw, '^[ \t\r\n]+', ''), '[ \t\r\n]+$', '')
    " />
    <xsl:if test="$has-children or $trimmed-text ne '' or @source">
      <div class="component__doc" lang="{(@xml:lang/string(), $xml-lang)[. ne ''][1]}">
        <xsl:if test="@xml:lang">
          <span
            class="component__doc-lang"
            title="{x:t('doc.langTitle', map { 'lang': string(@xml:lang) })}"
            role="img"
            aria-label="{x:t('doc.langLabel', map { 'lang': string(@xml:lang) })}">
            <xsl:value-of select="@xml:lang" />
          </span>
        </xsl:if>
        <xsl:choose>
          <xsl:when test="$has-children and $doc-html eq 'permissive'">
            <xsl:apply-templates select="node()" mode="doc-permissive" />
          </xsl:when>
          <xsl:when test="$has-children">
            <div dir="auto">
              <xsl:apply-templates select="node()" mode="doc-safe" />
            </div>
          </xsl:when>
          <xsl:when test="$trimmed-text ne ''">
            <p>
              <bdi>
                <xsl:call-template name="emit-with-line-breaks">
                  <xsl:with-param name="text" select="$trimmed-text" />
                </xsl:call-template>
              </bdi>
            </p>
          </xsl:when>
        </xsl:choose>
        <xsl:if test="@source">
          <a
            class="component__doc-source"
            href="{@source}"
            rel="external noopener noreferrer"
            target="_blank">↗&#160;<xsl:value-of select="x:t('doc.sourceLink')" /></a>
        </xsl:if>
      </div>
    </xsl:if>
  </xsl:template>

  <xsl:template match="annotation/appinfo" mode="doc">
    <details class="component__appinfo">
      <summary>
        <span class="badge badge--appinfo">appinfo</span>
        <xsl:if test="@source">
          <code>
            <xsl:value-of select="@source" />
          </code>
        </xsl:if>
      </summary>
      <pre class="xsd-source">
        <xsl:apply-templates select="node()" mode="xsd-source" />
      </pre>
    </details>
  </xsl:template>

  <xsl:template name="emit-with-line-breaks">
    <xsl:param name="text" as="xs:string" />
    <xsl:variable name="lines" select="tokenize($text, '&#10;')" />
    <xsl:for-each select="$lines">
      <xsl:if test="position() gt 1">
        <br />
      </xsl:if>
      <xsl:value-of select="." />
    </xsl:for-each>
  </xsl:template>

  <!-- Safe mode: allowlist of elements/attrs; reject unsafe schemes. -->
  <xsl:template match="*" mode="doc-safe">
    <xsl:choose>
      <xsl:when test="lower-case(local-name()) = $doc-allowed-elements">
        <xsl:variable name="tag" select="lower-case(local-name())" as="xs:string" />
        <xsl:element name="{$tag}" namespace="">
          <xsl:for-each select="@*">
            <xsl:variable name="aname" select="lower-case(local-name())" as="xs:string" />
            <xsl:choose>
              <xsl:when test="$aname eq 'href' and $tag eq 'a'">
                <xsl:variable name="safe" select="x:safe-href(string(.))" as="xs:string?" />
                <xsl:if test="exists($safe)">
                  <xsl:attribute name="href" select="$safe" />
                  <xsl:attribute name="rel" select="'noopener noreferrer'" />
                </xsl:if>
              </xsl:when>
              <xsl:when test="$aname = $doc-allowed-attrs">
                <xsl:attribute name="{$aname}">
                  <xsl:value-of select="." />
                </xsl:attribute>
              </xsl:when>
            </xsl:choose>
          </xsl:for-each>
          <xsl:apply-templates select="node()" mode="doc-safe" />
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="node()" mode="doc-safe" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="text()" mode="doc-safe">
    <xsl:if test="normalize-space(.) ne ''">
      <xsl:call-template name="emit-with-line-breaks">
        <xsl:with-param name="text" select="string(.)" />
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Permissive mode: copy element + attrs verbatim. Unsafe; opt-in. -->
  <xsl:template match="*" mode="doc-permissive">
    <xsl:element name="{local-name()}" namespace="">
      <xsl:for-each select="@*">
        <xsl:attribute name="{local-name()}">
          <xsl:value-of select="." />
        </xsl:attribute>
      </xsl:for-each>
      <xsl:apply-templates select="node()" mode="doc-permissive" />
    </xsl:element>
  </xsl:template>

  <xsl:template match="text()" mode="doc-permissive">
    <xsl:if test="normalize-space(.) ne ''">
      <xsl:call-template name="emit-with-line-breaks">
        <xsl:with-param name="text" select="string(.)" />
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- ===== Region 15. XSD source pretty-printer ===== -->

  <!--
    Render an XSD element as syntax-highlighted source, with namespace
    declarations only on the root element (to keep the per-component
    pretty-print compact) and indentation by depth. The mode walks
    everything reachable from the call site; outer "section" mode
    dispatches into it only via xsl:apply-templates select="."
    mode="xsd-source" inside a <pre> wrapper.
  -->

  <xsl:template match="*" mode="xsd-source">
    <xsl:param name="depth" select="0" tunnel="yes" />
    <xsl:param name="emit-ns" select="true()" tunnel="yes" />
    <xsl:variable name="indent" select="x:xsd-indent($depth)" />
    <xsl:variable name="local" select="local-name()" />
    <xsl:variable
      name="prefix"
      select="if (namespace-uri() eq $xs-ns) then 'xs' else
      (for $p in in-scope-prefixes(.)
       return if (namespace-uri-for-prefix($p, .) eq namespace-uri()) then $p else ()
      )[1]" />
    <xsl:variable
      name="qname-display"
      select="
      if ($prefix ne '' and $prefix) then concat($prefix, ':', $local) else $local
    " />
    <xsl:value-of select="$indent" />
    <xsl:text>&lt;</xsl:text>
    <span class="xml-tag">
      <xsl:value-of select="$qname-display" />
    </span>
    <xsl:if test="$emit-ns">
      <xsl:variable name="src" as="element()" select="." />
      <xsl:for-each
        select="
        in-scope-prefixes($src)[
          not(. = ('xml'))
          and namespace-uri-for-prefix(., $src) ne ''
          and namespace-uri-for-prefix(., $src) ne $xs-ns
        ]
      ">
        <xsl:text> </xsl:text>
        <span class="xml-attr">xmlns<xsl:if test=". ne ''">:<xsl:value-of select="." /></xsl:if></span>
        <span class="xml-eq">=</span>
        <span class="xml-str">"<xsl:value-of select="namespace-uri-for-prefix(., $src)" />"</span>
      </xsl:for-each>
    </xsl:if>
    <xsl:for-each select="@*">
      <xsl:text> </xsl:text>
      <span class="xml-attr">
        <xsl:variable
          name="a-prefix"
          select="
          if (namespace-uri() eq '') then ''
          else (for $p in in-scope-prefixes(..)
                return if (namespace-uri-for-prefix($p, ..) eq namespace-uri())
                       then $p else ())[1]
        " />
        <xsl:if test="$a-prefix and $a-prefix ne ''">
          <xsl:value-of select="$a-prefix" />:</xsl:if>
        <xsl:value-of select="local-name()" />
      </span>
      <span class="xml-eq">=</span>
      <span class="xml-str">"<xsl:value-of select="." />"</span>
    </xsl:for-each>
    <xsl:choose>
      <xsl:when test="empty(node())">
        <xsl:text>/&gt;
</xsl:text>
      </xsl:when>
      <xsl:when test="empty(*) and not(matches(string(.), '\n'))">
        <xsl:text>&gt;</xsl:text>
        <xsl:value-of select="string(.)" />
        <xsl:text>&lt;/</xsl:text>
        <span class="xml-tag">
          <xsl:value-of select="$qname-display" />
        </span>
        <xsl:text>&gt;
</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>&gt;
</xsl:text>
        <xsl:apply-templates select="node()" mode="xsd-source">
          <xsl:with-param name="depth" select="$depth + 1" tunnel="yes" />
          <xsl:with-param name="emit-ns" select="false()" tunnel="yes" />
        </xsl:apply-templates>
        <xsl:value-of select="$indent" />
        <xsl:text>&lt;/</xsl:text>
        <span class="xml-tag">
          <xsl:value-of select="$qname-display" />
        </span>
        <xsl:text>&gt;
</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="text()" mode="xsd-source">
    <xsl:param name="depth" select="0" tunnel="yes" />
    <xsl:if test="normalize-space(.) ne ''">
      <xsl:value-of select="x:xsd-indent($depth)" />
      <xsl:value-of select="." />
      <xsl:text>
</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="comment()" mode="xsd-source">
    <xsl:param name="depth" select="0" tunnel="yes" />
    <xsl:value-of select="x:xsd-indent($depth)" />
    <span class="xml-comment">&lt;!-- <xsl:value-of select="." /> --&gt;</span>
    <xsl:text>
</xsl:text>
  </xsl:template>

  <xsl:function name="x:xsd-indent" as="xs:string">
    <xsl:param name="depth" as="xs:integer" />
    <xsl:sequence select="string-join(for $i in 1 to $depth return '  ', '')" />
  </xsl:function>
</xsl:stylesheet>
