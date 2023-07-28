#!/usr/bin/env bash

version=$( head -n 1 ../src/pdfpc.version )
cat << EOF > pdfpc_version.nsh
!define PDFPC_VERSION "$version"
EOF