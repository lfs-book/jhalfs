#!/bin/bash

#-------------------------------------------------------------------------
# generates an xsl stylesheet containing a template for special
# cases in the book:
#  - If the version does not begin with a number, it is impossible to know
#    where the package name ends and where the version begins. We therefore
#    use the ENTITY at the beginning of the validated full-xml.
#  - If a package is part of a group of xorg packages (proto, fonts, etc)
#    there is no easy way to extract it from the xml. We use the ENTITY at
#    the top of each file x7*.xml
#  - Some non-versioned packages are needed as dependencies of others: we
#    attribute version 1.0.0 to them. It is just used to know if the package
#    is installed, by checking inst-version.
#  - If a package is versioned but the version is not mentioned in the book
#    (currently only udev), we retrieve the version by other means
#-------------------------------------------------------------------------
# Arguments:
# $1 contains the name of the validated xml book
# $2 contains the name of the ouput xsl file
# $3 contains the name of the book sources directory
#-------------------------------------------------------------------------

BLFS_XML=$1
if ! test -f ${BLFS_XML}; then
  echo File \`${BLFS_XML}\' does not exist
  exit 1
fi
SPECIAL_FILE=$2
if test -z "${SPECIAL_FILE}"; then SPECIAL_FILE=specialCases.xsl;fi
BLFS_DIR=$3
if test -z "${BLFS_DIR}"; then BLFS_DIR=$(cd $(dirname ${BLFS_XML})/.. ; pwd);fi

# Packages whose version does not begin with a number
EXCEPTIONS=$(grep 'ENTITY.*version[ ]*"[^0-9"&.].*[0-9]' ${BLFS_DIR}/packages.ent |
             sed 's@^[^"]*"\([^"]*\)".*@\1@')

# Non-versioned packages:
NV_LIST="postlfs-config-profile postlfs-config-random postlfs-config-vimrc \
initramfs xorg-env kde-pre-install-config kf6-intro \
lxqt-post-install ojdk-conf tex-path"
# lxqt-pre-install does not contain any instruction

cat >$SPECIAL_FILE << EOF
<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0">

<xsl:template match='*' mode="special">
  <xsl:choose>
<!-- Although versioned, this page is not a package. But
     the sect2 with id "xorg-env" is referred to at several
     places in the book. We have added it to the list of non
     versioned packages. -->
    <xsl:when test="@id='xorg7'">
      <xsl:apply-templates select="child::sect2" mode="special"/>
    </xsl:when>
EOF

# Non-versionned packages. Add to NV_LIST if you need more.
for nv_id in $NV_LIST; do
# Actually, kf6-intro and tex-path contain some version info, so should be
# versioned. For other packages, we define version to 1.0.0
# because the DTD needs a version tag.
  DUM_VER=1.0.0
  if [ $nv_id = kf6-intro ]; then
    DUM_VER=$(grep kf6-version $BLFS_DIR/packages.ent | \
              sed 's/[^"]*"\([^"]*\).*/\1/')
  fi
  if [ $nv_id = tex-path ]; then
    DUM_VER=$(grep texlive-year $BLFS_DIR/packages.ent | \
              sed 's/[^"]*"\([^"]*\).*/\1/')
  fi
  cat >>$SPECIAL_FILE << EOF
    <xsl:when test="@id='$nv_id'">
      <xsl:text>      </xsl:text>
      <package><xsl:text>&#xA;        </xsl:text>
        <xsl:element name="name">$nv_id</xsl:element>
        <xsl:text>&#xA;        </xsl:text>
        <xsl:element name="version">$DUM_VER</xsl:element>
        <xsl:if
            test="document(\$installed-packages)//package[name=current()/@id]">
          <xsl:text>&#xA;        </xsl:text>
          <xsl:element name="inst-version">
            <xsl:value-of
              select="document(\$installed-packages
                              )//package[name=current()/@id]/version"/>
          </xsl:element>
        </xsl:if>
<!-- Dependencies -->
        <xsl:apply-templates select=".//para[@role='required' or
                                             @role='recommended' or
                                             @role='optional']"
                             mode="dependency"/>
<!-- End dependencies -->
        <xsl:text>&#xA;      </xsl:text>
      </package><xsl:text>&#xA;</xsl:text>
    </xsl:when>
EOF
done

# Taking packages contained in pages installing several packages (x7* except
# x7driver, xcb-utilities, kf6-frameworks, and plasma-all), as versionned
# modules. We also write a dependency expansion when a dep is of the form
# xorg7-something or xcb-utils or kf6-frameworks or plasma-build.
# Since that is another
# template, we need a temporary file, which we shall concatenate at the end
cat >tmpfile << EOF
  <xsl:template name="expand-deps">
    <xsl:param name="section"/>
    <xsl:param name="status"/>
    <xsl:param name="build"/>
    <xsl:choose>
EOF
for file in $(ls ${BLFS_DIR}/x/installing/x7* | grep -v x7driver) \
	    ${BLFS_DIR}/kde/kf6/kf6-frameworks.xml                \
            ${BLFS_DIR}/kde/plasma/plasma-all.xml                \
            ${BLFS_DIR}/x/installing/xcb-utilities.xml; do
  id=$(grep xreflabel $file | sed 's@.*id="\([^"]*\).*@\1@')
  cat >>$SPECIAL_FILE << EOF
    <xsl:when test="@id='$id'">
      <xsl:text>      </xsl:text>
      <package><xsl:text>&#xA;        </xsl:text>
        <xsl:element name="name">$id</xsl:element>
        <xsl:text>&#xA;        </xsl:text>
EOF
  cat >> tmpfile << EOF
      <xsl:when test="\$section='$id'">
EOF

# We extract the list of packages for those pages from
# the "cat" command that creates the md5 file. We assume
# that the preceding package is a dependency of the following,
# except the first.
# note that some pages may have several "cat" command, so we have to
# make a complex regex for the first line to save. All those lines have
# .md5 in them except the one for x7legacy that has .dat.
# we need also to remove lines beginning with #.
# Note that only xorg pages have '&' in them. So for kde
# pages, what is extracted it the full tarball name.
  list_cat="$(sed -n '/>cat.*\.\(md5\|dat\)/,/EOF</p' $file | \
              grep -v '>cat\|EOF<\|#' | \
              awk '{ print $NF }' | sed 's/-&.*//')"

  precpack=NONE
  for pack in $list_cat; do
# plasma-activities-* are in kf-apps, so remove them from plasma.
# the test is for any compound actually, but prevents another test
# anyway.
    if [ "${pack#plasma-activities}" != "$pack" ]; then continue; fi
    if grep -q -E 'x7|xcb' $file; then # this is an xorg package
      packname=$pack
# We extract the version from the ENTITY parts of the .xml file.
      packversion=$(grep "ENTITY ${pack}-version" $file | \
	            sed 's@[^"]*"\([^"]*\).*@\1@')
    else
      packname=${pack%-[[:digit:]]*}
      packversion=$(echo $pack | sed 's/[^.]*-\([.[:digit:]]*\)\.tar.*/\1/')
    fi
    cat >>$SPECIAL_FILE << EOF
        <module><xsl:text>&#xA;          </xsl:text>
          <xsl:element name="name">$packname</xsl:element>
          <xsl:element name="version">$packversion</xsl:element>
          <xsl:if test="document(\$installed-packages)//package[name='$packname']">
            <xsl:element name="inst-version">
              <xsl:value-of
                select="document(\$installed-packages
                                )//package[name='$packname']/version"/>
            </xsl:element>
          </xsl:if>
<!-- Dependencies -->
EOF
    if test $precpack != NONE; then
      cat >>$SPECIAL_FILE << EOF
          <xsl:element name="dependency">
            <xsl:attribute name="status">required</xsl:attribute>
            <xsl:attribute name="build">before</xsl:attribute>
            <xsl:attribute name="name">$precpack</xsl:attribute>
            <xsl:attribute name="type">ref</xsl:attribute>
          </xsl:element>
EOF
    else
      cat >>$SPECIAL_FILE << EOF
          <xsl:apply-templates select=".//para[@role='required' or
                                               @role='recommended' or
                                               @role='optional']"
                               mode="dependency"/>
EOF
# we have to add plasma-activities* to plasma dependencies
# Also we add a runtime dep on plasma-post-install, in case a user
# changes the defaults in the "plasma" package (untick plasma-post-install
# which is ticked by default).
      if [ $(basename $file .xml) = plasma-all ]; then
        cat >>$SPECIAL_FILE << EOF
          <xsl:element name="dependency">
            <xsl:attribute name="status">required</xsl:attribute>
            <xsl:attribute name="build">before</xsl:attribute>
            <xsl:attribute name="name">plasma-activities</xsl:attribute>
            <xsl:attribute name="type">ref</xsl:attribute>
          </xsl:element>
          <xsl:element name="dependency">
            <xsl:attribute name="status">required</xsl:attribute>
            <xsl:attribute name="build">before</xsl:attribute>
            <xsl:attribute name="name">plasma-activities-stats</xsl:attribute>
            <xsl:attribute name="type">ref</xsl:attribute>
          </xsl:element>
          <xsl:element name="dependency">
            <xsl:attribute name="status">required</xsl:attribute>
            <xsl:attribute name="build">after</xsl:attribute>
            <xsl:attribute name="name">plasma-post-install</xsl:attribute>
            <xsl:attribute name="type">ref</xsl:attribute>
          </xsl:element>
EOF
      fi
    fi
    cat >>$SPECIAL_FILE << EOF
<!-- End dependencies -->
        </module>
EOF
#    cat >> tmpfile << EOF
#        <xsl:element name="dependency">
#          <xsl:attribute name="status">
#            <xsl:value-of select="\$status"/>
#          </xsl:attribute>
#          <xsl:attribute name="build">
#            <xsl:value-of select="\$build"/>
#          </xsl:attribute>
#          <xsl:attribute name="name">$packname</xsl:attribute>
#          <xsl:attribute name="type">ref</xsl:attribute>
#        </xsl:element>
#EOF
    precpack=$packname
  done
# We need a dummy package for plasma post install instructions
  if [ $(basename $file .xml) = plasma-all ]; then
    cat >>$SPECIAL_FILE << EOF
        <module><xsl:text>&#xA;          </xsl:text>
          <xsl:element name="name">plasma-post-install</xsl:element>
          <xsl:element name="version">1.0.0</xsl:element>
          <xsl:if test="document(\$installed-packages)//package[name='plasma-post-install']">
            <xsl:element name="inst-version">
              <xsl:value-of
                select="document(\$installed-packages
                                )//package[name='plasma-post-install']/version"/>
            </xsl:element>
          </xsl:if>
<!-- Dependencies -->
          <xsl:element name="dependency">
            <xsl:attribute name="status">required</xsl:attribute>
            <xsl:attribute name="build">before</xsl:attribute>
            <xsl:attribute name="name">$precpack</xsl:attribute>
            <xsl:attribute name="type">ref</xsl:attribute>
          </xsl:element>
<!-- End dependencies -->
        </module>
EOF
  fi

  cat >>$SPECIAL_FILE << EOF
     </package>
   </xsl:when>
EOF
  cat >> tmpfile << EOF
        <xsl:element name="dependency">
          <xsl:attribute name="status">
            <xsl:value-of select="\$status"/>
          </xsl:attribute>
          <xsl:attribute name="build">
            <xsl:value-of select="\$build"/>
          </xsl:attribute>
          <xsl:attribute name="name">$packname</xsl:attribute>
          <xsl:attribute name="type">ref</xsl:attribute>
        </xsl:element>
      </xsl:when>
EOF
done

for ver_ent in $EXCEPTIONS; do
  id=$(grep 'xreflabel=".*'$ver_ent $BLFS_XML | sed 's@.*id="\([^"]*\)".*@\1@')
  [[ -z $id ]] && continue
  cat >>$SPECIAL_FILE << EOF
    <xsl:when test="@id='$id'">
<!-- if there is a sect1 ancestor, we have a module -->
      <xsl:choose>
        <xsl:when test="ancestor::sect1">
          <xsl:text>        </xsl:text>
          <module><xsl:text>&#xA;          </xsl:text>
            <xsl:element name="name">$id</xsl:element>
            <xsl:text>&#xA;          </xsl:text>
            <xsl:element name="version">$ver_ent</xsl:element>
            <xsl:if
                test="document(\$installed-packages)//package[name=current()/@id]">
              <xsl:text>&#xA;          </xsl:text>
              <xsl:element name="inst-version">
                <xsl:value-of
                  select="document(\$installed-packages
                                  )//package[name=current()/@id]/version"/>
              </xsl:element>
            </xsl:if>
<!-- Dependencies -->
            <xsl:apply-templates select=".//para[@role='required' or
                                                 @role='recommended' or
                                                 @role='optional']"
                                 mode="dependency"/>
<!-- End dependencies -->
            <xsl:text>&#xA;        </xsl:text>
          </module><xsl:text>&#xA;</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>      </xsl:text>
          <package><xsl:text>&#xA;        </xsl:text>
            <xsl:element name="name">$id</xsl:element>
            <xsl:text>&#xA;        </xsl:text>
            <xsl:element name="version">$ver_ent</xsl:element>
            <xsl:if
                test="document(\$installed-packages)//package[name=current()/@id]">
              <xsl:text>&#xA;        </xsl:text>
              <xsl:element name="inst-version">
                <xsl:value-of
                  select="document(\$installed-packages
                                  )//package[name=current()/@id]/version"/>
              </xsl:element>
            </xsl:if>
<!-- Dependencies -->
            <xsl:apply-templates select=".//para[@role='required' or
                                                 @role='recommended' or
                                                 @role='optional']"
                                 mode="dependency"/>
<!-- End dependencies -->
            <xsl:text>&#xA;      </xsl:text>
          </package><xsl:text>&#xA;</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
EOF
done

cat >>$SPECIAL_FILE << EOF
    <xsl:otherwise>
        <xsl:apply-templates
           select="self::node()[contains(translate(@xreflabel,
                                                  '123456789',
                                                  '000000000'),
                                         '-0')
                               ]"
           mode="normal"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
EOF
cat $SPECIAL_FILE tmpfile > tmpfile1
mv tmpfile1 $SPECIAL_FILE
rm tmpfile
cat >> $SPECIAL_FILE << EOF
    <xsl:otherwise>
      <xsl:message>
        <xsl:text>You should not be seeing this</xsl:text>
      </xsl:message>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
</xsl:stylesheet>
EOF
