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
  docker buildx bake --metadata-file "$WORKDIR/metadata.json" default repotool
}

extract_packages() {
  echo "Extracting Artifacts"
  echo "Dir: $ARTIFACTSDIR"
  ls -ld $ARTIFACTSDIR

  jq < "$WORKDIR/metadata.json" -r 'to_entries[] | select(.value["containerimage.digest"] != null and .key != "repotool") | "\(.key) \(.value["containerimage.digest"])"' \
  | ARTIFACTSDIR="$ARTIFACTSDIR" xargs -P4 -n2 sh -c 'mkdir "$ARTIFACTSDIR/$1"; ls -ld "$ARTIFACTSDIR/$1"; docker run --user="$(id -u):$(id -g)" --volume "$ARTIFACTSDIR/$1:/out:z" "$2" sh -c "cp /tmp/target/* /out"' -
}

verify_packages() {
  jq < "$WORKDIR/metadata.json" -r 'to_entries[] | select(.value["containerimage.digest"] != null and .key != "repotool") | "\(.key) \(.value["containerimage.digest"])"' \
  | xargs -P4 -n2 sh -c 'docker run --volume "./verify.sh:/tmp/verify.sh:z" "$2" sh -c "ls -1d /tmp/target/*.rpm /tmp/target/*.deb 2> /dev/null | xargs -n1 sh /tmp/verify.sh"' -
}

cleanup() {
  rm "$ARTIFACTSDIR"/fpm-*/{fpm*,package.json}
  rm "$ARTIFACTSDIR"/metadata.json
  rmdir "$ARTIFACTSDIR"/fpm-*
  rmdir "$ARTIFACTSDIR"
}

build_repo() {
  [ ! -d "$WORKDIR/web" ] && mkdir "$WORKDIR/web"
  [ ! -d "$WORKDIR/web/packages" ] && mkdir "$WORKDIR/web/packages"
  [ ! -d "$WORKDIR/gpg" ] && mkdir "$WORKDIR/gpg"

  # Generate a throw-away key for signing packages.
  sh ../gpg/generate-key.sh foo@example.com | gpg --homedir "$WORKDIR/gpg" --import 

  docker run \
    --user "$(id -u):$(id -g)" \
    --volume "$ARTIFACTSDIR:/artifacts:z" \
    --volume "$WORKDIR/gpg:/gpg:z" \
    --env GNUPGHOME=/gpg \
    --volume "$WORKDIR/web:/web:z" fpm-repotool:latest sh -c 'sh /tmp/update.sh /artifacts /web/packages'
}

build_web() {
  [ ! -d "$WORKDIR/web" ] && mkdir "$WORKDIR/web"
  sh ../repo/website.sh ../html "$WORKDIR/web"
}

build_images

extract_packages

verify_packages

build_repo

build_web

#cleanup
