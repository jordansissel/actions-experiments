#!/bin/sh

set -e

if [ -z "$1" ] ; then
  echo "Usage: $0 <email>" >&2
  echo >&2
  echo "This will create a new pgp key for the given email" >&2
  echo "and will output the public and private keys" >&2
  exit 1
fi

tmp="$(mktemp -d)"

email="$1"

# Generate a never-expiring key
gpg --homedir "$tmp" --quiet --batch \
  --passphrase '' --pinentry-mode loopback \
  --quick-generate-key "$email" default default never

gpg --homedir "$tmp" --armor --export "$email"
echo

gpg --homedir "$tmp" --armor --export-secret-keys "$email"
echo

rm -r "$tmp/openpgp-revocs.d"
rm -r "$tmp/private-keys-v1.d"
rm "$tmp/pubring.kbx"
rm "$tmp/pubring.kbx~"
rm "$tmp/trustdb.gpg"
rmdir "$tmp"
