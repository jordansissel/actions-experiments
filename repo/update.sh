
add() {
  inbox="$1"
  workdir="$2"

  metadata="$1/package.json"
  system_id="$(jq -r '.distro' < $artifact)"
  system_version="$(jq -r '.version' < $artifact)"
  system_codename="$(jq -r '.codename' < $artifact)"

  source="$(find "$1" -name '*.rpm' -o -name '*.deb')"

  echo "[ $system_id $system_version ] Processing package: ${source}"


  case "$system_id" in
    debian|ubuntu)
      repo="$workdir/$system_id"
      prepare_repo "$metadata" "$repo"

      echo "=> Signing deb"
      debsigs -v --gpgopts="--batch --no-tty --pinentry-mode=loopback" --sign=origin --default-key="$KEY_ID" "$source" || exit 1

      # reprepro includedeb will copy the file into the repo for us
      # The path is based in the package name, like: pool/f/foo/foo_123_all.deb
      destination="$repo/pool/$(printf %c $files)/${files%%_*}/$files"

      if [ -f "$destination" ] ; then
        echo "Cannot proceed, this package already exists in the repository: $destination"
        echo "::error ::The package already exists in the $system_id $system_version repository: $files (as $destination)"
        exit 1
      fi

      if ! reprepro -Vb "$repo" includedeb "$system_codename" "$source" ; then
        echo "::error ::reprepro failed on $repo"
        exit 1
      fi
      ;;
    rocky|almalinux|fedora)
      repo="repository/${system_id}/${system_version}"

      [ ! -d "$repo/packages" ] && mkdir -p "$repo/packages"

      destination="$repo/packages/$files"
      if [ -f "$destination" ] ; then
        echo "::error ::The package already exists in the $system_id $system_version repository: $files (as $destination)"
        exit 1
      else
        cp -v --preserve=timestamps "$source"  "$destination"
      fi

      echo "=> Signing RPM"
      rpmsign --verbose --define "%_gpg_name $KEY_ID" --addsign "$destination"
      
      if ! createrepo_c -v "$repo" ; then
        echo "Problem: createrepo failed on repo: $repo"
        echo "::error ::createrepo failed on $repo"
        exit 1
      fi
      ;;
    *)
      echo "Problem: Unexpected distro name: $system_id"
      cat $artifact
      exit 1
      ;;
  esac
}

prepare_repo() {
  metadata="$1"
  repo="$2"

  system_id="$(jq -r '.distro' < $artifact)"
  system_version="$(jq -r '.version' < $artifact)"
  system_codename="$(jq -r '.codename' < $artifact)"

  case "$system_id" in
    debian|ubuntu)
      if ! grep -qxF "Codename: $system_codename" "$repo/conf/distributions" ; then
        [ ! -d "$repo/conf" ] && mkdir -p "$repo/conf"
        echo "=> Adding new codename to $system_id repo: $system_codename"

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

echo "# Package Repository Updates" >> $GITHUB_STEP_SUMMARY

inbox="$1"
workdir="$2"

if [ "$#" -ne 2 ] ; then
  echo "Usage: $0 inboxdir workdir"
  echo
  echo "  inboxdir: A directory containing one or more subdirectories containing rpms/debs and package.json files"
  echo "  workdir: The base directory of the repository space to perform the work"
  exit 1
fi

for artifact in "${RUNNER_TEMP}/artifacts/"*/package.json ; do
  files="$(jq -r '.files' < $artifact)"
  system_id="$(jq -r '.system_id' < $artifact)"
  system_version="$(jq -r '.system_version' < $artifact)"
  system_codename="$(jq -r '.system_codename' < $artifact)"

  source="$(dirname "$artifact")/${files}"

  add "$(dirname "$artifact")" 
  inbox="$1"
  workdir="$2"

  echo "* $name - Added to repository: $files" >> $GITHUB_STEP_SUMMARY
done