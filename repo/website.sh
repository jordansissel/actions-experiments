#!/bin/sh

fail() {
    echo "$@"
    exit 1
}

set -e 

workdir="$1"
[ -z "$workdir" ] && fail "Missing argument for work directory"

base="$(dirname "$0")"
html="$(dirname "$0")"/../html

cd "$html"
docker run --volume "$PWD:/srv/jekyll:z" --volume "$workdir:/workdir:z" jekyll/minimal jekyll build -d "/workdir"