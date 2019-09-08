#!/usr/bin/env bash

# This file is part of pdfpc.
#
# Copyright 2019 Andreas Bilke
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Steps to make this script working
#
# 0. - (if 2FA enabled): create personal access token in web interface
#    - Assign "repo" scope
# 1. - Add credentials to .netrc file
#    - $ cat ~/.netrc
#      machine api.github.com
#      login <username>
#      password <personal access token>
#
#      machine uploads.github.com
#      login <username>
#      password <personal access token>
# 2. - create git tag for release, push it to remote

set -e
set -f
set -u

if [ $# -ne 1 ]; then
    echo "Usage: $0 <tag-name>" >&2
    exit 1
fi


if ! [ $( git tag -l "$1" ) ]; then
    echo "tag $1 not found" >&2
    exit 1
fi

function create_demo_assets() {
    cd demo/
    make

    cd pdfpc-video-example
    make

    cd ../../
}

function create_release() {
    API_URL=$1
    TAG_NAME=$2

    curl --basic --netrc -s -H "Content-Type: application/json" --data "
    {
        \"tag_name\": \"$TAG_NAME\",
        \"name\": \"$TAG_NAME\",
        \"body\": \"Release of $TAG_NAME\"
    }
    " $API_URL | jq -r ".id"
}

function attach_asset() {
    API_URL=$1

    curl --basic --netrc -H "Content-Type: application/pdf" --data-binary @demo/pdfpc-demo.pdf "$API_URL?name=pdfpc-demo.pdf" > /dev/null
    curl --basic --netrc -H "Content-Type: application/zip" --data-binary @demo/pdfpc-video-example/video-example.zip "$API_URL?name=pdfpc-video-example.zip" > /dev/null
}

TAG_NAME=$1

API_BASE="https://api.github.com/repos/pdfpc/pdfpc/releases"
UPLOAD_BASE="https://uploads.github.com/repos/pdfpc/pdfpc/releases"

create_demo_assets
RELEASE_ID=$( create_release "$API_BASE" "$TAG_NAME" )
attach_asset "$UPLOAD_BASE/$RELEASE_ID/assets"
