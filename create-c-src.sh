#!/bin/zsh

# *Very* ad-hoc script for creating the C sources, which can also be
# parametrized with cmake (INSTALL_PREFIX and SYSCONFDIR) 

CBUILDTMP=`mktemp -d`
BASEDIR=`readlink -f $(dirname $0)`

function parametrizedFiles() {
    VAR=$1
    files=(`grep -l $VAR **/*.c`)
    for f in $files; do
        echo $f
        sed -i "s:/$VAR:$VAR:g" $f
        mv $f ${f/.c/.in}
        sed -i "/BEGIN_CONFIGURE_FILES/ a\
CONFIGURE_FILE(\$\{CMAKE_CURRENT_SOURCE_DIR\}/${f/.c/.in} \$\{CMAKE_CURRENT_SOURCE_DIR}/$f)" CMakeLists.txt
    done
}

cd $BASEDIR
git checkout master

cd $CBUILDTMP
cmake -DCMAKE_INSTALL_PREFIX="/@CMAKE_INSTALL_PREFIX@" -DSYSCONFDIR="/@SYSCONFDIR@" $BASEDIR
cd $BASEDIR 
rm -rf $CBUILDTMP
git checkout release
find src -name '*.vala' | xargs valac -b src -d c-src --pkg gtk+-2.0 --pkg poppler-glib --pkg posix --pkg librsvg-2.0 --pkg gee-1.0 -C --header=c-src/presenter.h --internal-header=c-src/presenter_internal.h
cd c-src
rm paths.c

# Modify the CMakeLists.txt for parametrized files
# Cleanup if we have something
sed -i '/BEGIN_CONFIGURE_FILES/,/END_CONFIGURE_FILES/ {
        /BEGIN_CONFIGURE_FILES/n
        /END_CONFIGURE_FILES/ !{d}
    }' CMakeLists.txt
parametrizedFiles @CMAKE_INSTALL_PREFIX@
parametrizedFiles @SYSCONFDIR@
