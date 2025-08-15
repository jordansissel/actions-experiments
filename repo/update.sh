#!/bin/sh

# docker build repo -t repotest 
# rm -fr /tmp/gpgtest; mkdir /tmp/gpgtest; sh gpg/generate-key.sh foo@example.com | gpg --homedir /tmp/gpgtest --import --batch
# docker run -it --volume ./:/code:z --volume /tmp/gpgtest:/root/.gnupg:z --volume /tmp/repository:/repository:z --volume /tmp/tmp.qF53h3XBZR:/inbox:z repotest sh -c 'cd /code; sh repo/update.sh /inbox /repository'

set -e 

add() {
  inbox="$1"
  workdir="$2"

  if [ ! -d "$inbox" ] ; then
    echo "add: inbox path must be a directory: $inbox"
    exit 1
  fi

  if [ ! -d "$workdir" ] ; then
    echo "add: workdir must be a directory: $workdir"
    exit 1
  fi

  metadata="$1/package.json"
  system_id="$(jq -r '.distro' < $metadata)"
  system_version="$(jq -r '.version' < $metadata)"
  system_codename="$(jq -r '.codename' < $metadata)"

  source="$(find "$1" -name '*.rpm' -o -name '*.deb')"
  sourcefile="$(basename "$source")"

  echo "[ $system_id $system_version ] Processing package: ${source}"

  KEY_ID="$(gpg --list-keys --list-options show-only-fpr-mbox | cut -f1 -d' ')"

  case "$system_id" in
    debian|ubuntu)
      repo="$workdir/$system_id"
      prepare_repo "$metadata" "$repo"

      echo "=> Signing deb"
      debsigs -v --gpgopts="--batch --no-tty --pinentry-mode=loopback" --sign=origin --default-key="$KEY_ID" "$source" || exit 1

      # reprepro includedeb will copy the file into the repo for us
      # The path is based in the package name, like: pool/f/foo/foo_123_all.deb
      destination="$repo/pool/$(printf %c $sourcefile)/${sourcefile%%_*}/$sourcefile"

      if [ -f "$destination" ] ; then
        echo "Cannot proceed, this package already exists in the repository: $destination"
        echo "::error ::The package already exists in the $system_id $system_version repository: $sourcefile (as $destination)"
        exit 1
      fi

      if ! reprepro -Vb "$repo" includedeb "$system_codename" "$source" ; then
        echo "::error ::reprepro failed on $repo"
        exit 1
      fi
      ;;
    rocky|almalinux|fedora)
      repo="$workdir/$system_id/$system_version"
      [ ! -d "$workdir/$system_id" ] && mkdir "$workdir/$system_id"
      prepare_repo "$metadata" "$repo"

      [ ! -d "$repo/packages" ] && mkdir -p "$repo/packages"

      destination="$repo/packages/$sourcefile"

      if [ -f "$destination" ] ; then
        echo "Cannot proceed, this package already exists in the repository: $destination"
        echo "::error ::The package already exists in the $system_id $system_version repository: $sourcefile (as $destination)"
        ls -ld "$destination"
        exit 1
      else
        cp -v --preserve=timestamps "$source"  "$destination"
      fi

      echo "=> Signing RPM"
      rpmsign --verbose --define "%__gpg /usr/bin/gpg" --define "%_gpg_name $KEY_ID" --addsign "$destination"
      
      if ! createrepo_c -v "$repo" ; then
        echo "Problem: createrepo failed on repo: $repo"
        echo "::error ::createrepo failed on $repo"
        exit 1
      fi
      ;;
    *)
      echo "Problem: Unexpected distro name: $system_id"
      cat $metadata
      exit 1
      ;;
  esac
}

prepare_repo() {
  metadata="$1"
  repo="$2"

  if [ "$#" -ne 2 -o -z "$1" -o -z "$2" ] ; then
    echo "Usage: <prepare_repo> path/to/package.json path/to/repo/base"
    exit 1
  fi

  if [ ! -f "$metadata" ] ; then
    echo "prepare_repo: metadata file does not exist: $metadata"
    exit 1
  fi

  if [ ! -d "$repo" ] ; then
    if [ ! -d "$(dirname "$repo")" ] ; then
      echo "prepare_repo: repo path must be in an existing directory: $(dirname "$repo")"
      exit 1
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
        ) >> "$repo/conf/distributions" || exit 1
      fi
      ;;
  esac
} # prepare

check_gpg() {
  keycount="$(gpg --list-keys --list-options show-only-fpr-mbox | wc -l)"
  if [ "$keycount" -ne 1 ] ; then
    echo "GPG is not configured correctly. Got $keycount keys, need exactly 1"
    echo "Is GNUPGHOME set? Current value: $GNUPGHOME"
    exit 1
  fi
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
  echo ">> $metadata"
  files="$(jq -r '.files' < $metadata)"
  system_id="$(jq -r '.system_id' < $metadata)"
  system_version="$(jq -r '.system_version' < $metadata)"
  system_codename="$(jq -r '.system_codename' < $metadata)"

  add "$(dirname "$metadata")" "$workdir"

  #echo "* $name - Added to repository: $files" >> $GITHUB_STEP_SUMMARY
done