#!/usr/bin/env bash

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
    make all clean

    cd pdfpc-video-example
    make all clean

    zip -j ../pdfpc-video-example.zip video-example.pdf video-example.tex apollo17.avi apollo17.jpg
    cd ../../
}

function create_release() {
    API_URL=$1
    TAG_NAME=$2

    curl --data <<<EOF
    {
        "tag_name": "$TAG_NAME",
        "name": "$TAG_NAME",
        "body": "Release of $TAG_NAME"
    }
    EOF $API_URL | jq -r ".id"
}

function attach_asset() {
    API_URL=$1

    curl --data-binary @demo/pdfpc-demo.pdf "$API_URL?name=pdfpc-demo.pdf" > /dev/null
    curl --data-binary @demo/pdfpc-video-example.zip "$API_URL?name=pdfpc-video-example.zip" > /dev/null
}

TAG_NAME=$1

GITHUB_API_BASE="https://api.github.com"
API_BASE="$GITHUB_API_BASE/repos/pdfpc/pdfpc/releases"

create_demo_assets
RELEASE_ID=$( create_release "$API_BASE" "$TAG_NAME" )
attach_asset "$API_BASE/$RELEASE_ID/assets"
