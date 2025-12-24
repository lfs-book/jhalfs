#!/bin/bash

#------
# Launch a menu containing all packages. Selected pacakges will
# be added to the tracking file, so that they will be considered
# "installed" (even if not!). Note that a package can also be removed
# from the tracking file if not selected. In other words, the
# resulting tracking file will only contain the selected packages.
# Initially, the packages already installed known to the system are
# selected in the menu.
# Usually, all LFS packages are supposed
# to be installed, so you can put "A" in the tick box of LFS
# packages. For BLFS packages, you'll have to select them
# individually, unless you are sure that all the packages in a
# menu are installed, in which case you can put a "A" in the menu
# tick box.
#------

# The tracking file is taken from Makefile in the same directory.
MYDIR=$( cd $(dirname $0); pwd )
if [ -f $MYDIR/Makefile ]; then
    TRACKING_DIR=$(sed -n 's/TRACKING_DIR[ ]*=[ ]*//p' $MYDIR/Makefile)
    TRACKFILE=${TRACKING_DIR}/instpkg.xml
else
    echo The directory where $0 resides does not contain a Makefile
    exit 1
fi
PACK_LIST="$MYDIR"/packages.xml
XSLDIR="$MYDIR"/xsl


# First generate "packages.xml".
make "$PACK_LIST"
# Generate a Kconfig file (named newpack.in)
xsltproc --nonet -o newpack.in ${XSLDIR}/gen_newpack.xsl ${PACK_LIST}
# Launch the menu
# First remove the existing .conf to be sure to get the defaults
rm -f newpack.conf
CONFIG_= KCONFIG_CONFIG=newpack.conf menu/menuconfig.py newpack.in
if ! [ -f newpack.conf ]; then
	echo Configuration was not saved. Exiting
	exit
fi
# Erase and initialize the tracking file:
cat >$TRACKFILE << EOF
<?xml version="1.0" encoding="ISO-8859-1"?>

<!DOCTYPE sublist SYSTEM "${MYDIR}/packdesc.dtd">
<sublist>
  <name>Installed</name>
</sublist>
EOF
# Populate the tracking file
sed -n 's/CONFIG_\([^=[:space:]]\+\)[[:space:]]*=[[:space:]]*y/\1/p' newpack.conf | while read pack; do
   version=$(sed -n s/VERSION_$pack'[[:space:]]*=[[:space:]"]*\([^"]*\).*/\1/p' newpack.conf)
   if [ -z "$version" ]; then version=N; fi # special value to use
                                            # the version in packages.xml
   # Add pack to trackfile
   xsltproc --stringparam packages "${PACK_LIST}" \
            --stringparam package "$pack" \
            --stringparam version "$version" \
            -o track.tmp "${XSLDIR}/bump.xsl" "$TRACKFILE"
   sed -i "s@PACKDESC@${MYDIR}/packdesc.dtd@" track.tmp
   xmllint --format --postvalid track.tmp > "$TRACKFILE"
done #while read pack
rm -f newpack.{in,conf} track.tmp
exit
