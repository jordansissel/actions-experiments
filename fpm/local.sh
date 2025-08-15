#!/bin/sh

set -e

echo "Dirname: $(dirname "$0")"
if [ "$(dirname "$0")" != "." ] ; then
  echo "cd"
  cd "$(dirname "$0")"
fi


export WORKDIR="${RUNNER_TEMP:-$(mktemp -d)}"

build_images() {
  # Build all the linux packages
  docker buildx bake --metadata-file "$WORKDIR/metadata.json"
}

extract_packages() {
  jq < "$WORKDIR/metadata.json" -r 'to_entries[] | "\(.key) \(.value["containerimage.digest"])"' \
  | xargs -P4 -n2 sh -c 'mkdir "$WORKDIR/$1" && docker run "$2" sh -c "cd target; tar -zc *" | tar -zx -C "$WORKDIR/$1"' -
}

cleanup() {
  rm "$WORKDIR"/fpm-*/{fpm*,package.json}
  rm "$WORKDIR"/metadata.json
  rmdir "$WORKDIR"/fpm-*
  rmdir "$WORKDIR"
}

build_images

extract_packages

#cleanup

find "$WORKDIR"