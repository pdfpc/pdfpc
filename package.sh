#!/bin/bash

# Create the relase tgz

VERSION=$1
TEMPDIR=`mktemp -d`
BASEDIR=`readlink -f $(dirname $0)`
cd $TEMPDIR

git clone $BASEDIR pdfpc-${VERSION}
cd pdfpc-${VERSION}
git submodule init
git submodule update
git checkout release
cd ..
rm -rf pdfpc-${VERSION}/cmake/Vala_CMake/.git
rm -rf pdfpc-${VERSION}/.git*
rm -f pdfpc-${VERSION}/.history
rm -rf pdfpc-${VERSION}/package.sh
rm -rf pdfpc-${VERSION}/create-c-src.sh
tar czvf pdfpc-${VERSION}.tgz pdfpc-${VERSION}/
mv pdfpc-${VERSION}.tgz $BASEDIR
rm -rf $TEMPDIR
