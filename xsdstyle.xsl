<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:vc="http://www.w3.org/2007/XMLSchema-versioning"
  xmlns:html="http://www.w3.org/1999/xhtml"
  xmlns:f="urn:xsdoc:functions"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="#all"
  expand-text="yes">
  <xsl:output method="html" html-version="5" encoding="UTF-8" indent="yes" />

  <xsl:param name="page-title" as="xs:string?" select="()" />
  <xsl:param name="asset-base-uri" as="xs:string" select="'./assets/'" />
  <xsl:param name="show-source" as="xs:boolean" select="true()" />
  <xsl:param name="documentation-markup" as="xs:string" select="'safe'" />
  <xsl:param name="interface-language" as="xs:string" select="'en'" />
  <xsl:param name="documentation-language" as="xs:string" select="'en'" />
  <xsl:param name="interface-direction" as="xs:string" select="'auto'" />
  <xsl:param name="robots-noindex" as="xs:boolean" select="false()" />

  <xsl:mode on-no-match="shallow-skip" />
  <xsl:mode name="doc" on-no-match="text-only-copy" />
  <xsl:mode name="source" on-no-match="shallow-skip" />
  <xsl:mode name="particle" on-no-match="shallow-skip" />

  <xsl:variable name="version" as="xs:string" select="'v0.1.0-dev'" />
  <xsl:variable name="xsd-ns" as="xs:string" select="'http://www.w3.org/2001/XMLSchema'" />
  <xsl:variable name="vc-ns" as="xs:string" select="'http://www.w3.org/2007/XMLSchema-versioning'" />
  <xsl:variable
    name="kind-order"
    as="xs:string*"
    select="('element', 'complexType', 'simpleType', 'attribute', 'attributeGroup', 'group', 'notation')" />
  <xsl:variable
    name="rtl-languages"
    as="xs:string*"
    select="('ar', 'he', 'fa', 'ur', 'ps', 'yi', 'dv', 'ug', 'ckb', 'sd', 'arc')" />
  <xsl:variable
    name="builtin-types"
    as="xs:string*"
    select="
    ('anyType', 'anySimpleType', 'anyAtomicType', 'string', 'boolean', 'decimal',
     'float', 'double', 'duration', 'dateTime', 'time', 'date', 'gYearMonth',
     'gYear', 'gMonthDay', 'gDay', 'gMonth', 'hexBinary', 'base64Binary',
     'anyURI', 'QName', 'NOTATION', 'normalizedString', 'token', 'language',
     'NMTOKEN', 'NMTOKENS', 'Name', 'NCName', 'ID', 'IDREF', 'IDREFS', 'ENTITY',
     'ENTITIES', 'integer', 'nonPositiveInteger', 'negativeInteger', 'long',
     'int', 'short', 'byte', 'nonNegativeInteger', 'unsignedLong',
     'unsignedInt', 'unsignedShort', 'unsignedByte', 'positiveInteger',
     'yearMonthDuration', 'dayTimeDuration', 'dateTimeStamp')" />
  <xsl:variable
    name="xsd11-builtins"
    as="xs:string*"
    select="('yearMonthDuration', 'dayTimeDuration', 'dateTimeStamp')" />
  <!--
    Fundamental facets (ordered / bounded / cardinality / numeric) of the
    built-in datatypes, per XSD 1.1 Part 2 Appendix F. Values keep the
    specification vocabulary; "finite" and "countably infinite" are values of
    the cardinality facet, not facets themselves. The special types anyType,
    anySimpleType, and anyAtomicType have no fundamental facets and are
    deliberately absent.
  -->
  <xsl:variable
    name="fundamental-facets"
    as="map(xs:string, map(xs:string, xs:string))"
    select="
    map:merge((
      for $n in ('string', 'hexBinary', 'base64Binary', 'anyURI', 'QName', 'NOTATION',
                 'normalizedString', 'token', 'language', 'NMTOKEN', 'NMTOKENS', 'Name',
                 'NCName', 'ID', 'IDREF', 'IDREFS', 'ENTITY', 'ENTITIES')
        return map:entry($n,
          map { 'ordered': 'false', 'bounded': 'false', 'cardinality': 'countably infinite', 'numeric': 'false' }),
      map:entry('boolean',
        map { 'ordered': 'false', 'bounded': 'false', 'cardinality': 'finite', 'numeric': 'false' }),
      for $n in ('decimal', 'integer', 'nonPositiveInteger', 'negativeInteger',
                 'nonNegativeInteger', 'positiveInteger')
        return map:entry($n,
          map { 'ordered': 'total', 'bounded': 'false', 'cardinality': 'countably infinite', 'numeric': 'true' }),
      for $n in ('long', 'int', 'short', 'byte', 'unsignedLong', 'unsignedInt',
                 'unsignedShort', 'unsignedByte')
        return map:entry($n,
          map { 'ordered': 'total', 'bounded': 'true', 'cardinality': 'finite', 'numeric': 'true' }),
      for $n in ('float', 'double')
        return map:entry($n,
          map { 'ordered': 'partial', 'bounded': 'true', 'cardinality': 'finite', 'numeric': 'true' }),
      for $n in ('duration', 'dateTime', 'time', 'date', 'gYearMonth', 'gYear', 'gMonthDay',
                 'gDay', 'gMonth', 'yearMonthDuration', 'dayTimeDuration', 'dateTimeStamp')
        return map:entry($n,
          map { 'ordered': 'partial', 'bounded': 'false', 'cardinality': 'countably infinite', 'numeric': 'false' })
    ))" />
  <!--
    The complete XSD 1.0 + 1.1 element vocabulary. Any element in the XSD
    namespace whose local name is not in this list, appearing in a schema
    position, is reported as an unknown-element diagnostic.
  -->
  <xsl:variable
    name="xsd-elements"
    as="xs:string*"
    select="
    ('schema', 'include', 'import', 'redefine', 'override', 'annotation',
     'appinfo', 'documentation', 'element', 'attribute', 'complexType',
     'simpleType', 'complexContent', 'simpleContent', 'extension',
     'restriction', 'group', 'attributeGroup', 'sequence', 'choice', 'all',
     'any', 'anyAttribute', 'key', 'keyref', 'unique', 'selector', 'field',
     'notation', 'list', 'union', 'openContent', 'defaultOpenContent',
     'assert', 'assertion', 'alternative', 'length', 'minLength', 'maxLength',
     'pattern', 'enumeration', 'whiteSpace', 'maxInclusive', 'maxExclusive',
     'minInclusive', 'minExclusive', 'totalDigits', 'fractionDigits',
     'explicitTimezone')" />

  <!--
    Icon SVGs live as standalone files under assets/ (next to this stylesheet)
    and are read at transform time, so rendering needs assets/ico-*.svg
    alongside xsdstyle.xsl. Each icon's geometry is emitted once, as a
    <symbol> in a hidden sprite (f:icon-sprite); icon sites reference it via
    <use> (f:icon) so repeated icons don't duplicate path data. The use-site
    <svg> keeps the file's class/data-when/aria-hidden hooks and stays inline
    and currentColor-driven per docs/dom.md.
  -->
  <xsl:variable
    name="icon-names"
    as="xs:string*"
    select="
    ('ico-expand', 'ico-collapse', 'ico-theme-dark', 'ico-theme-light',
     'ico-search', 'ico-copy-link', 'ico-copy-check')" />

  <xsl:function name="f:icon-file" as="element()">
    <xsl:param name="name" as="xs:string" />
    <xsl:sequence select="doc(resolve-uri('assets/' || $name || '.svg', static-base-uri()))/*" />
  </xsl:function>

  <xsl:function name="f:icon" as="element()">
    <xsl:param name="name" as="xs:string" />
    <xsl:variable name="icon" select="f:icon-file($name)" />
    <svg xmlns="http://www.w3.org/2000/svg">
      <xsl:copy-of select="$icon/(@class, @data-when, @aria-hidden, @viewBox)" />
      <use href="#{$name}" />
    </svg>
  </xsl:function>

  <xsl:function name="f:icon-sprite" as="element()">
    <svg xmlns="http://www.w3.org/2000/svg" class="icon-sprite" aria-hidden="true">
      <xsl:for-each select="$icon-names">
        <xsl:variable name="icon" select="f:icon-file(.)" />
        <symbol id="{.}">
          <xsl:copy-of select="$icon/(@* except (@class, @data-when, @aria-hidden))" />
          <xsl:copy-of select="$icon/node()" />
        </symbol>
      </xsl:for-each>
    </svg>
  </xsl:function>

  <xsl:function name="f:tok-punct" as="element(span)">
    <xsl:param name="value" as="xs:string" />
    <span class="tok-punct">
      <xsl:value-of select="$value" />
    </span>
  </xsl:function>

  <!--
    UI message catalog. All generated chrome flows through f:t() so it can be
    localised. To add a locale, copy the 'en' block, change the outer key to a
    lowercase BCP-47 tag, and translate the values (leave the keys untouched).
    Schema-authored names, QNames, namespace URIs, XPath, regexes, facet
    values, and source code are never translated. The catalog is the single
    source for both server-rendered chrome and the small JSON block consumed by
    xsdstyle.js. Missing keys render as [[key]] so omissions stay visible.
  -->
  <xsl:variable name="i18n-messages" as="map(xs:string, map(xs:string, xs:string))">
    <xsl:map>
      <xsl:map-entry key="'en'">
        <xsl:map>
          <xsl:map-entry key="'a11y.skipToContent'" select="'Skip to main content'" />
          <xsl:map-entry key="'action.expandAll'" select="'Expand all'" />
          <xsl:map-entry key="'theme.toDark'" select="'Dark'" />
          <xsl:map-entry key="'theme.toLight'" select="'Light'" />
          <xsl:map-entry key="'theme.switch'" select="'Switch theme'" />
          <xsl:map-entry key="'nav.label'" select="'Components'" />
          <xsl:map-entry key="'nav.filter'" select="'Filter components'" />
          <xsl:map-entry key="'nav.clear'" select="'Clear'" />
          <xsl:map-entry key="'nav.clearLabel'" select="'Clear filter'" />
          <xsl:map-entry
            key="'nav.filterHint'"
            select="'Filter by component name, namespace, kind, or visible documentation.'" />
          <xsl:map-entry key="'nav.docMatch'" select="'documentation match'" />
          <xsl:map-entry key="'colophon.generated'" select="'Generated by'" />
          <xsl:map-entry key="'overview.eyebrow'" select="'Schema reference'" />
          <xsl:map-entry key="'overview.metadata'" select="'Schema metadata'" />
          <xsl:map-entry key="'overview.primaryUri'" select="'Primary document URI'" />
          <xsl:map-entry key="'overview.declaredNs'" select="'Declared target namespace'" />
          <xsl:map-entry key="'overview.annotation'" select="'Schema annotation'" />
          <xsl:map-entry key="'overview.defaults'" select="'Schema defaults'" />
          <xsl:map-entry key="'overview.features'" select="'Feature summary'" />
          <xsl:map-entry key="'overview.documents'" select="'Schema documents'" />
          <xsl:map-entry key="'ff.heading'" select="'Fundamental facets'" />
          <xsl:map-entry key="'ff.ordered'" select="'ordered'" />
          <xsl:map-entry key="'ff.bounded'" select="'bounded'" />
          <xsl:map-entry key="'ff.cardinality'" select="'cardinality'" />
          <xsl:map-entry key="'ff.numeric'" select="'numeric'" />
          <xsl:map-entry key="'schema.rel.primary'" select="'primary'" />
          <xsl:map-entry key="'schema.rel.reachable'" select="'reachable'" />
          <xsl:map-entry key="'schema.declared'" select="'declared:'" />
          <xsl:map-entry key="'schema.effective'" select="'effective:'" />
          <xsl:map-entry key="'schema.none'" select="'(none)'" />
          <xsl:map-entry key="'schema.in'" select="'in'" />
          <xsl:map-entry key="'schema.namespace'" select="'namespace:'" />
          <xsl:map-entry key="'schema.noSchemaLocation'" select="'(no schemaLocation)'" />
          <xsl:map-entry key="'schema.status.loaded'" select="'loaded'" />
          <xsl:map-entry key="'schema.status.notLoaded'" select="'not loaded'" />
          <xsl:map-entry key="'schema.status.notRequested'" select="'not requested'" />
          <xsl:map-entry key="'msg.noTargetNamespace'" select="'no target namespace'" />
          <xsl:map-entry key="'msg.anonymous'" select="'anonymous'" />
          <xsl:map-entry key="'msg.yes'" select="'yes'" />
          <xsl:map-entry key="'msg.no'" select="'no'" />
          <xsl:map-entry key="'seeAlso.as'" select="'as'" />
          <xsl:map-entry key="'seeAlso.in'" select="'in'" />
          <xsl:map-entry key="'versioning.on'" select="'on'" />
          <xsl:map-entry
            key="'versioning.note'"
            select="'Documentation shows the source annotations and does not apply conditional inclusion filtering by default.'" />
          <xsl:map-entry key="'diag.ctxParameter'" select="'Parameter'" />
          <xsl:map-entry key="'diag.ctxValue'" select="'value'" />
          <xsl:map-entry key="'diag.ctxNormalizedTo'" select="'normalized to'" />
          <xsl:map-entry key="'diag.ctxReferencedBy'" select="'referenced by'" />
          <xsl:map-entry key="'diag.ctxElement'" select="'Element'" />
          <xsl:map-entry key="'diag.ctxNotRecognized'" select="'is not a recognized XSD construct.'" />
          <xsl:map-entry
            key="'diag.ctxRefCycle'"
            select="'participates in a reference cycle and is not expanded inline.'" />
          <xsl:map-entry key="'diag.ctxAttribute'" select="'Attribute'" />
          <xsl:map-entry key="'diag.ctxHasValue'" select="'has value'" />
          <xsl:map-entry key="'value.default'" select="'default'" />
          <xsl:map-entry key="'value.fixed'" select="'fixed'" />
          <xsl:map-entry key="'wildcard.anyAttribute'" select="'anyAttribute'" />
          <xsl:map-entry key="'wildcard.processContents'" select="'processContents'" />
          <xsl:map-entry key="'typeAlt.implicitFallback'" select="'implicit fallback to @type'" />
          <xsl:map-entry
            key="'notice.permissiveMarkup'"
            select="'Documentation markup is rendered in permissive mode: schema-authored markup is copied verbatim, including executable content. Do not publish output generated from untrusted schemas.'" />
          <xsl:map-entry key="'field.targetNamespace'" select="'Target namespace'" />
          <xsl:map-entry key="'field.defaultAttributes'" select="'Default attributes'" />
          <xsl:map-entry key="'field.defaultAttributesApply'" select="'Default attributes apply'" />
          <xsl:map-entry key="'field.defaultOpenContent'" select="'Default open content'" />
          <xsl:map-entry key="'field.name'" select="'Name'" />
          <xsl:map-entry key="'field.documentation'" select="'Documentation'" />
          <xsl:map-entry key="'field.variety'" select="'Variety'" />
          <xsl:map-entry key="'variety.atomic'" select="'atomic'" />
          <xsl:map-entry key="'variety.list'" select="'list'" />
          <xsl:map-entry key="'variety.union'" select="'union'" />
          <xsl:map-entry key="'variety.unknown'" select="'not determinable (base not resolved)'" />
          <xsl:map-entry key="'variety.unspecified'" select="'not specified in source'" />
          <xsl:map-entry key="'field.derivedBy'" select="'Derived by'" />
          <xsl:map-entry key="'derivation.restriction'" select="'restriction'" />
          <xsl:map-entry key="'derivation.list'" select="'list'" />
          <xsl:map-entry key="'derivation.union'" select="'union'" />
          <xsl:map-entry key="'derivation.of'" select="'of'" />
          <xsl:map-entry key="'facet.patternOr'" select="'or'" />
          <xsl:map-entry key="'facet.patternStep'" select="'step {n} of {m}'" />
          <xsl:map-entry key="'attr.via'" select="'via'" />
          <xsl:map-entry key="'attr.noDeclaredType'" select="'no declared type'" />
          <xsl:map-entry key="'attr.groupExpandedBelow'" select="'attributes from this group are listed below'" />
          <xsl:map-entry
            key="'attr.expansionStoppedCycle'"
            select="'not expanded: recursive attribute-group reference'" />
          <xsl:map-entry
            key="'attr.expansionStoppedAmbiguous'"
            select="'not expanded: ambiguous attribute-group reference'" />
          <xsl:map-entry key="'wildcard.via.direct'" select="'via direct content'" />
          <xsl:map-entry key="'wildcard.via.open-content'" select="'via open content'" />
          <xsl:map-entry key="'wildcard.via.default-open-content'" select="'via default open content'" />
          <xsl:map-entry key="'wildcard.via.attribute-group'" select="'via attribute group'" />
          <xsl:map-entry key="'wildcard.tok.any'" select="'any namespace'" />
          <xsl:map-entry key="'wildcard.tok.other'" select="'any namespace other than the target namespace'" />
          <xsl:map-entry key="'wildcard.tok.local'" select="'no namespace'" />
          <xsl:map-entry key="'wildcard.tok.targetNamespace'" select="'the target namespace'" />
          <xsl:map-entry key="'wildcard.tok.defined'" select="'names of declarations defined in the schema'" />
          <xsl:map-entry
            key="'wildcard.tok.definedSibling'"
            select="'names of sibling declarations in the enclosing all group'" />
          <xsl:map-entry key="'wildcard.on.element'" select="'constraint on an element wildcard'" />
          <xsl:map-entry key="'wildcard.on.attribute'" select="'constraint on an attribute wildcard'" />
          <xsl:map-entry key="'contentType.empty'" select="'empty content (no child elements or text)'" />
          <xsl:map-entry key="'contentType.simple'" select="'simple content (text only, no child elements)'" />
          <xsl:map-entry key="'contentType.element-only'" select="'element-only content (child elements, no text)'" />
          <xsl:map-entry key="'contentType.mixed'" select="'mixed content (child elements and text)'" />
          <xsl:map-entry key="'contentType.open'" select="'open'" />
          <xsl:map-entry
            key="'xref.externalTitle'"
            select="'External reference: the namespace is known but no schema document for it is loaded.'" />
          <xsl:map-entry
            key="'xref.unresolvedTitle'"
            select="'Unresolved reference: no matching definition was found in the loaded schema collection.'" />
          <xsl:map-entry key="'field.baseType'" select="'Base type'" />
          <xsl:map-entry key="'field.itemType'" select="'Item type'" />
          <xsl:map-entry key="'field.memberTypes'" select="'Member types'" />
          <xsl:map-entry key="'field.public'" select="'Public'" />
          <xsl:map-entry key="'field.system'" select="'System'" />
          <xsl:map-entry key="'field.openContent'" select="'Open content'" />
          <xsl:map-entry key="'field.typeRef'" select="'Type/ref'" />
          <xsl:map-entry key="'field.use'" select="'Use'" />
          <xsl:map-entry key="'field.valueConstraint'" select="'Value constraint'" />
          <xsl:map-entry key="'field.inheritable'" select="'Inheritable'" />
          <xsl:map-entry key="'field.id'" select="'ID'" />
          <xsl:map-entry key="'field.kind'" select="'Kind'" />
          <xsl:map-entry key="'field.selector'" select="'Selector'" />
          <xsl:map-entry key="'field.fields'" select="'Fields'" />
          <xsl:map-entry key="'field.refer'" select="'Refer'" />
          <xsl:map-entry key="'field.when'" select="'When'" />
          <xsl:map-entry key="'field.type'" select="'Type'" />
          <xsl:map-entry key="'field.facet'" select="'Facet'" />
          <xsl:map-entry key="'field.value'" select="'Value'" />
          <xsl:map-entry key="'field.fixed'" select="'Fixed'" />
          <xsl:map-entry key="'field.test'" select="'Test'" />
          <xsl:map-entry key="'field.version'" select="'Version'" />
          <xsl:map-entry key="'feat.heading10'" select="'XSD 1.0 features in use'" />
          <xsl:map-entry key="'feat.heading11'" select="'XSD 1.1 features in use'" />
          <xsl:map-entry key="'feat.none'" select="'None detected.'" />
          <xsl:map-entry key="'feat.derivation'" select="'Type derivation by extension or restriction'" />
          <xsl:map-entry key="'feat.substitution'" select="'Substitution groups'" />
          <xsl:map-entry key="'feat.identity'" select="'Identity constraints'" />
          <xsl:map-entry key="'feat.composition'" select="'Schema composition'" />
          <xsl:map-entry key="'feat.wildcards'" select="'Wildcards'" />
          <xsl:map-entry key="'feat.abf'" select="'Abstract, block, or final constraints'" />
          <xsl:map-entry key="'feat.namedGroups'" select="'Named model or attribute groups'" />
          <xsl:map-entry key="'feat.facets'" select="'Constraining facets'" />
          <xsl:map-entry key="'feat.notations'" select="'Notations'" />
          <xsl:map-entry key="'feat.assertions'" select="'Assertions'" />
          <xsl:map-entry key="'feat.assertionFacets'" select="'Assertion facets'" />
          <xsl:map-entry key="'feat.cta'" select="'Conditional type assignment'" />
          <xsl:map-entry key="'feat.openContent'" select="'Open content'" />
          <xsl:map-entry key="'feat.inheritable'" select="'Inheritable attributes'" />
          <xsl:map-entry key="'feat.negWildcards'" select="'Negative wildcard constraints'" />
          <xsl:map-entry key="'feat.versioning'" select="'Versioning annotations'" />
          <xsl:map-entry key="'feat.override'" select="'Schema override'" />
          <xsl:map-entry key="'flag.abstract'" select="'abstract'" />
          <xsl:map-entry key="'flag.mixed'" select="'mixed'" />
          <xsl:map-entry key="'flag.nillable'" select="'nillable'" />
          <xsl:map-entry key="'flag.redefined'" select="'redefined'" />
          <xsl:map-entry key="'flag.overridden'" select="'overridden'" />
          <xsl:map-entry key="'flag.xsd11feature'" select="'XSD 1.1 feature'" />
          <xsl:map-entry key="'flag.xsd11'" select="'XSD 1.1'" />
          <xsl:map-entry key="'component.definedIn'" select="'Defined in'" />
          <xsl:map-entry key="'action.copyLinkLabel'" select="'Copy link'" />
          <xsl:map-entry key="'action.copied'" select="'Copied'" />
          <xsl:map-entry key="'block.source'" select="'XSD source'" />
          <xsl:map-entry key="'block.properties'" select="'Properties'" />
          <xsl:map-entry key="'block.identityConstraints'" select="'Identity constraints'" />
          <xsl:map-entry key="'block.typeAlternatives'" select="'Type alternatives'" />
          <xsl:map-entry key="'block.derivation'" select="'Derivation'" />
          <xsl:map-entry key="'block.contentModel'" select="'Content model'" />
          <xsl:map-entry key="'block.modelGroup'" select="'Model group'" />
          <xsl:map-entry key="'block.notationIds'" select="'Notation identifiers'" />
          <xsl:map-entry key="'block.versioning'" select="'Versioning annotations'" />
          <xsl:map-entry key="'block.simpleTypeDef'" select="'Simple type definition'" />
          <xsl:map-entry key="'block.facets'" select="'Facets'" />
          <xsl:map-entry key="'block.attributes'" select="'Attributes'" />
          <xsl:map-entry key="'block.typeHierarchy'" select="'Type hierarchy'" />
          <xsl:map-entry key="'block.assertions'" select="'Assertions'" />
          <xsl:map-entry key="'block.seeAlso'" select="'See also'" />
          <xsl:map-entry key="'block.appinfo'" select="'Appinfo'" />
          <xsl:map-entry key="'deriv.thisType'" select="'this type'" />
          <xsl:map-entry key="'deriv.descendant'" select="'descendant'" />
          <xsl:map-entry key="'msg.anonymousType'" select="'Anonymous type'" />
          <xsl:map-entry key="'msg.anonymousComplexType'" select="'Anonymous complex type.'" />
          <xsl:map-entry key="'msg.anonymousSimpleType'" select="'Anonymous simple type.'" />
          <xsl:map-entry key="'msg.base'" select="'Base:'" />
          <xsl:map-entry key="'msg.appliedFromSchema'" select="'Applied from schema'" />
          <xsl:map-entry
            key="'msg.defaultAttributesNotApplied'"
            select="'; schema default attributes are not applied.'" />
          <xsl:map-entry
            key="'msg.inheritedDefaultOpenContent'"
            select="'Inherited from schema default open content.'" />
          <xsl:map-entry key="'msg.ctaInheritable'" select="'Inheritable attributes available to CTA test context'" />
          <xsl:map-entry
            key="'msg.ctaInheritableDesc'"
            select="'These inheritable attributes from the type chain are available in xs:alternative/@test XPath expressions.'" />
          <xsl:map-entry key="'doc.langTitle'" select="'Documentation language ({lang})'" />
          <xsl:map-entry key="'doc.langLabel'" select="'Documentation language: {lang}'" />
          <xsl:map-entry key="'doc.sourceLink'" select="'source'" />
          <xsl:map-entry key="'doc.sourceLinkLabel'" select="'Documentation source'" />
          <xsl:map-entry key="'js.showMore'" select="'Show more'" />
          <xsl:map-entry key="'js.showLess'" select="'Show less'" />
          <xsl:map-entry key="'seeAlso.usedAsType'" select="'Used as a type by'" />
          <xsl:map-entry key="'seeAlso.usedAsElementRef'" select="'Referenced as an element by'" />
          <xsl:map-entry key="'seeAlso.usedAsGroupRef'" select="'Referenced as a model group by'" />
          <xsl:map-entry key="'seeAlso.usedAsAttributeGroupRef'" select="'Referenced as an attribute group by'" />
          <xsl:map-entry key="'seeAlso.usedAsAttributeRef'" select="'Referenced as an attribute by'" />
          <xsl:map-entry key="'seeAlso.substitutionMembers'" select="'Substitution group members'" />
          <xsl:map-entry key="'seeAlso.substitutionHeads'" select="'Substitution group heads'" />
          <xsl:map-entry key="'seeAlso.referencedByKeyref'" select="'Referenced by keyref'" />
          <xsl:map-entry key="'facet.enumerationCount'" select="'{count} enumeration values'" />
          <xsl:map-entry key="'facet.enumerationCountOne'" select="'{count} enumeration value'" />
          <xsl:map-entry key="'facet.codeList'" select="'Code list'" />
          <xsl:map-entry key="'caption.identityConstraints'" select="'Identity constraints for {name}'" />
          <xsl:map-entry key="'caption.typeAlternatives'" select="'Type alternatives for {name}'" />
          <xsl:map-entry key="'caption.facets'" select="'Constraining facets for {name}'" />
          <xsl:map-entry key="'caption.attributeUses'" select="'Attribute uses for {name}'" />
          <xsl:map-entry key="'caption.assertions'" select="'Assertions for {name}'" />
          <xsl:map-entry key="'name.anonymousComplexType'" select="'anonymous complex type'" />
          <xsl:map-entry key="'name.anonymousSimpleType'" select="'anonymous simple type'" />
          <xsl:map-entry key="'diag.heading'" select="'Diagnostics'" />
          <xsl:map-entry key="'diag.invalidParameter'" select="'Invalid parameter value normalized to a default.'" />
          <xsl:map-entry key="'diag.schemaNotLoaded'" select="'Schema document not loaded.'" />
          <xsl:map-entry key="'diag.notSchema'" select="'Loaded document is not an xs:schema.'" />
          <xsl:map-entry key="'diag.cycleSkipped'" select="'Schema traversal skipped a cycle or duplicate instance.'" />
          <xsl:map-entry key="'diag.unknownElement'" select="'Unknown XSD-namespace element in a schema position.'" />
          <xsl:map-entry
            key="'diag.recursiveExpansion'"
            select="'Recursive group or attribute-group expansion stopped.'" />
          <xsl:map-entry key="'diag.qnameUnresolved'" select="'QName reference not resolved.'" />
          <xsl:map-entry key="'kind.element.label'" select="'element'" />
          <xsl:map-entry key="'kind.complexType.label'" select="'complex type'" />
          <xsl:map-entry key="'kind.simpleType.label'" select="'simple type'" />
          <xsl:map-entry key="'kind.attribute.label'" select="'attribute'" />
          <xsl:map-entry key="'kind.attributeGroup.label'" select="'attribute group'" />
          <xsl:map-entry key="'kind.group.label'" select="'model group'" />
          <xsl:map-entry key="'kind.notation.label'" select="'notation'" />
          <xsl:map-entry key="'kind.element.plural'" select="'Elements'" />
          <xsl:map-entry key="'kind.complexType.plural'" select="'Complex types'" />
          <xsl:map-entry key="'kind.simpleType.plural'" select="'Simple types'" />
          <xsl:map-entry key="'kind.attribute.plural'" select="'Attributes'" />
          <xsl:map-entry key="'kind.attributeGroup.plural'" select="'Attribute groups'" />
          <xsl:map-entry key="'kind.group.plural'" select="'Model groups'" />
          <xsl:map-entry key="'kind.notation.plural'" select="'Notations'" />
          <xsl:map-entry key="'count.one'" select="'component'" />
          <xsl:map-entry key="'count.many'" select="'components'" />
          <xsl:map-entry key="'js.filterResults'" select="'components shown'" />
          <xsl:map-entry key="'js.copyOk'" select="'Link copied'" />
          <xsl:map-entry key="'js.copyFailed'" select="'Copy failed'" />
        </xsl:map>
      </xsl:map-entry>
    </xsl:map>
  </xsl:variable>

  <!-- Active locale: exact interface-language, then primary subtag, then 'en'. -->
  <xsl:variable name="active-locale" as="xs:string">
    <xsl:variable name="req" select="lower-case(normalize-space($interface-language))" />
    <xsl:variable name="primary" select="if (contains($req, '-')) then substring-before($req, '-') else $req" />
    <xsl:sequence
      select="
      if ($req ne '' and map:contains($i18n-messages, $req)) then $req
      else if ($primary ne '' and map:contains($i18n-messages, $primary)) then $primary
      else 'en'" />
  </xsl:variable>

  <!--
    Message lookup. f:t($key) returns the active-locale text for $key, falling
    back to the 'en' value and finally to the literal sentinel '[[key]]'.
    f:t($key, $params) additionally substitutes {name} placeholders.
  -->
  <xsl:function name="f:t" as="xs:string">
    <xsl:param name="key" as="xs:string" />
    <xsl:sequence select="f:t($key, map {})" />
  </xsl:function>

  <xsl:function name="f:t" as="xs:string">
    <xsl:param name="key" as="xs:string" />
    <xsl:param name="params" as="map(xs:string, xs:anyAtomicType)" />
    <xsl:variable name="catalog" select="$i18n-messages($active-locale)" />
    <xsl:variable name="en" select="$i18n-messages('en')" />
    <xsl:variable
      name="raw"
      select="
      if (map:contains($catalog, $key)) then $catalog($key)
      else if (map:contains($en, $key)) then $en($key)
      else concat('[[', $key, ']]')" />
    <xsl:sequence select="f:format-message($raw, $params)" />
  </xsl:function>

  <!--
    Substitute every {name} placeholder in $template with the matching $params
    entry. Param values are user-controlled (a URI may contain '$' or '\'), so
    they are escaped before use as a replacement string to avoid FORX0004.
  -->
  <xsl:function name="f:format-message" as="xs:string">
    <xsl:param name="template" as="xs:string" />
    <xsl:param name="params" as="map(xs:string, xs:anyAtomicType)" />
    <xsl:iterate select="map:keys($params)">
      <xsl:param name="acc" as="xs:string" select="$template" />
      <xsl:on-completion select="$acc" />
      <xsl:next-iteration>
        <xsl:with-param
          name="acc"
          select="replace($acc, concat('\{', ., '\}'), replace(replace(string($params(.)), '\\', '\\\\'), '\$', '\\\$'))" />
      </xsl:next-iteration>
    </xsl:iterate>
  </xsl:function>

  <xsl:function name="f:coalesce-string" as="xs:string">
    <xsl:param name="values" as="xs:string*" />
    <xsl:sequence select="($values[normalize-space(.) ne ''][1], '')[1]" />
  </xsl:function>

  <xsl:function name="f:config" as="map(*)">
    <xsl:variable name="lang" select="f:coalesce-string(($interface-language, 'en'))" />
    <xsl:variable name="doc-lang" select="f:coalesce-string(($documentation-language, 'en'))" />
    <xsl:variable name="requested-dir" select="lower-case(f:coalesce-string(($interface-direction, 'auto')))" />
    <xsl:variable name="primary-lang" select="lower-case(tokenize($lang, '-')[1])" />
    <xsl:variable
      name="resolved-dir"
      select="
        if ($requested-dir = ('ltr', 'rtl')) then $requested-dir
        else if ($primary-lang = $rtl-languages) then 'rtl'
        else 'ltr'" />
    <xsl:variable
      name="param-diagnostics"
      as="map(*)*"
      select="(
        if (normalize-space($documentation-markup) ne '' and not($documentation-markup = ('safe', 'permissive')))
          then map { 'code': 'invalid-parameter', 'severity': 'info', 'param': 'documentation-markup', 'value': string($documentation-markup), 'normalized': 'safe' }
          else (),
        if (normalize-space($requested-dir) ne '' and not($requested-dir = ('auto', 'ltr', 'rtl')))
          then map { 'code': 'invalid-parameter', 'severity': 'info', 'param': 'interface-direction', 'value': string($interface-direction), 'normalized': $resolved-dir }
          else ()
      )" />
    <xsl:sequence
      select="map {
      'page-title': f:coalesce-string(($page-title, '')),
      'asset-base-uri': f:coalesce-string(($asset-base-uri, './assets/')),
      'show-source': $show-source,
      'documentation-markup': (if ($documentation-markup = ('safe', 'permissive')) then $documentation-markup else 'safe'),
      'interface-language': $lang,
      'documentation-language': $doc-lang,
      'requested-interface-direction': $requested-dir,
      'interface-direction': $resolved-dir,
      'robots-noindex': $robots-noindex,
      'diagnostics': $param-diagnostics
    }" />
  </xsl:function>

  <xsl:function name="f:kind" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:sequence select="local-name($node)" />
  </xsl:function>

  <xsl:function name="f:kind-label" as="xs:string">
    <xsl:param name="kind" as="xs:string" />
    <xsl:sequence select="f:t(concat('kind.', $kind, '.label'))" />
  </xsl:function>

  <xsl:function name="f:kind-plural" as="xs:string">
    <xsl:param name="kind" as="xs:string" />
    <xsl:sequence select="f:t(concat('kind.', $kind, '.plural'))" />
  </xsl:function>

  <xsl:function name="f:kind-abbrev" as="xs:string">
    <xsl:param name="kind" as="xs:string" />
    <xsl:sequence
      select="map {
      'element': 'el',
      'complexType': 'ct',
      'simpleType': 'st',
      'attribute': 'at',
      'attributeGroup': 'ag',
      'group': 'gr',
      'notation': 'no'
    }($kind)" />
  </xsl:function>

  <xsl:function name="f:safe-id" as="xs:string">
    <xsl:param name="value" as="xs:string?" />
    <xsl:variable name="ascii" select="replace(normalize-space(string($value)), '[^A-Za-z0-9_.-]+', '-')" />
    <xsl:sequence select="if ($ascii ne '') then $ascii else 'unnamed'" />
  </xsl:function>

  <xsl:function name="f:clark" as="xs:string">
    <xsl:param name="qname" as="xs:QName?" />
    <xsl:sequence
      select="if (exists($qname)) then concat('{', namespace-uri-from-QName($qname), '}', local-name-from-QName($qname)) else ''" />
  </xsl:function>

  <xsl:function name="f:doc-uri" as="xs:string">
    <xsl:param name="schema" as="element(xs:schema)" />
    <xsl:sequence
      select="if (base-uri($schema)) then string(base-uri($schema)) else concat('memory:', generate-id($schema))" />
  </xsl:function>

  <xsl:function name="f:absolute-uri" as="xs:string?">
    <xsl:param name="href" as="xs:string?" />
    <xsl:param name="base" as="xs:string?" />
    <xsl:sequence
      select="
      if (empty($href) or normalize-space($href) = '') then ()
      else if (matches($href, '^[A-Za-z][A-Za-z0-9+.-]*:')) then string($href)
      else resolve-uri($href, $base)" />
  </xsl:function>

  <xsl:function name="f:composition-edges" as="element()*">
    <xsl:param name="schema" as="element(xs:schema)" />
    <xsl:sequence select="$schema/(xs:include | xs:import | xs:redefine | xs:override)[@schemaLocation]" />
  </xsl:function>

  <xsl:function name="f:composition-child-ns" as="xs:string">
    <xsl:param name="loaded" as="element(xs:schema)" />
    <xsl:param name="edge" as="element()" />
    <xsl:param name="parent-effective-ns" as="xs:string" />
    <xsl:sequence
      select="
      if ($loaded/@targetNamespace) then string($loaded/@targetNamespace)
      else if ($edge/self::xs:include or $edge/self::xs:redefine) then $parent-effective-ns
      else string($loaded/@targetNamespace)" />
  </xsl:function>

  <!--
    Express $uri relative to the directory $base (which ends in '/') so that
    host-specific absolute paths do not leak into deterministic output. A URI
    at or below $base is stripped to the remainder; a URI sharing the same
    scheme://authority origin gets a '../'-prefixed path; a different origin
    (or anything the regex cannot split) is returned verbatim.
  -->
  <xsl:function name="f:relativize" as="xs:string">
    <xsl:param name="uri" as="xs:string" />
    <xsl:param name="base" as="xs:string" />
    <xsl:choose>
      <xsl:when test="$base ne '' and starts-with($uri, $base)">
        <xsl:sequence select="substring-after($uri, $base)" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="origin-re" as="xs:string" select="'^([a-z][a-z0-9+.\-]*:(?://[^/]*)?)(/.*)?$'" />
        <xsl:variable name="base-origin" as="xs:string" select="replace($base, $origin-re, '$1')" />
        <xsl:variable name="uri-origin" as="xs:string" select="replace($uri, $origin-re, '$1')" />
        <xsl:choose>
          <xsl:when test="$base-origin ne $uri-origin or $base-origin eq $base">
            <xsl:sequence select="$uri" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable
              name="base-dirs"
              as="xs:string*"
              select="tokenize(replace($base, $origin-re, '$2'), '/')[. ne '']" />
            <xsl:variable
              name="uri-segs"
              as="xs:string*"
              select="tokenize(replace($uri, $origin-re, '$2'), '/')[. ne '']" />
            <xsl:variable name="shared" as="xs:integer" select="min((count($base-dirs), count($uri-segs)))" />
            <xsl:variable
              name="first-diff"
              as="xs:integer?"
              select="(for $i in 1 to $shared return if ($base-dirs[$i] ne $uri-segs[$i]) then $i else ())[1]" />
            <xsl:variable
              name="common"
              as="xs:integer"
              select="if (exists($first-diff)) then $first-diff - 1 else $shared" />
            <xsl:variable name="ups" as="xs:integer" select="count($base-dirs) - $common" />
            <xsl:sequence
              select="string-join((for $k in 1 to $ups return '../'), '')
                || string-join($uri-segs[position() gt $common], '/')" />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Directory of the primary schema document, for relativizing displayed URIs. -->
  <xsl:function name="f:primary-base" as="xs:string">
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="primary" select="($schemas[?is-primary], $schemas)[1]" />
    <xsl:sequence select="if (exists($primary)) then replace(string($primary?uri), '[^/]+$', '') else ''" />
  </xsl:function>

  <xsl:function name="f:collect-schemas" as="map(*)*">
    <xsl:param name="schema" as="element(xs:schema)" />
    <xsl:param name="effective-ns" as="xs:string" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:variable name="uri" select="f:doc-uri($schema)" />
    <xsl:variable name="key" select="concat($uri, '|', $effective-ns)" />
    <xsl:choose>
      <xsl:when test="$key = $visited" />
      <xsl:otherwise>
        <xsl:sequence
          select="map {
          'uri': $uri,
          'node': $schema,
          'declared-target-namespace': string($schema/@targetNamespace),
          'effective-target-namespace': $effective-ns,
          'is-primary': empty($visited),
          'is-chameleon': not($schema/@targetNamespace),
          'load-status': 'loaded'
        }" />
        <xsl:for-each select="f:composition-edges($schema)">
          <xsl:variable name="edge" select="." />
          <xsl:variable name="resolved" select="f:absolute-uri(string($edge/@schemaLocation), base-uri($edge))" />
          <xsl:if test="$resolved and doc-available($resolved)">
            <xsl:variable name="loaded" select="doc($resolved)/*" />
            <xsl:if test="$loaded/self::xs:schema">
              <xsl:variable name="child-ns" select="f:composition-child-ns($loaded, $edge, $effective-ns)" />
              <xsl:sequence select="f:collect-schemas($loaded, $child-ns, ($visited, $key))" />
            </xsl:if>
          </xsl:if>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:schema-record" as="map(*)?">
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="node" as="node()" />
    <xsl:variable name="schema" select="$node/ancestor-or-self::xs:schema[1]" />
    <xsl:sequence select="$schemas[?uri = f:doc-uri($schema)][1]" />
  </xsl:function>

  <xsl:function name="f:effective-ns" as="xs:string">
    <xsl:param name="node" as="node()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:sequence
      select="string((f:schema-record($schemas, $node)?effective-target-namespace, $node/ancestor::xs:schema[1]/@targetNamespace, '')[1])" />
  </xsl:function>

  <xsl:function name="f:component-nodes" as="element()*">
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:sequence
      select="$schemas ! ?node/(xs:element | xs:complexType | xs:simpleType | xs:attribute | xs:attributeGroup | xs:group | xs:notation | (xs:redefine | xs:override)/(xs:element | xs:complexType | xs:simpleType | xs:attribute | xs:attributeGroup | xs:group | xs:notation))[@name]" />
  </xsl:function>

  <xsl:function name="f:namespace-id" as="xs:string">
    <xsl:param name="ns" as="xs:string" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="primary" select="string($schemas[1]?effective-target-namespace)" />
    <xsl:variable name="namespaces" select="distinct-values(($schemas?effective-target-namespace, ''))" />
    <xsl:variable name="index" select="index-of($namespaces[. ne $primary], $ns)[1]" />
    <!--
      Known namespaces get the deterministic first-seen id (ns1, ns2, …). A
      namespace not present in any collected schema (e.g. referenced but never
      loaded) has no collection-order slot, so fall back to a distinct id
      derived from the namespace itself rather than a bare 'ns' that would
      collide across every such namespace.
    -->
    <xsl:sequence
      select="
      if ($ns = $primary) then ''
      else if (exists($index)) then concat('ns', $index)
      else concat('nsx-', f:safe-id($ns))" />
  </xsl:function>

  <xsl:function name="f:anchor" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="kind" select="f:kind($node)" />
    <xsl:variable name="ns-id" select="f:namespace-id(f:effective-ns($node, $schemas), $schemas)" />
    <xsl:variable
      name="base"
      select="string-join((f:kind-abbrev($kind), $ns-id, f:safe-id(string($node/@name)))[. ne ''], '-')" />
    <xsl:variable
      name="disposition"
      select="if ($node/ancestor::xs:redefine) then 'redefined' else if ($node/ancestor::xs:override) then 'overridden' else ''" />
    <xsl:sequence select="string-join(($base, $disposition)[. ne ''], '-')" />
  </xsl:function>

  <!--
    Deterministic anchor for a component nested inside another component's
    content model (e.g. a local xs:element carrying xs:alternative). Combines
    the enclosing top-level component's anchor with the node's sibling-position
    path, so the id is page-unique and stable without relying on generate-id().
  -->
  <xsl:function name="f:local-anchor" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable
      name="top"
      as="element()"
      select="$node/ancestor-or-self::*[parent::xs:schema or parent::xs:redefine or parent::xs:override][1]" />
    <xsl:variable
      name="steps"
      as="xs:string*"
      select="$node/ancestor-or-self::*[$top intersect ancestor::*] ! string(count(preceding-sibling::*) + 1)" />
    <xsl:sequence select="string-join((f:anchor($top, $schemas), $steps), '-')" />
  </xsl:function>

  <xsl:function name="f:qname" as="xs:QName?">
    <xsl:param name="lexical" as="xs:string?" />
    <xsl:param name="context" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="value" select="normalize-space(string($lexical))" />
    <xsl:choose>
      <xsl:when test="$value = ''" />
      <xsl:when test="contains($value, ':')">
        <xsl:try>
          <xsl:sequence select="resolve-QName($value, $context)" />
          <xsl:catch />
        </xsl:try>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="QName(f:effective-ns($context, $schemas), $value)" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:components-matching" as="element()*">
    <xsl:param name="qname" as="xs:QName?" />
    <xsl:param name="expected" as="xs:string" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="nodes" select="f:component-nodes($schemas)" />
    <xsl:sequence
      select="$nodes[
      (@name = local-name-from-QName($qname))
      and (f:effective-ns(., $schemas) = namespace-uri-from-QName($qname))
      and (
        ($expected = 'type' and (self::xs:complexType or self::xs:simpleType))
        or ($expected = 'element' and self::xs:element)
        or ($expected = 'attribute' and self::xs:attribute)
        or ($expected = 'attributeGroup' and self::xs:attributeGroup)
        or ($expected = 'group' and self::xs:group)
        or ($expected = 'notation' and self::xs:notation)
        or ($expected = '')
      )
    ]" />
  </xsl:function>

  <xsl:function name="f:component-qname" as="xs:QName?">
    <xsl:param name="node" as="element()?" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:sequence
      select="if (exists($node) and $node/@name) then QName(f:effective-ns($node, $schemas), string($node/@name)) else ()" />
  </xsl:function>

  <xsl:function name="f:owner-component" as="element()?">
    <xsl:param name="node" as="node()" />
    <xsl:sequence
      select="$node/ancestor-or-self::*[
      @name
      and (parent::xs:schema or parent::xs:redefine or parent::xs:override)
      and (self::xs:element or self::xs:complexType or self::xs:simpleType
      or self::xs:attribute or self::xs:attributeGroup or self::xs:group or self::xs:notation)
    ][1]" />
  </xsl:function>

  <xsl:function name="f:usage-name" as="xs:string?">
    <xsl:param name="node" as="element()" />
    <xsl:sequence
      select="
      if ($node/self::xs:element or $node/self::xs:attribute) then
        string(($node/@name, $node/@ref)[1])
      else if ($node/self::xs:group or $node/self::xs:attributeGroup) then
        string(($node/@ref, $node/@name)[1])
      else
        string(($node/@base, $node/@itemType, $node/@type, $node/@ref, $node/@name)[1])" />
  </xsl:function>

  <xsl:function name="f:owner-type" as="element()?">
    <xsl:param name="node" as="node()" />
    <xsl:sequence
      select="$node/ancestor::*[(self::xs:complexType or self::xs:simpleType) and (@name or parent::xs:element or parent::xs:attribute)][1]" />
  </xsl:function>

  <!--
    Anchor for an identity constraint: {owner-anchor}-{k|kr|u}-{name}. A
    ref-only constraint (XSD 1.1 @ref, no @name) uses ref-{safe(@ref)} with a
    deterministic sibling-count suffix when identical ref-only siblings would
    collide.
  -->
  <xsl:function name="f:identity-anchor" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="owner" select="f:owner-component($node)" />
    <xsl:variable name="abbr" select="map { 'key': 'k', 'keyref': 'kr', 'unique': 'u' }(local-name($node))" />
    <xsl:variable name="name-part" as="xs:string">
      <xsl:choose>
        <xsl:when test="$node/@name">
          <xsl:sequence select="f:safe-id(string($node/@name))" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable
            name="dups"
            select="count($node/preceding-sibling::*[local-name() = local-name($node)][empty(@name)][string(@ref) = string($node/@ref)])" />
          <xsl:sequence
            select="concat('ref-', f:safe-id(string($node/@ref)), if ($dups gt 0) then concat('-', $dups + 1) else '')" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence
      select="concat(
      if ($owner) then f:anchor($owner, $schemas) else 'ic',
      '-',
      $abbr,
      '-',
      $name-part
    )" />
  </xsl:function>

  <!-- Resolve a lexical QName purely against in-scope namespaces (no target-namespace preference). -->
  <xsl:function name="f:lexical-qname" as="xs:QName?">
    <xsl:param name="lexical" as="xs:string?" />
    <xsl:param name="context" as="element()" />
    <xsl:try>
      <xsl:sequence select="resolve-QName(normalize-space(string($lexical))[. ne ''], $context)" />
      <xsl:catch />
    </xsl:try>
  </xsl:function>

  <xsl:function name="f:identity-match" as="element()?">
    <xsl:param name="q" as="xs:QName?" />
    <xsl:param name="kinds" as="xs:string*" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:sequence
      select="
      if (exists($q)) then
        ($schemas ! ?node//(xs:key | xs:keyref | xs:unique)[local-name() = $kinds]
          [@name = local-name-from-QName($q)]
          [f:effective-ns(., $schemas) = namespace-uri-from-QName($q)])[1]
      else ()" />
  </xsl:function>

  <!--
    Resolve an identity-constraint reference (xs:keyref/@refer or the XSD 1.1
    @ref) to its target constraint. Identity constraints are not schema
    components, so this mirrors f:reference-qname's unprefixed preference
    (effective target namespace first, lexical default namespace fallback)
    against the identity-constraint pool instead of f:components-matching.
  -->
  <xsl:function name="f:identity-target" as="element()?">
    <xsl:param name="lexical" as="xs:string" />
    <xsl:param name="context" as="element()" />
    <xsl:param name="kinds" as="xs:string*" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="primary" select="f:qname($lexical, $context, $schemas)" />
    <xsl:variable name="first" select="f:identity-match($primary, $kinds, $schemas)" />
    <xsl:choose>
      <xsl:when test="exists($first) or contains(normalize-space($lexical), ':')">
        <xsl:sequence select="$first" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="f:identity-match(f:lexical-qname($lexical, $context), $kinds, $schemas)" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:is-builtin-type" as="xs:boolean">
    <xsl:param name="qname" as="xs:QName?" />
    <xsl:sequence
      select="exists($qname)
      and namespace-uri-from-QName($qname) = $xsd-ns
      and local-name-from-QName($qname) = $builtin-types" />
  </xsl:function>

  <!--
    Fundamental facet record for a built-in datatype local name, or empty for
    unknown names and the special types that have no fundamental facets.
  -->
  <xsl:function name="f:fundamental-facets" as="map(xs:string, xs:string)?">
    <xsl:param name="local" as="xs:string" />
    <xsl:sequence select="$fundamental-facets($local)" />
  </xsl:function>

  <xsl:function name="f:builtin-type-href" as="xs:string">
    <xsl:param name="local" as="xs:string" />
    <xsl:sequence
      select="
      if ($local = 'anyType') then 'https://www.w3.org/TR/xmlschema11-1/#anyType'
      else concat('https://www.w3.org/TR/xmlschema11-2/#', $local)" />
  </xsl:function>

  <xsl:function name="f:reference-qname" as="xs:QName?">
    <xsl:param name="lexical" as="xs:string?" />
    <xsl:param name="context" as="element()" />
    <xsl:param name="expected" as="xs:string" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="primary" select="f:qname($lexical, $context, $schemas)" />
    <xsl:choose>
      <xsl:when test="empty($primary) or contains(normalize-space(string($lexical)), ':')">
        <xsl:sequence select="$primary" />
      </xsl:when>
      <xsl:when test="exists(f:components-matching($primary, $expected, $schemas)) or f:is-builtin-type($primary)">
        <xsl:sequence select="$primary" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:try>
          <xsl:sequence select="resolve-QName(normalize-space(string($lexical)), $context)" />
          <xsl:catch>
            <xsl:sequence select="$primary" />
          </xsl:catch>
        </xsl:try>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:type-base" as="xs:QName?">
    <xsl:param name="type" as="element()?" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable
      name="base"
      select="$type/(xs:complexContent | xs:simpleContent)/(xs:extension | xs:restriction)/@base
      | $type/xs:restriction/@base" />
    <xsl:sequence select="if ($base) then f:reference-qname(string($base[1]), $base[1]/.., 'type', $schemas) else ()" />
  </xsl:function>

  <xsl:function name="f:type-ancestors" as="element()*">
    <xsl:param name="type" as="element()?" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:variable name="here" select="f:clark(f:component-qname($type, $schemas))" />
    <xsl:choose>
      <xsl:when test="empty($type) or $here = $visited or count($visited) gt 32" />
      <xsl:otherwise>
        <xsl:variable name="base-q" select="f:type-base($type, $schemas)" />
        <xsl:variable name="base" select="f:components-matching($base-q, 'type', $schemas)[1]" />
        <xsl:sequence select="($base, f:type-ancestors($base, $schemas, ($visited, $here)))[exists(.)]" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:inheritable-attrs" as="element()*">
    <xsl:param name="type" as="element()?" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:variable name="ancestors" select="f:type-ancestors($type, $schemas, $visited)" />
    <xsl:sequence select="$ancestors//xs:attribute[f:xsd-true(string(@inheritable))]" />
  </xsl:function>

  <!--
    Variety of a simple type: 'list', 'union', or 'atomic' when determinable
    from source, walking resolved restriction bases (anonymous types skip the
    visited check because they have no Clark name; the depth bound still
    terminates). 'unknown' when the base is not resolvable, 'unspecified' when
    the type has no derivation child at all.
  -->
  <xsl:function name="f:simple-type-variety" as="xs:string">
    <xsl:param name="type" as="element()?" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:variable name="here" select="f:clark(f:component-qname($type, $schemas))" />
    <xsl:choose>
      <xsl:when test="empty($type) or ($here ne '' and $here = $visited) or count($visited) gt 32">
        <xsl:sequence select="'unknown'" />
      </xsl:when>
      <xsl:when test="$type/xs:list">
        <xsl:sequence select="'list'" />
      </xsl:when>
      <xsl:when test="$type/xs:union">
        <xsl:sequence select="'union'" />
      </xsl:when>
      <xsl:when test="$type/xs:restriction/xs:simpleType">
        <xsl:sequence
          select="f:simple-type-variety($type/xs:restriction/xs:simpleType, $schemas, ($visited, $here[. ne ''], 'anonymous'))" />
      </xsl:when>
      <xsl:when test="$type/xs:restriction/@base">
        <xsl:variable name="restriction" select="$type/xs:restriction" />
        <xsl:variable name="q" select="f:reference-qname(string($restriction/@base), $restriction, 'type', $schemas)" />
        <xsl:choose>
          <xsl:when test="f:is-builtin-type($q)">
            <xsl:sequence
              select="if (local-name-from-QName($q) = ('NMTOKENS', 'IDREFS', 'ENTITIES')) then 'list' else 'atomic'" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="target" select="f:components-matching($q, 'type', $schemas)[1]" />
            <xsl:sequence
              select="
              if ($target/self::xs:simpleType) then f:simple-type-variety($target, $schemas, ($visited, $here[. ne '']))
              else 'unknown'" />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="$type/xs:restriction">
        <xsl:sequence select="'unknown'" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="'unspecified'" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!--
    Origin of a displayed wildcard. The renderer is source-honest: wildcards
    inherited from a base type render in the declaring type's own section, so
    the possible origins are the wildcard's lexical context.
  -->
  <xsl:function name="f:wildcard-provenance" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:sequence
      select="
      if ($node/ancestor::xs:defaultOpenContent) then 'default-open-content'
      else if ($node/ancestor::xs:openContent) then 'open-content'
      else if ($node/ancestor::xs:attributeGroup[@name]) then 'attribute-group'
      else 'direct'" />
  </xsl:function>

  <xsl:function name="f:effective-open-content" as="element()?">
    <xsl:param name="type" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="own" select="($type/xs:openContent, $type/xs:complexContent/xs:openContent)[1]" />
    <xsl:variable name="schema" select="$type/ancestor::xs:schema[1]" />
    <xsl:variable name="default" select="$schema/xs:defaultOpenContent[1]" />
    <xsl:variable
      name="has-particle"
      select="exists($type/(xs:sequence | xs:choice | xs:all | xs:group | xs:complexContent/*/(xs:sequence | xs:choice | xs:all | xs:group)))" />
    <xsl:sequence
      select="
      if ($own and not($own/@mode = 'none')) then $own
      else if ($default and not($default/@mode = 'none') and empty($type/xs:simpleContent)
        and ($has-particle or f:xsd-true(string($default/@appliesToEmpty)))) then $default
      else ()" />
  </xsl:function>

  <!--
    Content-type classification of a complex type as derivable from source:
    simple content, mixed, element-only (a particle that can contain elements,
    wildcards, or group references), or empty. Openness is orthogonal and
    reported separately via f:effective-open-content.
  -->
  <xsl:function name="f:content-type" as="xs:string">
    <xsl:param name="type" as="element()" />
    <xsl:choose>
      <xsl:when test="$type/xs:simpleContent">
        <xsl:sequence select="'simple'" />
      </xsl:when>
      <xsl:when test="f:xsd-true(string($type/@mixed)) or f:xsd-true(string($type/xs:complexContent/@mixed))">
        <xsl:sequence select="'mixed'" />
      </xsl:when>
      <xsl:when
        test="exists($type/(xs:sequence | xs:choice | xs:all | xs:group | xs:complexContent/*/(xs:sequence | xs:choice | xs:all | xs:group))/descendant-or-self::*[self::xs:element or self::xs:any or self::xs:group[@ref]])">
        <xsl:sequence select="'element-only'" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="'empty'" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="f:default-attribute-group" as="element()?">
    <xsl:param name="type" as="element(xs:complexType)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="schema" select="$type/ancestor::xs:schema[1]" />
    <xsl:sequence
      select="
      if (f:xsd-true(string($type/@defaultAttributesApply)) = false() and $type/@defaultAttributesApply) then ()
      else if ($schema/@defaultAttributes) then
        f:components-matching(f:reference-qname(string($schema/@defaultAttributes), $schema, 'attributeGroup', $schemas), 'attributeGroup', $schemas)[1]
      else ()" />
  </xsl:function>

  <xsl:function name="f:facet-href" as="xs:string?">
    <xsl:param name="local" as="xs:string" />
    <xsl:sequence
      select="
      map {
        'length': 'https://www.w3.org/TR/xmlschema11-2/#rf-length',
        'minLength': 'https://www.w3.org/TR/xmlschema11-2/#rf-minLength',
        'maxLength': 'https://www.w3.org/TR/xmlschema11-2/#rf-maxLength',
        'pattern': 'https://www.w3.org/TR/xmlschema11-2/#rf-pattern',
        'enumeration': 'https://www.w3.org/TR/xmlschema11-2/#rf-enumeration',
        'whiteSpace': 'https://www.w3.org/TR/xmlschema11-2/#rf-whiteSpace',
        'maxInclusive': 'https://www.w3.org/TR/xmlschema11-2/#rf-maxInclusive',
        'maxExclusive': 'https://www.w3.org/TR/xmlschema11-2/#rf-maxExclusive',
        'minInclusive': 'https://www.w3.org/TR/xmlschema11-2/#rf-minInclusive',
        'minExclusive': 'https://www.w3.org/TR/xmlschema11-2/#rf-minExclusive',
        'totalDigits': 'https://www.w3.org/TR/xmlschema11-2/#rf-totalDigits',
        'fractionDigits': 'https://www.w3.org/TR/xmlschema11-2/#rf-fractionDigits',
        'assertion': 'https://www.w3.org/TR/xmlschema11-2/#rf-assertions',
        'explicitTimezone': 'https://www.w3.org/TR/xmlschema11-2/#rf-explicitTimezone'
      }($local)" />
  </xsl:function>

  <xsl:function name="f:is-notation-simple-type" as="xs:boolean">
    <xsl:param name="type" as="element(xs:simpleType)?" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:variable name="base" select="f:type-base($type, $schemas)" />
    <xsl:variable name="here" select="f:clark(f:component-qname($type, $schemas))" />
    <xsl:sequence
      select="
      exists($base)
      and (
        (namespace-uri-from-QName($base) = $xsd-ns and local-name-from-QName($base) = 'NOTATION')
        or (
          not($here = $visited)
          and exists(f:components-matching($base, 'type', $schemas)[self::xs:simpleType]
            [f:is-notation-simple-type(., $schemas, ($visited, $here))])
        )
      )" />
  </xsl:function>

  <!--
    URL allowlist for hrefs inside <xs:documentation>. Strips ASCII
    whitespace + C0 controls the same way a browser does before scheme
    resolution, then rejects everything that isn't an http(s)/mailto/tel/
    ftp(s) URL or a relative path/fragment. Returns () for a rejected URL.
  -->
  <xsl:function name="f:safe-href" as="xs:string?">
    <xsl:param name="raw" as="xs:string?" />
    <xsl:variable name="stripped" select="replace(string($raw), '[\s\p{Cc}]', '')" />
    <xsl:variable name="lower" select="lower-case($stripped)" />
    <xsl:sequence
      select="
        if ($stripped ne ''
          and (not(matches($lower, '^[a-z][a-z0-9+.\-]*:'))
            or matches($lower, '^(https?|mailto|tel|ftps?):')))
        then $stripped
        else ()" />
  </xsl:function>

  <xsl:function name="f:occurs" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:variable name="bounds" select="f:occurs-bounds($node)" />
    <xsl:variable name="min" select="$bounds?min" />
    <xsl:variable name="max" select="$bounds?max" />
    <xsl:sequence
      select="
      if ($min = '1' and $max = '1') then ''
      else if ($min = '0' and $max = '1') then '?'
      else if ($min = '0' and $max = 'unbounded') then '*'
      else if ($min = '1' and $max = 'unbounded') then '+'
      else concat('[', $min, '..', $max, ']')" />
  </xsl:function>

  <xsl:function name="f:occurs-title" as="xs:string">
    <xsl:param name="node" as="element()" />
    <xsl:variable name="bounds" select="f:occurs-bounds($node)" />
    <xsl:variable name="min" select="$bounds?min" />
    <xsl:variable name="max" select="$bounds?max" />
    <xsl:sequence
      select="
      if ($min = '1' and $max = '1') then ''
      else if ($min = '0' and $max = '1') then concat('Optional: 0 or 1 occurrence (minOccurs=', $min, ', maxOccurs=', $max, ')')
      else if ($min = '0' and $max = 'unbounded') then concat('Zero or more occurrences (minOccurs=', $min, ', maxOccurs=', $max, ')')
      else if ($min = '1' and $max = 'unbounded') then concat('One or more occurrences (minOccurs=', $min, ', maxOccurs=', $max, ')')
      else if ($min = $max) then concat('Exactly ', $min, ' occurrences (minOccurs=', $min, ', maxOccurs=', $max, ')')
      else concat('Occurs ', $min, ' to ', $max, ' times (minOccurs=', $min, ', maxOccurs=', $max, ')')" />
  </xsl:function>

  <xsl:function name="f:occurs-bounds" as="map(xs:string, xs:string)">
    <xsl:param name="node" as="element()" />
    <xsl:sequence
      select="map { 'min': string(($node/@minOccurs, '1')[1]), 'max': string(($node/@maxOccurs, '1')[1]) }" />
  </xsl:function>

  <xsl:function name="f:xsd-true" as="xs:boolean">
    <xsl:param name="value" as="xs:string?" />
    <xsl:sequence select="lower-case(normalize-space(string($value))) = ('true', '1')" />
  </xsl:function>

  <!--
    A documentation block renders a body only when it carries actual content:
    non-whitespace text or element children. Link-only blocks (a bare @source)
    and whitespace-only blocks contribute no body and no clamp toggle.
  -->
  <xsl:function name="f:documentation-renders" as="xs:boolean">
    <xsl:param name="doc" as="element(xs:documentation)" />
    <xsl:sequence select="normalize-space(string($doc)) ne '' or exists($doc/*)" />
  </xsl:function>

  <xsl:function name="f:annotation-renders" as="xs:boolean">
    <xsl:param name="ann" as="element(xs:annotation)" />
    <xsl:sequence
      select="exists($ann/xs:appinfo)
      or exists($ann/xs:documentation[f:documentation-renders(.) or exists(f:safe-href(string(@source)))])" />
  </xsl:function>

  <xsl:function name="f:has-xsd11" as="xs:boolean">
    <xsl:param name="node" as="element()" />
    <xsl:sequence
      select="exists($node//@*[namespace-uri() = $vc-ns])
      or exists($node//xs:alternative | $node//xs:assert | $node//xs:assertion | $node//xs:openContent | $node//xs:defaultOpenContent)
      or exists($node//@xpathDefaultNamespace | $node//@defaultAttributes | $node//@defaultAttributesApply | $node//@inheritable | $node//@notNamespace | $node//@notQName)" />
  </xsl:function>

  <xsl:template match="/xs:schema">
    <xsl:variable name="config" select="f:config()" />
    <xsl:variable name="schemas" select="f:collect-schemas(., string(@targetNamespace), ())" />
    <xsl:variable name="components" select="f:component-nodes($schemas)" />
    <!--
      Reverse-reference indexes, built once over the whole schema set so each
      per-component "See also" section is an O(1) map lookup instead of a fresh
      full-document scan per component (architecture.md: renderers consult
      indexes, they do not re-scan raw nodes). Keys are the Clark name of the
      referenced component; values are the referencing nodes in document order.
    -->
    <xsl:variable
      name="type-users-index"
      as="map(*)"
      select="
      map:merge(
        for $n in $schemas ! ?node//*[@type or @base or @itemType]
        return map:entry(
          f:clark(f:reference-qname(string(($n/@type | $n/@base | $n/@itemType)[1]), $n, 'type', $schemas)),
          $n),
        map { 'duplicates': 'combine' })" />
    <xsl:variable
      name="keyref-index"
      as="map(*)"
      select="
      map:merge(
        for $n in $schemas ! ?node//xs:keyref[@refer]
        return map:entry(
          f:clark(f:reference-qname(string($n/@refer), $n, '', $schemas)),
          $n),
        map { 'duplicates': 'combine' })" />
    <xsl:variable
      name="element-ref-index"
      as="map(*)"
      select="
      map:merge(
        for $n in $schemas ! ?node//xs:element[@ref]
        return map:entry(
          f:clark(f:reference-qname(string($n/@ref), $n, 'element', $schemas)),
          $n),
        map { 'duplicates': 'combine' })" />
    <xsl:variable
      name="group-ref-index"
      as="map(*)"
      select="
      map:merge(
        for $n in $schemas ! ?node//xs:group[@ref]
        return map:entry(
          f:clark(f:reference-qname(string($n/@ref), $n, 'group', $schemas)),
          $n),
        map { 'duplicates': 'combine' })" />
    <xsl:variable
      name="attribute-group-ref-index"
      as="map(*)"
      select="
      map:merge(
        for $n in $schemas ! ?node//xs:attributeGroup[@ref]
        return map:entry(
          f:clark(f:reference-qname(string($n/@ref), $n, 'attributeGroup', $schemas)),
          $n),
        map { 'duplicates': 'combine' })" />
    <xsl:variable
      name="attribute-ref-index"
      as="map(*)"
      select="
      map:merge(
        for $n in $schemas ! ?node//xs:attribute[@ref]
        return map:entry(
          f:clark(f:reference-qname(string($n/@ref), $n, 'attribute', $schemas)),
          $n),
        map { 'duplicates': 'combine' })" />
    <xsl:variable name="unresolved-refs" as="attribute()*" select="f:unresolved-refs($schemas)" />
    <xsl:variable
      name="derived-title"
      select="
      if ($config?page-title ne '') then $config?page-title
      else if (@id) then string(@id)
      else if (@targetNamespace) then concat('Schema: ', string(@targetNamespace))
      else 'XSD Documentation'" />
    <html lang="{$config?interface-language}" dir="{$config?interface-direction}">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="color-scheme" content="light dark" />
        <meta name="generator" content="xsdstyle {$version}" />
        <xsl:if test="$config?robots-noindex">
          <meta name="robots" content="noindex" />
        </xsl:if>
        <title>{$derived-title}</title>
        <script>
          <xsl:text
            expand-text="no">try{var t=localStorage.getItem('xsdstyle-theme');if(t){document.documentElement.dataset.theme=t;}}catch(e){}</xsl:text>
        </script>
        <link rel="stylesheet" href="{concat($config?asset-base-uri, 'xsdstyle.css')}" />
        <script src="{concat($config?asset-base-uri, 'xsdstyle.js')}" defer="defer" />
      </head>
      <body>
        <a class="skip-link" href="#main">{f:t('a11y.skipToContent')}</a>
        <div hidden="hidden">
          <xsl:sequence select="f:icon-sprite()" />
        </div>
        <header class="topbar">
          <div class="brand">
            <span class="brand__mark" aria-hidden="true">XSD</span>
            <span class="brand__title">{$derived-title}</span>
            <span
              class="brand__ns"
              title="{f:t('field.targetNamespace')}">{if (@targetNamespace) then string(@targetNamespace) else f:t('msg.noTargetNamespace')}</span>
          </div>
          <div class="topbar__actions">
            <button class="iconbtn" type="button" data-toggle-all="all" data-state="closed">
              <xsl:sequence select="f:icon('ico-expand')" />
              <xsl:sequence select="f:icon('ico-collapse')" />
              <span class="iconbtn__label">{f:t('action.expandAll')}</span>
            </button>
            <button class="iconbtn theme-toggle" type="button" aria-label="{f:t('theme.switch')}">
              <xsl:sequence select="f:icon('ico-theme-dark')" />
              <xsl:sequence select="f:icon('ico-theme-light')" />
              <span class="iconbtn__label" data-when="to-dark">{f:t('theme.toDark')}</span>
              <span class="iconbtn__label" data-when="to-light">{f:t('theme.toLight')}</span>
            </button>
          </div>
        </header>
        <div class="layout">
          <nav class="sidebar" aria-label="{f:t('nav.label')}">
            <search class="nav-filter">
              <div class="nav-search" data-has-value="false">
                <xsl:sequence select="f:icon('ico-search')" />
                <label class="visually-hidden" for="nav-filter-input">{f:t('nav.filter')}</label>
                <input
                  id="nav-filter-input"
                  type="search"
                  autocomplete="off"
                  spellcheck="false"
                  placeholder="{f:t('nav.filter')}"
                  aria-describedby="nav-filter-hint"
                  aria-keyshortcuts="/ Escape" />
                <kbd class="nav-slash" aria-hidden="true">/</kbd>
                <button class="nav-clear" type="button" aria-label="{f:t('nav.clearLabel')}">{f:t('nav.clear')}</button>
              </div>
              <p id="nav-filter-hint" class="visually-hidden">{f:t('nav.filterHint')}</p>
              <p class="nav-result-note" role="status" aria-live="polite" hidden="hidden" />
            </search>
            <xsl:for-each select="$kind-order">
              <xsl:variable name="kind" select="." />
              <xsl:variable name="items" select="$components[f:kind(.) = $kind]" />
              <xsl:if test="exists($items)">
                <div class="nav-group" data-kind="{$kind}">
                  <button class="nav-group__head" type="button" aria-expanded="true">
                    <span class="nav-group__swatch" aria-hidden="true" />
                    <span class="nav-group__label">{f:kind-plural($kind)}</span>
                    <span class="nav-group__count" data-total="{count($items)}">{count($items)}</span>
                  </button>
                  <ul class="nav-list">
                    <xsl:for-each select="$items">
                      <xsl:sort select="f:effective-ns(., $schemas)" />
                      <xsl:sort select="lower-case(string(@name))" />
                      <xsl:sort select="string(@name)" />
                      <xsl:sort select="count(preceding::*)" data-type="number" />
                      <li>
                        <a class="nav-link" href="#{f:anchor(., $schemas)}">
                          <span class="nav-link__name">{@name}</span>
                          <span class="nav-link__hit" hidden="hidden">{f:t('nav.docMatch')}</span>
                        </a>
                      </li>
                    </xsl:for-each>
                  </ul>
                </div>
              </xsl:if>
            </xsl:for-each>
          </nav>
          <main class="main" id="main" tabindex="-1">
            <div class="main__inner">
              <xsl:call-template name="overview">
                <xsl:with-param name="title" select="$derived-title" />
                <xsl:with-param name="schemas" select="$schemas" />
                <xsl:with-param name="components" select="$components" />
                <xsl:with-param name="config" select="$config" />
              </xsl:call-template>
              <xsl:for-each select="$kind-order">
                <xsl:variable name="kind" select="." />
                <xsl:variable name="items" select="$components[f:kind(.) = $kind]" />
                <xsl:if test="exists($items)">
                  <section
                    class="kind-section"
                    id="kind-{f:kind-abbrev($kind)}"
                    aria-labelledby="kind-{f:kind-abbrev($kind)}-title">
                    <div class="section-head">
                      <p
                        class="eyebrow">{count($items)} {if (count($items) = 1) then f:t('count.one') else f:t('count.many')}</p>
                      <h2 id="kind-{f:kind-abbrev($kind)}-title">{f:kind-plural($kind)}</h2>
                    </div>
                    <xsl:for-each select="$items">
                      <xsl:sort select="f:effective-ns(., $schemas)" />
                      <xsl:sort select="lower-case(string(@name))" />
                      <xsl:sort select="string(@name)" />
                      <xsl:sort select="count(preceding::*)" data-type="number" />
                      <xsl:call-template name="component">
                        <xsl:with-param name="node" select="." />
                        <xsl:with-param name="schemas" select="$schemas" />
                        <xsl:with-param name="components" select="$components" />
                        <xsl:with-param name="config" select="$config" />
                        <xsl:with-param name="type-users-index" select="$type-users-index" tunnel="yes" />
                        <xsl:with-param name="keyref-index" select="$keyref-index" tunnel="yes" />
                        <xsl:with-param name="element-ref-index" select="$element-ref-index" tunnel="yes" />
                        <xsl:with-param name="group-ref-index" select="$group-ref-index" tunnel="yes" />
                        <xsl:with-param
                          name="attribute-group-ref-index"
                          select="$attribute-group-ref-index"
                          tunnel="yes" />
                        <xsl:with-param name="attribute-ref-index" select="$attribute-ref-index" tunnel="yes" />
                        <xsl:with-param name="unresolved-refs" select="$unresolved-refs" tunnel="yes" />
                      </xsl:call-template>
                    </xsl:for-each>
                  </section>
                </xsl:if>
              </xsl:for-each>
              <xsl:call-template name="diagnostics">
                <xsl:with-param name="schemas" select="$schemas" />
                <xsl:with-param name="components" select="$components" />
                <xsl:with-param name="config" select="$config" />
                <xsl:with-param name="unresolved" select="$unresolved-refs" />
              </xsl:call-template>
            </div>
          </main>
          <footer class="colophon">
            <div class="colophon__inner">
              <p>
                <xsl:value-of select="f:t('colophon.generated')" />
                <xsl:text> </xsl:text>
                <a
                href="https://github.com/bardiharborow/xsdstyle"
                rel="external noopener noreferrer"
                target="_blank">xsdstyle</a>
                <xsl:text> </xsl:text>
                <xsl:value-of select="$version" />.
              </p>
            </div>
          </footer>
        </div>
        <p id="copy-status" class="visually-hidden" role="status" aria-live="polite" />
        <script type="application/json" id="xsdoc-i18n">
          <xsl:value-of
            select="serialize(
              map {
                'filterResults': f:t('js.filterResults'),
                'copyOk': f:t('js.copyOk'),
                'copyFailed': f:t('js.copyFailed')
              },
              map { 'method': 'json' })" />
        </script>
      </body>
    </html>
  </xsl:template>

  <xsl:template name="overview">
    <xsl:param name="title" as="xs:string" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="components" as="element()*" />
    <xsl:param name="config" as="map(*)" />
    <section class="overview" id="overview" aria-labelledby="ov-title">
      <p class="eyebrow">{f:t('overview.eyebrow')}</p>
      <h1 class="overview__title" id="ov-title">{$title}</h1>
      <xsl:if test="$config?documentation-markup = 'permissive'">
        <p class="notice notice--unsafe" role="note" data-code="permissive-markup">{f:t('notice.permissiveMarkup')}</p>
      </xsl:if>
      <xsl:if test="xs:annotation">
        <section class="block" aria-labelledby="overview-doc-title">
          <h2 class="block__title" id="overview-doc-title">{f:t('overview.annotation')}</h2>
          <xsl:apply-templates select="xs:annotation" mode="annotation">
            <xsl:with-param name="config" select="$config" tunnel="yes" />
          </xsl:apply-templates>
        </section>
      </xsl:if>
      <section class="block" aria-labelledby="overview-metadata-title">
        <h2 class="block__title" id="overview-metadata-title">{f:t('overview.metadata')}</h2>
        <dl class="proplist">
          <div>
            <dt>{f:t('overview.primaryUri')}</dt>
            <dd>
              <code dir="ltr">{f:relativize(f:doc-uri(.), f:primary-base($schemas))}</code>
            </dd>
          </div>
          <div>
            <dt>{f:t('overview.declaredNs')}</dt>
            <dd>
              <code dir="ltr">{if (@targetNamespace) then string(@targetNamespace) else f:t('schema.none')}</code>
            </dd>
          </div>
          <xsl:for-each
            select="@version | @id | @xml:lang | @elementFormDefault | @attributeFormDefault | @blockDefault | @finalDefault | @xpathDefaultNamespace | @defaultAttributes | @defaultAttributesApply">
            <div>
              <dt>{name()}</dt>
              <dd>
                <code dir="ltr">{if (normalize-space(.) ne '') then string(.) else f:t('schema.none')}</code>
              </dd>
            </div>
          </xsl:for-each>
        </dl>
      </section>
      <xsl:if test="@defaultAttributes or xs:defaultOpenContent">
        <section class="block" aria-labelledby="overview-defaults-title">
          <h2 class="block__title" id="overview-defaults-title">{f:t('overview.defaults')}</h2>
          <dl class="proplist">
            <xsl:if test="@defaultAttributes">
              <div>
                <dt>{f:t('field.defaultAttributes')}</dt>
                <dd>
                  <code dir="ltr">{@defaultAttributes}</code>
                </dd>
              </div>
            </xsl:if>
            <xsl:if test="@defaultAttributesApply">
              <div>
                <dt>{f:t('field.defaultAttributesApply')}</dt>
                <dd>
                  <code dir="ltr">{@defaultAttributesApply}</code>
                </dd>
              </div>
            </xsl:if>
            <xsl:if test="xs:defaultOpenContent">
              <div>
                <dt>{f:t('field.defaultOpenContent')}</dt>
                <dd>
                  <div class="tree" role="list">
                    <xsl:apply-templates select="xs:defaultOpenContent" mode="particle" />
                  </div>
                </dd>
              </div>
            </xsl:if>
          </dl>
        </section>
      </xsl:if>
      <section class="block" aria-labelledby="overview-features-title">
        <h2 class="block__title" id="overview-features-title">{f:t('overview.features')}</h2>
        <xsl:variable name="nodes" select="$schemas ! ?node" />
        <xsl:variable
          name="facet-names"
          select="('length', 'minLength', 'maxLength', 'pattern', 'enumeration', 'whiteSpace', 'maxInclusive', 'maxExclusive', 'minInclusive', 'minExclusive', 'totalDigits', 'fractionDigits', 'explicitTimezone')" />
        <xsl:variable name="f10" as="element()*">
          <xsl:if test="exists($nodes//(xs:complexContent | xs:simpleContent)/(xs:extension | xs:restriction))">
            <li>{f:t('feat.derivation')}</li>
          </xsl:if>
          <xsl:if test="exists($nodes//xs:element/@substitutionGroup)">
            <li>{f:t('feat.substitution')}</li>
          </xsl:if>
          <xsl:if test="exists($nodes//(xs:key | xs:keyref | xs:unique))">
            <li>{f:t('feat.identity')} <code dir="ltr">key / keyref / unique</code></li>
          </xsl:if>
          <xsl:if test="exists($nodes/(xs:import | xs:include | xs:redefine))">
            <li>{f:t('feat.composition')} <code dir="ltr">import / include / redefine</code></li>
          </xsl:if>
          <xsl:if test="exists($nodes//(xs:any | xs:anyAttribute))">
            <li>{f:t('feat.wildcards')} <code dir="ltr">any / anyAttribute</code></li>
          </xsl:if>
          <xsl:if
            test="exists($nodes//*[@abstract or @block or @final]) or exists($nodes/(@blockDefault | @finalDefault))">
            <li>{f:t('feat.abf')}</li>
          </xsl:if>
          <xsl:if test="exists($components[self::xs:group or self::xs:attributeGroup])">
            <li>{f:t('feat.namedGroups')}</li>
          </xsl:if>
          <xsl:if test="exists($nodes//xs:restriction/*[local-name() = $facet-names])">
            <li>{f:t('feat.facets')}</li>
          </xsl:if>
          <xsl:if test="exists($components[self::xs:notation])">
            <li>{f:t('feat.notations')}</li>
          </xsl:if>
        </xsl:variable>
        <xsl:variable name="f11" as="element()*">
          <xsl:if test="exists($nodes//xs:assert)">
            <li>{f:t('feat.assertions')} <code dir="ltr">xs:assert</code></li>
          </xsl:if>
          <xsl:if test="exists($nodes//xs:assertion)">
            <li>{f:t('feat.assertionFacets')} <code dir="ltr">xs:assertion</code></li>
          </xsl:if>
          <xsl:if test="exists($nodes//xs:alternative)">
            <li>{f:t('feat.cta')} <code dir="ltr">xs:alternative</code></li>
          </xsl:if>
          <xsl:if test="exists($nodes//xs:openContent) or exists($nodes/xs:defaultOpenContent)">
            <li>{f:t('feat.openContent')}</li>
          </xsl:if>
          <xsl:if test="exists($nodes//xs:attribute[f:xsd-true(string(@inheritable))])">
            <li>{f:t('feat.inheritable')}</li>
          </xsl:if>
          <xsl:if test="exists($nodes//@notNamespace) or exists($nodes//@notQName)">
            <li>{f:t('feat.negWildcards')} <code dir="ltr">notNamespace / notQName</code></li>
          </xsl:if>
          <xsl:if test="exists($nodes/@defaultAttributes) or exists($nodes//@defaultAttributesApply)">
            <li>{f:t('field.defaultAttributes')}</li>
          </xsl:if>
          <xsl:if test="exists($nodes//@*[namespace-uri() = $vc-ns])">
            <li>{f:t('feat.versioning')} <code dir="ltr">vc:*</code>
              <!--
                vc:* can sit deeply inside a component, so the summary groups
                the annotations by their nearest named owning component
                instead of listing every carrying element (spec §22).
              -->
              <xsl:variable
              name="vc-owners"
              select="($nodes//@*[namespace-uri() = $vc-ns] ! f:owner-component(.)) | ()" />
              <xsl:if test="exists($vc-owners)">
              <xsl:text> </xsl:text>
              <span class="versioning-owners">
                <xsl:for-each select="$vc-owners">
                  <xsl:if test="position() gt 1">, </xsl:if>
                  <a class="xref xref--int" href="#{f:anchor(., $schemas)}">{@name}</a>
                </xsl:for-each>
              </span>
            </xsl:if>
            </li>
          </xsl:if>
          <xsl:if test="exists($nodes/xs:override)">
            <li>{f:t('feat.override')} <code dir="ltr">xs:override</code></li>
          </xsl:if>
        </xsl:variable>
        <div class="featuregroup">
          <h3 class="featuregroup__title" id="overview-feat-10-title">{f:t('feat.heading10')}</h3>
          <ul class="featurelist" data-version="1.0" aria-labelledby="overview-feat-10-title">
            <xsl:choose>
              <xsl:when test="exists($f10)">
                <xsl:copy-of select="$f10" />
              </xsl:when>
              <xsl:otherwise>
                <li class="muted">{f:t('feat.none')}</li>
              </xsl:otherwise>
            </xsl:choose>
          </ul>
        </div>
        <div class="featuregroup">
          <h3 class="featuregroup__title" id="overview-feat-11-title">{f:t('feat.heading11')}</h3>
          <ul class="featurelist" data-version="1.1" aria-labelledby="overview-feat-11-title">
            <xsl:choose>
              <xsl:when test="exists($f11)">
                <xsl:copy-of select="$f11" />
              </xsl:when>
              <xsl:otherwise>
                <li class="muted">{f:t('feat.none')}</li>
              </xsl:otherwise>
            </xsl:choose>
          </ul>
        </div>
      </section>
      <section class="block" aria-labelledby="schema-documents-title">
        <h2 class="block__title" id="schema-documents-title">{f:t('overview.documents')}</h2>
        <div class="schemas">
          <xsl:for-each select="$schemas">
            <xsl:variable name="record" select="." />
            <div
              class="schema-row"
              id="schema-doc-s{position()}"
              data-document-id="s{position()}"
              data-status="{$record?load-status}">
              <span
                class="schema-row__rel"
                data-rel="{if ($record?is-primary) then 'primary' else 'reachable'}">{f:t(if ($record?is-primary) then 'schema.rel.primary' else 'schema.rel.reachable')}</span>
              <span class="schema-row__uri">{f:relativize(string($record?uri), f:primary-base($schemas))}</span>
              <span
                class="schema-row__declared-ns">{f:t('schema.declared')} {if ($record?declared-target-namespace ne '') then $record?declared-target-namespace else f:t('schema.none')}</span>
              <span
                class="schema-row__effective-ns">{f:t('schema.effective')} {if ($record?effective-target-namespace ne '') then $record?effective-target-namespace else f:t('schema.none')}</span>
              <xsl:if test="$record?node/@version">
                <span class="schema-row__version">{f:t('field.version')}: <code dir="ltr">
                  <bdi>{$record?node/@version}</bdi>
                </code></span>
              </xsl:if>
              <span
                class="schema-row__status">{f:t(concat('schema.status.', if ($record?load-status = 'not-loaded') then 'notLoaded' else if ($record?load-status = 'not-requested') then 'notRequested' else 'loaded'))}</span>
            </div>
          </xsl:for-each>
          <xsl:for-each select="$schemas ! ?node/(xs:include | xs:import | xs:redefine | xs:override)">
            <xsl:variable name="declaring-schema" select="ancestor::xs:schema[1]" />
            <div
              class="schema-row"
              id="schema-edge-{position()}"
              data-status="{if (@schemaLocation and doc-available(f:absolute-uri(string(@schemaLocation), base-uri(.)))) then 'loaded' else if (@schemaLocation) then 'not-loaded' else 'not-requested'}">
              <span class="schema-row__in">{f:t('schema.in')} <code
                dir="ltr">{f:relativize(f:doc-uri($declaring-schema), f:primary-base($schemas))}</code></span>
              <span class="schema-row__rel" data-rel="{local-name()}">{local-name()}</span>
              <span
                class="schema-row__uri">{if (@schemaLocation) then string(@schemaLocation) else f:t('schema.noSchemaLocation')}</span>
              <span
                class="schema-row__declared-ns">{f:t('schema.namespace')} {if (@namespace) then string(@namespace) else f:t('schema.none')}</span>
              <xsl:variable name="edge-uri" select="f:absolute-uri(string(@schemaLocation), base-uri(.))" />
              <xsl:if test="@schemaLocation and doc-available($edge-uri) and doc($edge-uri)/*/@version">
                <span class="schema-row__version">{f:t('field.version')}: <code dir="ltr">
                  <bdi>{doc($edge-uri)/*/@version}</bdi>
                </code></span>
              </xsl:if>
              <span
                class="schema-row__status">{f:t(concat('schema.status.', if (@schemaLocation and doc-available($edge-uri)) then 'loaded' else if (@schemaLocation) then 'notLoaded' else 'notRequested'))}</span>
              <xsl:apply-templates select="xs:annotation" mode="annotation">
                <xsl:with-param name="config" select="$config" tunnel="yes" />
              </xsl:apply-templates>
            </div>
          </xsl:for-each>
        </div>
      </section>
    </section>
  </xsl:template>

  <xsl:template name="component">
    <xsl:param name="node" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="components" as="element()*" />
    <xsl:param name="config" as="map(*)" />
    <xsl:variable name="kind" select="f:kind($node)" />
    <xsl:variable name="anchor" select="f:anchor($node, $schemas)" />
    <xsl:variable name="ns" select="f:effective-ns($node, $schemas)" />
    <xsl:variable name="clark" select="concat('{', $ns, '}', string($node/@name))" />
    <article
      class="cmp"
      id="{$anchor}"
      aria-labelledby="{$anchor}-name"
      data-component-id="{$anchor}"
      data-kind="{$kind}"
      data-name="{$node/@name}"
      data-clark="{$clark}"
      data-doc="{normalize-space(string-join($node/xs:annotation/xs:documentation//text(), ' '))}">
      <header class="cmp__head">
        <div class="cmp__id">
          <div class="cmp__titleline">
            <span class="kind" data-kind="{$kind}">{f:kind-label($kind)}</span>
            <h3 class="cmp__name" id="{$anchor}-name">
              <bdi>{$node/@name}</bdi>
            </h3>
            <div class="flags">
              <xsl:if test="$node/@abstract = ('true', '1')">
                <span class="flag" data-flag="abstract">{f:t('flag.abstract')}</span>
              </xsl:if>
              <xsl:if test="$node/@mixed = ('true', '1')">
                <span class="flag" data-flag="mixed">{f:t('flag.mixed')}</span>
              </xsl:if>
              <xsl:if test="$node/@nillable = ('true', '1')">
                <span class="flag" data-flag="nillable">{f:t('flag.nillable')}</span>
              </xsl:if>
              <xsl:if test="$node/ancestor::xs:redefine">
                <span class="flag" data-flag="redefined">{f:t('flag.redefined')}</span>
              </xsl:if>
              <xsl:if test="$node/ancestor::xs:override">
                <span class="flag" data-flag="overridden">{f:t('flag.overridden')}</span>
              </xsl:if>
              <xsl:if test="f:has-xsd11($node)">
                <span class="flag" data-flag="xsd11">{f:t('flag.xsd11feature')}</span>
              </xsl:if>
            </div>
          </div>
          <code class="cmp__fqn" dir="ltr">
            <bdi>{$clark}</bdi>
          </code>
          <div class="cmp__meta">
            <span>{f:t('component.definedIn')} <a
              href="#schema-doc-s{index-of($schemas?uri, f:doc-uri($node/ancestor::xs:schema[1]))[1]}">{f:relativize(f:doc-uri($node/ancestor::xs:schema[1]), f:primary-base($schemas))}</a></span>
          </div>
        </div>
        <div class="cmp__actions">
          <button
            class="iconbtn"
            type="button"
            data-copy-link="{$anchor}"
            title="{f:t('action.copyLinkLabel')}"
            aria-label="{f:t('action.copyLinkLabel')}">
            <xsl:sequence select="f:icon('ico-copy-link')" />
            <xsl:sequence select="f:icon('ico-copy-check')" />
            <span class="copybtn__tip" aria-hidden="true">{f:t('action.copied')}</span>
          </button>
        </div>
      </header>
      <div class="cmp__body">
        <xsl:if test="$node/xs:annotation">
          <section class="block">
            <h4 class="block__title" id="{$anchor}-doc-title">{f:t('field.documentation')}</h4>
            <xsl:apply-templates select="$node/xs:annotation" mode="annotation">
              <xsl:with-param name="config" select="$config" tunnel="yes" />
            </xsl:apply-templates>
          </section>
        </xsl:if>
        <xsl:call-template name="component-properties">
          <xsl:with-param name="node" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$anchor" />
        </xsl:call-template>
        <xsl:call-template name="component-detail">
          <xsl:with-param name="node" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="components" select="$components" />
          <xsl:with-param name="anchor" select="$anchor" />
          <xsl:with-param name="config" select="$config" />
        </xsl:call-template>
        <xsl:call-template name="see-also">
          <xsl:with-param name="node" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="components" select="$components" />
          <xsl:with-param name="anchor" select="$anchor" />
        </xsl:call-template>
        <xsl:if test="$config?show-source">
          <details class="disclosure" data-kind-block="source">
            <summary>{f:t('block.source')} <span class="src-lang">xml</span></summary>
            <pre class="src" dir="ltr">
              <code>
                <xsl:apply-templates select="$node" mode="source" />
              </code>
            </pre>
          </details>
        </xsl:if>
      </div>
    </article>
  </xsl:template>

  <xsl:template name="component-properties">
    <xsl:param name="node" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:variable
      name="reference-attributes"
      select="$node/@type | $node/@base | $node/@ref | $node/@substitutionGroup | $node/@itemType | $node/@memberTypes | $node/@refer | $node/@defaultAttributes" />
    <xsl:variable
      name="literal-attributes"
      select="$node/@*[not(local-name() = ('name', 'abstract', 'mixed', 'nillable', 'type', 'base', 'ref', 'substitutionGroup', 'itemType', 'memberTypes', 'refer', 'defaultAttributes', 'public', 'system'))]" />
    <xsl:if test="exists($reference-attributes | $literal-attributes)">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-props-title">{f:t('block.properties')}</h4>
        <dl class="proplist">
          <xsl:for-each select="$reference-attributes">
            <div>
              <dt>{name()}</dt>
              <dd>
                <xsl:choose>
                  <xsl:when test="local-name() = 'memberTypes'">
                    <xsl:for-each select="tokenize(normalize-space(.), '\s+')">
                      <xsl:call-template name="render-reference">
                        <xsl:with-param name="lexical" select="." />
                        <xsl:with-param name="context" select="$node" />
                        <xsl:with-param name="expected" select="'type'" />
                        <xsl:with-param name="schemas" select="$schemas" />
                        <xsl:with-param name="source-attr" select="$node/@memberTypes" />
                      </xsl:call-template>
                      <xsl:if test="position() ne last()" />
                    </xsl:for-each>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:call-template name="render-reference">
                      <xsl:with-param name="lexical" select="string(.)" />
                      <xsl:with-param name="context" select="$node" />
                      <xsl:with-param
                        name="expected"
                        select="
                        if (local-name() = ('type', 'base', 'itemType', 'defaultAttributes')) then
                          if (local-name() = 'defaultAttributes') then 'attributeGroup' else 'type'
                        else if (local-name() = 'ref' and $node/self::xs:attribute) then 'attribute'
                        else if (local-name() = 'ref' and $node/self::xs:attributeGroup) then 'attributeGroup'
                        else if (local-name() = 'ref' and $node/self::xs:group) then 'group'
                        else if (local-name() = 'refer') then ''
                        else 'element'" />
                      <xsl:with-param name="schemas" select="$schemas" />
                      <xsl:with-param name="source-attr" select="." />
                    </xsl:call-template>
                  </xsl:otherwise>
                </xsl:choose>
              </dd>
            </div>
          </xsl:for-each>
          <xsl:for-each select="$literal-attributes">
            <div>
              <dt>{name()}</dt>
              <dd>
                <code dir="ltr">
                  <bdi>{.}</bdi>
                </code>
              </dd>
            </div>
          </xsl:for-each>
        </dl>
      </section>
    </xsl:if>
  </xsl:template>

  <xsl:template name="component-detail">
    <xsl:param name="node" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="components" as="element()*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:param name="config" as="map(*)" />
    <xsl:choose>
      <xsl:when test="$node/self::xs:element">
        <xsl:call-template name="element-detail">
          <xsl:with-param name="node" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$anchor" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$node/self::xs:complexType">
        <xsl:call-template name="complex-type-detail">
          <xsl:with-param name="node" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$anchor" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$node/self::xs:simpleType">
        <xsl:call-template name="simple-type-detail">
          <xsl:with-param name="node" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$anchor" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$node/self::xs:attribute">
        <xsl:if test="$node/xs:simpleType">
          <section class="block">
            <h4 class="block__title" id="{$anchor}-inline-type-title">{f:t('msg.anonymousType')}</h4>
            <xsl:apply-templates select="$node/xs:simpleType" mode="inline-type">
              <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
            </xsl:apply-templates>
          </section>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$node/self::xs:attributeGroup">
        <xsl:call-template name="attribute-uses">
          <xsl:with-param name="owner" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$anchor" />
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$node/self::xs:group">
        <section class="block">
          <h4 class="block__title" id="{$anchor}-model-title">{f:t('block.modelGroup')}</h4>
          <div class="tree" role="list">
            <xsl:apply-templates select="$node/(xs:all | xs:choice | xs:sequence)" mode="particle">
              <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
            </xsl:apply-templates>
          </div>
        </section>
      </xsl:when>
      <xsl:when test="$node/self::xs:notation">
        <section class="block">
          <h4 class="block__title" id="{$anchor}-notation-title">{f:t('block.notationIds')}</h4>
          <dl class="proplist">
            <xsl:if test="$node/@public">
              <div>
                <dt>{f:t('field.public')}</dt>
                <dd>
                  <code dir="ltr">{$node/@public}</code>
                </dd>
              </div>
            </xsl:if>
            <xsl:if test="$node/@system">
              <div>
                <dt>{f:t('field.system')}</dt>
                <dd>
                  <code dir="ltr">{$node/@system}</code>
                </dd>
              </div>
            </xsl:if>
          </dl>
        </section>
      </xsl:when>
    </xsl:choose>
    <xsl:if test="$node//@*[namespace-uri() = $vc-ns]">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-versioning-title">{f:t('block.versioning')}</h4>
        <ul class="featurelist">
          <xsl:for-each select="$node//@*[namespace-uri() = $vc-ns]">
            <li><code dir="ltr">{name()}</code> {f:t('versioning.on')} <code dir="ltr">{name(..)}</code>: <code
              dir="ltr">{.}</code></li>
          </xsl:for-each>
        </ul>
        <p>{f:t('versioning.note')}</p>
      </section>
    </xsl:if>
  </xsl:template>

  <xsl:template name="element-detail">
    <xsl:param name="node" as="element(xs:element)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:if test="$node/xs:complexType | $node/xs:simpleType">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-inline-type-title">{f:t('msg.anonymousType')}</h4>
        <xsl:apply-templates select="$node/(xs:complexType | xs:simpleType)" mode="inline-type">
          <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
        </xsl:apply-templates>
      </section>
    </xsl:if>
    <xsl:if test="$node/(xs:key | xs:keyref | xs:unique)">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-identity-title">{f:t('block.identityConstraints')}</h4>
        <xsl:variable
          name="table-label"
          select="f:t('caption.identityConstraints', map { 'name': string($node/@name) })" />
        <div class="tbl-wrap" tabindex="0" role="group" aria-label="{$table-label}">
          <table class="tbl">
            <caption>{$table-label}</caption>
            <thead>
              <tr>
                <th scope="col">{f:t('field.kind')}</th>
                <th scope="col">{f:t('field.name')}</th>
                <th scope="col">{f:t('field.selector')}</th>
                <th scope="col">{f:t('field.fields')}</th>
                <th scope="col">{f:t('field.refer')}</th>
                <th scope="col">{f:t('field.documentation')}</th>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="$node/(xs:key | xs:keyref | xs:unique)">
                <tr id="{f:identity-anchor(., $schemas)}">
                  <th scope="row">
                    <span class="chip" data-ic-kind="{local-name()}">{local-name()}</span>
                  </th>
                  <td>
                    <xsl:choose>
                      <xsl:when test="@name">
                        <code dir="ltr">{@name}</code>
                      </xsl:when>
                      <xsl:when test="@ref">
                        <xsl:variable
                          name="ref-target"
                          select="f:identity-target(string(@ref), ., ('key', 'keyref', 'unique'), $schemas)" />
                        <xsl:choose>
                          <xsl:when test="$ref-target">
                            <a class="xref xref--int" href="#{f:identity-anchor($ref-target, $schemas)}">
                              <bdi>{@ref}</bdi>
                            </a>
                          </xsl:when>
                          <xsl:otherwise>
                            <span class="xref xref--unresolved" tabindex="0" title="{f:t('xref.unresolvedTitle')}">
                              <bdi>{@ref}</bdi>
                            </span>
                          </xsl:otherwise>
                        </xsl:choose>
                      </xsl:when>
                    </xsl:choose>
                  </td>
                  <td>
                    <code dir="ltr">{xs:selector/@xpath}</code>
                  </td>
                  <td>
                    <xsl:if test="xs:field">
                      <ul class="ic-fields">
                        <xsl:for-each select="xs:field">
                          <li>
                            <code dir="ltr">{@xpath}</code>
                          </li>
                        </xsl:for-each>
                      </ul>
                    </xsl:if>
                  </td>
                  <td>
                    <xsl:if test="@refer">
                      <xsl:variable
                        name="target"
                        select="f:identity-target(string(@refer), ., ('key', 'unique'), $schemas)" />
                      <xsl:choose>
                        <xsl:when test="$target">
                          <a class="xref xref--int" href="#{f:identity-anchor($target, $schemas)}">{@refer}</a>
                        </xsl:when>
                        <xsl:otherwise>
                          <span class="xref xref--unresolved" tabindex="0" title="{f:t('xref.unresolvedTitle')}">
                            <bdi>{@refer}</bdi>
                          </span>
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:if>
                  </td>
                  <td>
                    <xsl:apply-templates select="xs:annotation" mode="annotation" />
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
      </section>
    </xsl:if>
    <xsl:call-template name="type-alternatives">
      <xsl:with-param name="node" select="$node" />
      <xsl:with-param name="schemas" select="$schemas" />
      <xsl:with-param name="anchor" select="$anchor" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="type-alternatives">
    <xsl:param name="node" as="element(xs:element)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:if test="$node/xs:alternative">
      <xsl:variable name="enclosing-type" as="element(xs:complexType)?" select="$node/ancestor::xs:complexType[1]" />
      <xsl:variable
        name="inherited"
        as="element()*"
        select="if ($enclosing-type) then f:inheritable-attrs($enclosing-type, $schemas, ()) else ()" />
      <section class="block">
        <h4 class="block__title" id="{$anchor}-alternatives-title">{f:t('block.typeAlternatives')}</h4>
        <xsl:variable
          name="table-label"
          select="f:t('caption.typeAlternatives', map { 'name': string($node/@name) })" />
        <div class="tbl-wrap" tabindex="0" role="group" aria-label="{$table-label}">
          <table class="tbl">
            <caption>{$table-label}</caption>
            <thead>
              <tr>
                <th scope="col">{f:t('field.when')}</th>
                <th scope="col">{f:t('field.type')}</th>
                <th scope="col">{f:t('field.documentation')}</th>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="$node/xs:alternative">
                <tr id="{$anchor}-alt-{position()}">
                  <td>
                    <xsl:choose>
                      <xsl:when test="@test">
                        <code dir="ltr">{@test}</code>
                      </xsl:when>
                      <xsl:otherwise>
                        <em>otherwise</em>
                      </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="@xpathDefaultNamespace">
                      <div class="muted">xpathDefaultNamespace <code dir="ltr">{@xpathDefaultNamespace}</code></div>
                    </xsl:if>
                  </td>
                  <td>
                    <xsl:choose>
                      <xsl:when test="@type">
                        <xsl:call-template name="render-reference">
                          <xsl:with-param name="lexical" select="string(@type)" />
                          <xsl:with-param name="context" select="." />
                          <xsl:with-param name="expected" select="'type'" />
                          <xsl:with-param name="schemas" select="$schemas" />
                          <xsl:with-param name="source-attr" select="@type" />
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:when test="xs:complexType | xs:simpleType">
                        <span class="inline-marker">{f:t('msg.anonymous')}</span>
                        <xsl:apply-templates select="xs:complexType | xs:simpleType" mode="inline-type">
                          <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
                        </xsl:apply-templates>
                      </xsl:when>
                      <xsl:otherwise>
                        <code dir="ltr">xs:error</code>
                      </xsl:otherwise>
                    </xsl:choose>
                  </td>
                  <td>
                    <xsl:apply-templates select="xs:annotation" mode="annotation" />
                  </td>
                </tr>
              </xsl:for-each>
              <xsl:if test="$node/@type and not($node/xs:alternative[not(@test)])">
                <tr>
                  <td>
                    <em>otherwise</em>
                  </td>
                  <td>
                    <xsl:call-template name="render-reference">
                      <xsl:with-param name="lexical" select="string($node/@type)" />
                      <xsl:with-param name="context" select="$node" />
                      <xsl:with-param name="expected" select="'type'" />
                      <xsl:with-param name="schemas" select="$schemas" />
                      <xsl:with-param name="source-attr" select="$node/@type" />
                    </xsl:call-template>
                  </td>
                  <td>
                    <span class="muted">{f:t('typeAlt.implicitFallback')}</span>
                  </td>
                </tr>
              </xsl:if>
            </tbody>
          </table>
        </div>
        <xsl:if test="$inherited">
          <div class="type-alternatives__inherited">
            <h5 id="{$anchor}-altcta-title">{f:t('msg.ctaInheritable')}</h5>
            <p class="type-alt-note">{f:t('msg.ctaInheritableDesc')}</p>
            <ul class="attrs-inherited__list" aria-labelledby="{$anchor}-altcta-title">
              <xsl:for-each select="$inherited">
                <li>
                  <code dir="ltr">@{(@name, @ref)[1]}</code>
                  <xsl:if test="@type"> : <xsl:call-template name="render-reference">
                    <xsl:with-param name="lexical" select="string(@type)" />
                    <xsl:with-param name="context" select="." />
                    <xsl:with-param name="expected" select="'type'" />
                    <xsl:with-param name="schemas" select="$schemas" />
                    <xsl:with-param name="source-attr" select="@type" />
                  </xsl:call-template></xsl:if>
                </li>
              </xsl:for-each>
            </ul>
          </div>
        </xsl:if>
      </section>
    </xsl:if>
  </xsl:template>

  <!--
    Derivation facts (extension/restriction base) shared by named complex
    types and anonymous complex types rendered inline.
  -->
  <xsl:template name="derivation-block">
    <xsl:param name="node" as="element(xs:complexType)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:if test="$node/(xs:complexContent | xs:simpleContent)">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-derivation-title">{f:t('block.derivation')}</h4>
        <dl class="proplist">
          <xsl:for-each select="$node/(xs:complexContent | xs:simpleContent)/(xs:extension | xs:restriction)">
            <div>
              <dt>{local-name()}</dt>
              <dd>
                <xsl:call-template name="render-reference">
                  <xsl:with-param name="lexical" select="string(@base)" />
                  <xsl:with-param name="context" select="." />
                  <xsl:with-param name="expected" select="'type'" />
                  <xsl:with-param name="schemas" select="$schemas" />
                  <xsl:with-param name="source-attr" select="@base" />
                </xsl:call-template>
              </dd>
            </div>
          </xsl:for-each>
        </dl>
      </section>
    </xsl:if>
  </xsl:template>

  <!--
    Content-type classification plus the particle tree, shared by named and
    anonymous complex types. The particle walk reaches through
    complexContent/simpleContent derivation bodies and includes top-level
    group references, so a type whose only particle is xs:group/@ref still
    gets a tree. The tree container is omitted entirely when the type has no
    particles.
  -->
  <xsl:template name="content-model-block">
    <xsl:param name="node" as="element(xs:complexType)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <section class="block">
      <h4 class="block__title" id="{$anchor}-content-title">{f:t('block.contentModel')}</h4>
      <xsl:variable name="content-type" select="f:content-type($node)" />
      <xsl:variable name="is-open" select="exists(f:effective-open-content($node, $schemas))" />
      <p class="content-type" data-content-type="{$content-type}" data-open="{$is-open}">
        <xsl:sequence select="f:t(concat('contentType.', $content-type))" />
        <xsl:if test="$is-open"> · {f:t('contentType.open')}</xsl:if>
      </p>
      <xsl:variable
        name="particles"
        select="$node/(xs:sequence | xs:choice | xs:all | xs:group
          | xs:complexContent/*/(xs:sequence | xs:choice | xs:all | xs:group)
          | xs:simpleContent/*/(xs:sequence | xs:choice | xs:all))" />
      <xsl:if test="$particles">
        <div class="tree" role="list">
          <xsl:apply-templates select="$particles" mode="particle">
            <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
          </xsl:apply-templates>
        </div>
      </xsl:if>
    </section>
  </xsl:template>

  <xsl:template name="complex-type-detail">
    <xsl:param name="node" as="element(xs:complexType)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:call-template name="type-hierarchy">
      <xsl:with-param name="node" select="$node" />
      <xsl:with-param name="schemas" select="$schemas" />
      <xsl:with-param name="anchor" select="$anchor" />
    </xsl:call-template>
    <xsl:call-template name="derivation-block">
      <xsl:with-param name="node" select="$node" />
      <xsl:with-param name="schemas" select="$schemas" />
      <xsl:with-param name="anchor" select="$anchor" />
    </xsl:call-template>
    <xsl:call-template name="content-model-block">
      <xsl:with-param name="node" select="$node" />
      <xsl:with-param name="schemas" select="$schemas" />
      <xsl:with-param name="anchor" select="$anchor" />
    </xsl:call-template>
    <xsl:call-template name="attribute-uses">
      <xsl:with-param name="owner" select="$node" />
      <xsl:with-param name="schemas" select="$schemas" />
      <xsl:with-param name="anchor" select="$anchor" />
    </xsl:call-template>
    <xsl:variable name="default-attrs" select="f:default-attribute-group($node, $schemas)" />
    <xsl:if test="$default-attrs or $node/@defaultAttributesApply">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-default-attrs-title">{f:t('field.defaultAttributes')}</h4>
        <xsl:choose>
          <xsl:when test="$node/@defaultAttributesApply and not(f:xsd-true(string($node/@defaultAttributesApply)))">
            <p><code dir="ltr">defaultAttributesApply="false"</code>{f:t('msg.defaultAttributesNotApplied')}</p>
          </xsl:when>
          <xsl:when test="$default-attrs">
            <p>{f:t('msg.appliedFromSchema')} <code dir="ltr">@defaultAttributes</code> group
              <a class="xref xref--int" href="#{f:anchor($default-attrs, $schemas)}">{$default-attrs/@name}</a>.</p>
            <xsl:call-template name="attribute-uses">
              <xsl:with-param name="owner" select="$default-attrs" />
              <xsl:with-param name="schemas" select="$schemas" />
              <xsl:with-param name="anchor" select="concat($anchor, '-default')" />
            </xsl:call-template>
          </xsl:when>
        </xsl:choose>
      </section>
    </xsl:if>
    <xsl:variable name="effective-open-content" select="f:effective-open-content($node, $schemas)" />
    <xsl:if test="$effective-open-content and empty($node//xs:openContent)">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-open-content-title">{f:t('field.openContent')}</h4>
        <p class="muted">{f:t('msg.inheritedDefaultOpenContent')}</p>
        <div class="tree" role="list">
          <xsl:apply-templates select="$effective-open-content" mode="particle" />
        </div>
      </section>
    </xsl:if>
    <xsl:if test="$node//xs:assert">
      <xsl:call-template name="assertions">
        <xsl:with-param name="owner" select="$node" />
        <xsl:with-param name="anchor" select="$anchor" />
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="$node//xs:openContent">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-open-content-title">{f:t('field.openContent')}</h4>
        <div class="tree" role="list">
          <xsl:apply-templates select="$node//xs:openContent" mode="particle" />
        </div>
      </section>
    </xsl:if>
  </xsl:template>

  <xsl:template name="simple-type-detail">
    <xsl:param name="node" as="element(xs:simpleType)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <section class="block">
      <h4 class="block__title" id="{$anchor}-simple-title">{f:t('block.simpleTypeDef')}</h4>
      <dl class="proplist">
        <xsl:call-template name="simple-type-definition-rows">
          <xsl:with-param name="node" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
        </xsl:call-template>
      </dl>
    </section>
    <xsl:if
      test="$node//xs:restriction/*[local-name() = ('length', 'minLength', 'maxLength', 'pattern', 'enumeration', 'whiteSpace', 'maxInclusive', 'maxExclusive', 'minExclusive', 'minInclusive', 'totalDigits', 'fractionDigits', 'assertion', 'explicitTimezone')]">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-facets-title">{f:t('block.facets')}</h4>
        <xsl:call-template name="facet-table">
          <xsl:with-param name="node" select="$node" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$anchor" />
          <xsl:with-param name="wrap-class" select="'tbl-wrap'" />
        </xsl:call-template>
      </section>
    </xsl:if>
  </xsl:template>

  <xsl:template name="attribute-uses">
    <xsl:param name="owner" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:variable name="attrs" select="$owner//xs:attribute" />
    <xsl:variable name="groups" select="$owner//xs:attributeGroup[@ref]" />
    <xsl:variable name="wildcards" select="$owner//xs:anyAttribute" />
    <xsl:variable
      name="inherited"
      select="if ($owner/self::xs:complexType) then f:inheritable-attrs($owner, $schemas, ()) else ()" />
    <xsl:variable
      name="visited-seed"
      select="if ($owner/self::xs:attributeGroup) then f:clark(f:component-qname($owner, $schemas)) else ()" />
    <xsl:variable name="table-nodes" select="f:attribute-table-nodes($owner, $schemas, $visited-seed)" />
    <xsl:variable name="show-inheritable" select="exists($table-nodes[self::xs:attribute]/@inheritable)" />
    <xsl:variable name="show-doc" select="exists($table-nodes/xs:annotation[f:annotation-renders(.)])" />
    <xsl:if test="$attrs or $groups or $wildcards or $inherited">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-attrs-title">{f:t('block.attributes')}</h4>
        <xsl:variable
          name="table-label"
          select="f:t('caption.attributeUses', map { 'name': (string($owner/@name)[. ne ''], f:t('name.anonymousComplexType'))[1] })" />
        <div class="tbl-wrap" tabindex="0" role="group" aria-label="{$table-label}">
          <table class="tbl">
            <caption>{$table-label}</caption>
            <thead>
              <tr>
                <th scope="col">{f:t('field.name')}</th>
                <th scope="col">{f:t('field.typeRef')}</th>
                <th scope="col">{f:t('field.use')}</th>
                <th scope="col">{f:t('field.valueConstraint')}</th>
                <xsl:if test="$show-inheritable">
                  <th scope="col">{f:t('field.inheritable')}</th>
                </xsl:if>
                <xsl:if test="$show-doc">
                  <th scope="col">{f:t('field.documentation')}</th>
                </xsl:if>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="$attrs">
                <xsl:call-template name="attribute-use-row">
                  <xsl:with-param name="attr" select="." />
                  <xsl:with-param name="schemas" select="$schemas" />
                  <xsl:with-param name="show-inheritable" select="$show-inheritable" />
                  <xsl:with-param name="show-doc" select="$show-doc" />
                </xsl:call-template>
              </xsl:for-each>
              <xsl:for-each select="$groups">
                <xsl:call-template name="attribute-group-rows">
                  <xsl:with-param name="group-ref" select="." />
                  <xsl:with-param name="schemas" select="$schemas" />
                  <xsl:with-param name="visited" select="$visited-seed" />
                  <xsl:with-param name="show-inheritable" select="$show-inheritable" />
                  <xsl:with-param name="show-doc" select="$show-doc" />
                </xsl:call-template>
              </xsl:for-each>
              <xsl:for-each select="$wildcards">
                <xsl:call-template name="any-attribute-row">
                  <xsl:with-param name="wildcard" select="." />
                  <xsl:with-param name="schemas" select="$schemas" />
                  <xsl:with-param name="show-inheritable" select="$show-inheritable" />
                  <xsl:with-param name="show-doc" select="$show-doc" />
                </xsl:call-template>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
        <xsl:if test="$inherited">
          <div class="component__attrs-inherited">
            <h5 id="{$anchor}-attrcta-title">{f:t('msg.ctaInheritable')}</h5>
            <ul class="attrs-inherited__list" aria-labelledby="{$anchor}-attrcta-title">
              <xsl:for-each select="$inherited">
                <li>
                  <code dir="ltr">@<bdi>{(@name, @ref)[1]}</bdi></code>
                  <xsl:if test="@type"> : <xsl:call-template name="render-reference">
                    <xsl:with-param name="lexical" select="string(@type)" />
                    <xsl:with-param name="context" select="." />
                    <xsl:with-param name="expected" select="'type'" />
                    <xsl:with-param name="schemas" select="$schemas" />
                    <xsl:with-param name="source-attr" select="@type" />
                  </xsl:call-template></xsl:if>
                </li>
              </xsl:for-each>
            </ul>
          </div>
        </xsl:if>
      </section>
    </xsl:if>
  </xsl:template>

  <xsl:template name="type-hierarchy">
    <xsl:param name="node" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:variable name="ancestors" select="reverse(f:type-ancestors($node, $schemas, ()))" />
    <xsl:variable name="self-q" select="f:component-qname($node, $schemas)" />
    <xsl:variable
      name="descendants"
      select="f:component-nodes($schemas)[
      (self::xs:complexType or self::xs:simpleType)
      and f:clark(f:type-base(., $schemas)) = f:clark($self-q)
    ]" />
    <xsl:if test="$ancestors or $descendants">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-hierarchy-title">{f:t('block.typeHierarchy')}</h4>
        <div class="deriv">
          <ul>
            <xsl:call-template name="hierarchy-tree">
              <xsl:with-param name="ancestors" select="$ancestors" />
              <xsl:with-param name="self" select="$node" />
              <xsl:with-param name="descendants" select="$descendants" />
              <xsl:with-param name="schemas" select="$schemas" />
            </xsl:call-template>
          </ul>
        </div>
      </section>
    </xsl:if>
  </xsl:template>

  <!--
    Emit a nested <li> chain: root ancestor wraps the next ancestor, ..., which
    wraps the current type (.is-this), which in turn wraps its direct
    descendants. When $ancestors is empty the current type is the rendered root.
    $ancestors is root-first.
  -->
  <xsl:template name="hierarchy-tree">
    <xsl:param name="ancestors" as="element()*" />
    <xsl:param name="self" as="element()" />
    <xsl:param name="descendants" as="element()*" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:choose>
      <xsl:when test="empty($ancestors)">
        <li class="deriv__node is-this" aria-current="location">
          <span class="deriv__name">{$self/@name}</span>
          <span class="deriv__this-tag">{f:t('deriv.thisType')}</span>
          <xsl:if test="$descendants">
            <ul class="deriv__children">
              <xsl:for-each select="$descendants">
                <xsl:sort select="@name" />
                <li class="deriv__node deriv__node--descendant">
                  <a class="xref xref--int" href="#{f:anchor(., $schemas)}">{@name}</a>
                  <span class="deriv__rel"> {f:t('deriv.descendant')}</span>
                </li>
              </xsl:for-each>
            </ul>
          </xsl:if>
        </li>
      </xsl:when>
      <xsl:otherwise>
        <li class="deriv__node deriv__node--ancestor">
          <a class="xref xref--int" href="#{f:anchor($ancestors[1], $schemas)}">{$ancestors[1]/@name}</a>
          <ul class="deriv__children">
            <xsl:call-template name="hierarchy-tree">
              <xsl:with-param name="ancestors" select="tail($ancestors)" />
              <xsl:with-param name="self" select="$self" />
              <xsl:with-param name="descendants" select="$descendants" />
              <xsl:with-param name="schemas" select="$schemas" />
            </xsl:call-template>
          </ul>
        </li>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="assertions">
    <xsl:param name="owner" as="element()" />
    <xsl:param name="anchor" as="xs:string" />
    <section class="block">
      <h4 class="block__title" id="{$anchor}-assertions-title">{f:t('block.assertions')}</h4>
      <xsl:variable
        name="table-label"
        select="f:t('caption.assertions', map { 'name': (string($owner/@name)[. ne ''], f:t('name.anonymousComplexType'))[1] })" />
      <div class="tbl-wrap" tabindex="0" role="group" aria-label="{$table-label}">
        <table class="tbl">
          <caption>{$table-label}</caption>
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">{f:t('field.test')}</th>
              <th scope="col">{f:t('field.documentation')}</th>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="$owner//xs:assert">
              <tr id="{$anchor}-assert-{position()}">
                <td>{position()}</td>
                <td>
                  <code dir="ltr">{@test}</code>
                  <xsl:if test="@xpathDefaultNamespace">
                    <div class="muted">xpathDefaultNamespace <code dir="ltr">{@xpathDefaultNamespace}</code></div>
                  </xsl:if>
                </td>
                <td>
                  <xsl:apply-templates select="xs:annotation" mode="annotation" />
                </td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
      </div>
    </section>
  </xsl:template>

  <xsl:template name="see-also">
    <xsl:param name="node" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="components" as="element()*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:param name="type-users-index" as="map(*)" tunnel="yes" />
    <xsl:param name="keyref-index" as="map(*)" tunnel="yes" />
    <xsl:param name="element-ref-index" as="map(*)" tunnel="yes" />
    <xsl:param name="group-ref-index" as="map(*)" tunnel="yes" />
    <xsl:param name="attribute-group-ref-index" as="map(*)" tunnel="yes" />
    <xsl:param name="attribute-ref-index" as="map(*)" tunnel="yes" />
    <xsl:variable name="qname" select="f:component-qname($node, $schemas)" />
    <xsl:variable name="clark" select="f:clark($qname)" />
    <xsl:variable
      name="users-by-type"
      select="
      if ($node/self::xs:complexType or $node/self::xs:simpleType) then
        $type-users-index($clark)
      else ()" />
    <xsl:variable
      name="subst-members"
      select="
      if ($node/self::xs:element) then
        $components[self::xs:element][@substitutionGroup][
          some $sg in tokenize(normalize-space(string(@substitutionGroup)), '\s+')
          satisfies f:clark(f:reference-qname($sg, ., 'element', $schemas)) = $clark
        ]
      else ()" />
    <xsl:variable
      name="element-ref-users"
      select="if ($node/self::xs:element) then $element-ref-index($clark) else ()" />
    <xsl:variable name="group-ref-users" select="if ($node/self::xs:group) then $group-ref-index($clark) else ()" />
    <xsl:variable
      name="attribute-group-ref-users"
      select="if ($node/self::xs:attributeGroup) then $attribute-group-ref-index($clark) else ()" />
    <xsl:variable
      name="attribute-ref-users"
      select="if ($node/self::xs:attribute) then $attribute-ref-index($clark) else ()" />
    <xsl:variable
      name="own-identity-clarks"
      select="
      if ($node/self::xs:element) then
        $node/(xs:key | xs:unique)[@name] ! f:clark(QName(f:effective-ns(., $schemas), string(@name)))
      else ()" />
    <xsl:variable name="keyref-targets" select="$own-identity-clarks ! $keyref-index(.)" />
    <xsl:if
      test="$users-by-type or $element-ref-users or $group-ref-users or $attribute-group-ref-users or $attribute-ref-users or $subst-members or $keyref-targets or $node/self::xs:element/@substitutionGroup">
      <section class="block">
        <h4 class="block__title" id="{$anchor}-see-also-title">{f:t('block.seeAlso')}</h4>
        <xsl:if test="$users-by-type">
          <xsl:call-template name="see-also-owner-group">
            <xsl:with-param name="nodes" select="$users-by-type" />
            <xsl:with-param name="schemas" select="$schemas" />
            <xsl:with-param name="anchor" select="$anchor" />
            <xsl:with-param name="id-suffix" select="'type'" />
            <xsl:with-param name="title-key" select="'seeAlso.usedAsType'" />
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$element-ref-users">
          <xsl:call-template name="see-also-owner-group">
            <xsl:with-param name="nodes" select="$element-ref-users" />
            <xsl:with-param name="schemas" select="$schemas" />
            <xsl:with-param name="anchor" select="$anchor" />
            <xsl:with-param name="id-suffix" select="'elementref'" />
            <xsl:with-param name="title-key" select="'seeAlso.usedAsElementRef'" />
            <xsl:with-param name="relation-label" select="f:kind-label('element')" />
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$group-ref-users">
          <xsl:call-template name="see-also-owner-group">
            <xsl:with-param name="nodes" select="$group-ref-users" />
            <xsl:with-param name="schemas" select="$schemas" />
            <xsl:with-param name="anchor" select="$anchor" />
            <xsl:with-param name="id-suffix" select="'groupref'" />
            <xsl:with-param name="title-key" select="'seeAlso.usedAsGroupRef'" />
            <xsl:with-param name="relation-label" select="f:kind-label('group')" />
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$attribute-group-ref-users">
          <xsl:call-template name="see-also-owner-group">
            <xsl:with-param name="nodes" select="$attribute-group-ref-users" />
            <xsl:with-param name="schemas" select="$schemas" />
            <xsl:with-param name="anchor" select="$anchor" />
            <xsl:with-param name="id-suffix" select="'attrgroupref'" />
            <xsl:with-param name="title-key" select="'seeAlso.usedAsAttributeGroupRef'" />
            <xsl:with-param name="relation-label" select="f:kind-label('attributeGroup')" />
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$attribute-ref-users">
          <xsl:call-template name="see-also-owner-group">
            <xsl:with-param name="nodes" select="$attribute-ref-users" />
            <xsl:with-param name="schemas" select="$schemas" />
            <xsl:with-param name="anchor" select="$anchor" />
            <xsl:with-param name="id-suffix" select="'attrref'" />
            <xsl:with-param name="title-key" select="'seeAlso.usedAsAttributeRef'" />
            <xsl:with-param name="relation-label" select="f:kind-label('attribute')" />
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="$subst-members">
          <div class="see-also__group">
            <h5 id="{$anchor}-seealso-subst">{f:t('seeAlso.substitutionMembers')}</h5>
            <ul aria-labelledby="{$anchor}-seealso-subst">
              <xsl:for-each select="$subst-members">
                <li>
                  <a class="xref xref--int" href="#{f:anchor(., $schemas)}">{@name}</a>
                </li>
              </xsl:for-each>
            </ul>
          </div>
        </xsl:if>
        <xsl:if test="$node/self::xs:element/@substitutionGroup">
          <div class="see-also__group">
            <h5 id="{$anchor}-seealso-heads">{f:t('seeAlso.substitutionHeads')}</h5>
            <ul aria-labelledby="{$anchor}-seealso-heads">
              <xsl:call-template name="substitution-head-items">
                <xsl:with-param name="el" select="$node" />
                <xsl:with-param name="schemas" select="$schemas" />
                <xsl:with-param name="visited" select="$clark" />
              </xsl:call-template>
            </ul>
          </div>
        </xsl:if>
        <xsl:if test="$keyref-targets">
          <div class="see-also__group">
            <h5 id="{$anchor}-seealso-keyref">{f:t('seeAlso.referencedByKeyref')}</h5>
            <ul aria-labelledby="{$anchor}-seealso-keyref">
              <xsl:for-each select="$keyref-targets">
                <xsl:variable name="owner" select="f:owner-component(.)" />
                <li>
                  <a class="xref xref--int" href="#{f:identity-anchor(., $schemas)}">{@name}</a>
                  <xsl:if test="$owner">
                    <span class="muted"> {f:t('seeAlso.in')} <a
                      class="xref xref--int"
                      href="#{f:anchor($owner, $schemas)}">{$owner/@name}</a></span>
                  </xsl:if>
                </li>
              </xsl:for-each>
            </ul>
          </div>
        </xsl:if>
      </section>
    </xsl:if>
  </xsl:template>

  <xsl:template name="see-also-owner-group">
    <xsl:param name="nodes" as="element()*" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:param name="id-suffix" as="xs:string" />
    <xsl:param name="title-key" as="xs:string" />
    <xsl:param name="relation-label" as="xs:string?" select="()" />
    <div class="see-also__group">
      <h5 id="{$anchor}-seealso-{$id-suffix}">{f:t($title-key)}</h5>
      <ul aria-labelledby="{$anchor}-seealso-{$id-suffix}">
        <xsl:for-each select="$nodes">
          <xsl:variable name="owner" select="f:owner-component(.)" />
          <xsl:variable name="usage-name" select="f:usage-name(.)" />
          <xsl:variable name="label" select="($relation-label[. ne ''], local-name())[1]" />
          <xsl:if test="$owner">
            <li>
              <a class="xref xref--int" href="#{f:anchor($owner, $schemas)}">{$owner/@name}</a>
              <span class="muted">
                <xsl:text> </xsl:text>
                <xsl:value-of select="f:t('seeAlso.as')" />
                <xsl:text> </xsl:text>
                <xsl:value-of select="$label" />
                <xsl:if test="$usage-name ne ''">
                  <xsl:text> </xsl:text>
                  <code dir="ltr">{$usage-name}</code>
                </xsl:if>
              </span>
            </li>
          </xsl:if>
        </xsl:for-each>
      </ul>
    </div>
  </xsl:template>

  <!--
    List items for the transitive substitution-group head chain of $el, in
    chain order (direct heads first, then their heads). Each lexical token is
    rendered through render-reference so unresolved heads stay visible. The
    walk is cycle-safe: $visited carries the Clark names already emitted
    (seeded with the starting element), and count($visited) bounds the depth.
  -->
  <xsl:template name="substitution-head-items">
    <xsl:param name="el" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:if test="count($visited) le 32">
      <xsl:for-each select="tokenize(normalize-space(string($el/@substitutionGroup)), '\s+')[. ne '']">
        <xsl:variable name="token" select="." />
        <xsl:variable name="qname" select="f:reference-qname($token, $el, 'element', $schemas)" />
        <xsl:variable name="clark" select="f:clark($qname)" />
        <xsl:variable name="target" select="f:components-matching($qname, 'element', $schemas)[1]" />
        <xsl:if test="empty($clark) or not($clark = $visited)">
          <li>
            <xsl:call-template name="render-reference">
              <xsl:with-param name="lexical" select="$token" />
              <xsl:with-param name="context" select="$el" />
              <xsl:with-param name="expected" select="'element'" />
              <xsl:with-param name="schemas" select="$schemas" />
              <xsl:with-param name="source-attr" select="$el/@substitutionGroup" />
            </xsl:call-template>
          </li>
          <xsl:if test="$target/@substitutionGroup">
            <xsl:call-template name="substitution-head-items">
              <xsl:with-param name="el" select="$target" />
              <xsl:with-param name="schemas" select="$schemas" />
              <xsl:with-param name="visited" select="($visited, $clark)" />
            </xsl:call-template>
          </xsl:if>
        </xsl:if>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <xsl:template name="simple-type-definition-rows">
    <xsl:param name="node" as="element(xs:simpleType)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="variety" select="f:simple-type-variety($node, $schemas, ())" />
    <div>
      <dt>{f:t('field.variety')}</dt>
      <dd data-variety="{$variety}">{f:t(concat('variety.', $variety))}</dd>
    </div>
    <xsl:variable name="derivation" select="local-name($node/(xs:restriction | xs:list | xs:union)[1])" />
    <xsl:if test="$derivation ne ''">
      <div>
        <dt>{f:t('field.derivedBy')}</dt>
        <dd data-derivation="{$derivation}">{f:t(concat('derivation.', $derivation))}</dd>
      </div>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="$node/xs:restriction">
        <xsl:if test="$node/xs:restriction/@base">
          <div>
            <dt>{f:t('field.baseType')}</dt>
            <dd>
              <xsl:call-template name="render-reference">
                <xsl:with-param name="lexical" select="string($node/xs:restriction/@base)" />
                <xsl:with-param name="context" select="$node/xs:restriction" />
                <xsl:with-param name="expected" select="'type'" />
                <xsl:with-param name="schemas" select="$schemas" />
                <xsl:with-param name="source-attr" select="$node/xs:restriction/@base" />
              </xsl:call-template>
            </dd>
          </div>
          <xsl:variable
            name="base-qname"
            select="f:reference-qname(string($node/xs:restriction/@base), $node/xs:restriction, 'type', $schemas)" />
          <xsl:variable
            name="ff"
            select="if (f:is-builtin-type($base-qname)) then f:fundamental-facets(local-name-from-QName($base-qname)) else ()" />
          <xsl:if test="exists($ff)">
            <div>
              <dt>{f:t('ff.heading')}</dt>
              <dd class="fundamental-facets" data-ff-type="{local-name-from-QName($base-qname)}">
                <xsl:for-each select="('ordered', 'bounded', 'cardinality', 'numeric')">
                  <xsl:if test="position() gt 1">, </xsl:if>
                  <span class="ff" data-ff="{.}">{f:t(concat('ff.', .))} <code dir="ltr">{$ff(.)}</code></span>
                </xsl:for-each>
              </dd>
            </div>
          </xsl:if>
        </xsl:if>
        <xsl:if test="$node/xs:restriction/xs:simpleType">
          <div>
            <dt>{f:t('field.baseType')}</dt>
            <dd>
              <div class="inline-type inline-type--base">
                <xsl:apply-templates select="$node/xs:restriction/xs:simpleType" mode="inline-type">
                  <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
                </xsl:apply-templates>
              </div>
            </dd>
          </div>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$node/xs:list">
        <xsl:if test="$node/xs:list/@itemType">
          <div>
            <dt>{f:t('field.itemType')}</dt>
            <dd>
              <xsl:call-template name="render-reference">
                <xsl:with-param name="lexical" select="string($node/xs:list/@itemType)" />
                <xsl:with-param name="context" select="$node/xs:list" />
                <xsl:with-param name="expected" select="'type'" />
                <xsl:with-param name="schemas" select="$schemas" />
                <xsl:with-param name="source-attr" select="$node/xs:list/@itemType" />
              </xsl:call-template>
            </dd>
          </div>
        </xsl:if>
        <xsl:if test="$node/xs:list/xs:simpleType">
          <div>
            <dt>{f:t('field.itemType')}</dt>
            <dd>
              <div class="inline-type inline-type--item">
                <xsl:apply-templates select="$node/xs:list/xs:simpleType" mode="inline-type">
                  <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
                </xsl:apply-templates>
              </div>
            </dd>
          </div>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$node/xs:union">
        <xsl:if test="$node/xs:union/@memberTypes or $node/xs:union/xs:simpleType">
          <div>
            <dt>{f:t('field.memberTypes')}</dt>
            <dd>
              <xsl:for-each select="tokenize(normalize-space(string($node/xs:union/@memberTypes)), '\s+')[. ne '']">
                <xsl:if test="position() ne 1">
                  <xsl:text> </xsl:text>
                </xsl:if>
                <xsl:call-template name="render-reference">
                  <xsl:with-param name="lexical" select="." />
                  <xsl:with-param name="context" select="$node/xs:union" />
                  <xsl:with-param name="expected" select="'type'" />
                  <xsl:with-param name="schemas" select="$schemas" />
                  <xsl:with-param name="source-attr" select="$node/xs:union/@memberTypes" />
                </xsl:call-template>
              </xsl:for-each>
              <xsl:for-each select="$node/xs:union/xs:simpleType">
                <div class="inline-type inline-type--member">
                  <xsl:apply-templates select="." mode="inline-type">
                    <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
                  </xsl:apply-templates>
                </div>
              </xsl:for-each>
            </dd>
          </div>
        </xsl:if>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!--
    Constraining-facet table shared by top-level and inline simple types.
    Pattern facets get one row per restriction step: patterns within a step
    are alternatives (OR), while steps combine as conjoined constraints
    (AND), so same-step patterns must not render as independent rows.
  -->
  <xsl:template name="facet-table">
    <xsl:param name="node" as="element(xs:simpleType)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="anchor" as="xs:string" />
    <xsl:param name="wrap-class" as="xs:string" select="'tbl-wrap inline-facets'" />
    <xsl:variable
      name="facets"
      select="$node//xs:restriction/*[local-name() = ('length', 'minLength', 'maxLength', 'pattern', 'enumeration', 'whiteSpace', 'maxInclusive', 'maxExclusive', 'minExclusive', 'minInclusive', 'totalDigits', 'fractionDigits', 'assertion', 'explicitTimezone')]" />
    <xsl:if test="$facets">
      <xsl:variable name="is-notation" select="f:is-notation-simple-type($node, $schemas, ())" />
      <xsl:variable name="enum-facets" select="$facets[self::xs:enumeration]" />
      <xsl:variable name="is-code-list" select="exists($enum-facets) and empty($facets except $enum-facets)" />
      <xsl:variable name="pattern-steps" select="$node//xs:restriction[xs:pattern]" />
      <xsl:variable
        name="table-label"
        select="f:t('caption.facets', map { 'name': (string($node/@name)[. ne ''], f:t('name.anonymousSimpleType'))[1] })" />
      <div class="{$wrap-class}" tabindex="0" role="group" aria-label="{$table-label}">
        <xsl:if test="$enum-facets">
          <p class="facet-summary">
            <span class="flag" data-flag="enumeration-count">{f:t(
                if (count($enum-facets) eq 1) then 'facet.enumerationCountOne' else 'facet.enumerationCount',
                map { 'count': count($enum-facets) })}</span>
            <xsl:if test="$is-code-list">
              <span class="flag" data-flag="code-list">{f:t('facet.codeList')}</span>
            </xsl:if>
          </p>
        </xsl:if>
        <table
          class="{if ($is-code-list) then 'tbl tbl--code-list' else 'tbl'}"
          data-enumeration-count="{count($enum-facets)}"
          data-code-list="{if ($is-code-list) then 'true' else 'false'}">
          <caption>{$table-label}</caption>
          <thead>
            <tr>
              <th scope="col">{f:t('field.facet')}</th>
              <th scope="col">{f:t('field.value')}</th>
              <th scope="col">{f:t('field.fixed')}</th>
              <th scope="col">{f:t('field.id')}</th>
              <th scope="col">{f:t('field.documentation')}</th>
            </tr>
          </thead>
          <tbody>
            <xsl:for-each select="$facets[not(self::xs:pattern)]">
              <tr id="{$anchor}-facet-{local-name()}-{position()}">
                <th scope="row">
                  <xsl:variable name="facet-href" select="f:facet-href(local-name())" />
                  <xsl:choose>
                    <xsl:when test="$facet-href">
                      <a
                        class="xref xref--ext xref--builtin"
                        href="{$facet-href}"
                        rel="external noopener noreferrer"
                        target="_blank">{local-name()}</a>
                    </xsl:when>
                    <xsl:otherwise>{local-name()}</xsl:otherwise>
                  </xsl:choose>
                  <xsl:if test="local-name() = ('assertion', 'explicitTimezone')">
                    <xsl:text> </xsl:text>
                    <span class="flag" data-flag="xsd11">{f:t('flag.xsd11')}</span>
                  </xsl:if>
                </th>
                <td>
                  <xsl:choose>
                    <xsl:when test="local-name() = 'enumeration' and $is-notation">
                      <xsl:call-template name="render-reference">
                        <xsl:with-param name="lexical" select="string(@value)" />
                        <xsl:with-param name="context" select="." />
                        <xsl:with-param name="expected" select="'notation'" />
                        <xsl:with-param name="schemas" select="$schemas" />
                      </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                      <code dir="ltr">
                        <bdi>{(@value, @test)[1]}</bdi>
                      </code>
                    </xsl:otherwise>
                  </xsl:choose>
                  <xsl:if test="self::xs:assertion and @xpathDefaultNamespace">
                    <div class="muted">xpathDefaultNamespace <code dir="ltr">{@xpathDefaultNamespace}</code></div>
                  </xsl:if>
                </td>
                <td>
                  <xsl:choose>
                    <xsl:when test="f:xsd-true(string(@fixed))">
                      <span class="flag" data-flag="fixed">{f:t('value.fixed')}</span>
                    </xsl:when>
                    <xsl:when test="@fixed">{string(@fixed)}</xsl:when>
                  </xsl:choose>
                </td>
                <td>
                  <xsl:if test="@id">
                    <code dir="ltr">
                      <bdi>{@id}</bdi>
                    </code>
                  </xsl:if>
                </td>
                <td>
                  <xsl:apply-templates select="xs:annotation" mode="annotation" />
                </td>
              </tr>
            </xsl:for-each>
            <xsl:for-each select="$pattern-steps">
              <tr id="{$anchor}-facet-pattern-step-{position()}" data-restriction-step="{position()}">
                <th scope="row">
                  <xsl:variable name="facet-href" select="f:facet-href('pattern')" />
                  <xsl:choose>
                    <xsl:when test="$facet-href">
                      <a
                        class="xref xref--ext xref--builtin"
                        href="{$facet-href}"
                        rel="external noopener noreferrer"
                        target="_blank">pattern</a>
                    </xsl:when>
                    <xsl:otherwise>pattern</xsl:otherwise>
                  </xsl:choose>
                  <xsl:if test="last() gt 1">
                    <xsl:text> </xsl:text>
                    <span class="muted">{f:t('facet.patternStep', map { 'n': position(), 'm': last() })}</span>
                  </xsl:if>
                </th>
                <td>
                  <xsl:for-each select="xs:pattern">
                    <xsl:if test="position() ne 1">
                      <xsl:text> </xsl:text>
                      <span class="facet-or">{f:t('facet.patternOr')}</span>
                      <xsl:text> </xsl:text>
                    </xsl:if>
                    <code dir="ltr">
                      <bdi>{@value}</bdi>
                    </code>
                  </xsl:for-each>
                </td>
                <td>{string-join(xs:pattern/@fixed, ' ')}</td>
                <td>
                  <xsl:for-each select="xs:pattern[@id]">
                    <xsl:if test="position() ne 1">
                      <xsl:text> </xsl:text>
                    </xsl:if>
                    <code dir="ltr">
                      <bdi>{@id}</bdi>
                    </code>
                  </xsl:for-each>
                </td>
                <td>
                  <xsl:apply-templates select="xs:pattern/xs:annotation" mode="annotation" />
                </td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
      </div>
    </xsl:if>
  </xsl:template>

  <xsl:template match="xs:complexType | xs:simpleType" mode="inline-type">
    <xsl:param name="schemas" as="map(*)*" tunnel="yes" />
    <xsl:choose>
      <xsl:when test="self::xs:complexType">
        <xsl:variable name="local-anchor" select="f:local-anchor(., $schemas)" />
        <p>{f:t('msg.anonymousComplexType')}</p>
        <xsl:call-template name="derivation-block">
          <xsl:with-param name="node" select="self::xs:complexType" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$local-anchor" />
        </xsl:call-template>
        <xsl:call-template name="content-model-block">
          <xsl:with-param name="node" select="self::xs:complexType" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$local-anchor" />
        </xsl:call-template>
        <xsl:call-template name="attribute-uses">
          <xsl:with-param name="owner" select="." />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="$local-anchor" />
        </xsl:call-template>
        <xsl:if test=".//xs:assert">
          <xsl:call-template name="assertions">
            <xsl:with-param name="owner" select="." />
            <xsl:with-param name="anchor" select="$local-anchor" />
          </xsl:call-template>
        </xsl:if>
      </xsl:when>
      <xsl:when test="self::xs:simpleType">
        <xsl:call-template name="inline-simple-type-definition">
          <xsl:with-param name="node" select="self::xs:simpleType" />
          <xsl:with-param name="schemas" select="$schemas" />
        </xsl:call-template>
        <xsl:call-template name="facet-table">
          <xsl:with-param name="node" select="self::xs:simpleType" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="anchor" select="f:local-anchor(., $schemas)" />
        </xsl:call-template>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!--
    Compact definition line for anonymous simple types: the derivation
    keyword front-and-center ("restriction of xs:token") instead of the
    named-type proplist, which reads as noise in nested contexts. Anonymous
    operand types recurse below the headline in their usual inline-type
    wrappers. Types with no derivation child fall back to the proplist so
    the "not specified in source" variety stays visible.
  -->
  <xsl:template name="inline-simple-type-definition">
    <xsl:param name="node" as="element(xs:simpleType)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="derivation" select="local-name($node/(xs:restriction | xs:list | xs:union)[1])" />
    <xsl:choose>
      <xsl:when test="$derivation ne ''">
        <p
          class="inline-def"
          data-derivation="{$derivation}"
          data-variety="{f:simple-type-variety($node, $schemas, ())}">
          <span class="chip" data-derivation="{$derivation}">{f:t(concat('derivation.', $derivation))}</span>
          <span class="inline-def__of">{f:t('derivation.of')}</span>
          <xsl:choose>
            <xsl:when test="$node/xs:restriction/@base">
              <xsl:call-template name="render-reference">
                <xsl:with-param name="lexical" select="string($node/xs:restriction/@base)" />
                <xsl:with-param name="context" select="$node/xs:restriction" />
                <xsl:with-param name="expected" select="'type'" />
                <xsl:with-param name="schemas" select="$schemas" />
                <xsl:with-param name="source-attr" select="$node/xs:restriction/@base" />
              </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node/xs:list/@itemType">
              <xsl:call-template name="render-reference">
                <xsl:with-param name="lexical" select="string($node/xs:list/@itemType)" />
                <xsl:with-param name="context" select="$node/xs:list" />
                <xsl:with-param name="expected" select="'type'" />
                <xsl:with-param name="schemas" select="$schemas" />
                <xsl:with-param name="source-attr" select="$node/xs:list/@itemType" />
              </xsl:call-template>
            </xsl:when>
            <xsl:when test="$node/xs:union/@memberTypes">
              <xsl:for-each select="tokenize(normalize-space(string($node/xs:union/@memberTypes)), '\s+')[. ne '']">
                <xsl:call-template name="render-reference">
                  <xsl:with-param name="lexical" select="." />
                  <xsl:with-param name="context" select="$node/xs:union" />
                  <xsl:with-param name="expected" select="'type'" />
                  <xsl:with-param name="schemas" select="$schemas" />
                  <xsl:with-param name="source-attr" select="$node/xs:union/@memberTypes" />
                </xsl:call-template>
              </xsl:for-each>
            </xsl:when>
          </xsl:choose>
        </p>
        <xsl:for-each select="$node/xs:restriction/xs:simpleType">
          <div class="inline-type inline-type--base">
            <xsl:apply-templates select="." mode="inline-type">
              <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
            </xsl:apply-templates>
          </div>
        </xsl:for-each>
        <xsl:for-each select="$node/xs:list/xs:simpleType">
          <div class="inline-type inline-type--item">
            <xsl:apply-templates select="." mode="inline-type">
              <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
            </xsl:apply-templates>
          </div>
        </xsl:for-each>
        <xsl:for-each select="$node/xs:union/xs:simpleType">
          <div class="inline-type inline-type--member">
            <xsl:apply-templates select="." mode="inline-type">
              <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
            </xsl:apply-templates>
          </div>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <p>{f:t('msg.anonymousSimpleType')}</p>
        <dl class="proplist">
          <xsl:call-template name="simple-type-definition-rows">
            <xsl:with-param name="node" select="$node" />
            <xsl:with-param name="schemas" select="$schemas" />
          </xsl:call-template>
        </dl>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="attribute-use-row">
    <xsl:param name="attr" as="element(xs:attribute)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="via" as="element()?" select="()" />
    <xsl:param name="show-inheritable" as="xs:boolean" select="true()" />
    <xsl:param name="show-doc" as="xs:boolean" select="true()" />
    <tr>
      <xsl:if test="$via">
        <xsl:attribute name="data-via" select="f:clark(f:component-qname($via, $schemas))" />
      </xsl:if>
      <th scope="row">
        <code dir="ltr">
          <bdi>{($attr/@name, $attr/@ref)[1]}</bdi>
        </code>
        <xsl:for-each select="$attr/(@form | @targetNamespace)">
          <span class="chip" data-particle-flag="{local-name()}">{local-name()}=<code dir="ltr">
            <bdi>{.}</bdi>
          </code></span>
        </xsl:for-each>
        <xsl:if test="$via">
          <span class="attr-via muted">{f:t('attr.via')} <a
            class="xref xref--int"
            href="#{f:anchor($via, $schemas)}">{$via/@name}</a></span>
        </xsl:if>
      </th>
      <td>
        <xsl:choose>
          <xsl:when test="$attr/@type">
            <xsl:call-template name="render-reference">
              <xsl:with-param name="lexical" select="string($attr/@type)" />
              <xsl:with-param name="context" select="$attr" />
              <xsl:with-param name="expected" select="'type'" />
              <xsl:with-param name="schemas" select="$schemas" />
              <xsl:with-param name="source-attr" select="$attr/@type" />
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="$attr/@ref">
            <xsl:call-template name="render-reference">
              <xsl:with-param name="lexical" select="string($attr/@ref)" />
              <xsl:with-param name="context" select="$attr" />
              <xsl:with-param name="expected" select="'attribute'" />
              <xsl:with-param name="schemas" select="$schemas" />
              <xsl:with-param name="source-attr" select="$attr/@ref" />
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="$attr/xs:simpleType">
            <div class="inline-type inline-type--attribute">
              <xsl:apply-templates select="$attr/xs:simpleType" mode="inline-type">
                <xsl:with-param name="schemas" select="$schemas" tunnel="yes" />
              </xsl:apply-templates>
            </div>
          </xsl:when>
          <xsl:otherwise>
            <span class="muted attr-no-type">{f:t('attr.noDeclaredType')}</span>
          </xsl:otherwise>
        </xsl:choose>
      </td>
      <td>
        <xsl:variable name="use" select="string(($attr/@use, 'optional')[1])" />
        <span class="use use--{$use}">{$use}</span>
      </td>
      <td>
        <xsl:if test="$attr/@default">{f:t('value.default')} <code dir="ltr">
          <bdi>{$attr/@default}</bdi>
        </code></xsl:if>
        <xsl:if test="$attr/@fixed">{f:t('value.fixed')} <code dir="ltr">
          <bdi>{$attr/@fixed}</bdi>
        </code></xsl:if>
      </td>
      <xsl:if test="$show-inheritable">
        <td>{f:t(if (f:xsd-true(string($attr/@inheritable))) then 'msg.yes' else 'msg.no')}</td>
      </xsl:if>
      <xsl:if test="$show-doc">
        <td>
          <xsl:apply-templates select="$attr/xs:annotation" mode="annotation" />
        </td>
      </xsl:if>
    </tr>
  </xsl:template>

  <xsl:template name="any-attribute-row">
    <xsl:param name="wildcard" as="element(xs:anyAttribute)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="show-inheritable" as="xs:boolean" select="true()" />
    <xsl:param name="show-doc" as="xs:boolean" select="true()" />
    <tr>
      <th scope="row">{f:t('wildcard.anyAttribute')}</th>
      <td>
        <xsl:for-each select="$wildcard">
          <xsl:call-template name="wildcard-tokens">
            <xsl:with-param name="raw" select="string((@namespace, '##any')[1])" />
            <xsl:with-param name="attr" select="'namespace'" />
            <xsl:with-param name="kind" select="'attribute'" />
          </xsl:call-template>
          <xsl:if test="@notNamespace"> notNamespace <xsl:call-template name="wildcard-tokens">
            <xsl:with-param name="raw" select="string(@notNamespace)" />
            <xsl:with-param name="attr" select="'notNamespace'" />
            <xsl:with-param name="kind" select="'attribute'" />
          </xsl:call-template></xsl:if>
          <xsl:if test="@notQName"> notQName <xsl:call-template name="wildcard-notqname-tokens">
            <xsl:with-param name="raw" select="string(@notQName)" />
            <xsl:with-param name="context" select="." />
            <xsl:with-param name="expected" select="'attribute'" />
            <xsl:with-param name="schemas" select="$schemas" />
          </xsl:call-template></xsl:if>
        </xsl:for-each>
      </td>
      <td
        colspan="{2 + (if ($show-inheritable) then 1 else 0)}">{f:t('wildcard.processContents')}={string(($wildcard/@processContents, 'strict')[1])} <span
        class="wildcard-provenance"
        data-provenance="{f:wildcard-provenance($wildcard)}">{f:t(concat('wildcard.via.', f:wildcard-provenance($wildcard)))}</span></td>
      <xsl:if test="$show-doc">
        <td>
          <xsl:apply-templates select="$wildcard/xs:annotation" mode="annotation" />
        </td>
      </xsl:if>
    </tr>
  </xsl:template>

  <!--
    The attribute and wildcard nodes an attribute table will actually show,
    mirroring the row-emission walk exactly (descendant axis on the owner,
    child axis inside referenced groups, same ambiguity predicate and visited
    stops as attribute-group-rows). Drives the whole-table column decision so
    a column is emitted iff some row will populate it.
  -->
  <xsl:function name="f:attribute-table-nodes" as="element()*">
    <xsl:param name="owner" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:sequence select="$owner//xs:attribute | $owner//xs:anyAttribute" />
    <xsl:for-each select="$owner//xs:attributeGroup[@ref]">
      <xsl:sequence select="f:attribute-group-nodes(., $schemas, $visited)" />
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="f:attribute-group-resolution" as="map(*)">
    <xsl:param name="group-ref" as="element(xs:attributeGroup)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable
      name="q"
      select="f:reference-qname(string($group-ref/@ref), $group-ref, 'attributeGroup', $schemas)" />
    <xsl:variable name="matches" select="f:components-matching($q, 'attributeGroup', $schemas)" />
    <xsl:variable name="target" select="$matches[1]" />
    <xsl:sequence
      select="
      map {
        'qname': $q,
        'matches': $matches,
        'target': $target,
        'target-clark': f:clark(f:component-qname($target, $schemas)),
        'ambiguous': count($matches[not(ancestor::xs:redefine or ancestor::xs:override)]) gt 1
      }" />
  </xsl:function>

  <xsl:function name="f:attribute-group-nodes" as="element()*">
    <xsl:param name="group-ref" as="element(xs:attributeGroup)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:variable name="resolution" select="f:attribute-group-resolution($group-ref, $schemas)" />
    <xsl:variable name="target" select="$resolution?target" />
    <xsl:variable name="target-clark" select="$resolution?target-clark" />
    <xsl:variable name="ambiguous" select="$resolution?ambiguous" />
    <xsl:if test="exists($target) and not($target-clark = $visited) and not($ambiguous)">
      <xsl:sequence select="$target/xs:attribute | $target/xs:anyAttribute" />
      <xsl:for-each select="$target/xs:attributeGroup[@ref]">
        <xsl:sequence select="f:attribute-group-nodes(., $schemas, ($visited, $target-clark))" />
      </xsl:for-each>
    </xsl:if>
  </xsl:function>

  <!--
    Expand a referenced attribute group into the enclosing attribute table:
    a header row showing the reference, then one row per attribute the group
    introduces (directly or through nested group references). $visited carries
    the Clark names of groups already being expanded; a reference back into
    that set stops with a visible note instead of recursing (spec §10).
  -->
  <xsl:template name="attribute-group-rows">
    <xsl:param name="group-ref" as="element(xs:attributeGroup)" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:param name="show-inheritable" as="xs:boolean" select="true()" />
    <xsl:param name="show-doc" as="xs:boolean" select="true()" />
    <xsl:variable
      name="wide-span"
      select="2 + (if ($show-inheritable) then 1 else 0) + (if ($show-doc) then 1 else 0)" />
    <xsl:variable name="resolution" select="f:attribute-group-resolution($group-ref, $schemas)" />
    <xsl:variable name="target" select="$resolution?target" />
    <xsl:variable name="target-clark" select="$resolution?target-clark" />
    <xsl:variable name="ambiguous" select="$resolution?ambiguous" />
    <tr>
      <th scope="row">{f:kind-label('attributeGroup')}</th>
      <td>
        <xsl:call-template name="render-reference">
          <xsl:with-param name="lexical" select="string($group-ref/@ref)" />
          <xsl:with-param name="context" select="$group-ref" />
          <xsl:with-param name="expected" select="'attributeGroup'" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="source-attr" select="$group-ref/@ref" />
        </xsl:call-template>
      </td>
      <xsl:choose>
        <xsl:when test="exists($target) and $target-clark = $visited">
          <td colspan="{$wide-span}" data-code="recursive-expansion-stopped">{f:t('attr.expansionStoppedCycle')}</td>
        </xsl:when>
        <xsl:when test="$ambiguous">
          <td
            colspan="{$wide-span}"
            data-code="recursive-expansion-stopped">{f:t('attr.expansionStoppedAmbiguous')}</td>
        </xsl:when>
        <xsl:when test="exists($target)">
          <td colspan="{$wide-span}" class="muted">{f:t('attr.groupExpandedBelow')}</td>
        </xsl:when>
        <xsl:otherwise>
          <td colspan="{$wide-span}" />
        </xsl:otherwise>
      </xsl:choose>
    </tr>
    <xsl:if test="exists($target) and not($target-clark = $visited) and not($ambiguous)">
      <xsl:for-each select="$target/xs:attribute">
        <xsl:call-template name="attribute-use-row">
          <xsl:with-param name="attr" select="." />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="via" select="$target" />
          <xsl:with-param name="show-inheritable" select="$show-inheritable" />
          <xsl:with-param name="show-doc" select="$show-doc" />
        </xsl:call-template>
      </xsl:for-each>
      <xsl:for-each select="$target/xs:anyAttribute">
        <xsl:call-template name="any-attribute-row">
          <xsl:with-param name="wildcard" select="." />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="show-inheritable" select="$show-inheritable" />
          <xsl:with-param name="show-doc" select="$show-doc" />
        </xsl:call-template>
      </xsl:for-each>
      <xsl:for-each select="$target/xs:attributeGroup[@ref]">
        <xsl:call-template name="attribute-group-rows">
          <xsl:with-param name="group-ref" select="." />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="visited" select="($visited, $target-clark)" />
          <xsl:with-param name="show-inheritable" select="$show-inheritable" />
          <xsl:with-param name="show-doc" select="$show-doc" />
        </xsl:call-template>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <xsl:template name="particle-flags">
    <xsl:if test="@nillable = ('true', '1')">
      <span class="chip" data-particle-flag="nillable">{f:t('flag.nillable')}</span>
    </xsl:if>
    <xsl:if test="@abstract = ('true', '1')">
      <span class="chip" data-particle-flag="abstract">{f:t('flag.abstract')}</span>
    </xsl:if>
    <xsl:for-each select="@default | @fixed | @form | @block | @final | @targetNamespace">
      <span class="chip" data-particle-flag="{local-name()}">{local-name()}=<code dir="ltr">
        <bdi>{.}</bdi>
      </code></span>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="xs:sequence | xs:choice | xs:all | xs:openContent | xs:defaultOpenContent" mode="particle">
    <xsl:param name="schemas" as="map(*)*" tunnel="yes" />
    <div class="tree__node" role="listitem">
      <div class="tree__row">
        <span class="chip chip--comp" data-comp="{local-name()}">{local-name()}</span>
        <xsl:if test="f:occurs(.) ne ''">
          <span
            class="occurs"
            title="{f:occurs-title(.)}"
            role="img"
            aria-label="{f:occurs-title(.)}">{f:occurs(.)}</span>
        </xsl:if>
        <xsl:if test="@mode">
          <span class="chip">mode={@mode}</span>
        </xsl:if>
        <xsl:if test="@appliesToEmpty">
          <span class="chip">appliesToEmpty={@appliesToEmpty}</span>
        </xsl:if>
      </div>
      <div class="tree__children" role="list">
        <xsl:apply-templates
          select="xs:element | xs:group | xs:any | xs:sequence | xs:choice | xs:all | xs:anyAttribute"
          mode="particle" />
      </div>
    </div>
  </xsl:template>

  <xsl:template match="xs:element" mode="particle">
    <xsl:param name="schemas" as="map(*)*" tunnel="yes" />
    <div class="tree__node" role="listitem">
      <div class="tree__row">
        <span class="chip chip--comp" data-comp="element">element</span>
        <xsl:choose>
          <xsl:when test="@ref">
            <xsl:call-template name="render-reference">
              <xsl:with-param name="lexical" select="string(@ref)" />
              <xsl:with-param name="context" select="." />
              <xsl:with-param name="expected" select="'element'" />
              <xsl:with-param name="schemas" select="$schemas" />
              <xsl:with-param name="source-attr" select="@ref" />
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <code dir="ltr">
              <bdi>{@name}</bdi>
            </code>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="@type">
          <span class="tree__sep">:</span>
          <xsl:call-template name="render-reference">
            <xsl:with-param name="lexical" select="string(@type)" />
            <xsl:with-param name="context" select="." />
            <xsl:with-param name="expected" select="'type'" />
            <xsl:with-param name="schemas" select="$schemas" />
            <xsl:with-param name="source-attr" select="@type" />
          </xsl:call-template>
        </xsl:if>
        <xsl:if test="f:occurs(.) ne ''">
          <span
            class="occurs"
            title="{f:occurs-title(.)}"
            role="img"
            aria-label="{f:occurs-title(.)}">{f:occurs(.)}</span>
        </xsl:if>
        <xsl:call-template name="particle-flags" />
      </div>
      <xsl:if test="xs:complexType | xs:simpleType">
        <div class="tree__children">
          <xsl:apply-templates select="xs:complexType | xs:simpleType" mode="inline-type" />
        </div>
      </xsl:if>
      <xsl:if test="xs:alternative">
        <div class="tree__children">
          <xsl:call-template name="type-alternatives">
            <xsl:with-param name="node" select="." />
            <xsl:with-param name="schemas" select="$schemas" />
            <xsl:with-param name="anchor" select="f:local-anchor(., $schemas)" />
          </xsl:call-template>
        </div>
      </xsl:if>
    </div>
  </xsl:template>

  <xsl:template match="xs:group" mode="particle">
    <xsl:param name="schemas" as="map(*)*" tunnel="yes" />
    <div class="tree__node" role="listitem">
      <div class="tree__row">
        <span class="chip chip--comp" data-comp="group">group</span>
        <xsl:call-template name="render-reference">
          <xsl:with-param name="lexical" select="string(@ref)" />
          <xsl:with-param name="context" select="." />
          <xsl:with-param name="expected" select="'group'" />
          <xsl:with-param name="schemas" select="$schemas" />
          <xsl:with-param name="source-attr" select="@ref" />
        </xsl:call-template>
        <xsl:if test="f:occurs(.) ne ''">
          <span
            class="occurs"
            title="{f:occurs-title(.)}"
            role="img"
            aria-label="{f:occurs-title(.)}">{f:occurs(.)}</span>
        </xsl:if>
        <xsl:call-template name="particle-flags" />
      </div>
    </div>
  </xsl:template>

  <xsl:template name="wildcard-notqname-tokens">
    <xsl:param name="raw" as="xs:string" />
    <xsl:param name="context" as="element()" />
    <xsl:param name="expected" as="xs:string" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:for-each select="tokenize(normalize-space($raw), '\s+')[. ne '']">
      <xsl:if test="position() gt 1">
        <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="starts-with(., '##')">
          <code
            class="wildcard-token"
            dir="ltr"
            data-wildcard-attr="notQName"
            data-wildcard-kind="{$expected}"
            title="{f:t(concat('wildcard.tok.', substring-after(., '##')))} (notQName {f:t(concat('wildcard.on.', $expected))})">{.}</code>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="render-reference">
            <xsl:with-param name="lexical" select="." />
            <xsl:with-param name="context" select="$context" />
            <xsl:with-param name="expected" select="$expected" />
            <xsl:with-param name="schemas" select="$schemas" />
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!--
    Format a space-separated wildcard namespace / notNamespace token list.
    Wildcard tokens (##any, ##other, ##local, ##targetNamespace) render as
    distinct wildcard-token code spans labelled for the carrying attribute
    and wildcard kind; explicit namespace URIs render as plain code. Always
    left-to-right.
  -->
  <xsl:template name="wildcard-tokens">
    <xsl:param name="raw" as="xs:string" />
    <xsl:param name="attr" as="xs:string" select="'namespace'" />
    <xsl:param name="kind" as="xs:string" select="'element'" />
    <xsl:for-each select="tokenize(normalize-space($raw), '\s+')[. ne '']">
      <xsl:if test="position() gt 1">
        <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="starts-with(., '##')">
          <code
            class="wildcard-token"
            dir="ltr"
            data-wildcard-attr="{$attr}"
            data-wildcard-kind="{$kind}"
            title="{f:t(concat('wildcard.tok.', substring-after(., '##')))} ({$attr} {f:t(concat('wildcard.on.', $kind))})">{.}</code>
        </xsl:when>
        <xsl:otherwise>
          <code class="wildcard-ns" dir="ltr">{.}</code>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="xs:any | xs:anyAttribute" mode="particle">
    <xsl:param name="schemas" as="map(*)*" tunnel="yes" />
    <xsl:variable name="kind" select="if (self::xs:anyAttribute) then 'attribute' else 'element'" />
    <div class="tree__node" role="listitem">
      <div class="tree__row">
        <span class="chip chip--comp" data-comp="{local-name()}">{local-name()}</span>
        <span>namespace <xsl:call-template name="wildcard-tokens">
          <xsl:with-param name="raw" select="string((@namespace, '##any')[1])" />
          <xsl:with-param name="attr" select="'namespace'" />
          <xsl:with-param name="kind" select="$kind" />
        </xsl:call-template></span>
        <xsl:if test="@notNamespace">
          <span>notNamespace <xsl:call-template name="wildcard-tokens">
            <xsl:with-param name="raw" select="string(@notNamespace)" />
            <xsl:with-param name="attr" select="'notNamespace'" />
            <xsl:with-param name="kind" select="$kind" />
          </xsl:call-template></span>
        </xsl:if>
        <xsl:if test="@notQName">
          <span>notQName <xsl:call-template name="wildcard-notqname-tokens">
            <xsl:with-param name="raw" select="string(@notQName)" />
            <xsl:with-param name="context" select="." />
            <xsl:with-param name="expected" select="$kind" />
            <xsl:with-param name="schemas" select="$schemas" />
          </xsl:call-template></span>
        </xsl:if>
        <span>{f:t('wildcard.processContents')}={string((@processContents, 'strict')[1])}</span>
        <xsl:if test="self::xs:any and f:occurs(.) ne ''">
          <span
            class="occurs"
            title="{f:occurs-title(.)}"
            role="img"
            aria-label="{f:occurs-title(.)}">{f:occurs(.)}</span>
        </xsl:if>
        <span
          class="wildcard-provenance"
          data-provenance="{f:wildcard-provenance(.)}">{f:t(concat('wildcard.via.', f:wildcard-provenance(.)))}</span>
      </div>
      <xsl:apply-templates select="xs:annotation" mode="annotation" />
    </div>
  </xsl:template>

  <xsl:template name="render-reference">
    <xsl:param name="lexical" as="xs:string?" />
    <xsl:param name="context" as="element()" />
    <xsl:param name="expected" as="xs:string" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="source-attr" as="attribute()?" select="()" />
    <xsl:param name="unresolved-refs" as="attribute()*" select="()" tunnel="yes" />
    <xsl:variable name="qname" select="f:reference-qname($lexical, $context, $expected, $schemas)" />
    <!--
      Inside xs:redefine, a same-name reference designates the ORIGINAL
      definition being redefined, so matches outside the enclosing redefine
      are preferred over the redefinition itself.
    -->
    <xsl:variable name="matches" select="f:components-matching($qname, $expected, $schemas)" />
    <xsl:variable
      name="target"
      select="($matches[empty(ancestor::xs:redefine intersect $context/ancestor::xs:redefine)], $matches)[1]" />
    <xsl:choose>
      <xsl:when test="$target">
        <a class="xref xref--int" href="#{f:anchor($target, $schemas)}">
          <bdi>{normalize-space($lexical)}</bdi>
        </a>
      </xsl:when>
      <xsl:when test="f:is-builtin-type($qname)">
        <a
          class="xref xref--ext xref--builtin"
          href="{f:builtin-type-href(local-name-from-QName($qname))}"
          rel="external noopener noreferrer"
          target="_blank">
          <bdi>{normalize-space($lexical)}</bdi>
        </a>
        <xsl:if test="local-name-from-QName($qname) = $xsd11-builtins">
          <span class="flag" data-flag="xsd11">{f:t('flag.xsd11')}</span>
        </xsl:if>
      </xsl:when>
      <xsl:when test="exists($qname) and namespace-uri-from-QName($qname) ne ''">
        <span class="xref xref--external" tabindex="0" title="{f:t('xref.externalTitle')}">
          <bdi>{normalize-space($lexical)}</bdi>
        </span>
      </xsl:when>
      <xsl:otherwise>
        <span class="xref xref--unresolved" tabindex="0" title="{f:t('xref.unresolvedTitle')}">
          <xsl:variable name="idx" select="f:unresolved-index($source-attr, $unresolved-refs)" />
          <xsl:if test="exists($idx)">
            <xsl:attribute name="aria-describedby" select="concat('diag-unresolved-', $idx)" />
          </xsl:if>
          <bdi>{normalize-space($lexical)}</bdi>
        </span>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="xs:annotation" mode="annotation">
    <xsl:param name="config" as="map(*)" tunnel="yes" select="f:config()" />
    <xsl:for-each select="xs:documentation">
      <xsl:variable name="renders" select="f:documentation-renders(.)" />
      <xsl:variable name="source-href" select="f:safe-href(string(@source))" />
      <xsl:if test="$renders or exists($source-href)">
        <div
          class="doc{' is-clampable'[$renders]}"
          lang="{string((@xml:lang, $config?documentation-language)[1])}"
          dir="auto">
          <xsl:if test="$renders">
            <div class="doc__body">
              <xsl:if test="@xml:lang">
                <span
                  class="component__doc-lang"
                  title="{f:t('doc.langTitle', map { 'lang': string(@xml:lang) })}"
                  role="img"
                  aria-label="{f:t('doc.langLabel', map { 'lang': string(@xml:lang) })}">
                  <xsl:value-of select="@xml:lang" />
                </span>
              </xsl:if>
              <xsl:choose>
                <xsl:when test="$config?documentation-markup = 'permissive'">
                  <xsl:copy-of select="node()" />
                </xsl:when>
                <xsl:otherwise>
                  <xsl:apply-templates select="node()" mode="doc" />
                </xsl:otherwise>
              </xsl:choose>
            </div>
            <button
              class="doc__toggle"
              type="button"
              data-more="{f:t('js.showMore')}"
              data-less="{f:t('js.showLess')}"
              hidden="hidden">{f:t('js.showMore')}</button>
          </xsl:if>
          <xsl:if test="exists($source-href)">
            <a
              class="component__doc-source"
              href="{$source-href}"
              rel="external noopener noreferrer"
              target="_blank"
              aria-label="{f:t('doc.sourceLinkLabel')}">{f:t('doc.sourceLink')}</a>
          </xsl:if>
        </div>
      </xsl:if>
    </xsl:for-each>
    <xsl:for-each select="xs:appinfo">
      <details class="disclosure" data-kind-block="appinfo">
        <summary>{f:t('block.appinfo')} <span class="src-lang">xml</span></summary>
        <pre class="src" dir="ltr">
          <code>
            <xsl:apply-templates select="." mode="source" />
          </code>
        </pre>
      </details>
    </xsl:for-each>
  </xsl:template>

  <!--
    Whitespace at the very start and end of a documentation block is authoring
    indentation, not content, so the edge text nodes of xs:documentation are
    trimmed. Interior whitespace (and whitespace around nested markup) is kept.
  -->
  <xsl:template match="text()" mode="doc">
    <xsl:variable
      name="lead"
      select="if (parent::xs:documentation and empty(preceding-sibling::node())) then replace(., '^\s+', '') else string(.)" />
    <xsl:variable
      name="trimmed"
      select="if (parent::xs:documentation and empty(following-sibling::node())) then replace($lead, '\s+$', '') else $lead" />
    <xsl:for-each select="tokenize($trimmed, '&#10;')">
      <xsl:if test="position() gt 1">
        <br />
      </xsl:if>
      <xsl:value-of select="." />
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="*" mode="doc">
    <xsl:choose>
      <xsl:when
        test="(namespace-uri() = '' or namespace-uri() = 'http://www.w3.org/1999/xhtml') and local-name() = ('p', 'div', 'span', 'br', 'hr', 'em', 'strong', 'i', 'b', 'u', 's', 'sub', 'sup', 'code', 'kbd', 'samp', 'var', 'pre', 'a', 'abbr', 'cite', 'q', 'blockquote', 'ul', 'ol', 'li', 'dl', 'dt', 'dd', 'table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td', 'caption', 'colgroup', 'col', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'figure', 'figcaption')">
        <xsl:element name="{local-name()}">
          <xsl:for-each
            select="@*[local-name() = ('href', 'title', 'lang', 'dir', 'class', 'scope', 'colspan', 'rowspan', 'headers', 'datetime', 'start', 'reversed', 'value')]">
            <xsl:variable name="safe-href" select="not(local-name() = 'href') or exists(f:safe-href(string(.)))" />
            <xsl:if test="$safe-href">
              <xsl:attribute
                name="{local-name()}"
                select="if (local-name() = 'href') then f:safe-href(string(.)) else string(.)" />
              <xsl:if test="local-name() = 'href'">
                <xsl:attribute name="rel" select="'external noopener noreferrer'" />
              </xsl:if>
            </xsl:if>
          </xsl:for-each>
          <xsl:apply-templates select="node()" mode="doc" />
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="node()" mode="doc" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
    Collection-time diagnostics. Replays the f:collect-schemas graph walk and
    emits a record per problem edge: schema-not-loaded (the schemaLocation does
    not resolve to an available document), not-schema (the document loads but
    its root is not xs:schema), and traversal-cycle-skipped (the target was
    already on the current ancestral path, so collection stopped to avoid a
    cycle). The visited-key logic mirrors f:collect-schemas exactly.
  -->
  <xsl:function name="f:collection-diagnostics" as="map(*)*">
    <xsl:param name="schema" as="element(xs:schema)" />
    <xsl:param name="effective-ns" as="xs:string" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:variable name="key" select="concat(f:doc-uri($schema), '|', $effective-ns)" />
    <xsl:if test="not($key = $visited)">
      <xsl:for-each select="f:composition-edges($schema)">
        <xsl:variable name="edge" select="." />
        <xsl:variable name="resolved" select="f:absolute-uri(string($edge/@schemaLocation), base-uri($edge))" />
        <xsl:choose>
          <xsl:when test="empty($resolved)" />
          <xsl:when test="not(doc-available($resolved))">
            <xsl:sequence select="map { 'code': 'schema-not-loaded', 'severity': 'warning', 'node': $edge }" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="loaded" select="doc($resolved)/*" />
            <xsl:choose>
              <xsl:when test="not($loaded/self::xs:schema)">
                <xsl:sequence select="map { 'code': 'not-schema', 'severity': 'warning', 'node': $edge }" />
              </xsl:when>
              <xsl:otherwise>
                <xsl:variable name="child-ns" select="f:composition-child-ns($loaded, $edge, $effective-ns)" />
                <xsl:choose>
                  <xsl:when test="concat(f:doc-uri($loaded), '|', $child-ns) = ($visited, $key)">
                    <xsl:sequence
                      select="map { 'code': 'traversal-cycle-skipped', 'severity': 'info', 'node': $edge }" />
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:sequence select="f:collection-diagnostics($loaded, $child-ns, ($visited, $key))" />
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:if>
  </xsl:function>

  <!-- Top-level group / attributeGroup definitions that $def references by @ref. -->
  <xsl:function name="f:ref-targets" as="element()*">
    <xsl:param name="def" as="element()" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="kind" select="local-name($def)" />
    <xsl:for-each select="$def//*[local-name() = $kind and @ref]">
      <xsl:variable
        name="matches"
        select="f:components-matching(f:reference-qname(string(@ref), ., $kind, $schemas), $kind, $schemas)" />
      <xsl:sequence
        select="($matches[empty(ancestor::xs:redefine intersect current()/ancestor::xs:redefine)], $matches)[1]" />
    </xsl:for-each>
  </xsl:function>

  <!--
    True when the group / attributeGroup whose Clark QName is $target can be
    reached from $current by following @ref edges. Used to detect recursive
    group references; the $visited set bounds the walk against non-termination.
  -->
  <xsl:function name="f:reaches-ref" as="xs:boolean">
    <xsl:param name="target" as="xs:string" />
    <xsl:param name="current" as="element()" />
    <xsl:param name="visited" as="xs:string*" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="ck" select="f:clark(f:component-qname($current, $schemas))" />
    <xsl:sequence
      select="
      if ($ck = $visited) then false()
      else
        some $t in f:ref-targets($current, $schemas) satisfies
          (f:clark(f:component-qname($t, $schemas)) = $target
           or f:reaches-ref($target, $t, ($visited, $ck), $schemas))" />
  </xsl:function>

  <!--
    True when a lexical QName reference resolves to nothing in the loaded
    collection: no matching component, not a built-in, and not an external
    namespace (references into a known-but-unloaded namespace stay "external"
    rather than "unresolved").
  -->
  <xsl:function name="f:is-unresolved-reference" as="xs:boolean">
    <xsl:param name="lexical" as="xs:string" />
    <xsl:param name="context" as="element()" />
    <xsl:param name="expected" as="xs:string" />
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable name="q" select="f:reference-qname($lexical, $context, $expected, $schemas)" />
    <xsl:sequence
      select="empty(f:components-matching($q, $expected, $schemas)) and not(f:is-builtin-type($q)) and not(exists($q) and namespace-uri-from-QName($q) ne '')" />
  </xsl:function>

  <!--
    Every QName-valued attribute in the loaded collection whose reference does
    not resolve, in document order. Shared by the diagnostics list and by
    render-reference, which points each unresolved marker at its diagnostic
    entry (diag-unresolved-{index}) via aria-describedby.
  -->
  <xsl:function name="f:unresolved-refs" as="attribute()*">
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:variable
      name="qname-attrs"
      select="$schemas ! ?node//@type | $schemas ! ?node//@base | $schemas ! ?node//@ref | $schemas ! ?node//@substitutionGroup | $schemas ! ?node//@itemType | $schemas ! ?node//@memberTypes | $schemas ! ?node//@refer | $schemas ! ?node//@defaultAttributes" />
    <xsl:for-each select="$qname-attrs">
      <xsl:choose>
        <xsl:when test="local-name() = 'memberTypes'">
          <xsl:variable name="attr" select="." />
          <xsl:if
            test="some $token in tokenize(normalize-space(string(.)), '\s+')[. ne '']
              satisfies f:is-unresolved-reference($token, $attr/.., 'type', $schemas)">
            <xsl:sequence select="." />
          </xsl:if>
        </xsl:when>
        <xsl:when test="local-name() = ('ref', 'refer') and ../(self::xs:key | self::xs:keyref | self::xs:unique)">
          <xsl:variable
            name="kinds"
            select="if (local-name() = 'refer') then ('key', 'unique') else ('key', 'keyref', 'unique')" />
          <xsl:variable name="q" select="f:lexical-qname(string(.), ..)" />
          <xsl:if
            test="empty(f:identity-target(string(.), .., $kinds, $schemas))
              and not(exists($q) and namespace-uri-from-QName($q) ne '')">
            <xsl:sequence select="." />
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable
            name="expected"
            select="if (local-name() = ('type', 'base', 'itemType')) then 'type' else if (local-name() = 'ref' and ../self::xs:attribute) then 'attribute' else if (local-name() = 'ref' and ../self::xs:attributeGroup) then 'attributeGroup' else if (local-name() = 'ref' and ../self::xs:group) then 'group' else 'element'" />
          <xsl:if test="f:is-unresolved-reference(string(.), .., $expected, $schemas)">
            <xsl:sequence select="." />
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>

  <!--
    Position of $attr in the unresolved-reference list, by node identity so
    repeated attribute values stay distinct.
  -->
  <xsl:function name="f:unresolved-index" as="xs:integer?">
    <xsl:param name="attr" as="attribute()?" />
    <xsl:param name="unresolved" as="attribute()*" />
    <xsl:sequence
      select="
      if (exists($attr)) then
        (for $i in 1 to count($unresolved) return if ($unresolved[$i] is $attr) then $i else ())[1]
      else ()" />
  </xsl:function>

  <xsl:template name="diagnostics">
    <xsl:param name="schemas" as="map(*)*" />
    <xsl:param name="components" as="element()*" />
    <xsl:param name="config" as="map(*)" />
    <xsl:param name="unresolved" as="attribute()*" select="f:unresolved-refs($schemas)" />
    <xsl:variable name="primary" select="($schemas[?is-primary], $schemas)[1]?node" />
    <xsl:variable
      name="collection"
      select="if (exists($primary)) then f:collection-diagnostics($primary, string($primary/@targetNamespace), ()) else ()" />
    <xsl:variable
      name="unknown"
      select="$schemas ! ?node/descendant::*[namespace-uri() = $xsd-ns and not(local-name() = $xsd-elements) and not(ancestor::xs:appinfo or ancestor::xs:documentation)]" />
    <xsl:variable
      name="ref-cycles"
      select="$components[(self::xs:group or self::xs:attributeGroup) and @name][f:reaches-ref(f:clark(f:component-qname(., $schemas)), ., (), $schemas)]" />
    <xsl:variable name="param-diags" select="$config?diagnostics" />
    <xsl:if
      test="exists($collection) or exists($unresolved) or exists($unknown) or exists($ref-cycles) or exists($param-diags)">
      <section class="diagnostics" id="diagnostics" aria-labelledby="diagnostics-title">
        <h2 id="diagnostics-title">{f:t('diag.heading')}</h2>
        <ol class="diagnostic-list">
          <xsl:for-each select="$param-diags">
            <li
              id="diag-param-{position()}"
              class="diagnostic"
              data-severity="{?severity}"
              data-code="invalid-parameter">
              <p class="diagnostic__summary">{f:t('diag.invalidParameter')}</p>
              <p class="diagnostic__context">{f:t('diag.ctxParameter')} <code
                dir="ltr">{?param}</code> {f:t('diag.ctxValue')} <code
                dir="ltr">{?value}</code> {f:t('diag.ctxNormalizedTo')} <code dir="ltr">{?normalized}</code>.</p>
            </li>
          </xsl:for-each>
          <xsl:for-each select="$collection">
            <xsl:variable name="d" select="." />
            <li
              id="diag-collection-{position()}"
              class="diagnostic"
              data-severity="{$d?severity}"
              data-code="{$d?code}">
              <p class="diagnostic__summary">
                <xsl:choose>
                  <xsl:when test="$d?code = 'schema-not-loaded'">{f:t('diag.schemaNotLoaded')}</xsl:when>
                  <xsl:when test="$d?code = 'not-schema'">{f:t('diag.notSchema')}</xsl:when>
                  <xsl:otherwise>{f:t('diag.cycleSkipped')}</xsl:otherwise>
                </xsl:choose>
              </p>
              <p class="diagnostic__context"><code
                dir="ltr">{$d?node/@schemaLocation}</code> {f:t('diag.ctxReferencedBy')} <code
                dir="ltr">{local-name($d?node)}</code>.</p>
            </li>
          </xsl:for-each>
          <xsl:for-each select="$unknown">
            <li id="diag-unknown-{position()}" class="diagnostic" data-severity="info" data-code="unknown-element">
              <p class="diagnostic__summary">{f:t('diag.unknownElement')}</p>
              <p class="diagnostic__context">{f:t('diag.ctxElement')} <code
                dir="ltr">{name()}</code> {f:t('diag.ctxNotRecognized')}</p>
            </li>
          </xsl:for-each>
          <xsl:for-each select="$ref-cycles">
            <li
              id="diag-recursive-{position()}"
              class="diagnostic"
              data-severity="info"
              data-code="recursive-expansion-stopped">
              <p class="diagnostic__summary">{f:t('diag.recursiveExpansion')}</p>
              <p class="diagnostic__context"><code dir="ltr">{local-name()} {@name}</code> {f:t('diag.ctxRefCycle')}</p>
            </li>
          </xsl:for-each>
          <xsl:for-each select="$unresolved">
            <li
              id="diag-unresolved-{position()}"
              class="diagnostic"
              data-severity="warning"
              data-code="qname-unresolved">
              <p class="diagnostic__summary">{f:t('diag.qnameUnresolved')}</p>
              <p class="diagnostic__context">{f:t('diag.ctxAttribute')} <code
                dir="ltr">@{name()}</code> {f:t('diag.ctxHasValue')} <code dir="ltr">{.}</code>.</p>
            </li>
          </xsl:for-each>
        </ol>
      </section>
    </xsl:if>
  </xsl:template>

  <!--
    Namespace pruning for source listings: a fragment root re-declares only the
    prefixes the fragment uses. A prefix counts as used when the emitter would
    pick it for an element or attribute name inside the fragment, or when it
    appears as a QName-shaped token inside any attribute value (type="tns:Foo",
    memberTypes lists, notQName, assertion XPath, ...). False positives merely
    retain a declaration. Declarations made on descendants of the fragment root
    were never re-emitted and still are not.
  -->
  <xsl:function name="f:value-prefix-candidates" as="xs:string*">
    <xsl:param name="value" as="xs:string" />
    <xsl:analyze-string select="$value" regex="([\i-[:]][\c-[:]]*):[\i-[:]]">
      <xsl:matching-substring>
        <xsl:sequence select="regex-group(1)" />
      </xsl:matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="f:source-used-prefixes" as="xs:string*">
    <xsl:param name="src" as="element()" />
    <xsl:sequence
      select="
      distinct-values((
        for $e in $src/descendant-or-self::*[namespace-uri() ne '' and namespace-uri() ne $xsd-ns]
        return (for $p in in-scope-prefixes($e)
                return if ($p ne '' and namespace-uri-for-prefix($p, $e) = namespace-uri($e)) then $p else ())[1],
        for $a in $src/descendant-or-self::*/@*[namespace-uri() ne '']
        return (for $p in in-scope-prefixes($a/parent::*)
                return if ($p ne '' and namespace-uri-for-prefix($p, $a/parent::*) = namespace-uri($a)) then $p else ())[1],
        for $v in $src/descendant-or-self::*/@* return f:value-prefix-candidates(string($v))
      ))" />
  </xsl:function>

  <xsl:template match="*" mode="source">
    <xsl:param name="depth" as="xs:integer" select="0" tunnel="yes" />
    <xsl:param name="emit-ns" as="xs:boolean" select="true()" tunnel="yes" />
    <xsl:variable name="src" select="." />
    <xsl:variable name="indent" select="string-join(for $i in 1 to $depth return '  ', '')" />
    <xsl:variable
      name="prefix"
      select="
      if (namespace-uri($src) = $xsd-ns) then 'xs'
      else (for $p in in-scope-prefixes($src)
            return if ($p ne '' and namespace-uri-for-prefix($p, $src) = namespace-uri($src)) then $p else ())[1]" />
    <xsl:variable name="qname" select="if ($prefix ne '') then concat($prefix, ':', local-name()) else local-name()" />
    <xsl:value-of select="$indent" />
    <xsl:sequence select="f:tok-punct('&lt;')" />
    <span class="tok-tag">{$qname}</span>
    <xsl:if test="$emit-ns">
      <xsl:variable name="used-prefixes" select="f:source-used-prefixes($src)" />
      <xsl:for-each
        select="in-scope-prefixes($src)[. ne 'xml' and namespace-uri-for-prefix(., $src) ne '' and namespace-uri-for-prefix(., $src) ne $xsd-ns][. eq '' or . = $used-prefixes]">
        <xsl:text> </xsl:text>
        <span class="tok-attr">xmlns<xsl:if test=". ne ''">:<xsl:value-of select="." /></xsl:if></span>
        <span class="tok-punct">=</span>
        <span class="tok-val">"<xsl:value-of select="namespace-uri-for-prefix(., $src)" />"</span>
      </xsl:for-each>
    </xsl:if>
    <xsl:for-each select="@*">
      <xsl:variable name="attr" select="." />
      <xsl:variable
        name="attr-prefix"
        select="(for $p in in-scope-prefixes($src)
                 return if ($p ne '' and namespace-uri-for-prefix($p, $src) = namespace-uri($attr)) then $p else ())[1]" />
      <xsl:text> </xsl:text>
      <span class="tok-attr">
        <xsl:if test="namespace-uri() ne ''">
          <xsl:value-of select="$attr-prefix" />
          <xsl:if test="$attr-prefix ne ''">:</xsl:if>
        </xsl:if>
        <xsl:value-of select="local-name()" />
      </span>
      <span class="tok-punct">=</span>
      <span class="tok-val">"<xsl:value-of select="." />"</span>
    </xsl:for-each>
    <xsl:choose>
      <xsl:when test="empty(node())">
        <span class="tok-punct">/&gt;</span>
        <xsl:text>&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="empty(node() except text()) and not(contains(string(.), '&#10;'))">
        <xsl:sequence select="f:tok-punct('&gt;')" />
        <xsl:value-of select="string(.)" />
        <xsl:sequence select="f:tok-punct('&lt;/')" />
        <span class="tok-tag">{$qname}</span>
        <xsl:sequence select="f:tok-punct('&gt;')" />
        <xsl:text>&#10;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="f:tok-punct('&gt;')" />
        <xsl:text>&#10;</xsl:text>
        <xsl:apply-templates select="node()" mode="source">
          <xsl:with-param name="depth" select="$depth + 1" tunnel="yes" />
          <xsl:with-param name="emit-ns" select="false()" tunnel="yes" />
        </xsl:apply-templates>
        <xsl:value-of select="$indent" />
        <xsl:sequence select="f:tok-punct('&lt;/')" />
        <span class="tok-tag">{$qname}</span>
        <xsl:sequence select="f:tok-punct('&gt;')" />
        <xsl:text>&#10;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="text()" mode="source">
    <xsl:param name="depth" as="xs:integer" select="0" tunnel="yes" />
    <xsl:if test="normalize-space(.) ne ''">
      <xsl:value-of select="string-join(for $i in 1 to $depth return '  ', '')" />
      <xsl:value-of select="." />
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="comment()" mode="source">
    <xsl:param name="depth" as="xs:integer" select="0" tunnel="yes" />
    <xsl:value-of select="string-join(for $i in 1 to $depth return '  ', '')" />
    <span class="tok-comment">&lt;!-- <xsl:value-of select="." /> --&gt;</span>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>
</xsl:stylesheet>
