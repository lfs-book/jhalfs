<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

  <xsl:param name="list" select="''"/>
  <xsl:param name="MTA" select="'sendmail'"/>
  <xsl:param name="lfsbook" select="'lfs-full.xml'"/>

<!-- Check whether the book is sysv or systemd -->
  <xsl:variable name="rev">
    <xsl:choose>
      <xsl:when test="//bookinfo/title/phrase[@revision='systemd']">
        <xsl:text>systemd</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>sysv</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:output
    method="xml"
    encoding="ISO-8859-1"
    doctype-system="http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd"/>

  <xsl:include href="lfs_make_book.xsl"/>

  <xsl:template match="/">
    <book>
      <xsl:copy-of select="/book/bookinfo"/>
      <preface>
        <?dbhtml filename="preface.html"?>
        <title>Preface</title>
        <xsl:choose>
          <xsl:when test="$rev='sysv'">
            <xsl:copy-of select="id('bootscripts')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:copy-of select="id('systemd-units')"/>
          </xsl:otherwise>
        </xsl:choose>
      </preface>
      <chapter>
        <?dbhtml filename="chapter.html"?>
        <title>Installing packages in dependency build order</title>
        <xsl:call-template name="apply-list">
          <xsl:with-param name="list" select="normalize-space($list)"/>
        </xsl:call-template>
      </chapter>
      <xsl:copy-of select="id('CC')"/>
      <xsl:copy-of select="id('MIT')"/>
      <index/>
    </book>
  </xsl:template>

<!-- apply-templates for each item in the list.
     Normally, those items are id of nodes.
     Those nodes can be sect1 (normal case),
     sect2 (python/perl modules/dependencies )
     The templates after this one treat each of those cases.
     However, some items are sub-packages of compound packages (xorg7-*,
     xcb-utils, kf6, plasma), and not id.
     We need special instructions in that case.
     The difficulty is that some of those names *are* id's,
     because they are referenced in the index.
     Hopefully, none of those id's are sect{1,2}...
     We also need a special template for plasma-post-install,
     because this one is not an id at all!-->
  <xsl:template name="apply-list">
    <xsl:param name="list" select="''"/>
    <xsl:if test="string-length($list) &gt; 0">
      <xsl:choose>
        <!-- iterate if there are several packages in list -->
        <xsl:when test="contains($list,' ')">
          <xsl:call-template name="apply-list">
            <xsl:with-param name="list"
                            select="substring-before($list,' ')"/>
          </xsl:call-template>
          <xsl:call-template name="apply-list">
            <xsl:with-param name="list"
                            select="substring-after($list,' ')"/>
          </xsl:call-template>
        </xsl:when>
        <!-- From now on, $list contains only one package -->
        <!-- If it is a group, do nothing -->
        <xsl:when test="contains($list,'groupxx')"/>
        <xsl:otherwise>
          <xsl:variable name="is-lfs">
            <xsl:call-template name="detect-lfs">
              <xsl:with-param name="package" select="$list"/>
              <xsl:with-param name="lfsbook" select="$lfsbook"/>
            </xsl:call-template>
          </xsl:variable>
          <xsl:choose>
            <xsl:when test="$is-lfs='true'">
            <!-- LFS package -->
              <xsl:message>
                <xsl:value-of select="$list"/>
                <xsl:text> is an lfs package</xsl:text>
              </xsl:message>
              <xsl:call-template name="process-lfs">
                <xsl:with-param name="package" select="$list"/>
                <xsl:with-param name="lfsbook" select="$lfsbook"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:when test="contains(concat($list,' '),'-pass1 ')">
<!-- We need to do it for both sect1 and sect2, because of libva -->
              <xsl:variable
                   name="real-id"
                   select="substring-before(concat($list,' '),'-pass1 ')"/>
              <xsl:if test="id($real-id)[self::sect1]">
                <xsl:apply-templates select="id($real-id)" mode="pass1"/>
              </xsl:if>
              <xsl:if test="id($real-id)[self::sect2]">
                <xsl:apply-templates select="id($real-id)" mode="pass1-sect2"/>
              </xsl:if>
            </xsl:when>
            <xsl:when test="$list='plasma-post-install'">
              <xsl:apply-templates
                select="//sect1[@id='plasma-build']"
                mode="plasma-post-install"/>
            </xsl:when>
            <xsl:when test="not(id($list)[self::sect1 or self::sect2])">
              <!-- This is a sub-package: parse the corresponding compound
                   package. Note that the test for the content of literal
                   may return several compound packages. For example kf6
                   contains kwallet-<version> and plasma contains
                   kwallet-pam-<version>. Also breeze in plasma may also
                   match breeze-icons in kf. We could test that $list is
                   followed by -<digit> to make sure we have the right
                   package, but since we'll have to do that test anyway
                   later because there are also cases where packages start
                   the same in one cat command, let's not do complicate things
                   here. -->
              <xsl:apply-templates
                select="//sect1[(contains(@id,'xorg7') or
                                 contains(@id,'frameworks') or
                                 contains(@id,'plasma-build') or
                                 contains(@id,'xcb-utilities'))
                                 and .//userinput/literal[contains(string(),
                                            concat($list,'-'))]]"
                 mode="compound">
                <xsl:with-param name="package" select="$list"/>
              </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="id($list)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

<!-- The normal case : just copy to the book. Exceptions are if there
     is a xref, so use a special "mode" template -->
  <xsl:template match="sect1">
    <xsl:apply-templates select="." mode="sect1"/>
  </xsl:template>

  <xsl:template match="*" mode="pass1">
    <xsl:choose>
      <xsl:when test="self::xref">
        <xsl:choose>
          <xsl:when test="contains(concat(' ',normalize-space($list),' '),
                                   concat(' ',@linkend,' '))">
            <xsl:choose>
              <xsl:when test="@linkend='x-window-system' or @linkend='xorg7'">
                <xref linkend="xorg7-server"/>
              </xsl:when>
              <xsl:when test="@linkend='server-mail'">
                <xref linkend="{$MTA}"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="@linkend='bootscripts' or
                              @linkend='systemd-units'">
                <xsl:copy-of select="."/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@linkend"/> (in full book)
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@id">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
              <xsl:if test="name() = 'id'">-pass1</xsl:if>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="pass1"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test=".//xref | .//@id">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="pass1"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="pass1-sect2">
    <xsl:choose>
      <xsl:when test="self::sect2">
        <xsl:element name="sect1">
          <xsl:attribute name="id"><xsl:value-of select="@id"/>-pass1</xsl:attribute>
          <xsl:attribute name="xreflabel"><xsl:value-of select="@xreflabel"/></xsl:attribute>
          <xsl:processing-instruction name="dbhtml">filename="<xsl:value-of
                          select="@id"/>-pass1.html"</xsl:processing-instruction>
          <xsl:apply-templates mode="pass1-sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::sect3">
        <xsl:element name="sect2">
          <xsl:attribute name="role">
            <xsl:value-of select="@role"/>
          </xsl:attribute>
          <xsl:apply-templates mode="pass1-sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::bridgehead">
        <xsl:element name="bridgehead">
          <xsl:attribute name="renderas">
            <xsl:if test="@renderas='sect4'">sect3</xsl:if>
            <xsl:if test="@renderas='sect5'">sect4</xsl:if>
          </xsl:attribute>
          <xsl:value-of select='.'/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::xref">
        <xsl:choose>
          <xsl:when test="contains(concat(' ',normalize-space($list),' '),
                                   concat(' ',@linkend,' '))">
            <xsl:choose>
              <xsl:when test="@linkend='x-window-system' or @linkend='xorg7'">
                <xref linkend="xorg7-server"/>
              </xsl:when>
              <xsl:when test="@linkend='server-mail'">
                <xref linkend="{$MTA}"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="@linkend='bootscripts' or
                              @linkend='systemd-units'">
                <xsl:copy-of select="."/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@linkend"/> (in full book)
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@id">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
              <xsl:if test="name() = 'id'">-pass1</xsl:if>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="pass1-sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test=".//xref | .//@id">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="pass1-sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="processing-instruction()" mode="pass1">
    <xsl:variable name="pi-full" select="string()"/>
    <xsl:variable name="pi-value"
                  select="substring-after($pi-full,'filename=')"/>
    <xsl:variable name="filename"
                  select="substring-before(substring($pi-value,2),'.html')"/>
    <xsl:processing-instruction name="dbhtml">filename="<xsl:copy-of
                select="$filename"/>-pass1.html"</xsl:processing-instruction>
  </xsl:template>

  <xsl:template match="processing-instruction()" mode="sect1">
    <xsl:copy-of select="."/>
  </xsl:template>

<!-- Any node which has no xref descendant is copied verbatim. If there
     is an xref descendant, output the node and recurse. -->
  <xsl:template match="*" mode="sect1">
    <xsl:choose>
      <xsl:when test="self::xref">
        <xsl:choose>
          <xsl:when test="contains(concat(' ',normalize-space($list),' '),
                                   concat(' ',@linkend,' '))">
            <xsl:choose>
              <xsl:when test="@linkend='x-window-system' or @linkend='xorg7'">
                <xref linkend="xorg7-server"/>
              </xsl:when>
              <xsl:when test="@linkend='server-mail'">
                <xref linkend="{$MTA}"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="@linkend='bootscripts' or
                              @linkend='systemd-units'">
                <xsl:copy-of select="."/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="@linkend"/> (in full book)
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test=".//xref">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="sect1"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<!-- Python modules and DBus bindings -->
  <xsl:template match="sect2">
    <xsl:apply-templates select='.' mode="sect2"/>
  </xsl:template>

  <xsl:template match="*" mode="sect2">
    <xsl:choose>
      <xsl:when test="self::sect2">
        <xsl:element name="sect1">
          <xsl:attribute name="id"><xsl:value-of select="@id"/></xsl:attribute>
          <xsl:attribute name="xreflabel"><xsl:value-of select="@xreflabel"/></xsl:attribute>
          <xsl:processing-instruction name="dbhtml">filename="<xsl:value-of
                          select="@id"/>.html"</xsl:processing-instruction>
          <xsl:apply-templates mode="sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::sect3">
        <xsl:element name="sect2">
          <xsl:attribute name="role">
            <xsl:value-of select="@role"/>
          </xsl:attribute>
          <xsl:apply-templates mode="sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::bridgehead">
        <xsl:element name="bridgehead">
          <xsl:attribute name="renderas">
            <xsl:if test="@renderas='sect4'">sect3</xsl:if>
            <xsl:if test="@renderas='sect5'">sect4</xsl:if>
          </xsl:attribute>
          <xsl:value-of select='.'/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::xref">
        <xsl:choose>
          <xsl:when test="contains(concat(' ',normalize-space($list),' '),
                                   concat(' ',@linkend,' '))">
            <xsl:choose>
              <xsl:when test="@linkend='x-window-system' or @linkend='xorg7'">
                <xref linkend="xorg7-server"/>
              </xsl:when>
              <xsl:when test="@linkend='server-mail'">
                <xref linkend="{$MTA}"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="."/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@linkend"/> (in full book)
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test=".//xref">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="sect2"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<!-- Perl modules : transform them to minimal sect1. Use a template
     for installation instructions -->
  <xsl:template match="bridgehead">
  <xsl:if test="ancestor::sect1[@id='perl-modules']">
    <xsl:element name="sect1">
      <xsl:attribute name="id"><xsl:value-of select="./@id"/></xsl:attribute>
      <xsl:attribute name="xreflabel"><xsl:value-of select="./@xreflabel"/></xsl:attribute>
      <xsl:processing-instruction name="dbhtml">
     filename="<xsl:value-of select="@id"/>.html"</xsl:processing-instruction>
      <title><xsl:value-of select="./@xreflabel"/></title>
      <sect2 role="package">
        <title>Introduction to <xsl:value-of select="@id"/></title>
        <bridgehead renderas="sect3">Package Information</bridgehead>
        <itemizedlist spacing="compact">
          <listitem>
            <para>Download (HTTP): <xsl:copy-of select="./following-sibling::itemizedlist[1]/listitem/para/ulink"/></para>
          </listitem>
          <listitem>
            <para>Download (FTP): <ulink url=" "/></para>
          </listitem>
        </itemizedlist>
      </sect2>
      <xsl:choose>
        <xsl:when test="following-sibling::itemizedlist[1]//xref[@linkend='perl-standard-install'] | following-sibling::itemizedlist[1]/preceding-sibling::para//xref[@linkend='perl-standard-install']">
          <xsl:apply-templates mode="perl-install"  select="id('perl-standard-install')"/>
        </xsl:when>
        <xsl:otherwise>
          <sect2 role="installation">
            <title>Installation of <xsl:value-of select="@xreflabel"/></title>
            <para>Run the following commands:</para>
            <for-each select="following-sibling::bridgehead/preceding-sibling::screen[not(@role)]">
              <xsl:copy-of select="."/>
            </for-each>
            <para>Now, as the <systemitem class="username">root</systemitem> user:</para>
            <for-each select="following-sibling::bridgehead/preceding-sibling::screen[@role='root']">
              <xsl:copy-of select="."/>
            </for-each>
          </sect2>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:if>
  </xsl:template>

<!-- The case of depdendencies of perl modules. Same treatment
     as for perl modules. Just easier because always perl standard -->
  <xsl:template match="para">
    <xsl:element name="sect1">
      <xsl:attribute name="id"><xsl:value-of select="./@id"/></xsl:attribute>
      <xsl:attribute name="xreflabel"><xsl:value-of select="./@xreflabel"/></xsl:attribute>
      <xsl:processing-instruction name="dbhtml">filename="<xsl:value-of
     select="@id"/>.html"</xsl:processing-instruction>
      <title><xsl:value-of select="./@xreflabel"/></title>
      <sect2 role="package">
        <title>Introduction to <xsl:value-of select="@id"/></title>
        <bridgehead renderas="sect3">Package Information</bridgehead>
        <itemizedlist spacing="compact">
          <listitem>
            <para>Download (HTTP): <xsl:copy-of select="./ulink"/></para>
          </listitem>
          <listitem>
            <para>Download (FTP): <ulink url=" "/></para>
          </listitem>
        </itemizedlist>
      </sect2>
      <xsl:apply-templates mode="perl-install"  select="id('perl-standard-install')"/>
    </xsl:element>
  </xsl:template>

<!-- copy of the perl standard installation instructions:
     suppress id (otherwise not unique) and note (which we
     do not want to apply -->
  <xsl:template match="sect2" mode="perl-install">
    <sect2 role="installation">
      <xsl:for-each select="./*">
        <xsl:if test="not(self::note)">
          <xsl:copy-of select="."/>
        </xsl:if>
      </xsl:for-each>
    </sect2>
  </xsl:template>

<!-- we have gotten an xorg package (or xcb-utils or plasma or kf6).
     We are at the installation page
     but now we need to make an autonomous page from the global
     one -->
  <xsl:template match="sect1" mode="compound">
    <xsl:param name="package"/>
<!-- First get the line in the .md5 (.dat) file which contains
     ' '$package'-'<digit> and does not start with a hash (#)
     Note that this may be empty because of the selection of the
     sect1 -->
    <xsl:variable name="line">
      <xsl:call-template name="match-tarball">
        <xsl:with-param name="package" select="concat(' ',$package,'-')"/>
        <xsl:with-param name="cat-md5"
                        select="string(.//userinput[starts-with(string(),'cat ')])"/>
      </xsl:call-template>
    </xsl:variable>
<!-- If there is no match for ' '$package-<digit> in cat-md5, the
     line variable is empty. This may happen if there is a package
     "pkg" in one sect1 and "pkg-something" in another sect1, and the
     current element is the second sect1 while we want to match just
     "pkg". So only run the sequel if $line is not empty.-->
    <xsl:if test="$line!=''">
<!-- line is of the form "md5<space>download-dir<space>tarball"
     where download-dir is empty for anything other than xorg-legacy.
     So the same functions work in all cases.-->
      <xsl:variable name="md5sum" select="substring-before($line,' ')"/>
      <xsl:variable name="download-dir" select="substring-before(substring-after($line,' '),' ')"/>
      <xsl:variable name="tarball" select="substring-after(substring-after($line,' '),' ')"/>
      <!-- We extract install instructions from the userinput containing
           a loop. There is always one pushd and one popd command.
           Problem is there may be more than one popd (case of kapidox
           in kf6 and libpciaccess,libxkbfile in Xorg libraries). So we call
           a special template for providing instructions that work in
           all cases. -->
      <xsl:variable name="install-instructions">
        <xsl:call-template name="inst-instr">
          <xsl:with-param name="inst-instr"
            select=
              "substring-after(
                 substring-after(.//userinput[starts-with(string(),'for ') or
                                              starts-with(string(),'while ')],
                                 'pushd'),
                 '&#xA;')"/>
          <xsl:with-param name="package" select="$package"/>
        </xsl:call-template>
      </xsl:variable>
      <!-- Make a minimal sect1 with the data collected above. -->
      <xsl:element name="sect1">
        <xsl:attribute name="id">
          <xsl:value-of select="$package"/>
        </xsl:attribute>
        <xsl:processing-instruction name="dbhtml">
           filename="<xsl:value-of select='$package'/>.html"
        </xsl:processing-instruction>
        <title><xsl:value-of select="$package"/></title>
        <sect2 role="package">
          <title>Introduction to <xsl:value-of select="$package"/></title>
          <bridgehead renderas="sect3">Package Information</bridgehead>
          <itemizedlist spacing="compact">
            <listitem>
              <para>Download (HTTP): <xsl:element name="ulink">
                <xsl:attribute name="url">
                  <xsl:value-of
                     select=".//para[contains(string(),'(HTTP)')]/ulink/@url"/>
                  <xsl:value-of select="$download-dir"/>
                  <!-- $download-dir contains the trailing / for xorg,
                       but not for KDE... -->
                  <xsl:if test="contains(@id,'frameworks') or
                                contains(@id,'plasma')">
                    <xsl:text>/</xsl:text>
                  </xsl:if>
                  <!-- Some kf packages are in a subdirectory (not anymore,
                       but kept just in case...
                  <xsl:if test="$package='khtml' or
                                $package='kdelibs4support' or
                                $package='kdesignerplugin' or
                                $package='kdewebkit' or
                                $package='kjs' or
                                $package='kjsembed' or
                                $package='kmediaplayer' or
                                $package='kross' or
                                $package='kxmlrpcclient'">
                    <xsl:text>portingAids/</xsl:text>
                  </xsl:if>-->
                  <xsl:value-of select="$tarball"/>
                </xsl:attribute>
               </xsl:element>
              </para>
            </listitem>
            <!-- don't use FTP, although they are available for xorg -->
            <listitem>
              <para>Download (FTP): <ulink url=" "/>
              </para>
            </listitem>
            <listitem>
              <para>
                Download MD5 sum: <xsl:value-of select="$md5sum"/>
              </para>
            </listitem>
          </itemizedlist>
          <!-- If there is an additional download, we need to output that -->
          <xsl:if test=".//bridgehead[contains(string(),'Additional')]">
            <xsl:copy-of
                   select=".//bridgehead[contains(string(),'Additional')]"/>
            <xsl:copy-of
                   select=".//bridgehead[contains(string(),'Additional')]
                           /following-sibling::itemizedlist[1]"/>
          </xsl:if>
        </sect2>
        <sect2 role="installation">
          <title>Installation of <xsl:value-of select="$package"/></title>

          <para>
            First define a function that can be customized for package
            management:
          </para>

          <screen>
            <userinput>
              <xsl:copy-of select=".//userinput[contains(text(),
                                                         'as_root()')]/text()"/>
            </userinput>
          </screen>

          <para>
            Install <application><xsl:value-of select="$package"/></application>
            by running the following commands:
          </para>
          <!-- packagedir is used in xorg lib instructions
               Note that now plasma uses srcdir, but not in instructions. -->
          <screen><userinput>packagedir=<xsl:value-of
                      select="substring-before($tarball,'.tar.')"/>
           <!-- name is used in kf6 instructions -->
            <xsl:text>
name=$(echo $packagedir | sed 's/-[[:digit:]].*//')
</xsl:text>
            <xsl:copy-of select="$install-instructions"/>
          </userinput></screen>

        </sect2>
      </xsl:element><!-- sect1 -->
    </xsl:if>

  </xsl:template>

<!-- get the line matching $package<digit> in the text for
     the .md( (.dat) file. $package should begin with a space ' '
     and end with a dash '-'. We must exclude lines starting with
     a hash '#' too. -->
  <xsl:template name="match-tarball">
    <xsl:param name="package"/>
    <xsl:param name="cat-md5"/>
    <xsl:variable name="tarball"
                  select="substring-before(
                             substring-after(
                                $cat-md5,
                                substring-before(
                                   $cat-md5,
                                   $package
                                )
                             ),
                             '&#xA;'
                          )"/>
<!-- To get the line, we need to break at a linefeed, but just before
     the found tarball. So we backup 64 chars to be sure to be in the
     preceding line (64 chars is twice the length of a md5 hash). -->
    <xsl:variable name="cut"
    select="string-length(substring-before($cat-md5,$tarball)) - 64"/>
    <xsl:variable name="line"
                  select="substring-before(
                             substring-after(
                                substring($cat-md5,$cut),
                                '&#xA;'
                             ),
                             '&#xA;'
                          )"/>
    <xsl:choose>
      <!-- tarball may be empty when we have found no match. For example
           when the current element is plasma and package is kwallet.
           This can happen because the test for kwallet- matches
           kwallet-pam in plasma, while kwallet is in kf6.
           The test below fails so that we call again the tarball
           template, with a cat-md5 variable which does not contain
           kwallet. We just do nothing in this case. -->
      <xsl:when test="$tarball=''"/>
      <!-- This is the test for matching $package-<digit>. We
           change all digits to X in tarball (which also contains a space
           before), and in $package (because it may also contain
           digits). We then compare both strings.-->
      <xsl:when test="contains(translate($tarball,'0123456789',
                                                  'XXXXXXXXXX'),
                        concat(translate($package,'0123456789',
                                                  'XXXXXXXXXX'),'X')) and
                      not(starts-with($line,'#'))">
        <xsl:copy-of select="$line"/>
      </xsl:when>
      <xsl:otherwise><!-- this is not the right tarball -->
        <xsl:call-template name="match-tarball">
          <xsl:with-param name="package" select="$package"/>
          <xsl:with-param name="cat-md5"
                          select="substring-after($cat-md5,$tarball)"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="inst-instr">
    <!-- This template is necessary because of the "kapidox" case in kf6:
         Normally, the general instructions extract the package and change
         to the extracted dir for running the installation instructions.
         When installing a sub-package of a compound package, the installation
         instructions to be run are located between a pushd and a popd,
         *except* for kf6, where a popd occurs inside a
         case for kapidox...
         So we call this template with a "inst-instr" string that contains
         everything after the pushd.-->
    <xsl:param name="inst-instr"/>
    <xsl:param name="package"/>
    <xsl:choose>
      <!-- first the cases where there are two "popd"-->
      <xsl:when test="contains(substring-after($inst-instr,'popd'),'popd')">
        <xsl:choose>
          <xsl:when test="$package='kapidox'">
            <!-- only the instructions inside the "case" and before popd -->
            <xsl:copy-of select="substring-after(substring-before($inst-instr,'popd'),'kapidox)')"/>
          </xsl:when>
          <xsl:otherwise>
            <!-- We first copy what is before the first "popd", then what is
            after the first "popd", by calling the template again. -->
            <xsl:copy-of select="substring-before($inst-instr,'popd')"/>
            <xsl:call-template name="inst-instr">
              <xsl:with-param
                name="inst-instr"
                select="substring-after($inst-instr,'popd')"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <!-- normal case: everything that is before popd -->
        <xsl:copy-of select="substring-before($inst-instr,'popd')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="sect1" mode="plasma-post-install">
    <xsl:variable name="package" select="'plasma-post-install'"/>
    <xsl:element name="sect1">
      <xsl:attribute name="id">
        <xsl:value-of select="$package"/>
      </xsl:attribute>
      <xsl:processing-instruction name="dbhtml">
         filename="<xsl:value-of select='$package'/>.html"
      </xsl:processing-instruction>
      <title><xsl:value-of select="$package"/></title>
      <sect2 role="installation">
        <title>Installation of <xsl:value-of select="$package"/></title>

        <para>
          Install <application><xsl:value-of select="$package"/></application>
          by running the following commands as the
          <systemitem class="username">root</systemitem> user:
        </para>
<!--    <screen role="root">
          <userinput>
            <xsl:call-template name="plasma-sessions">
              <xsl:with-param
                name="p-sessions-text"
                select="string(.//userinput[contains(text(),'xsessions')])"/>
            </xsl:call-template>
          </userinput>
        </screen>-->
        <xsl:copy-of select=".//screen[@role='root']"/>
      </sect2>
    </xsl:element><!-- sect1 -->
  </xsl:template>
  <!--
  <xsl:template name="plasma-sessions">
    <xsl:param name="p-sessions-text"/>
    <xsl:choose>
      <xsl:when test="string-length($p-sessions-text)=0"/>
      <xsl:when test="contains($p-sessions-text,'as_root')">
        <xsl:call-template name="plasma-sessions">
          <xsl:with-param
            name="p-sessions-text"
            select="substring-before($p-sessions-text,'as_root')"/>
        </xsl:call-template>
        <xsl:call-template name="plasma-sessions">
          <xsl:with-param
            name="p-sessions-text"
            select="substring-after($p-sessions-text,'as_root ')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="$p-sessions-text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>-->

</xsl:stylesheet>
