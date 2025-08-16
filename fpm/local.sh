#!/bin/sh

# rm -fr /tmp/gpgtest; mkdir /tmp/gpgtest; sh gpg/generate-key.sh foo@example.com | gpg --homedir /tmp/gpgtest --import --batch
# docker build repo -t repotest 
# docker run -it --volume ./:/code:z --volume /tmp/gpgtest:/root/.gnupg:z --volume /tmp/repository:/repository:z --volume /tmp/z/artifacts:/inbox:z repotest sh -c 'cd /code; sh repo/update.sh /inbox /repository'

set -e

echo "Dirname: $(dirname "$0")"

if [ "$(dirname "$0")" != "." ] ; then
  echo "cd"
  cd "$(dirname "$0")"
fi

WORKDIR="${RUNNER_TEMP:-$(mktemp -d)}"
ARTIFACTSDIR="$WORKDIR/artifacts"

mkdir "$ARTIFACTSDIR"

build_images() {
  # Build all the linux packages
  docker buildx bake --metadata-file "$WORKDIR/metadata.json"
}

extract_packages() {
  #jq < "$WORKDIR/metadata.json" -r 'to_entries[] | "\(.key) \(.value["containerimage.digest"])"' \
  jq < "$WORKDIR/metadata.json" -r 'to_entries[] | select(.value["containerimage.digest"] != null) | "\(.key) \(.value["containerimage.digest"])"' \
  | ARTIFACTSDIR="$ARTIFACTSDIR" xargs -P4 -n2 sh -c 'mkdir "$ARTIFACTSDIR/$1" && docker run "$2" sh -c "cd target; tar -zc *" | tar -zx -C "$ARTIFACTSDIR/$1"' -
}

cleanup() {
  rm "$ARTIFACTSDIR"/fpm-*/{fpm*,package.json}
  rm "$ARTIFACTSDIR"/metadata.json
  rmdir "$ARTIFACTSDIR"/fpm-*
  rmdir "$ARTIFACTSDIR"
}

build_repo() {
  [ ! -d "$WORKDIR/repo" ] && mkdir "$WORKDIR/repo"
  sh ../repo/update.sh "$ARTIFACTSDIR" "$WORKDIR/repo"
}

build_images
extract_packages
build_repo

#cleanup