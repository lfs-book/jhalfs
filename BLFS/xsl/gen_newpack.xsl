<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0">

  <xsl:output method="text"
              encoding='ISO-8859-1'/>

  <xsl:template match="/">
    <xsl:text>config MODULES
    bool
    default y
</xsl:text>
    <xsl:apply-templates select="//list"/>
  </xsl:template>

  <xsl:template match="list">
    <xsl:variable name="default">
      <xsl:choose>
        <xsl:when test=".//*[self::package or self::module][inst-version]">
          <xsl:text>m</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>n</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:text>menuconfig&#9;MENU_</xsl:text>
    <xsl:value-of select="@id"/>
    <xsl:text>
tristate&#9;"</xsl:text>
    <xsl:value-of select="name"/>
    <xsl:text>"
default&#9;"</xsl:text>
    <xsl:value-of select="$default"/>
    <xsl:text>"

if&#9;MENU_</xsl:text>
    <xsl:value-of select="@id"/>
    <xsl:text> != n

</xsl:text>
    <xsl:apply-templates select="sublist"/>
    <xsl:text>endif

</xsl:text>
  </xsl:template>

  <xsl:template match="sublist">
    <xsl:variable name="default">
      <xsl:choose>
        <xsl:when test=".//*[self::package or self::module][inst-version]">
          <xsl:text>m</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>n</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:text>&#9;menuconfig&#9;MENU_</xsl:text>
    <xsl:value-of select="@id"/>
    <xsl:text>
&#9;tristate&#9;"</xsl:text>
    <xsl:value-of select="name"/>
    <xsl:text>"
&#9;&#9;default&#9;y if MENU_</xsl:text>
    <xsl:value-of select="../@id"/>
    <xsl:text> = y
&#9;&#9;default&#9;"</xsl:text>
    <xsl:value-of select="$default"/>
    <xsl:text>"

&#9;if&#9;MENU_</xsl:text>
    <xsl:value-of select="@id"/>
    <xsl:text> != n

</xsl:text>
    <xsl:apply-templates select="package"/>
    <xsl:text>&#9;endif

</xsl:text>
  </xsl:template>

  <xsl:template match="package">
    <xsl:variable name="default">
      <xsl:choose>
        <xsl:when test="inst-version">
          <xsl:text>y</xsl:text>
        </xsl:when>
	<xsl:when test="./module[inst-version]">
          <xsl:text>m</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>n</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="version">
      <xsl:text>&#9;&#9;config&#9;CONFIG_</xsl:text>
      <xsl:value-of select="name"/>
      <xsl:text>
&#9;&#9;bool&#9;"</xsl:text>
      <xsl:value-of select="name"/>
      <xsl:text>"
&#9;&#9;default&#9;y if MENU_</xsl:text>
      <xsl:value-of select="../@id"/>
      <xsl:text> = y
&#9;&#9;default&#9;"</xsl:text>
      <xsl:value-of select="$default"/>
      <xsl:text>"
&#9;&#9;config&#9;VERSION_</xsl:text>
      <xsl:value-of select="name"/>
      <xsl:text>
&#9;&#9;string&#9;"Version of </xsl:text>
      <xsl:value-of select="name"/>
      <xsl:text>" if CONFIG_</xsl:text>
      <xsl:value-of select="name"/>
      <xsl:text>
&#9;&#9;default&#9;"</xsl:text>
      <xsl:choose>
        <xsl:when test="inst-version">
          <xsl:value-of select="inst-version"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="version"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>"

</xsl:text>
    </xsl:if>
    <xsl:if test="./module">
      <xsl:text>&#9;&#9;menuconfig&#9;MENU_</xsl:text>
      <xsl:value-of select="translate(name,' ()','___')"/>
      <xsl:text>
&#9;&#9;tristate&#9;"</xsl:text>
      <xsl:value-of select="name"/>
      <xsl:text>"
      &#9;&#9;default&#9;y if MENU_</xsl:text>
      <xsl:value-of select="../@id"/>
      <xsl:text> = y
&#9;&#9;default&#9;"</xsl:text>
      <xsl:value-of select="$default"/>
      <xsl:text>"

&#9;&#9;if&#9;MENU_</xsl:text>
      <xsl:value-of select="translate(name,' ()','___')"/>
      <xsl:text> != n

</xsl:text>
      <xsl:apply-templates select="module"/>
      <xsl:text>&#9;&#9;endif

</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="module">
    <xsl:variable name="default">
      <xsl:choose>
        <xsl:when test="inst-version">
          <xsl:text>y</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>n</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:text>&#9;&#9;&#9;config&#9;CONFIG_</xsl:text>
    <xsl:value-of select="name"/>
    <xsl:text>
&#9;&#9;&#9;bool&#9;"</xsl:text>
    <xsl:value-of select="name"/>
      <xsl:text>"
&#9;&#9;&#9;default&#9; y if MENU_</xsl:text>
      <xsl:value-of select="translate(../name,' ()','___')"/>
      <xsl:text> = y
&#9;&#9;&#9;default&#9;"</xsl:text>
    <xsl:value-of select="$default"/>
    <xsl:text>"
&#9;&#9;&#9;config&#9;VERSION_</xsl:text>
    <xsl:value-of select="name"/>
    <xsl:text>
&#9;&#9;&#9;string&#9;"Version of </xsl:text>
    <xsl:value-of select="name"/>
    <xsl:text>" if CONFIG_</xsl:text>
    <xsl:value-of select="name"/>
    <xsl:text>
&#9;&#9;&#9;default&#9;"</xsl:text>
    <xsl:choose>
      <xsl:when test="inst-version">
        <xsl:value-of select="inst-version"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="version"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>"

</xsl:text>
  </xsl:template>

</xsl:stylesheet>
