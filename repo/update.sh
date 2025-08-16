#!/bin/sh

set -e 

fail() {
  echo "Failure: $@"
  [ ! -z "$GITHUB_OUTPUT" ] && echo "::error ::Failure: $@"
  exit 1
}

add() {
  inbox="$1"
  workdir="$2"

  if [ ! -d "$inbox" ] ; then
    fail "add: inbox path must be a directory: $inbox"
  fi

  if [ ! -d "$workdir" ] ; then
    fail "add: workdir must be a directory: $workdir"
  fi

  metadata="$1/package.json"
  system_id="$(jq -r '.distro' < $metadata)"
  system_version="$(jq -r '.version' < $metadata)"
  system_codename="$(jq -r '.codename' < $metadata)"
  architecture="$(jq -r '.architecture' < $metadata)"

  source="$(find "$1" -name '*.rpm' -o -name '*.deb')"
  sourcefile="$(basename "$source")"

  echo "[ $system_id $system_version ] Processing package: ${source}"

  KEY_ID="$(gpg --list-keys --list-options show-only-fpr-mbox | cut -f1 -d' ')"

  case "$system_id" in
    debian|ubuntu)
      repo="$workdir/$system_id"
      prepare_repo "$metadata" "$repo"

      echo "=> Signing deb"
      debsigs -v --gpgopts="--batch --no-tty --pinentry-mode=loopback" --sign=origin --default-key="$KEY_ID" "$source" || fail "debsigs failed"

      # reprepro includedeb will copy the file into the repo for us
      # The path is based in the package name, like: pool/f/foo/foo_123_all.deb
      destination="$repo/pool/$(printf %c $sourcefile)/${sourcefile%%_*}/$sourcefile"

      if [ -f "$destination" ] ; then
        fail "Cannot proceed, this package ($sourcefile) already exists in the $system_id $system_version repository: $destination"
      fi

      if ! reprepro -Vb "$repo" includedeb "$system_codename" "$source" ; then
        fail "reprepro failed on $repo"
      fi
      ;;
    rocky|almalinux|fedora)
      repo="$workdir/$system_id/$system_version/stable/$architecture"
      [ ! -d "$repo" ] && mkdir -p "$repo"

      prepare_repo "$metadata" "$repo"

      name="$(rpm -qp "$source" --qf "%{Name}")"
      destination="$repo/pool/$(printf %c $name)/${name}/$sourcefile"

      if [ ! -d "$(dirname "$destination")" ] ; then
        mkdir -p "$(dirname "$destination")"
      fi

      if [ -f "$destination" ] ; then
        fail "::error ::The package already exists in the $system_id $system_version repository: $sourcefile (as $destination)"
      else
        cp -v --preserve=timestamps "$source"  "$destination"
      fi

      echo "=> Signing RPM"
      # Set %__gpg because rpmsign on ubuntu defaults to /usr/bin/gpg2 which doesn't exist.
      rpmsign --verbose --define "%__gpg /usr/bin/gpg" --define "%_gpg_name $KEY_ID" --addsign "$destination"
      
      if ! createrepo_c -v "$repo" ; then
        fail "Problem: createrepo failed on repo: $repo"
      fi
      ;;
    *)
      cat $metadata
      fail "Problem: Unexpected distro name: $system_id"
      ;;
  esac
}

prepare_repo() {
  metadata="$1"
  repo="$2"

  if [ "$#" -ne 2 -o -z "$1" -o -z "$2" ] ; then
    fail "Usage: <prepare_repo> path/to/package.json path/to/repo/base"
  fi

  if [ ! -f "$metadata" ] ; then
    fail "prepare_repo: metadata file does not exist: $metadata"
  fi

  if [ ! -d "$repo" ] ; then
    if [ ! -d "$(dirname "$repo")" ] ; then
      fail "prepare_repo: repo path must be in an existing directory: $(dirname "$repo")"
    fi
    mkdir "$repo"
  fi

  system_id="$(jq -r '.distro' < $metadata)"
  system_version="$(jq -r '.version' < $metadata)"
  system_codename="$(jq -r '.codename' < $metadata)"

  case "$system_id" in
    debian|ubuntu)
      if ! grep -qxF "Codename: $system_codename" "$repo/conf/distributions" ; then
        [ ! -d "$repo/conf" ] && mkdir -p "$repo/conf"
        echo "=> Adding new codename to $system_id repo: $system_codename"

        KEY_ID="$(gpg --list-keys --list-options show-only-fpr-mbox | cut -f1 -d' ')"
        # Add the codename to the distributions file
        (
          echo "Codename: $system_codename"
          echo "Architectures: amd64 arm64 i386"
          echo "Components: main"
          echo "Suite: stable"
          echo "SignWith: $KEY_ID"
          echo "Origin: the fpm project"
          echo "Label: fpm"
          echo "Description: fpm"
          echo
        ) >> "$repo/conf/distributions" || fail "Failed writing $repo/conf/distributions"
      fi
      ;;
  esac
} # prepare

check_gpg() {
  keycount="$(gpg --list-keys --list-options show-only-fpr-mbox | wc -l)"
  if [ "$keycount" -ne 1 ] ; then
    fail "GPG is not configured correctly. Got $keycount keys, need exactly 1. Is GNUPGHOME set? Current value: $GNUPGHOME"
  fi
}

process() {
  metadata="$1"
  [ -z "$metadata" ] && fail "process() called with no arguments"

  echo ">> $metadata"
  files="$(jq -r '.files' < $metadata)"
  system_id="$(jq -r '.system_id' < $metadata)"
  system_version="$(jq -r '.system_version' < $metadata)"
  system_codename="$(jq -r '.system_codename' < $metadata)"
  add "$(dirname "$metadata")" "$workdir"
}

#echo "# Package Repository Updates" >> $GITHUB_STEP_SUMMARY

inbox="$1"
workdir="$2"

if [ "$#" -ne 2 ] ; then
  echo "Usage: $0 inboxdir workdir"
  echo
  echo "  inboxdir: A directory containing one or more subdirectories containing rpms/debs and package.json files"
  echo "  workdir: The base directory of the repository space to perform the work"
  exit 1
fi

check_gpg

for metadata in "$inbox"/*/package.json ; do
  process "$metadata"
done

gpg --list-keys --list-options show-only-fpr-mbox | cut -f1 -d' ' > $workdir/gpg.pub