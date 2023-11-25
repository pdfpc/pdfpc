#!/bin/bash

# Windows packaging script. This does the following:
# 1. Run "install" target from CMake into setup folder
# 2. Copy runtime dependencies into setup folder
# 3. Create version file and execute NSIS to create installer

set -e

# go to script directory
cd $(dirname $(readlink -f "$0"))
# delete old setup, if there
echo "clean dist folder"

setup_dir=dist

rm -rf "$setup_dir"
rm -rf pdfpc-setup.exe

mkdir "$setup_dir"
mkdir "$setup_dir"/lib
mkdir -p ../build

echo "copy installed files"
(cd ../build && cmake .. -DMDVIEW=OFF -DCMAKE_MAKE_PROGRAM=ninja -DCMAKE_BUILD_TYPE=Release -DMOVIES=ON -DCMAKE_INSTALL_PREFIX= && DESTDIR=../windows-setup/"$setup_dir" cmake --build . --target install)

echo $(pwd)
echo "copy libraries"
ldd ../build/bin/pdfpc.exe | grep '\/mingw.*\.dll' -o | sort -u | xargs -I{} cp "{}" "$setup_dir"/bin/

echo "copy pixbuf libs"
cp -r /mingw64/lib/gdk-pixbuf-2.0 "$setup_dir"/lib/

echo "copy pixbuf lib dependencies"
ldd /mingw64/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.dll | grep '\/mingw.*\.dll' -o | xargs -I{} cp "{}" "$setup_dir"/bin/

echo "copy icons"
cp -r /mingw64/share/icons "$setup_dir"/share/

echo "copy glib shared"
cp -r /mingw64/share/glib-2.0 "$setup_dir"/share/

echo "copy poppler shared"
cp -r /mingw64/share/poppler "$setup_dir"/share/

echo "copy gspawn-win64-helper"
cp /mingw64/bin/gspawn-win64-helper.exe "$setup_dir"/bin
cp /mingw64/bin/gspawn-win64-helper-console.exe "$setup_dir"/bin

echo "copy gdbus"
cp /mingw64/bin/gdbus.exe "$setup_dir"/bin

echo "create installer"
bash make_version_nsh.sh
"/c/Program Files (x86)/NSIS/Bin/makensis.exe" pdfpc.nsi

echo "finished"